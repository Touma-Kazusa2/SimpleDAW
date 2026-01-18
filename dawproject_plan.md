# SimpleDAW -> DAWPROJECT Plan (Roll = Clip, Multi-Track)

## Goal
Export SimpleDAW projects into a valid, minimal DAWPROJECT file.
Assume export first; import can come later.

## Current State (short)
- notes_model.gd: notes list (pitch/start/duration/velocity)
- envelope_model.gd: automation points (no target/parameter yet)
- main.gd: bpm, beats_per_measure, playhead, view state
- simple_daw.gd: multi-roll UI, panel switching, meta on roll nodes
- comment_lane.gd: comments UI (range text)

## Mapping (minimal, Roll = Clip, Multi-Track)
- Project -> Transport -> Track (multiple) -> Arrangement -> Clips -> Clip -> Notes -> Note
- Automation -> AutomationTarget + Points (RealParameter)
- Comments -> Markers (use start time; store end in text or ignore end)
- Roll tab -> Clip (within selected track)

## Architecture Adjustments
1) Add a data layer separate from UI.
2) Use IDs and referenceable objects (for DAWPROJECT links).
3) Keep UI nodes as views that edit the data layer.

Suggested models:
- ProjectModel: metadata, transport, tracks
- TransportModel: tempo, time signature
- TrackModel: name, channel/program (optional), clip list
- ClipModel: start_time, length, notes, automation, comments
- AutomationModel: target_id, points

## Step-by-step Plan
Phase 0 - Decide scope and mapping
- Define time units (beats) and ID scheme (stable IDs).
- Decide how comments map to Markers.
- Decide clip start/length defaults (start at 0, length = visible_beats).
- Decide track mapping rules (MIDI Track -> split by its channels, no cross-track merge).
- Pick MIDI parsing approach (library vs custom) and confirm how meta events are handled.

Phase 1 - Data layer
- Add Project/Track/Clip/Transport models.
- Move notes/envelope/comments into ClipModel.
- Provide change signals for UI to listen to.
- Add TrackModel list and stable track IDs.

Phase 2 - UI -> data wiring
- Add track selection UI (minimal list or dropdown).
- Map each Roll tab to one ClipModel in the selected track.
- InputController edits ClipModel.notes instead of roll-local arrays.
- Envelope/Comment panels read ClipModel automation/comments.

Phase 2.5 - MIDI import mapping (if required)
- Parse SMF with chosen library.
- For each MIDI Track, split events by channel into TrackModel(s).
- Build one Clip per split-track (start=0, length=last event).

Phase 3 - Arrangement timeline (minimal)
- Store clip start time and length (default start=0).
- Keep per-track clip lists under a single Arrangement container.

Phase 4 - DAWPROJECT export (minimum valid)
- Write project.xml with Project/Transport/Track/Arrangement/Clip/Notes.
- Export automation as RealParameter with Points.
- Export comments as Markers (point at start time).
- Package into .dawproject container if required by the spec.

Phase 5 - Validation
- Validate XML with the reference.
- Test import in a DAW that supports DAWPROJECT.
- Fix missing required fields iteratively.

Phase 6 - Optional import
- Parse project.xml into models.
- Rebuild rolls from ClipModel notes and automation.

## Hard Parts / Risks
- Mapping automation targets (need stable parameter IDs).
- Comments are ranges; Markers are points (need a convention).
- Track mapping rules (MIDI track vs channel) must be consistent.
- Packaging rules (project.xml + assets) must match spec.

## Recommended Choice
- Roll = Clip, multi-track by MIDI track.
- Keep DAWPROJECT export minimal: notes + tempo + markers.
