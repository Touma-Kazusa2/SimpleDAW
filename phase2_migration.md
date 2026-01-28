# Phase2 Plan (RT-Friendly Architecture) — Interface Sketch + Migration Steps

## Goals
- Define stable engine boundaries so Phase3 becomes a mostly drop-in implementation swap.
- Keep behavior identical while moving heavy work off the main thread where possible.
- Ensure UI/editor only talks to the engine via a small, fixed API.

---

## Target Architecture (Phase2)

### Core Concepts
- **EngineFacade** (main-thread orchestrator): owns Play/Stop/Seek and dispatches to EngineCore.
- **EngineCore** (logic core): state machine + event scheduling; RT-friendly data layout.
- **Snapshot** (immutable model view): compact, sorted data arrays (notes, CC, tempo map).
- **EventQueue** (optional): UI edits enqueued as deltas (SPSC style), applied by EngineCore.
- **EventSink**: outputs events (current: MidiPlayerSink). In Phase3, replace with native sink.

### Data Flow (UI -> Engine)
- UI edits -> build new Snapshot OR push delta commands
- EngineCore swaps snapshot atomically (or at safe boundary)
- EngineCore schedules events based on playhead and tempo map

### Data Flow (Engine -> Output)
- EngineCore emits events to EventSink
- EventSink translates to MidiPlayer (Phase2), or AudioServer/GDExtension (Phase3)

---

## Interface Sketch (GDScript)

### EngineFacade (scripts/playback_engine.gd or new)
```
# EngineFacade API
func set_project_model(model: Node) -> void
func set_output_sink(sink: Node) -> void
func set_track_router(router: Node) -> void
func set_snapshot(snapshot: Dictionary) -> void
func push_edit(delta: Dictionary) -> void  # optional
func play(from_beats: float) -> void
func pause() -> void
func resume() -> void
func stop() -> void
func seek(to_beats: float) -> void
func set_playback_target(mode: String, track_index: int, clip_index: int) -> void
```

### EngineCore (new)
```
# EngineCore API
func set_snapshot(snapshot: Dictionary) -> void
func apply_deltas(deltas: Array) -> void
func process(delta_seconds: float) -> Array  # returns events for sink
func seek(to_beats: float) -> Array          # returns chase events for sink
```

### Snapshot (new data format)
```
{
  "notes": [ {"t": float, "d": float, "p": int, "v": int, "track": int, "clip": int}, ... ],
  "cc":    [ {"t": float, "cc": int, "val": int, "track": int}, ... ],
  "program": [ {"t": float, "pg": int, "track": int}, ... ],
  "tempo": [ {"t": float, "bpm": float}, ... ],
  "arr":   [ {"track": int, "clip": int, "start": float, "len": float}, ... ]
}
```

### EventSink (Phase2)
```
# MidiPlayerSink
func emit_events(events: Array) -> void
func send_all_notes_off() -> void
```

---

## Migration Steps (Phase2)

1) **Create new data builders**
   - Add `scripts/engine_snapshot_builder.gd`
   - Build compact arrays from project_model (tracks/clips/arrangement)

2) **Split EngineFacade vs EngineCore**
   - Keep current `PlaybackEngine` as Facade
   - Move scheduling and chasing logic into EngineCore (pure logic, no Node access)

3) **Introduce EventSink**
   - Wrap MidiPlayer into `MidiPlayerSink` with emit_events/all_notes_off
   - Facade routes scheduled events into sink

4) **Define stable API**
   - UI only calls Facade methods: play/pause/seek/set_snapshot
   - Replace direct reads of project_model during playback with Snapshot

5) **Optional: delta queue**
   - Add lock-free-ish queue in GDScript (array + single writer/reader)
   - Only if live edits need to apply without snapshot rebuild

6) **Thread heavy tasks**
   - Snapshot building for big projects runs in Thread
   - Swap in result on main thread when ready

7) **Validation**
   - Ensure same behavior: play/seek, chase, edit during playback

---

## Prompt for Future Implementation

Use this prompt when starting Phase2 work to ensure consistent direction:

"You are continuing Phase2 (RT-friendly architecture) for SimpleDAW. The goal is to freeze the engine API so Phase3 becomes a drop-in swap with minimal UI changes. Implement EngineSnapshotBuilder, EngineCore, and MidiPlayerSink as defined in `phase2_migration.md`. Replace PlaybackEngine internals to use snapshots instead of live project_model access, while preserving current playback behavior (play/seek/chase). Do not change UI behavior. Keep all heavy work off the main thread where feasible."

---

## Notes
- This Phase2 does NOT move scheduling into AudioServer; it prepares the interface to do so later.
- Phase3 replaces EngineCore + EventSink with GDExtension implementations while leaving UI/Facade intact.
