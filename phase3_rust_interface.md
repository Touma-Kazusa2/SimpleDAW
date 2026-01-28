# Phase3 Rust Interface Plan (GDExtension)

## Goals
- Audio/playback is independent from UI and ProjectModel so UI hitches do not affect sound.
- Keep a stable facade API so the editor/UI does not change when the engine moves to Rust.
- Support future AudioServer output and per-track soundfont or sampler routing.

---

## Proposed Godot API (GDScript-facing)

Class: `DawEngine` (GDExtension, Object or Node)

Required methods:
```
# lifecycle
func configure(sample_rate: float, buffer_size: int) -> void
func set_snapshot(snapshot: PackedByteArray) -> void
func set_routes(routes: Array) -> void # optional if routes baked into snapshot
func clear() -> void

# transport
func play(from_beats: float) -> void
func pause() -> void
func resume() -> void
func stop() -> void
func seek(to_beats: float) -> void
func is_playing() -> bool
func get_playhead_beats() -> float

# edits (optional in Phase3)
func push_deltas(deltas: PackedByteArray) -> void
```

Signals (optional):
```
signal finished
signal playhead_changed(time_beats: float)
```

Notes:
- `set_snapshot` is the primary path. Snapshot should be immutable once submitted.
- `push_deltas` is optional. If provided, it should be RT-safe and bounded.

---

## Snapshot Data Format (PackedByteArray)

Binary format is preferred for speed and to avoid Dictionary/Variant overhead.

### Header
```
struct SnapshotHeader {
  u32 version;
  u32 event_count;
  u32 note_range_count;
  u32 cc_count;
  u32 program_count;
  u32 tempo_count;
  u32 route_count;
}
```

### Events (sorted by time, stable ordering)
```
struct Event {
  f32 time_beats;
  u8  kind;        // 0=note_on,1=note_off,2=cc,3=program
  u8  channel;     // 0..15
  u8  pitch;       // note events
  u8  velocity;    // note_on
  u8  cc;          // cc events
  u8  value;       // cc value 0..127
  u8  program;     // program change
  u8  player_id;   // route index or player slot
}
```

### Note Ranges (for chase and reconcile)
```
struct NoteRange {
  f32 start_beats;
  f32 end_beats;
  u8  channel;
  u8  pitch;
  u8  velocity;
  u8  player_id;
}
```

### Tempo Events
```
struct TempoEvent {
  f32 time_beats;
  f32 bpm;
}
```

### Routes (optional if you embed player_id in events)
```
struct Route {
  u8  player_id;
  u8  channel;
  u32 soundfont_id;  // or hash; 0 means default
}
```

Notes:
- If `player_id` is embedded in every event, route table can be optional.
- Snapshot builder in GDScript can emit PackedByteArray, then Phase3 can move this builder to Rust.

---

## Rust Engine Core (Phase3)

Core components:
- `EngineCore`: event cursor, active notes, chase, tempo map, playhead advance.
- `SnapshotStore`: owns the current immutable snapshot and exposes read-only slices.
- `Scheduler`: pulls events per buffer window and outputs to sink.
- `Sink`: Phase3 target, either AudioServer output or MIDI synth.

RT rules:
- No allocations in the audio callback path.
- All swaps are atomic pointer swaps (Arc to Snapshot).
- All large allocations happen off the audio thread.

---

## Output Options

Option A (intermediate):
- Rust schedules events and pushes to a lock-free queue.
- Main thread drains queue and feeds Godot MidiPlayer.
- Pros: quick, reuse existing synth.
- Cons: still not fully RT-safe; main thread can jitter.

Option B (target):
- Rust does full synthesis and writes to AudioServer (AudioStreamGenerator or custom driver).
- Pros: true decoupling from UI; stable timing.
- Cons: more work, but is the long-term correct path.

---

## Migration Steps

1) Freeze GDScript facade API
   - Keep `PlaybackEngine` API stable (play/pause/seek/set_snapshot).
   - Ensure snapshot format is fixed and versioned.

2) Add PackedByteArray snapshot export (GDScript)
   - Implement `SnapshotBuilder.to_bytes()` in GDScript.
   - Keep the Dictionary path for debugging only.

3) Implement Rust `DawEngine` (no audio yet)
   - Parse snapshot bytes.
   - Run scheduling and chase logic.
   - Expose `get_playhead_beats` and `is_playing`.

4) Replace GDScript EngineCore with Rust core
   - `PlaybackEngine` becomes a thin wrapper that forwards calls to Rust.

5) Choose output path
   - Option A: Rust -> queue -> MidiPlayer (short-term).
   - Option B: Rust synth -> AudioServer (target).

6) Move snapshot builder to Rust (optional)
   - Provide direct MIDI import to Rust snapshot to skip GDScript build cost.

---

## Prompt for Future Phase3 Work

"You are implementing Phase3 for SimpleDAW. Replace the GDScript playback core with a Rust GDExtension class `DawEngine` that accepts a PackedByteArray snapshot and exposes play/pause/seek APIs matching the current PlaybackEngine. Preserve snapshot semantics (events, note ranges, cc, program, tempo). Avoid allocating in the audio path. Provide a minimal GDScript wrapper that forwards calls and keeps UI code unchanged."
