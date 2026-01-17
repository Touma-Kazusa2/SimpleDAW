extends Node

const DEBUG_LOGS := false

signal debug_click(local_pos: Vector2)
signal playhead_drag_started
signal playhead_time_changed(time_beats: float)
signal length_extend_requested(required_beats: float)

@export var debug_enabled: bool = false

var model: Node = null
var roll_content: Control = null

var pixels_per_beat: float = 120.0
var key_height: float = 16.0
var min_pitch: int = 36
var max_pitch: int = 96
var visible_beats: int = 32
var playhead_time_beats: float = 0.0

const MIN_DURATION_BEATS := 0.25
const RESIZE_HANDLE_PX := 6.0
const SNAP_STEPS := [1.0, 0.5, 0.25, 0.125, 0.0]

var is_dragging_note: bool = false
var is_dragging_playhead: bool = false
var drag_note_index: int = -1
var drag_mode: String = ""
var drag_offset: Vector2 = Vector2.ZERO
var drag_note_start: float = 0.0
var drag_note_pitch: int = 0
var drag_note_duration: float = 0.0
var snap_step_index: int = 0
var velocity_mode: bool = false
var is_dragging_velocity: bool = false
var drag_velocity_index: int = -1
var snap_enabled: bool = false

func setup(notes_model: Node, roll_root: Control) -> void:
	model = notes_model
	roll_content = roll_root

func _on_roll_gui_input(event: InputEvent) -> void:
	if roll_content == null or model == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			pass
		else:
			var hit = _find_note_at(event.position)
			if hit["index"] != -1:
				model.delete_note(hit["index"])
				roll_content.accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local_pos = event.position
			if debug_enabled:
				emit_signal("debug_click", local_pos)
				if DEBUG_LOGS:
					print("InputController: click local_pos=", local_pos)
			if velocity_mode:
				if _try_begin_velocity_drag(local_pos):
					roll_content.accept_event()
				return
			if _try_begin_playhead_drag(local_pos):
				roll_content.accept_event()
				return
			if _try_begin_note_drag(local_pos):
				roll_content.accept_event()
				return
			if _try_create_note(local_pos):
				roll_content.accept_event()
		else:
			if is_dragging_velocity:
				if drag_velocity_index >= 0 and drag_velocity_index < model.notes.size():
					var velocity = int(model.notes[drag_velocity_index].get("velocity", 127))
					if DEBUG_LOGS:
						print("Velocity:", velocity)
				is_dragging_velocity = false
				drag_velocity_index = -1
			if is_dragging_note or is_dragging_playhead:
				is_dragging_note = false
				is_dragging_playhead = false
				drag_note_index = -1
				drag_mode = ""

	if event is InputEventMouseMotion:
		if is_dragging_velocity:
			_update_velocity_drag(event.position)
			roll_content.accept_event()
			return
		if not is_dragging_note and not is_dragging_playhead:
			_update_hover_cursor(event.position)
		if is_dragging_playhead:
			_update_playhead_drag(event.position)
			roll_content.accept_event()
		elif is_dragging_note:
			_update_note_drag(event.position)
			roll_content.accept_event()

func set_grid_params(ppb: float, kh: float, min_p: int, max_p: int, beats: int) -> void:
	pixels_per_beat = ppb
	key_height = kh
	min_pitch = min_p
	max_pitch = max_p
	visible_beats = beats

func _try_create_note(local_pos: Vector2) -> bool:
	if local_pos.x < 0 or local_pos.y < 0:
		return false
	var grid_height = (max_pitch - min_pitch + 1) * key_height
	if local_pos.y > grid_height:
		return false
	var pitch = max_pitch - int(floor(local_pos.y / key_height))
	if pitch < min_pitch or pitch > max_pitch:
		return false
	var start_beats = int(floor(local_pos.x / pixels_per_beat))
	_ensure_length(start_beats + 1.0)
	model.add_note(pitch, start_beats, 1.0)
	return true

func _try_begin_playhead_drag(local_pos: Vector2) -> bool:
	var playhead_x = playhead_time_beats * pixels_per_beat
	if abs(local_pos.x - playhead_x) > RESIZE_HANDLE_PX:
		return false
	is_dragging_playhead = true
	emit_signal("playhead_drag_started")
	_update_playhead_drag(local_pos)
	return true

func _update_playhead_drag(local_pos: Vector2) -> void:
	var time_beats = local_pos.x / pixels_per_beat
	if snap_enabled:
		time_beats = _snap_beats(time_beats)
	time_beats = clamp(time_beats, 0.0, float(visible_beats))
	emit_signal("playhead_time_changed", time_beats)

func _try_begin_note_drag(local_pos: Vector2) -> bool:
	var hit = _find_note_at(local_pos)
	if hit["index"] == -1:
		return false
	is_dragging_note = true
	drag_note_index = hit["index"]
	drag_mode = hit["mode"]
	drag_offset = hit["offset"]
	drag_note_start = hit["start"]
	drag_note_pitch = hit["pitch"]
	drag_note_duration = hit["duration"]
	return true

func _try_begin_velocity_drag(local_pos: Vector2) -> bool:
	var hit = _find_note_at(local_pos)
	if hit["index"] == -1:
		return false
	is_dragging_velocity = true
	drag_velocity_index = hit["index"]
	_update_velocity_drag(local_pos)
	return true

func _update_note_drag(local_pos: Vector2) -> void:
	if drag_note_index < 0:
		return
	if drag_mode == "move":
		var raw_start = (local_pos.x - drag_offset.x) / pixels_per_beat
		var snapped_start = raw_start
		if snap_enabled:
			snapped_start = _snap_beats(raw_start)
		var snapped_pitch = _snap_pitch(local_pos.y - drag_offset.y)
		snapped_start = max(0.0, snapped_start)
		_ensure_length(snapped_start + drag_note_duration)
		_update_note(drag_note_index, snapped_pitch, snapped_start, drag_note_duration)
	elif drag_mode == "resize_left":
		var end_beats = drag_note_start + drag_note_duration
		var new_start = local_pos.x / pixels_per_beat
		if snap_enabled:
			new_start = _snap_beats(new_start)
		new_start = clamp(new_start, 0.0, end_beats - MIN_DURATION_BEATS)
		var new_duration = max(MIN_DURATION_BEATS, end_beats - new_start)
		_update_note(drag_note_index, drag_note_pitch, new_start, new_duration)
	elif drag_mode == "resize_right":
		var new_end = local_pos.x / pixels_per_beat
		if snap_enabled:
			new_end = _snap_beats(new_end)
		new_end = max(new_end, drag_note_start + MIN_DURATION_BEATS)
		var new_duration = max(MIN_DURATION_BEATS, new_end - drag_note_start)
		_ensure_length(new_end)
		_update_note(drag_note_index, drag_note_pitch, drag_note_start, new_duration)

func _update_note(index: int, pitch: int, start_beats: float, duration_beats: float) -> void:
	var clamped_pitch = clamp(pitch, min_pitch, max_pitch)
	model.update_note(index, clamped_pitch, start_beats, duration_beats)

func _update_velocity_drag(local_pos: Vector2) -> void:
	if drag_velocity_index < 0:
		return
	if drag_velocity_index >= model.notes.size():
		return
	var note = model.notes[drag_velocity_index]
	var start_beats = note["start"]
	var duration_beats = note["duration"]
	var pitch = note["pitch"]
	var x = start_beats * pixels_per_beat
	var y = (max_pitch - int(pitch)) * key_height
	var width = duration_beats * pixels_per_beat
	if width <= 0.0:
		return
	var rect = Rect2(Vector2(x, y), Vector2(width, key_height))
	var velocity_t = (local_pos.x - rect.position.x) / rect.size.x
	var velocity = int(round(clamp(velocity_t, 0.0, 1.0) * 127.0))
	model.update_velocity(drag_velocity_index, velocity)

func _ensure_length(required_beats: float) -> void:
	if required_beats <= visible_beats:
		return
	visible_beats = int(ceil(required_beats))
	emit_signal("length_extend_requested", required_beats)

func _find_note_at(local_pos: Vector2) -> Dictionary:
	for i in range(model.notes.size() - 1, -1, -1):
		var note = model.notes[i]
		var start_beats = note["start"]
		var duration_beats = note["duration"]
		var pitch = note["pitch"]
		var x = start_beats * pixels_per_beat
		var y = (max_pitch - int(pitch)) * key_height
		var width = duration_beats * pixels_per_beat
		var rect = Rect2(Vector2(x, y), Vector2(width, key_height))
		if not rect.has_point(local_pos):
			continue
		var right_edge = rect.position.x + rect.size.x
		if abs(local_pos.x - rect.position.x) <= RESIZE_HANDLE_PX:
			return {
				"index": i,
				"mode": "resize_left",
				"offset": Vector2.ZERO,
				"start": start_beats,
				"pitch": pitch,
				"duration": duration_beats
			}
		if abs(local_pos.x - right_edge) <= RESIZE_HANDLE_PX:
			return {
				"index": i,
				"mode": "resize_right",
				"offset": Vector2.ZERO,
				"start": start_beats,
				"pitch": pitch,
				"duration": duration_beats
			}
		return {
			"index": i,
			"mode": "move",
			"offset": local_pos - rect.position,
			"start": start_beats,
			"pitch": pitch,
			"duration": duration_beats
		}
	return {"index": -1}

func _snap_beats(beats: float) -> float:
	var step = SNAP_STEPS[snap_step_index]
	if step <= 0.0:
		return beats
	return round(beats / step) * step

func _snap_pitch(y: float) -> int:
	return max_pitch - int(floor(y / key_height))

func cycle_snap_step() -> float:
	if not snap_enabled:
		snap_enabled = true
		if SNAP_STEPS[snap_step_index] <= 0.0:
			snap_step_index = 0
		return SNAP_STEPS[snap_step_index]
	snap_step_index = (snap_step_index + 1) % SNAP_STEPS.size()
	return SNAP_STEPS[snap_step_index]

func get_snap_step() -> float:
	return SNAP_STEPS[snap_step_index]

func is_snap_enabled() -> bool:
	return snap_enabled

func toggle_snap() -> bool:
	snap_enabled = !snap_enabled
	if snap_enabled and SNAP_STEPS[snap_step_index] <= 0.0:
		snap_step_index = 0
	return snap_enabled

func _update_hover_cursor(local_pos: Vector2) -> void:
	if roll_content == null:
		return
	if velocity_mode:
		var velocity_hit = _find_note_at(local_pos)
		if velocity_hit["index"] == -1:
			roll_content.mouse_default_cursor_shape = Control.CURSOR_ARROW
		else:
			roll_content.mouse_default_cursor_shape = Control.CURSOR_HSIZE
		return
	var playhead_x = playhead_time_beats * pixels_per_beat
	if abs(local_pos.x - playhead_x) <= RESIZE_HANDLE_PX:
		roll_content.mouse_default_cursor_shape = Control.CURSOR_HSIZE
		return
	var note_hit = _find_note_at(local_pos)
	if note_hit["index"] == -1:
		roll_content.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	match note_hit["mode"]:
		"resize_left", "resize_right":
			roll_content.mouse_default_cursor_shape = Control.CURSOR_HSIZE
		"move":
			roll_content.mouse_default_cursor_shape = Control.CURSOR_MOVE
		_:
			roll_content.mouse_default_cursor_shape = Control.CURSOR_ARROW
