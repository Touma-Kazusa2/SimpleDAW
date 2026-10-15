# SimpleDAW (Godot)

Lightweight, beginner-friendly DAW built on a piano roll foundation. Focused on analysis-first workflows.

## Controls
- Left click: create note (1 beat)
- Right click: delete note
- Space: play/pause
- Home: stop and reset playhead
- Ctrl + Mouse Wheel: horizontal zoom (pixels per beat)
- Middle drag (vertical): vertical zoom (key height)
- Mouse Wheel: horizontal scroll
- Shift + Mouse Wheel: vertical scroll
- Arrow keys: scroll (prints scroll state)
- G: toggle snap on/off
- K: add 4 measures to length
- L: toggle velocity edit mode (drag velocity bar)

## Files
- `piano_roll.tscn`: Piano roll scene layout and node tree
- `project.godot`: Godot project settings
- `assets/blue_noise_128.png`: Blue noise texture used for UI grain
- `scripts/main.gd`: Global parameters, layout, scrolling, zoom, play/pause, input wiring
- `scripts/grid.gd`: Grid drawing (time and pitch lines)
- `scripts/notes_model.gd`: Notes data model (pitch/start/duration/velocity)
- `scripts/notes_view.gd`: Note rendering, swell animation, velocity bars, text labels
- `scripts/input_controller.gd`: Input handling for creation, drag, resize, playhead, velocity edit, snap
- `scripts/playhead.gd`: Playhead rendering
- `scripts/piano_keyboard.gd`: Keyboard rendering with labels and vertical scroll sync
- `scripts/note_palette.gd`: Note name/color mapping
- `scripts/input_debug_overlay.gd`: Optional input debug overlay

## Notes
- Velocity is stored as 0-127.
- Snap is off by default; toggle with G.
- Notes that extend past the current length will automatically add 4 measures.
- Vertical scrolling appears once key height makes content taller than the view.
- Note creation snaps to whole beats by design (even with snap off).

## License

The original SimpleDAW source code is available under either of these licenses:

- [Apache License 2.0](LICENSE-APACHE)
- [MIT License](LICENSE-MIT)

You may choose either license when using or redistributing the project. Third-party components and assets keep their own licenses: the MIDI addon is MIT licensed (`addons/midi/LICENSE.txt`), and the Lucid icon set is released under CC0 1.0 (`Lucid V1.2/License`). SoundFont files are not included in the repository and may have separate redistribution terms.
