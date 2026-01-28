# AGENTS.md

## Purpose
- Provide project-specific rules for automated edits and reviews in this repo.

## Encoding
- Use UTF-8 for all file reads/writes and when running PowerShell commands (e.g., `Get-Content -Encoding UTF8`, `Set-Content -Encoding UTF8`).
- If a file appears garbled, re-read it explicitly as UTF-8 before editing.

## Project Overview
- Main scene: `simple_daw.tscn` (set in `project.godot`).
- Core orchestration: `scripts/simple_daw.gd` (UI wiring, slots, selection bar, playback, import/export).
- Playback engine: `scripts/playback_engine.gd` (real-time event scheduling/chase; uses `scripts/engine_core.gd`, `scripts/engine_snapshot_builder.gd`, `scripts/midi_player_sink.gd`).
- Piano roll module: `piano_roll.tscn` with `scripts/main.gd`, `scripts/input_controller.gd`, `scripts/notes_model.gd`, `scripts/notes_view.gd`, `scripts/grid.gd`, `scripts/playhead.gd`, `scripts/piano_keyboard.gd`.
- Multi-panel slot: `scripts/panel_slot.gd` (mode switching, scroll sync, arrangement, 3D, comment/envelope).
- Arrangement timeline: `scripts/arrangement_lane.gd`.
- Envelope/comment lanes: `scripts/envelope_lane.gd`, `scripts/comment_lane.gd`, model in `scripts/envelope_model.gd`.
- Data models: `scripts/models/*` (project/track/clip/automation/transport).
- MIDI IO: `scripts/midi_importer.gd`, `scripts/midi_exporter.gd`, plugin in `addons/midi/*`.
- Soundfont routing: `scripts/soundfont_manager.gd` (per-track soundfont -> shared bank/player routing).
- 3D panel: `scripts/three_d_panel.gd`.

## Maintenance
- After code changes, consider whether the Project Overview needs updates (new files, renamed files, new entry points).
- If the overview changes materially, update both `AGENTS.md` and `AGENTS中文.md`.

## Editing
- Prefer minimal, targeted changes; avoid reformatting unrelated code.
- Keep comments concise and only when they add clarity.
- Preserve existing style and conventions unless instructed otherwise.
- After the user confirms requirements, state the planned change points and files before editing.

## Safety
- Do not run destructive commands unless explicitly requested.
- Do not remove or revert unrelated user changes.

## Testing
- If you run tests, state which command was used and the result.
- If you did not run tests, say so and why.

## Sync Rule
- Whenever `AGENTS.md` is modified, update `AGENTS中文.md` to match (create it if missing).
