extends Control

signal value_changed(value: float)

const INTERVAL_UTILS = preload("res://scripts/interval_utils.gd")

@export var vertical: bool = false
@export var min_value: float = 0.0
@export var max_value: float = 0.0
@export var page: float = 0.0
var _value: float = 0.0
@export var value: float:
	get:
		return _value
	set(value):
		_set_value(value)

const TRACK_COLOR = Color(0.08, 0.08, 0.09, 0.6)
const THUMB_COLOR = Color(0.9, 0.9, 0.92, 0.2)
const THUMB_HOVER = Color(1.0, 1.0, 1.0, 0.45)
const THUMB_BORDER = Color(1.0, 1.0, 1.0, 0.9)
const GRID_MINOR = Color(1.0, 1.0, 1.0, 0.12)
const GRID_MAJOR = Color(1.0, 1.0, 1.0, 0.22)
const MIN_THUMB_PX = 12.0
const FILL_COLOR = Color(0.85, 0.2, 0.2, 0.6)

var roll: Control = null
var notes_model: Node = null
var dragging := false
var drag_offset := 0.0
var hover := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func set_roll(target: Control) -> void:
	if notes_model != null:
		var callable = Callable(self, "_on_notes_changed")
		if notes_model.is_connected("changed", callable):
			notes_model.disconnect("changed", callable)
	roll = target
	notes_model = roll.get_node_or_null("NotesModel") if roll else null
	if notes_model != null:
		notes_model.connect("changed", Callable(self, "_on_notes_changed"))
	queue_redraw()

func _on_notes_changed() -> void:
	queue_redraw()

func _set_value(next_value: float) -> void:
	var clamped = clamp(next_value, min_value, max_value)
	if is_equal_approx(clamped, _value):
		return
	_value = clamped
	emit_signal("value_changed", _value)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = _thumb_rect().has_point(event.position)
		if dragging:
			_update_from_position(event.position)
			accept_event()
		else:
			queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var thumb = _thumb_rect()
				if thumb.has_point(event.position):
					dragging = true
					drag_offset = (event.position.y - thumb.position.y) if vertical else (event.position.x - thumb.position.x)
				else:
					_update_from_position(event.position, true)
				accept_event()
			else:
				dragging = false
				accept_event()

func _update_from_position(pos: Vector2, center_on_click: bool = false) -> void:
	var track_len = size.y if vertical else size.x
	var thumb_len = _thumb_length(track_len)
	if track_len <= thumb_len:
		_set_value(min_value)
		return
	var local = pos.y if vertical else pos.x
	var target = local
	if center_on_click:
		target -= thumb_len * 0.5
	else:
		target -= drag_offset
	var max_pos = track_len - thumb_len
	var clamped = clamp(target, 0.0, max_pos)
	var t = clamped / max_pos
	var value_range = max_value - min_value
	_set_value(min_value + t * value_range)

func _thumb_length(track_len: float) -> float:
	var value_range = max_value - min_value
	if value_range <= 0.0:
		return track_len
	var ratio = page / (page + value_range) if page > 0.0 else 0.2
	return clamp(track_len * ratio, MIN_THUMB_PX, track_len)

func _thumb_rect() -> Rect2:
	var track_len = size.y if vertical else size.x
	var thickness = size.x if vertical else size.y
	var thumb_len = _thumb_length(track_len)
	var value_range = max_value - min_value
	var t = 0.0
	if value_range > 0.0 and track_len > thumb_len:
		t = (_value - min_value) / value_range
	var pos = t * (track_len - thumb_len)
	if vertical:
		return Rect2(Vector2(0.0, pos), Vector2(thickness, thumb_len))
	return Rect2(Vector2(pos, 0.0), Vector2(thumb_len, thickness))

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), TRACK_COLOR, true)
	_draw_grid()
	_draw_minimap()
	var thumb = _thumb_rect()
	var fill = THUMB_HOVER if hover or dragging else THUMB_COLOR
	draw_rect(thumb, fill, true)
	draw_rect(thumb, THUMB_BORDER, false, 1.0)

func _draw_minimap() -> void:
	if roll == null or notes_model == null:
		return
	if notes_model.notes.is_empty():
		return
	if vertical:
		_draw_minimap_vertical()
	else:
		_draw_minimap_horizontal()

func _draw_grid() -> void:
	if roll == null:
		return
	if vertical:
		_draw_octave_grid()
	else:
		_draw_beat_grid()

func _draw_beat_grid() -> void:
	var total_beats = float(roll.get("visible_beats"))
	if total_beats <= 0.0:
		return
	var beats_per_measure = int(roll.get("beats_per_measure"))
	if beats_per_measure <= 0:
		beats_per_measure = 4
	for beat in range(int(total_beats) + 1):
		var x = (float(beat) / total_beats) * size.x
		var color = GRID_MAJOR if beat % beats_per_measure == 0 else GRID_MINOR
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), color, 1.0)

func _draw_octave_grid() -> void:
	var min_pitch = int(roll.get("min_pitch"))
	var max_pitch = int(roll.get("max_pitch"))
	if max_pitch < min_pitch:
		return
	var total_keys = max_pitch - min_pitch + 1
	if total_keys <= 0:
		return
	for i in range(total_keys + 1):
		var pitch = max_pitch - i
		if pitch % 12 != 0:
			continue
		var y = (float(i) / float(total_keys)) * size.y
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID_MAJOR, 1.0)

func _draw_minimap_horizontal() -> void:
	var total_beats = float(roll.get("visible_beats"))
	if total_beats <= 0.0:
		return
	var intervals: Array = []
	for note in notes_model.notes:
		var start = float(note.get("start", 0.0))
		var duration = float(note.get("duration", 0.0))
		var end = start + duration
		if end <= 0.0 or start >= total_beats:
			continue
		intervals.append([max(0.0, start), min(total_beats, end)])
	var merged = INTERVAL_UTILS.merge_intervals(intervals)
	for seg in merged:
		var x0 = (seg[0] / total_beats) * size.x
		var x1 = (seg[1] / total_beats) * size.x
		var w = max(1.0, x1 - x0)
		draw_rect(Rect2(Vector2(x0, 0.0), Vector2(w, size.y)), FILL_COLOR, true)

func _draw_minimap_vertical() -> void:
	var min_pitch = int(roll.get("min_pitch"))
	var max_pitch = int(roll.get("max_pitch"))
	if max_pitch < min_pitch:
		return
	var total_keys = max_pitch - min_pitch + 1
	var intervals: Array = []
	for note in notes_model.notes:
		var pitch = int(note.get("pitch", min_pitch))
		var idx = max_pitch - pitch
		if idx < 0 or idx >= total_keys:
			continue
		intervals.append([float(idx), float(idx + 1)])
	var merged = INTERVAL_UTILS.merge_intervals(intervals)
	for seg in merged:
		var y0 = (seg[0] / float(total_keys)) * size.y
		var y1 = (seg[1] / float(total_keys)) * size.y
		var h = max(1.0, y1 - y0)
		draw_rect(Rect2(Vector2(0.0, y0), Vector2(size.x, h)), FILL_COLOR, true)
