extends Control

signal clip_selected(track_index: int, clip_index: int)
signal track_selected(track_index: int)

@export var pixels_per_beat: float = 120.0
@export var view_scroll_x: float = 0.0
@export var view_scroll_y: float = 0.0
@export var view_width: float = 0.0

@export var label_width: float = 140.0
@export var row_height: float = 28.0
@export var row_spacing: float = 6.0
@export var top_padding: float = 8.0
@export var left_padding: float = 8.0
@export var clip_height: float = 20.0
@export var clip_radius: float = 4.0
@export var resize_margin: float = 6.0
@export var snap_step_beats: float = 1.0
@export var min_clip_length_beats: float = 1.0

const COLOR_BG = Color(0.05, 0.05, 0.06)
const COLOR_ROW = Color(0.08, 0.08, 0.1)
const COLOR_ROW_ALT = Color(0.07, 0.07, 0.09)
const COLOR_TRACK_BG = Color(0.08, 0.1, 0.14)
const COLOR_TRACK_TEXT = Color(0.86, 0.9, 0.98)
const COLOR_CLIP_FILL = Color(0.17, 0.3, 0.56, 0.9)
const COLOR_CLIP_BORDER = Color(0.35, 0.6, 0.95, 0.9)
const COLOR_CLIP_SELECTED = Color(0.32, 0.5, 0.86, 0.95)
const COLOR_CLIP_TEXT = Color(0.92, 0.96, 1.0, 0.95)

var project_model: Node = null
var selected_track_index := -1
var selected_clip_index := -1

var _drag_mode := ""
var _drag_track_index := -1
var _drag_clip_index := -1
var _drag_start_mouse_x := 0.0
var _drag_start_start := 0.0
var _drag_start_length := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_project_model(next_model: Node) -> void:
	if project_model != null and project_model.has_signal("changed"):
		var callable = Callable(self, "_on_model_changed")
		if project_model.is_connected("changed", callable):
			project_model.disconnect("changed", callable)
	project_model = next_model
	if project_model != null and project_model.has_signal("changed"):
		project_model.connect("changed", Callable(self, "_on_model_changed"))
	queue_redraw()

func set_selection(track_index: int, clip_index: int) -> void:
	selected_track_index = track_index
	selected_clip_index = clip_index
	queue_redraw()

func set_view(scroll_x: float, width: float) -> void:
	view_scroll_x = scroll_x
	view_width = width
	queue_redraw()

func set_view_scroll_y(scroll_y: float) -> void:
	view_scroll_y = max(0.0, scroll_y)
	queue_redraw()

func get_content_height() -> float:
	var track_count = _get_track_count()
	if track_count <= 0:
		return top_padding * 2.0 + row_height
	return top_padding * 2.0 + track_count * row_height + max(0, track_count - 1) * row_spacing

func _on_model_changed() -> void:
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	_draw_tracks()

func _draw_tracks() -> void:
	var track_count = _get_track_count()
	if track_count <= 0:
		return
	var lane_rect = _get_lane_rect()
	for i in range(track_count):
		var row_y = _row_y(i)
		var row_rect = Rect2(Vector2(0.0, row_y), Vector2(size.x, row_height))
		if row_rect.position.y > size.y or row_rect.position.y + row_rect.size.y < 0.0:
			continue
		var row_color = COLOR_ROW if (i % 2 == 0) else COLOR_ROW_ALT
		draw_rect(row_rect, row_color, true)
		var label_rect = Rect2(Vector2(0.0, row_y), Vector2(label_width, row_height))
		draw_rect(label_rect, COLOR_TRACK_BG, true)
		_draw_track_label(i, label_rect)
		_draw_track_clips(i, lane_rect)

func _draw_track_label(track_index: int, label_rect: Rect2) -> void:
	var label = _get_track_name(track_index)
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, label_rect.size.x, font_size)
	var text_x = label_rect.position.x + left_padding
	var text_y = label_rect.position.y + (label_rect.size.y - text_size.y) * 0.5 + font.get_ascent(font_size)
	draw_string(font, Vector2(text_x, text_y), label, HORIZONTAL_ALIGNMENT_LEFT, label_rect.size.x - left_padding, font_size, COLOR_TRACK_TEXT)

func _draw_track_clips(track_index: int, lane_rect: Rect2) -> void:
	var track = _get_track(track_index)
	if track == null:
		return
	var arrangement = track.arrangement
	if arrangement.is_empty():
		return
	for clip_index in range(arrangement.size()):
		var entry = arrangement[clip_index]
		var clip_rect = _clip_rect(track_index, entry)
		var clipped = clip_rect.intersection(lane_rect)
		if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
			continue
		var is_selected = track_index == selected_track_index and clip_index == selected_clip_index
		var fill = COLOR_CLIP_SELECTED if is_selected else COLOR_CLIP_FILL
		draw_rect(clipped, fill, true)
		draw_rect(clipped, COLOR_CLIP_BORDER, false, 1.0)
		_draw_clip_label(entry, clipped)

func _draw_clip_label(entry: Dictionary, clip_rect: Rect2) -> void:
	var clip = entry.get("clip")
	var label = ""
	if clip != null:
		label = str(clip.clip_name)
	if label == "":
		label = "Clip"
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, clip_rect.size.x, font_size)
	var text_x = clip_rect.position.x + left_padding
	var text_y = clip_rect.position.y + (clip_rect.size.y - text_size.y) * 0.5 + font.get_ascent(font_size)
	draw_string(font, Vector2(text_x, text_y), label, HORIZONTAL_ALIGNMENT_LEFT, clip_rect.size.x - left_padding, font_size, COLOR_CLIP_TEXT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag()
		accept_event()
		return
	if event is InputEventMouseMotion and _drag_mode != "":
		_update_drag(event.position)
		accept_event()

func _begin_drag(local_pos: Vector2) -> void:
	var hit = _hit_test_clip(local_pos)
	if hit.is_empty():
		_drag_mode = ""
		_drag_track_index = -1
		_drag_clip_index = -1
		var track_index = _track_index_at_pos(local_pos)
		if track_index >= 0:
			selected_track_index = track_index
			selected_clip_index = -1
			emit_signal("track_selected", track_index)
			queue_redraw()
		return
	selected_track_index = hit["track_index"]
	selected_clip_index = hit["clip_index"]
	emit_signal("clip_selected", selected_track_index, selected_clip_index)
	_drag_mode = hit["mode"]
	_drag_track_index = selected_track_index
	_drag_clip_index = selected_clip_index
	_drag_start_mouse_x = local_pos.x
	_drag_start_start = float(hit["entry"].get("start", 0.0))
	_drag_start_length = float(hit["entry"].get("length", 0.0))
	queue_redraw()

func _end_drag() -> void:
	_drag_mode = ""
	_drag_track_index = -1
	_drag_clip_index = -1

func _update_drag(local_pos: Vector2) -> void:
	if pixels_per_beat <= 0.0:
		return
	var track = _get_track(_drag_track_index)
	if track == null:
		return
	var arrangement = track.arrangement
	if _drag_clip_index < 0 or _drag_clip_index >= arrangement.size():
		return
	var entry = arrangement[_drag_clip_index]
	var clip = entry.get("clip")
	var delta_beats = (local_pos.x - _drag_start_mouse_x) / pixels_per_beat
	var start = _drag_start_start
	var length = _drag_start_length
	if _drag_mode == "move":
		var next_start = _snap_beats(start + delta_beats)
		next_start = max(0.0, next_start)
		_set_clip_placement(track, clip, next_start, length)
	elif _drag_mode == "resize_right":
		var next_length = _snap_beats(length + delta_beats)
		next_length = max(min_clip_length_beats, next_length)
		_set_clip_placement(track, clip, start, next_length)
	elif _drag_mode == "resize_left":
		var end_beats = start + length
		var next_start = _snap_beats(start + delta_beats)
		next_start = max(0.0, next_start)
		var next_length = max(min_clip_length_beats, end_beats - next_start)
		_set_clip_placement(track, clip, next_start, next_length)

func _set_clip_placement(track: Node, clip: Variant, start_beats: float, length_beats: float) -> void:
	if track == null or clip == null:
		return
	if track.has_method("set_clip_placement"):
		track.call("set_clip_placement", clip, start_beats, length_beats)
	queue_redraw()

func _hit_test_clip(local_pos: Vector2) -> Dictionary:
	var track_index = _track_index_at_pos(local_pos)
	if track_index < 0:
		return {}
	var track = _get_track(track_index)
	if track == null:
		return {}
	var arrangement = track.arrangement
	for clip_index in range(arrangement.size()):
		var entry = arrangement[clip_index]
		var rect = _clip_rect(track_index, entry)
		if rect.has_point(local_pos):
			var mode = "move"
			if local_pos.x <= rect.position.x + resize_margin:
				mode = "resize_left"
			elif local_pos.x >= rect.position.x + rect.size.x - resize_margin:
				mode = "resize_right"
			return {
				"track_index": track_index,
				"clip_index": clip_index,
				"entry": entry,
				"mode": mode
			}
	return {}

func _track_index_at_pos(local_pos: Vector2) -> int:
	var y = local_pos.y + view_scroll_y - top_padding
	if y < 0.0:
		return -1
	var stride = row_height + row_spacing
	var index = int(floor(y / stride))
	if index < 0 or index >= _get_track_count():
		return -1
	var row_local = y - float(index) * stride
	if row_local > row_height:
		return -1
	return index

func _row_y(track_index: int) -> float:
	return top_padding + track_index * (row_height + row_spacing) - view_scroll_y

func _clip_rect(track_index: int, entry: Dictionary) -> Rect2:
	var lane_left = label_width
	var start_beats = float(entry.get("start", 0.0))
	var length_beats = max(0.0, float(entry.get("length", 0.0)))
	var x0 = lane_left + start_beats * pixels_per_beat - view_scroll_x
	var width = max(2.0, length_beats * pixels_per_beat)
	var row_y = _row_y(track_index)
	var y = row_y + (row_height - clip_height) * 0.5
	return Rect2(Vector2(x0, y), Vector2(width, clip_height))

func _get_lane_rect() -> Rect2:
	var lane_width = size.x
	if view_width > 0.0:
		lane_width = min(size.x, view_width)
	var width = max(0.0, lane_width - label_width)
	return Rect2(Vector2(label_width, 0.0), Vector2(width, size.y))

func _get_track_count() -> int:
	if project_model == null:
		return 0
	return project_model.tracks.size()

func _get_track(track_index: int) -> Node:
	if project_model == null:
		return null
	if track_index < 0 or track_index >= project_model.tracks.size():
		return null
	return project_model.tracks[track_index]

func _get_track_name(track_index: int) -> String:
	var track = _get_track(track_index)
	if track == null:
		return "Track"
	return str(track.track_name)

func _snap_beats(value: float) -> float:
	if Input.is_key_pressed(KEY_SHIFT):
		return value
	if snap_step_beats <= 0.0:
		return value
	return round(value / snap_step_beats) * snap_step_beats
