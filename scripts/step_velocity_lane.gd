extends Control

signal config_changed

@export var pixels_per_beat: float = 120.0
@export var beats_per_measure: int = 4
@export var visible_beats: int = 32
@export var view_scroll_x: float = 0.0
@export var view_width: float = 0.0
@export var steps_per_measure: int = 8:
	set(value):
		steps_per_measure = clamp(value, 1, 16)
		emit_signal("config_changed")
		queue_redraw()
@export var step_pitch: int = 60:
	set(value):
		step_pitch = clamp(value, 0, 127)
		emit_signal("config_changed")
		queue_redraw()
@export var bar_gap_ratio: float = 0.12
@export var min_bar_width: float = 2.0
@export var min_bar_height: float = 2.0

const COLOR_BG = Color(0.06, 0.06, 0.07)
const COLOR_GRID = Color(1.0, 1.0, 1.0, 0.08)
const COLOR_MEASURE = Color(1.0, 1.0, 1.0, 0.18)
const COLOR_BAR = Color(0.25, 0.55, 0.95, 0.9)
const COLOR_BAR_MISMATCH = Color(0.9, 0.2, 0.2, 0.9)
const COLOR_LABEL_BG = Color(0.1, 0.1, 0.12, 0.7)
const COLOR_LABEL_TEXT = Color(0.92, 0.94, 1.0, 0.9)
const LABEL_MARGIN = Vector2(6.0, 6.0)
const LABEL_PADDING = Vector2(6.0, 4.0)

var model: Node = null
var roll: Control = null
var is_drawing := false
var is_deleting := false
var last_step_index := -9999
var last_step_velocity := -1
var last_delete_index := -9999
var last_wheel_frame := -1
var last_wheel_direction := 0

func set_from_roll(roll_node: Control) -> void:
	if roll_node == null:
		return
	roll = roll_node
	pixels_per_beat = float(roll_node.get("pixels_per_beat"))
	beats_per_measure = int(roll_node.get("beats_per_measure"))
	visible_beats = int(roll_node.get("visible_beats"))
	set_model(roll_node.get_node_or_null("NotesModel"))
	queue_redraw()

func set_model(next_model: Node) -> void:
	if model:
		var callable = Callable(self, "_on_model_changed")
		if model.is_connected("changed", callable):
			model.disconnect("changed", callable)
	model = next_model
	if model:
		model.connect("changed", Callable(self, "_on_model_changed"))
	queue_redraw()

func _on_model_changed() -> void:
	queue_redraw()

func set_view(scroll_x: float, width: float) -> void:
	view_scroll_x = scroll_x
	view_width = width
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)

func _gui_input(event: InputEvent) -> void:
	if model == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not event.pressed:
				return
			var delta = -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			var frame = Engine.get_process_frames()
			if frame == last_wheel_frame and delta == last_wheel_direction:
				return
			last_wheel_frame = frame
			last_wheel_direction = delta
			if event.alt_pressed:
				_adjust_steps(delta)
				accept_event()
				return
			if event.shift_pressed:
				_adjust_pitch(delta)
				accept_event()
				return
			if roll != null and roll.has_method("_on_roll_gui_input"):
				roll.call("_on_roll_gui_input", event)
				accept_event()
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_drawing = true
			is_deleting = false
			last_step_index = -9999
			last_step_velocity = -1
			_apply_at(event.position)
		else:
			is_drawing = false
			last_step_index = -9999
			last_step_velocity = -1
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_deleting = true
			is_drawing = false
			last_delete_index = -9999
			_clear_at(event.position)
		else:
			is_deleting = false
			last_delete_index = -9999
		accept_event()
		return
	if event is InputEventMouseMotion:
		if is_drawing:
			_apply_at(event.position)
			accept_event()
			return
		if is_deleting:
			_clear_at(event.position)
			accept_event()
			return

func _input(event: InputEvent) -> void:
	if not (is_drawing or is_deleting):
		return
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_drawing = false
			last_step_index = -9999
			last_step_velocity = -1
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_deleting = false
			last_delete_index = -9999

func _apply_at(local_pos: Vector2) -> void:
	var step_length = _get_step_length()
	if step_length <= 0.0 or pixels_per_beat <= 0.0:
		return
	var step_index = _step_index_from_x(local_pos.x)
	var velocity = _velocity_from_y(local_pos.y)
	if last_step_index == -9999:
		_apply_step_velocity(step_index, velocity)
		last_step_index = step_index
		last_step_velocity = velocity
		return
	if step_index == last_step_index:
		if velocity != last_step_velocity:
			_apply_step_velocity(step_index, velocity)
			last_step_velocity = velocity
		return
	var delta = step_index - last_step_index
	var steps = abs(delta)
	if steps <= 0:
		return
	var step_dir = 1 if delta > 0 else -1
	for i in range(1, steps + 1):
		var t = float(i) / float(steps)
		var interp = lerp(float(last_step_velocity), float(velocity), t)
		var interp_vel = int(round(interp))
		_apply_step_velocity(last_step_index + i * step_dir, interp_vel)
	last_step_index = step_index
	last_step_velocity = velocity

func _clear_at(local_pos: Vector2) -> void:
	var step_length = _get_step_length()
	if step_length <= 0.0 or pixels_per_beat <= 0.0:
		return
	var step_index = _step_index_from_x(local_pos.x)
	if last_delete_index == -9999:
		_apply_step_velocity(step_index, 0)
		last_delete_index = step_index
		return
	if step_index == last_delete_index:
		return
	var delta = step_index - last_delete_index
	var steps = abs(delta)
	if steps <= 0:
		return
	var step_dir = 1 if delta > 0 else -1
	for i in range(1, steps + 1):
		_apply_step_velocity(last_delete_index + i * step_dir, 0)
	last_delete_index = step_index

func _step_index_from_x(local_x: float) -> int:
	var beat = (view_scroll_x + local_x) / pixels_per_beat
	return int(floor(beat / _get_step_length()))

func _velocity_from_y(local_y: float) -> int:
	if size.y <= 0.0:
		return 0
	var t = 1.0 - clamp(local_y / size.y, 0.0, 1.0)
	return int(round(clamp(t, 0.0, 1.0) * 127.0))

func _get_step_length() -> float:
	var steps = max(1, steps_per_measure)
	var beats = max(1, beats_per_measure)
	return float(beats) / float(steps)

func _note_aligned(start: float, duration: float, step_length: float) -> bool:
	if step_length <= 0.0:
		return true
	var tol = max(0.001, step_length * 0.02)
	var start_snap = round(start / step_length) * step_length
	return abs(start - start_snap) <= tol and abs(duration - step_length) <= tol

func _aligned_step_index(start: float, step_length: float) -> int:
	if step_length <= 0.0:
		return -1
	return int(round(start / step_length))

func _apply_step_velocity(step_index: int, velocity: int) -> void:
	if model == null:
		return
	var step_length = _get_step_length()
	if step_length <= 0.0:
		return
	var step_start = max(0.0, float(step_index) * step_length)
	var step_end = step_start + step_length
	var overlaps: Array = []
	var aligned_index := -1
	for i in range(model.notes.size()):
		var note = model.notes[i]
		if int(note.get("pitch", -1)) != step_pitch:
			continue
		var start = float(note.get("start", 0.0))
		var duration = float(note.get("duration", 0.0))
		var end = start + duration
		if end <= step_start or start >= step_end:
			continue
		var aligned = _note_aligned(start, duration, step_length)
		if aligned:
			var note_step = _aligned_step_index(start, step_length)
			if note_step != step_index:
				continue
			if aligned_index < 0:
				aligned_index = i
			else:
				overlaps.append(i)
		else:
			overlaps.append(i)
	if velocity <= 0:
		var delete_indices = overlaps.duplicate()
		if aligned_index >= 0:
			delete_indices.append(aligned_index)
		_delete_note_indices(delete_indices)
		return
	if aligned_index >= 0:
		model.update_velocity(aligned_index, velocity)
		_delete_note_indices(overlaps)
		return
	_delete_note_indices(overlaps)
	model.add_note(step_pitch, step_start, step_length)
	var new_index = _find_aligned_note_index(step_start, step_length)
	if new_index >= 0:
		model.update_velocity(new_index, velocity)

func _delete_note_indices(indices: Array) -> void:
	if indices.is_empty():
		return
	indices.sort()
	for idx in range(indices.size() - 1, -1, -1):
		model.delete_note(int(indices[idx]))

func _find_aligned_note_index(step_start: float, step_length: float) -> int:
	var tol = max(0.001, step_length * 0.02)
	for i in range(model.notes.size()):
		var note = model.notes[i]
		if int(note.get("pitch", -1)) != step_pitch:
			continue
		var start = float(note.get("start", 0.0))
		var duration = float(note.get("duration", 0.0))
		if abs(start - step_start) <= tol and abs(duration - step_length) <= tol:
			return i
	return -1

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	_draw_grid()
	_draw_bars()
	_draw_config_label()

func _draw_grid() -> void:
	if pixels_per_beat <= 0.0:
		return
	var clip_width = size.x
	if view_width > 0.0:
		clip_width = min(size.x, view_width)
	var step_length = _get_step_length()
	if step_length <= 0.0:
		return
	var total_width = visible_beats * pixels_per_beat
	var draw_x0 = clamp(view_scroll_x, 0.0, total_width)
	var draw_x1 = clamp(view_scroll_x + clip_width, 0.0, total_width)
	var start_step = int(floor(draw_x0 / (step_length * pixels_per_beat)))
	var end_step = int(ceil(draw_x1 / (step_length * pixels_per_beat)))
	var measure_beats = max(1, beats_per_measure)
	for step in range(start_step, end_step + 1):
		var beat = float(step) * step_length
		var x = beat * pixels_per_beat - view_scroll_x
		if x < 0.0 or x > clip_width:
			continue
		var is_measure = abs(fmod(beat, float(measure_beats))) <= 0.001
		var color = COLOR_MEASURE if is_measure else COLOR_GRID
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), color, 1.0)

func _draw_bars() -> void:
	if model == null or pixels_per_beat <= 0.0:
		return
	var clip_width = size.x
	if view_width > 0.0:
		clip_width = min(size.x, view_width)
	var step_length = _get_step_length()
	if step_length <= 0.0:
		return
	var total_width = visible_beats * pixels_per_beat
	var draw_x0 = clamp(view_scroll_x, 0.0, total_width)
	var draw_x1 = clamp(view_scroll_x + clip_width, 0.0, total_width)
	var start_step = int(floor(draw_x0 / (step_length * pixels_per_beat)))
	var end_step = int(ceil(draw_x1 / (step_length * pixels_per_beat)))
	var pitch_notes: Array = []
	for i in range(model.notes.size()):
		var note = model.notes[i]
		if int(note.get("pitch", -1)) == step_pitch:
			pitch_notes.append({
				"index": i,
				"start": float(note.get("start", 0.0)),
				"duration": float(note.get("duration", 0.0)),
				"velocity": int(note.get("velocity", 127))
			})
	for step in range(start_step, end_step + 1):
		var step_start = float(step) * step_length
		var step_end = step_start + step_length
		var x0 = step_start * pixels_per_beat - view_scroll_x
		var full_width = step_length * pixels_per_beat
		if full_width <= 0.0:
			continue
		var gap = max(0.0, full_width * bar_gap_ratio)
		var bar_width = max(min_bar_width, full_width - gap)
		var x = x0 + (full_width - bar_width) * 0.5
		if x > clip_width or x + bar_width < 0.0:
			continue
		var state = _resolve_step_state(step_start, step_end, step_length, pitch_notes)
		if state.is_empty():
			continue
		var velocity = int(state.get("velocity", 0))
		if velocity <= 0:
			continue
		var height = max(min_bar_height, (float(velocity) / 127.0) * size.y)
		var rect = Rect2(Vector2(x, size.y - height), Vector2(bar_width, height))
		var color = COLOR_BAR_MISMATCH if bool(state.get("mismatch", false)) else COLOR_BAR
		draw_rect(rect, color, true)

func _resolve_step_state(step_start: float, step_end: float, step_length: float, pitch_notes: Array) -> Dictionary:
	if pitch_notes.is_empty():
		return {}
	var mismatch_note = {}
	var mismatch_overlap := -1.0
	var aligned_note = {}
	var step_index = _aligned_step_index(step_start, step_length)
	for note in pitch_notes:
		var start = float(note["start"])
		var duration = float(note["duration"])
		var end = start + duration
		if end <= step_start or start >= step_end:
			continue
		var aligned = _note_aligned(start, duration, step_length)
		if not aligned:
			var overlap = min(end, step_end) - max(start, step_start)
			if overlap > mismatch_overlap:
				mismatch_overlap = overlap
				mismatch_note = note
		elif aligned_note.is_empty():
			if _aligned_step_index(start, step_length) == step_index:
				aligned_note = note
	if not mismatch_note.is_empty():
		return {"velocity": mismatch_note["velocity"], "mismatch": true}
	if not aligned_note.is_empty():
		return {"velocity": aligned_note["velocity"], "mismatch": false}
	return {}

func _adjust_steps(delta: int) -> void:
	var next = clamp(steps_per_measure + delta, 1, 16)
	if next != steps_per_measure:
		steps_per_measure = next

func _adjust_pitch(delta: int) -> void:
	var next = clamp(step_pitch + delta, 0, 127)
	if next != step_pitch:
		step_pitch = next

func _pitch_label() -> String:
	var note = NotePalette.name_for_pitch(step_pitch)
	var octave = int(floor(float(step_pitch) / 12.0)) - 1
	return "%s%d" % [note, octave]

func _draw_config_label() -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	var font_size = get_theme_default_font_size()
	var label = "Steps: %d  Pitch: %s" % [steps_per_measure, _pitch_label()]
	var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var rect_size = Vector2(text_size.x + LABEL_PADDING.x * 2.0, text_size.y + LABEL_PADDING.y * 2.0)
	var rect = Rect2(LABEL_MARGIN, rect_size)
	draw_rect(rect, COLOR_LABEL_BG, true)
	var text_pos = rect.position + Vector2(LABEL_PADDING.x, LABEL_PADDING.y + font.get_ascent(font_size))
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - LABEL_PADDING.x * 2.0, font_size, COLOR_LABEL_TEXT)
