extends Control

signal clip_selected(track_index: int, clip_index: int)
signal track_selected(track_index: int)
signal selection_preview(start_beats: float, end_beats: float)
signal selection_committed(start_beats: float, end_beats: float)
signal content_height_changed
signal zoom_request(local_x: float, direction: int)
signal zoom_reset_requested(local_x: float)
signal scroll_request(delta_x: float, delta_y: float)

@export var pixels_per_beat: float = 120.0
@export var view_scroll_x: float = 0.0
@export var view_scroll_y: float = 0.0
@export var view_width: float = 0.0
@export var beats_per_measure: int = 4
@export var min_pitch: int = 36
@export var max_pitch: int = 96
@export var playhead_time_beats: float = -1.0

@export var label_width: float = 140.0
@export var row_height: float = 56.0
@export var row_spacing: float = 6.0
@export var top_padding: float = 8.0
@export var left_padding: float = 8.0
@export var clip_height: float = 56.0
@export var clip_radius: float = 4.0
@export var resize_margin: float = 6.0
@export var snap_step_beats: float = 1.0
@export var min_clip_length_beats: float = 1.0
@export var min_row_height: float = 40.0
@export var max_row_height: float = 200.0
@export var row_resize_margin: float = 6.0

const COLOR_BG = Color(0.05, 0.05, 0.06)
const COLOR_ROW = Color(0.08, 0.08, 0.1)
const COLOR_ROW_ALT = Color(0.07, 0.07, 0.09)
const COLOR_TRACK_BG = Color(0.08, 0.1, 0.14)
const COLOR_TRACK_TEXT = Color(0.86, 0.9, 0.98)
const COLOR_TRACK_FRAME = Color(0.2, 0.85, 0.35, 0.9)
const COLOR_GRID = Color(1.0, 1.0, 1.0, 0.08)
const COLOR_MEASURE = Color(1.0, 1.0, 1.0, 0.18)
const COLOR_CLIP_FILL = Color(0.17, 0.3, 0.56, 0.9)
const COLOR_CLIP_BORDER = Color(0.35, 0.6, 0.95, 0.9)
const COLOR_CLIP_SELECTED = Color(0.32, 0.5, 0.86, 0.95)
const COLOR_CLIP_LINKED = Color(0.95, 0.82, 0.2, 0.95)
const COLOR_CLIP_LINKED_PREVIEW = Color(0.95, 0.82, 0.2, 0.6)
const COLOR_CLIP_TEXT = Color(0.92, 0.96, 1.0, 0.95)
const COLOR_NOTE = Color(0.95, 0.55, 0.2, 0.7)
const COLOR_SELECTION = Color(0.95, 0.55, 0.2, 0.22)
const COLOR_SELECTION_BORDER = Color(0.95, 0.55, 0.2, 0.75)
const COLOR_PLAYHEAD = Color(0.95, 0.7, 0.3, 0.9)
const WHEEL_SCROLL_X := 80.0
const WHEEL_SCROLL_Y := 64.0

var project_model: Node = null
var selected_track_index := -1
var selected_clip_index := -1

var _drag_mode := ""
var _drag_track_index := -1
var _drag_clip_index := -1
var _drag_start_mouse_x := 0.0
var _drag_start_start := 0.0
var _drag_start_length := 0.0
var _selection_dragging := false
var _selection_drag_start := 0.0
var _selection_drag_end := 0.0
var _selection_drag_entry: Dictionary = {}
var _selection_drag_track_index := -1
var selection_start_beats := -1.0
var selection_end_beats := -1.0
var _resizing_track_index := -1
var _resize_start_y := 0.0
var _resize_start_height := 0.0
var _track_heights: Dictionary = {}
var _external_drag_active := false
var _external_drag_track_index := -1
var _external_drag_start := 0.0
var _external_drag_length := 0.0
var _external_drag_clip: Node = null

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
	var view_height = max(1.0, size.y)
	var max_y = max(0.0, get_content_height() - view_height)
	view_scroll_y = clamp(scroll_y, 0.0, max_y)
	queue_redraw()

func set_pitch_range(min_value: int, max_value: int) -> void:
	min_pitch = min_value
	max_pitch = max_value
	queue_redraw()

func set_selection_range(start_beats: float, end_beats: float) -> void:
	selection_start_beats = start_beats
	selection_end_beats = end_beats
	queue_redraw()

func set_playhead_time(time_beats: float) -> void:
	playhead_time_beats = time_beats
	queue_redraw()

func get_playhead_time_beats() -> float:
	return playhead_time_beats

func get_content_height() -> float:
	var track_count = _get_track_count()
	if track_count <= 0:
		return top_padding * 2.0 + row_height
	var total = top_padding * 2.0
	for i in range(track_count):
		total += _get_track_height(i)
	if track_count > 1:
		total += (track_count - 1) * row_spacing
	return total

func _on_model_changed() -> void:
	queue_redraw()
	emit_signal("content_height_changed")

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	_draw_tracks()
	_draw_global_grid()
	_draw_global_selection()
	_draw_playhead()

func _draw_playhead() -> void:
	if playhead_time_beats < 0.0 or pixels_per_beat <= 0.0:
		return
	var lane_rect = _get_lane_rect()
	var x = lane_rect.position.x + (playhead_time_beats * pixels_per_beat) - view_scroll_x
	if x < lane_rect.position.x or x > lane_rect.position.x + lane_rect.size.x:
		return
	draw_line(Vector2(x, lane_rect.position.y), Vector2(x, lane_rect.position.y + lane_rect.size.y), COLOR_PLAYHEAD, 2.0)

func _draw_tracks() -> void:
	var track_count = _get_track_count()
	if track_count <= 0:
		return
	var lane_rect = _get_lane_rect()
	var row_y = top_padding - view_scroll_y
	for i in range(track_count):
		var height = _get_track_height(i)
		var row_rect = Rect2(Vector2(0.0, row_y), Vector2(size.x, height))
		if row_rect.position.y > size.y or row_rect.position.y + row_rect.size.y < 0.0:
			row_y += height + row_spacing
			continue
		var row_color = COLOR_ROW if (i % 2 == 0) else COLOR_ROW_ALT
		draw_rect(row_rect, row_color, true)
		var track_clip_height = _get_track_clip_height(height)
		var label_rect = Rect2(Vector2(0.0, row_y + (height - track_clip_height) * 0.5), Vector2(label_width, track_clip_height))
		draw_rect(label_rect, COLOR_TRACK_BG, true)
		_draw_track_label(i, label_rect)
		_draw_track_clips(i, lane_rect)
		if _external_drag_active and _external_drag_track_index == i:
			_draw_external_drag_preview(i, lane_rect)
		row_y += height + row_spacing

func _draw_track_grid(row_rect: Rect2, lane_rect: Rect2) -> void:
	if pixels_per_beat <= 0.0:
		return
	var lane_width = lane_rect.size.x
	if lane_width <= 0.0:
		return
	var view_span = view_width if view_width > 0.0 else lane_width
	var draw_x0 = max(0.0, view_scroll_x)
	var draw_x1 = max(draw_x0, view_scroll_x + view_span)
	var beat_start = int(floor(draw_x0 / pixels_per_beat))
	var beat_end = int(ceil(draw_x1 / pixels_per_beat))
	var measure = max(1, beats_per_measure)
	for beat in range(beat_start, beat_end + 1):
		var x = lane_rect.position.x + (beat * pixels_per_beat) - view_scroll_x
		if x < lane_rect.position.x or x > lane_rect.position.x + lane_width:
			continue
		var color = COLOR_MEASURE if (beat % measure == 0) else COLOR_GRID
		draw_line(Vector2(x, row_rect.position.y), Vector2(x, row_rect.position.y + row_rect.size.y), color, 1.0)

func _draw_global_grid() -> void:
	if pixels_per_beat <= 0.0:
		return
	var lane_rect = _get_lane_rect()
	if lane_rect.size.x <= 0.0:
		return
	var view_span = view_width if view_width > 0.0 else lane_rect.size.x
	var draw_x0 = max(0.0, view_scroll_x)
	var draw_x1 = max(draw_x0, view_scroll_x + view_span)
	var beat_start = int(floor(draw_x0 / pixels_per_beat))
	var beat_end = int(ceil(draw_x1 / pixels_per_beat))
	var measure = max(1, beats_per_measure)
	for beat in range(beat_start, beat_end + 1):
		var x = lane_rect.position.x + (beat * pixels_per_beat) - view_scroll_x
		if x < lane_rect.position.x or x > lane_rect.position.x + lane_rect.size.x:
			continue
		var color = COLOR_MEASURE if (beat % measure == 0) else COLOR_GRID
		draw_line(Vector2(x, lane_rect.position.y), Vector2(x, lane_rect.position.y + lane_rect.size.y), color, 1.0)

func _draw_track_label(track_index: int, label_rect: Rect2) -> void:
	var label = _get_track_name(track_index)
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, label_rect.size.x, font_size)
	var text_x = label_rect.position.x + left_padding
	var text_y = label_rect.position.y + (label_rect.size.y - text_size.y) * 0.5 + font.get_ascent(font_size)
	draw_string(font, Vector2(text_x, text_y), label, HORIZONTAL_ALIGNMENT_LEFT, label_rect.size.x - left_padding, font_size, COLOR_TRACK_TEXT)
	draw_rect(label_rect, COLOR_TRACK_FRAME, false, 2.0)

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
		var clip = entry.get("clip")
		var is_selected = track_index == selected_track_index and clip_index == selected_clip_index
		var is_linked = false
		var is_owned = false
		if clip != null and clip.has_method("get"):
			is_linked = bool(clip.get("is_linked"))
			is_owned = str(clip.get("owner_track_id")) == str(track.id)
		var border = COLOR_CLIP_BORDER
		if is_selected:
			border = COLOR_CLIP_SELECTED
		elif is_linked or not is_owned:
			border = COLOR_CLIP_LINKED
		draw_rect(clipped, border, false, 2.0)
		_draw_clip_label(entry, clipped)
		_draw_clip_notes(entry, clip_rect, lane_rect)

func _draw_clip_notes(entry: Dictionary, clip_rect: Rect2, lane_rect: Rect2) -> void:
	var clip = entry.get("clip")
	if clip == null:
		return
	if not clip.has_method("get"):
		return
	var notes = clip.get("notes")
	if notes == null or notes.is_empty():
		return
	var length_beats = _get_display_length(entry)
	if length_beats <= 0.0:
		return
	var pitch_min = min_pitch
	var pitch_max = max_pitch
	var clip_pitch_min = pitch_max
	var clip_pitch_max = pitch_min
	for note in notes:
		var note_pitch = int(note.get("pitch", pitch_min))
		clip_pitch_min = min(clip_pitch_min, note_pitch)
		clip_pitch_max = max(clip_pitch_max, note_pitch)
	if clip_pitch_max < clip_pitch_min:
		return
	var padding = 1
	pitch_min = clip_pitch_min - padding
	pitch_max = clip_pitch_max + padding
	if pitch_max < pitch_min:
		return
	var pitch_range = float(pitch_max - pitch_min + 1)
	for note in notes:
		var note_start = float(note.get("start", 0.0))
		var note_duration = float(note.get("duration", 0.0))
		var note_end = note_start + note_duration
		if note_end <= 0.0 or note_start >= length_beats:
			continue
		var pitch = int(note.get("pitch", pitch_min))
		var clamped_pitch = clamp(pitch, pitch_min, pitch_max)
		var x0 = clip_rect.position.x + (note_start / length_beats) * clip_rect.size.x
		var x1 = clip_rect.position.x + (note_end / length_beats) * clip_rect.size.x
		var w = max(1.0, x1 - x0)
		var pitch_index = float(pitch_max - clamped_pitch)
		var y0 = clip_rect.position.y + (pitch_index / pitch_range) * clip_rect.size.y
		var h = max(4.0, clip_rect.size.y / pitch_range)
		var rect = Rect2(Vector2(x0, y0), Vector2(w, h))
		var clipped = rect.intersection(clip_rect).intersection(lane_rect)
		if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
			continue
		draw_rect(clipped, COLOR_NOTE, true)

func _draw_clip_selection(entry: Dictionary, clip_rect: Rect2, lane_rect: Rect2) -> void:
	if selection_start_beats < 0.0 or selection_end_beats <= selection_start_beats:
		return
	var length_beats = _get_display_length(entry)
	if length_beats <= 0.0:
		return
	var clip_start = float(entry.get("start", 0.0))
	var start = clamp(selection_start_beats - clip_start, 0.0, length_beats)
	var end = clamp(selection_end_beats - clip_start, 0.0, length_beats)
	if end <= start:
		return
	var x0 = clip_rect.position.x + (start / length_beats) * clip_rect.size.x
	var x1 = clip_rect.position.x + (end / length_beats) * clip_rect.size.x
	var rect = Rect2(Vector2(x0, clip_rect.position.y), Vector2(max(1.0, x1 - x0), clip_rect.size.y))
	var clipped = rect.intersection(clip_rect).intersection(lane_rect)
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		return
	draw_rect(clipped, COLOR_SELECTION, true)
	draw_rect(clipped, COLOR_SELECTION_BORDER, false, 1.0)

func _draw_global_selection() -> void:
	if selection_start_beats < 0.0 or selection_end_beats <= selection_start_beats:
		return
	var lane_rect = _get_lane_rect()
	if lane_rect.size.x <= 0.0 or lane_rect.size.y <= 0.0:
		return
	var x0 = lane_rect.position.x + (selection_start_beats * pixels_per_beat) - view_scroll_x
	var x1 = lane_rect.position.x + (selection_end_beats * pixels_per_beat) - view_scroll_x
	var rect = Rect2(Vector2(min(x0, x1), lane_rect.position.y), Vector2(abs(x1 - x0), lane_rect.size.y))
	var clipped = rect.intersection(lane_rect)
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		return
	draw_rect(clipped, COLOR_SELECTION, true)
	draw_rect(clipped, COLOR_SELECTION_BORDER, false, 1.0)

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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		emit_signal("zoom_reset_requested", event.position.x)
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.ctrl_pressed:
				var direction = 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
				emit_signal("zoom_request", event.position.x, direction)
				accept_event()
				return
			var wheel_delta = -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			if event.shift_pressed:
				emit_signal("scroll_request", 0.0, wheel_delta * WHEEL_SCROLL_Y)
			else:
				emit_signal("scroll_request", wheel_delta * WHEEL_SCROLL_X, 0.0)
			accept_event()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var resize_index = _resize_track_index_at_pos(event.position)
			if resize_index >= 0:
				_begin_track_resize(resize_index, event.position.y)
				accept_event()
				return
			if event.ctrl_pressed and _begin_selection_drag(event.position):
				accept_event()
				return
			_begin_drag(event.position)
		else:
			if _resizing_track_index >= 0:
				_end_track_resize()
				accept_event()
				return
			if _selection_dragging:
				_end_selection_drag(event.position)
			else:
				_end_drag()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var hit = _hit_test_clip(event.position)
		if not hit.is_empty():
			_remove_or_unplace_clip(hit["track_index"], hit["entry"])
			accept_event()
			return
	if event is InputEventMouseMotion and _resizing_track_index >= 0:
		_update_track_resize(event.position.y)
		accept_event()
		return
	if event is InputEventMouseMotion and _resizing_track_index < 0 and _drag_mode == "" and not _selection_dragging:
		var resize_index = _resize_track_index_at_pos(event.position)
		mouse_default_cursor_shape = Control.CURSOR_VSIZE if resize_index >= 0 else Control.CURSOR_ARROW
	if event is InputEventMouseMotion and _selection_dragging:
		_update_selection_drag(event.position)
		accept_event()
		return
	if event is InputEventMouseMotion and _drag_mode != "":
		_update_drag(event.position)
		accept_event()

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _is_browser_clip_drag(data):
		return false
	_update_external_drag_preview(at_position, data)
	return _external_drag_track_index >= 0

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _is_browser_clip_drag(data):
		return
	_update_external_drag_preview(at_position, data)
	if _external_drag_track_index >= 0:
		var track = _get_track(_external_drag_track_index)
		if track != null:
			if track.has_method("place_clip"):
				track.call("place_clip", _external_drag_clip, _external_drag_start, _external_drag_length)
			elif track.has_method("add_linked_clip"):
				track.call("add_linked_clip", _external_drag_clip, _external_drag_start, _external_drag_length)
	_clear_external_drag()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_clear_external_drag()

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

func _begin_selection_drag(local_pos: Vector2) -> bool:
	_selection_drag_entry = {}
	_selection_drag_track_index = -1
	var hit = _hit_test_clip(local_pos)
	if hit.is_empty():
		return false
	_selection_drag_entry = hit.get("entry", {})
	_selection_drag_track_index = int(hit.get("track_index", -1))
	var clip_rect = _clip_rect(hit["track_index"], hit["entry"])
	var length_beats = _get_display_length(hit["entry"])
	if length_beats <= 0.0 or clip_rect.size.x <= 0.0:
		return false
	var local_x = clamp(local_pos.x, clip_rect.position.x, clip_rect.position.x + clip_rect.size.x)
	var t = (local_x - clip_rect.position.x) / clip_rect.size.x
	var clip_start = float(hit["entry"].get("start", 0.0))
	_selection_drag_start = clip_start + clamp(t * length_beats, 0.0, length_beats)
	_selection_drag_end = _selection_drag_start
	_selection_dragging = true
	selection_start_beats = _selection_drag_start
	selection_end_beats = _selection_drag_end
	emit_signal("selection_preview", selection_start_beats, selection_end_beats)
	queue_redraw()
	return true

func _update_selection_drag(local_pos: Vector2) -> void:
	if not _selection_dragging:
		return
	if _selection_drag_entry.is_empty() or _selection_drag_track_index < 0:
		return
	var clip_rect = _clip_rect(_selection_drag_track_index, _selection_drag_entry)
	var length_beats = _get_display_length(_selection_drag_entry)
	if length_beats <= 0.0 or clip_rect.size.x <= 0.0:
		return
	var local_x = clamp(local_pos.x, clip_rect.position.x, clip_rect.position.x + clip_rect.size.x)
	var t = (local_x - clip_rect.position.x) / clip_rect.size.x
	var clip_start = float(_selection_drag_entry.get("start", 0.0))
	_selection_drag_end = clip_start + clamp(t * length_beats, 0.0, length_beats)
	selection_start_beats = min(_selection_drag_start, _selection_drag_end)
	selection_end_beats = max(_selection_drag_start, _selection_drag_end)
	emit_signal("selection_preview", selection_start_beats, selection_end_beats)
	queue_redraw()

func _end_selection_drag(local_pos: Vector2) -> void:
	if not _selection_dragging:
		return
	_update_selection_drag(local_pos)
	_selection_dragging = false
	_selection_drag_entry = {}
	_selection_drag_track_index = -1
	emit_signal("selection_committed", selection_start_beats, selection_end_beats)

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
	var acc = 0.0
	for i in range(_get_track_count()):
		var height = _get_track_height(i)
		if y >= acc and y <= acc + height:
			return i
		acc += height + row_spacing
	return -1

func _row_y(track_index: int) -> float:
	var y = top_padding - view_scroll_y
	for i in range(track_index):
		y += _get_track_height(i) + row_spacing
	return y

func _clip_rect(track_index: int, entry: Dictionary) -> Rect2:
	var lane_left = label_width
	var start_beats = float(entry.get("start", 0.0))
	var length_beats = _get_display_length(entry)
	var x0 = lane_left + start_beats * pixels_per_beat - view_scroll_x
	var width = max(2.0, length_beats * pixels_per_beat)
	var row_y = _row_y(track_index)
	var track_height = _get_track_height(track_index)
	var clip_h = _get_track_clip_height(track_height)
	var y = row_y + (track_height - clip_h) * 0.5
	return Rect2(Vector2(x0, y), Vector2(width, clip_h))

func _get_track_clip_height(track_height: float) -> float:
	return clamp(max(clip_height, track_height - 8.0), 4.0, track_height)

func _get_lane_rect() -> Rect2:
	var width = max(0.0, size.x - label_width)
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

func _get_track_height(track_index: int) -> float:
	var track = _get_track(track_index)
	if track != null:
		var key = str(track.id)
		if _track_heights.has(key):
			return float(_track_heights[key])
	return row_height

func _set_track_height(track_index: int, height: float) -> void:
	var track = _get_track(track_index)
	if track == null:
		return
	var key = str(track.id)
	_track_heights[key] = clamp(height, min_row_height, max_row_height)
	emit_signal("content_height_changed")
	queue_redraw()

func _resize_track_index_at_pos(local_pos: Vector2) -> int:
	var y = local_pos.y + view_scroll_y - top_padding
	if y < 0.0:
		return -1
	var acc = 0.0
	for i in range(_get_track_count()):
		var height = _get_track_height(i)
		if y >= acc and y <= acc + height:
			if y >= acc + height - row_resize_margin:
				return i
			return -1
		acc += height + row_spacing
	return -1

func _begin_track_resize(track_index: int, mouse_y: float) -> void:
	_resizing_track_index = track_index
	_resize_start_y = mouse_y
	_resize_start_height = _get_track_height(track_index)

func _update_track_resize(mouse_y: float) -> void:
	if _resizing_track_index < 0:
		return
	var delta = mouse_y - _resize_start_y
	_set_track_height(_resizing_track_index, _resize_start_height + delta)

func _end_track_resize() -> void:
	_resizing_track_index = -1

func _get_display_length(entry: Dictionary) -> float:
	var length_beats = max(0.0, float(entry.get("length", 0.0)))
	var clip = entry.get("clip")
	if clip != null and clip.has_method("get"):
		var clip_length = float(clip.get("clip_length_beats"))
		if clip_length > length_beats:
			length_beats = clip_length
	return length_beats

func get_content_length_beats() -> float:
	if project_model == null:
		return 0.0
	var max_end := 0.0
	for track in project_model.tracks:
		if track == null:
			continue
		var arrangement = track.arrangement
		for entry in arrangement:
			var start = float(entry.get("start", 0.0))
			var length = _get_display_length(entry)
			max_end = max(max_end, start + length)
	return max_end

func _snap_beats(value: float) -> float:
	if Input.is_key_pressed(KEY_SHIFT):
		return value
	if snap_step_beats <= 0.0:
		return value
	return round(value / snap_step_beats) * snap_step_beats

func _is_browser_clip_drag(data: Variant) -> bool:
	return data is Dictionary and String(data.get("type", "")) == "browser_clip"

func _update_external_drag_preview(at_position: Vector2, data: Dictionary) -> void:
	var track_index = _track_index_at_pos(at_position)
	if track_index < 0:
		_external_drag_track_index = -1
		queue_redraw()
		return
	var clip = data.get("clip")
	if clip == null:
		_external_drag_track_index = -1
		queue_redraw()
		return
	var lane_left = label_width
	var local_x = at_position.x - lane_left + view_scroll_x
	var start_beats = max(0.0, local_x / pixels_per_beat)
	start_beats = _snap_beats(start_beats)
	_external_drag_track_index = track_index
	_external_drag_start = start_beats
	_external_drag_clip = clip
	_external_drag_length = _get_drag_clip_length(clip)
	_external_drag_active = true
	queue_redraw()

func _clear_external_drag() -> void:
	if not _external_drag_active:
		return
	_external_drag_active = false
	_external_drag_track_index = -1
	_external_drag_clip = null
	queue_redraw()

func _get_drag_clip_length(clip: Node) -> float:
	if clip == null:
		return min_clip_length_beats
	var length = float(clip.get("clip_length_beats")) if clip.has_method("get") else 0.0
	if length <= 0.0:
		length = min_clip_length_beats
	return length

func _draw_external_drag_preview(track_index: int, lane_rect: Rect2) -> void:
	if _external_drag_clip == null:
		return
	var entry = {
		"clip": _external_drag_clip,
		"start": _external_drag_start,
		"length": _external_drag_length
	}
	var clip_rect = _clip_rect(track_index, entry)
	var clipped = clip_rect.intersection(lane_rect)
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		return
	var border = COLOR_CLIP_LINKED_PREVIEW
	if _external_drag_clip.has_method("get"):
		var is_used = bool(_external_drag_clip.get("is_used"))
		var owner_id = str(_external_drag_clip.get("owner_track_id"))
		var track = _get_track(track_index)
		if not is_used and track != null and owner_id == str(track.id):
			border = COLOR_CLIP_BORDER
	draw_rect(clipped, border, false, 2.0)
	_draw_clip_notes(entry, clip_rect, lane_rect)

func _remove_or_unplace_clip(track_index: int, entry: Dictionary) -> void:
	var track = _get_track(track_index)
	if track == null:
		return
	var clip = entry.get("clip")
	if clip == null:
		return
	if track.has_method("remove_clip_from_arrangement"):
		track.call("remove_clip_from_arrangement", clip)
