extends Control

signal clip_selected(track_index: int, clip_index: int)
signal track_selected(track_index: int)
signal clip_double_clicked(track_index: int, clip_index: int, time_beats: float, pitch: float)
signal selection_preview(start_beats: float, end_beats: float)
signal selection_committed(start_beats: float, end_beats: float)
signal playhead_drag_started
signal playhead_time_changed(time_beats: float)
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
@export var show_tempo_map: bool = true
@export var tempo_map_height: float = 140.0
@export var tempo_map_padding: float = 6.0
@export var tempo_header_height: float = 28.0

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
const COLOR_NOTE_ACTIVE = Color(0.1, 0.4, 0.95, 0.9)
const NOTE_ACTIVE_HOLD_SECONDS := 0.08
const COLOR_SELECTION = Color(0.95, 0.55, 0.2, 0.22)
const COLOR_SELECTION_BORDER = Color(0.95, 0.55, 0.2, 0.75)
const COLOR_PLAYHEAD = Color(0.95, 0.7, 0.3, 0.9)
const COLOR_CLIP_HOVER = Color(1.0, 1.0, 1.0, 0.95)
const COLOR_TEMPO_BG = Color(0.06, 0.06, 0.07)
const COLOR_TEMPO_CONTAINER_BG = Color(0.58, 0.58, 0.59)
const COLOR_TEMPO_GRID = Color(1.0, 1.0, 1.0, 0.08)
const COLOR_TEMPO_CURVE = Color(0.95, 0.55, 0.2, 0.9)
const COLOR_TEMPO_FILL = Color(0.95, 0.55, 0.2, 0.2)
const COLOR_TEMPO_POINT = Color(0.98, 0.82, 0.25, 1.0)
const COLOR_TEMPO_DIVIDER = Color(0.1, 0.1, 0.12)
const COLOR_TEMPO_FRAME = Color(0.95, 0.55, 0.2, 0.9)
const COLOR_LABEL_BUTTON_BG = Color(0.12, 0.12, 0.14, 0.9)
const COLOR_LABEL_BUTTON_ACTIVE = Color(0.95, 0.55, 0.2, 0.9)
const COLOR_LABEL_BUTTON_BORDER = Color(1.0, 1.0, 1.0, 0.2)
const COLOR_LABEL_BUTTON_TEXT = Color(0.92, 0.96, 1.0, 0.95)
const WHEEL_SCROLL_X := 80.0
const WHEEL_SCROLL_Y := 64.0
const ROW_ALPHA := 0.0
const TEMPO_BPM_MIN := 40.0
const TEMPO_BPM_MAX := 240.0
const TEMPO_POINT_RADIUS := 3.0
const TEMPO_DELETE_TOLERANCE_BEATS := 0.2
const TEMPO_DIVIDER_HEIGHT := 6.0
const TEMPO_ZOOM_MIN := 1.0
const TEMPO_ZOOM_MAX := 6.0
const TEMPO_ZOOM_DRAG_SCALE := 0.01
const LABEL_BUTTON_SIZE := 18.0
const LABEL_BUTTON_GAP := 4.0
const LABEL_BUTTON_PADDING := 4.0
const DIM_INAUDIBLE := 0.4
const PLAYHEAD_DRAG_TOLERANCE := 6.0

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
var _hover_track_index := -1
var _hover_clip_index := -1
var _hover_label_track_index := -1
var _tempo_drawing := false
var _tempo_deleting := false
var _tempo_zoom_dragging := false
var _tempo_zoom_last_y := 0.0
var _tempo_last_draw_time := -1.0
var _tempo_last_draw_bpm := 0.0
var _tempo_last_delete_time := -1.0
var _tempo_zoom := 1.0
var _dragging_playhead := false
var _global_resize_active := false
var _global_resize_start_y := 0.0
var _global_resize_base_row := 0.0
var _global_resize_base_heights: Dictionary = {}

@onready var tempo_header: Control = get_node_or_null("TempoHeader")
@onready var tempo_toggle: BaseButton = get_node_or_null("TempoHeader/TempoToggle")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	_update_tempo_header_layout()
	if tempo_toggle != null and tempo_toggle.has_signal("toggled"):
		var toggle_callable = Callable(self, "_on_tempo_toggle_toggled")
		if not tempo_toggle.is_connected("toggled", toggle_callable):
			tempo_toggle.connect("toggled", toggle_callable)
	tempo_toggle.button_pressed = show_tempo_map if tempo_toggle != null else false

func _on_mouse_exited() -> void:
	if _hover_track_index != -1 or _hover_clip_index != -1 or _hover_label_track_index != -1:
		_hover_track_index = -1
		_hover_clip_index = -1
		_hover_label_track_index = -1
		queue_redraw()

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
	var view_height = max(1.0, size.y - _tempo_slot_height())
	var content_height = get_content_height()
	var max_y = max(0.0, content_height - view_height)
	var clamped = clamp(scroll_y, 0.0, max_y)
	view_scroll_y = clamped
	_update_tempo_header_layout()
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

func get_view_height() -> float:
	return max(1.0, size.y - _tempo_slot_height())

func set_show_tempo_map(enabled: bool) -> void:
	if show_tempo_map == enabled:
		return
	show_tempo_map = enabled
	if tempo_toggle != null and tempo_toggle.button_pressed != enabled:
		tempo_toggle.button_pressed = enabled
	emit_signal("content_height_changed")
	queue_redraw()

func get_content_height() -> float:
	var track_count = _get_track_count()
	if track_count <= 0:
		return top_padding + row_height
	var total = top_padding
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
	_update_tempo_header_layout()
	if show_tempo_map:
		_draw_tempo_map()
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
	draw_line(Vector2(x, 0.0), Vector2(x, size.y), COLOR_PLAYHEAD, 2.0)

func _draw_tempo_map() -> void:
	var map_height = _tempo_map_height()
	var slot_height = _tempo_slot_height()
	if slot_height <= 0.0:
		return
	var slot_y = top_padding - view_scroll_y
	var slot_rect = Rect2(Vector2(0.0, slot_y), Vector2(size.x, slot_height))
	if slot_rect.position.y > size.y or slot_rect.position.y + slot_rect.size.y < 0.0:
		return
	draw_rect(slot_rect, COLOR_TEMPO_CONTAINER_BG, true)
	if map_height <= 0.0:
		return
	var map_y = top_padding - view_scroll_y + max(0.0, tempo_header_height)
	var rect = Rect2(Vector2(0.0, map_y), Vector2(size.x, map_height))
	draw_rect(rect, COLOR_TEMPO_BG, true)
	draw_rect(rect, COLOR_TEMPO_FRAME, false, 2.0)
	var lane_left = label_width
	var lane_width = max(0.0, size.x - lane_left)
	if lane_width <= 0.0:
		return
	var inner = Rect2(
		Vector2(lane_left + tempo_map_padding, map_y + tempo_map_padding),
		Vector2(max(0.0, lane_width - tempo_map_padding * 2.0), max(0.0, map_height - tempo_map_padding * 2.0))
	)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	_draw_tempo_grid(inner)
	var events = _get_tempo_events()
	var tempo_range = _tempo_display_range()
	var bpm_min = tempo_range.x
	var bpm_max = tempo_range.y
	var bpm_range = bpm_max - bpm_min
	if abs(bpm_range) <= 0.00001:
		return
	var points: Array = []
	for event in events:
		var time_beats = float(event.get("time", 0.0))
		var bpm = float(event.get("bpm", bpm_min))
		if not is_finite(time_beats) or not is_finite(bpm):
			continue
		var x = lane_left + time_beats * pixels_per_beat - view_scroll_x
		var t = (bpm - bpm_min) / bpm_range
		if not is_finite(x) or not is_finite(t):
			continue
		var y = inner.position.y + inner.size.y * (1.0 - t)
		if not is_finite(y):
			continue
		points.append(Vector2(x, y))
	if points.is_empty():
		return
	var draw_points = points.duplicate()
	var last = points[points.size() - 1]
	var end_x = lane_left + inner.size.x + tempo_map_padding
	if end_x < last.x:
		end_x = last.x
	points.append(Vector2(end_x, last.y))
	var prev = points[0]
	for i in range(1, points.size()):
		var cur = points[i]
		draw_line(prev, cur, COLOR_TEMPO_CURVE, 2.0)
		prev = cur
	var bottom_y = inner.position.y + inner.size.y
	for pos in points:
		bottom_y = max(bottom_y, pos.y + tempo_map_padding)
	var fill = PackedVector2Array(points)
	fill.append(Vector2(points[points.size() - 1].x, bottom_y))
	fill.append(Vector2(points[0].x, bottom_y))
	draw_colored_polygon(fill, COLOR_TEMPO_FILL)
	for pos in draw_points:
		if pos.x >= inner.position.x - TEMPO_POINT_RADIUS and pos.x <= inner.position.x + inner.size.x + TEMPO_POINT_RADIUS:
			draw_circle(pos, TEMPO_POINT_RADIUS, COLOR_TEMPO_POINT)
	var divider_y = rect.position.y + rect.size.y
	var divider_rect = Rect2(Vector2(0.0, divider_y), Vector2(size.x, TEMPO_DIVIDER_HEIGHT))
	draw_rect(divider_rect, COLOR_TEMPO_DIVIDER, true)

func _draw_tempo_grid(inner: Rect2) -> void:
	if pixels_per_beat <= 0.0:
		return
	var view_span = view_width if view_width > 0.0 else inner.size.x
	var draw_x0 = max(0.0, view_scroll_x)
	var draw_x1 = max(draw_x0, view_scroll_x + view_span)
	var beat_start = int(floor(draw_x0 / pixels_per_beat))
	var beat_end = int(ceil(draw_x1 / pixels_per_beat))
	var measure = max(1, beats_per_measure)
	for beat in range(beat_start, beat_end + 1):
		var x = label_width + (beat * pixels_per_beat) - view_scroll_x
		var color = COLOR_MEASURE if (beat % measure == 0) else COLOR_TEMPO_GRID
		if x < inner.position.x or x > inner.position.x + inner.size.x:
			continue
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.position.y + inner.size.y), color, 1.0)
	for i in range(1, 4):
		var y = inner.position.y + (inner.size.y * float(i) / 4.0)
		draw_line(Vector2(inner.position.x, y), Vector2(inner.position.x + inner.size.x, y), COLOR_TEMPO_GRID, 1.0)

func _draw_tracks() -> void:
	var track_count = _get_track_count()
	if track_count <= 0:
		return
	var lane_rect = _get_lane_rect()
	var any_solo = _has_any_solo_track()
	var row_y = _content_top() - view_scroll_y
	for i in range(track_count):
		var track = _get_track(i)
		var is_solo = _is_track_solo(track)
		var is_muted = _is_track_muted(track)
		var audible = (not is_muted) and (not any_solo or is_solo)
		var dim_factor = 1.0 if audible else DIM_INAUDIBLE
		var height = _get_track_height(i)
		var row_rect = Rect2(Vector2(0.0, row_y), Vector2(size.x, height))
		if row_rect.position.y > size.y or row_rect.position.y + row_rect.size.y < 0.0:
			row_y += height + row_spacing
			continue
		var row_color = COLOR_ROW if (i % 2 == 0) else COLOR_ROW_ALT
		row_color.a = ROW_ALPHA
		draw_rect(row_rect, row_color, true)
		var track_clip_height = _get_track_clip_height(height)
		var label_rect = Rect2(Vector2(0.0, row_y + (height - track_clip_height) * 0.5), Vector2(label_width, track_clip_height))
		draw_rect(label_rect, COLOR_TRACK_BG, true)
		_draw_track_label(i, label_rect, dim_factor)
		_draw_track_clips(i, lane_rect, dim_factor)
		if _external_drag_active and _external_drag_track_index == i:
			_draw_external_drag_preview(i, lane_rect, dim_factor)
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

func _draw_track_label(track_index: int, label_rect: Rect2, dim_factor: float) -> void:
	var label = _get_track_name(track_index)
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, label_rect.size.x, font_size)
	var text_x = label_rect.position.x + left_padding
	var text_y = label_rect.position.y + (label_rect.size.y - text_size.y) * 0.5 + font.get_ascent(font_size)
	draw_rect(label_rect, _dim_color(COLOR_TRACK_BG, dim_factor), true)
	draw_string(font, Vector2(text_x, text_y), label, HORIZONTAL_ALIGNMENT_LEFT, label_rect.size.x - left_padding, font_size, _dim_color(COLOR_TRACK_TEXT, dim_factor))
	draw_rect(label_rect, _dim_color(COLOR_TRACK_FRAME, dim_factor), false, 2.0)
	if track_index == _hover_label_track_index:
		_draw_track_label_buttons(track_index, label_rect, dim_factor)

func _draw_track_label_buttons(track_index: int, label_rect: Rect2, dim_factor: float) -> void:
	var track = _get_track(track_index)
	if track == null or label_rect.size.x <= 0.0 or label_rect.size.y <= 0.0:
		return
	var font = get_theme_default_font()
	var font_size = int(clamp(label_rect.size.y * 0.6, 8.0, 16.0))
	var rects = _label_button_rects(label_rect)
	if rects.is_empty():
		return
	var is_solo = track.has_method("get") and bool(track.get("is_solo"))
	var is_muted = track.has_method("get") and bool(track.get("is_muted"))
	_draw_label_button(rects["solo"], "S", is_solo, font, font_size, dim_factor)
	_draw_label_button(rects["mute"], "M", is_muted, font, font_size, dim_factor)

func _draw_label_button(rect: Rect2, label: String, active: bool, font: Font, font_size: int, dim_factor: float) -> void:
	var fill = COLOR_LABEL_BUTTON_ACTIVE if active else COLOR_LABEL_BUTTON_BG
	draw_rect(rect, _dim_color(fill, dim_factor), true)
	draw_rect(rect, _dim_color(COLOR_LABEL_BUTTON_BORDER, dim_factor), false, 1.0)
	var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size)
	var text_pos = Vector2(
		rect.position.x + (rect.size.x - text_size.x) * 0.5,
		rect.position.y + (rect.size.y - text_size.y) * 0.5 + font.get_ascent(font_size)
	)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, font_size, _dim_color(COLOR_LABEL_BUTTON_TEXT, dim_factor))

func _label_button_rects(label_rect: Rect2) -> Dictionary:
	var button_size = min(LABEL_BUTTON_SIZE, label_rect.size.y - LABEL_BUTTON_PADDING * 2.0)
	if button_size <= 0.0:
		return {}
	var right_x = label_rect.position.x + label_rect.size.x - LABEL_BUTTON_PADDING - button_size
	var y = label_rect.position.y + (label_rect.size.y - button_size) * 0.5
	var mute_rect = Rect2(Vector2(right_x, y), Vector2(button_size, button_size))
	var solo_rect = Rect2(Vector2(right_x - button_size - LABEL_BUTTON_GAP, y), Vector2(button_size, button_size))
	return {
		"solo": solo_rect,
		"mute": mute_rect
	}

func _draw_track_clips(track_index: int, lane_rect: Rect2, dim_factor: float) -> void:
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
		var is_hovered = track_index == _hover_track_index and clip_index == _hover_clip_index
		if is_hovered:
			border = COLOR_CLIP_HOVER
		border = _dim_color(border, dim_factor)
		var fill = border
		fill.a = 0.05
		draw_rect(clipped, fill, true)
		draw_rect(clipped, border, false, 2.0)
		_draw_clip_label(entry, clipped, dim_factor)
		_draw_clip_notes(entry, clip_rect, lane_rect, dim_factor)

func _draw_clip_notes(entry: Dictionary, clip_rect: Rect2, lane_rect: Rect2, dim_factor: float) -> void:
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
	var clip_start = float(entry.get("start", 0.0))
	var playhead = playhead_time_beats
	var has_playhead = playhead >= 0.0
	var hold_beats = 0.0
	if has_playhead:
		var bpm = _tempo_bpm_at(playhead)
		hold_beats = NOTE_ACTIVE_HOLD_SECONDS * bpm / 60.0
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
		var note_color = COLOR_NOTE
		if has_playhead:
			var note_global_start = clip_start + note_start
			var note_global_end = clip_start + note_end
			if playhead >= note_global_start and playhead <= note_global_end + hold_beats:
				note_color = COLOR_NOTE_ACTIVE
		note_color = _dim_color(note_color, dim_factor)
		draw_rect(clipped, note_color, true)

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

func _draw_clip_label(entry: Dictionary, clip_rect: Rect2, dim_factor: float) -> void:
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
	draw_string(font, Vector2(text_x, text_y), label, HORIZONTAL_ALIGNMENT_LEFT, clip_rect.size.x - left_padding, font_size, _dim_color(COLOR_CLIP_TEXT, dim_factor))

func _try_begin_playhead_drag(local_pos: Vector2) -> bool:
	if not _is_playhead_hovered(local_pos):
		return false
	_dragging_playhead = true
	mouse_default_cursor_shape = Control.CURSOR_HSIZE
	emit_signal("playhead_drag_started")
	_update_playhead_drag(local_pos)
	return true

func _update_playhead_drag(local_pos: Vector2) -> void:
	if pixels_per_beat <= 0.0:
		return
	var lane_x = local_pos.x + view_scroll_x - label_width
	var time_beats = max(0.0, lane_x / pixels_per_beat)
	playhead_time_beats = time_beats
	emit_signal("playhead_time_changed", time_beats)
	queue_redraw()

func _end_playhead_drag() -> void:
	_dragging_playhead = false
	mouse_default_cursor_shape = Control.CURSOR_ARROW

func _is_playhead_hovered(local_pos: Vector2) -> bool:
	if playhead_time_beats < 0.0 or pixels_per_beat <= 0.0:
		return false
	var lane_rect = _get_lane_rect()
	if local_pos.x < lane_rect.position.x or local_pos.x > lane_rect.position.x + lane_rect.size.x:
		return false
	if local_pos.y < lane_rect.position.y or local_pos.y > lane_rect.position.y + lane_rect.size.y:
		return false
	var playhead_x = lane_rect.position.x + playhead_time_beats * pixels_per_beat - view_scroll_x
	return abs(local_pos.x - playhead_x) <= PLAYHEAD_DRAG_TOLERANCE

func _gui_input(event: InputEvent) -> void:
	if _handle_tempo_map_input(event):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		var hit = _hit_test_clip(event.position)
		if not hit.is_empty():
			var entry = hit.get("entry", {})
			var track_index = int(hit.get("track_index", -1))
			var time_beats = _time_for_clip_pos(track_index, entry, event.position)
			var pitch = _pitch_for_clip_pos(track_index, entry, event.position)
			emit_signal("clip_double_clicked", track_index, int(hit.get("clip_index", -1)), time_beats, pitch)
			accept_event()
			return
		emit_signal("zoom_reset_requested", event.position.x)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			if _begin_global_resize(event.position.y):
				accept_event()
				return
		elif _global_resize_active:
			_end_global_resize()
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
			if _try_begin_playhead_drag(event.position):
				accept_event()
				return
			var label_hit = _label_button_hit(event.position)
			if not label_hit.is_empty():
				var track_index = int(label_hit.get("track_index", -1))
				var action = String(label_hit.get("action", ""))
				if action == "solo":
					_toggle_track_solo(track_index)
				elif action == "mute":
					_toggle_track_mute(track_index)
				accept_event()
				return
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
			if _dragging_playhead:
				_end_playhead_drag()
				accept_event()
				return
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
	if event is InputEventMouseMotion and _global_resize_active:
		_update_global_resize(event.position.y)
		accept_event()
		return
	if event is InputEventMouseMotion and _dragging_playhead:
		mouse_default_cursor_shape = Control.CURSOR_HSIZE
		_update_playhead_drag(event.position)
		accept_event()
		return
	if event is InputEventMouseMotion and _resizing_track_index >= 0:
		_update_track_resize(event.position.y)
		accept_event()
		return
	if event is InputEventMouseMotion and _resizing_track_index < 0 and _drag_mode == "" and not _selection_dragging:
		var resize_index = _resize_track_index_at_pos(event.position)
		if resize_index >= 0:
			mouse_default_cursor_shape = Control.CURSOR_VSIZE
		elif _is_playhead_hovered(event.position):
			mouse_default_cursor_shape = Control.CURSOR_HSIZE
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
	if event is InputEventMouseMotion and _selection_dragging:
		_update_selection_drag(event.position)
		accept_event()
		return
	if event is InputEventMouseMotion and _drag_mode != "":
		_update_drag(event.position)
		accept_event()
		return
	if event is InputEventMouseMotion:
		_update_hover_label(event.position)
		_update_hover_clip(event.position)

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

func _time_for_clip_pos(track_index: int, entry: Dictionary, local_pos: Vector2) -> float:
	if track_index < 0 or entry.is_empty():
		return 0.0
	var clip_rect = _clip_rect(track_index, entry)
	if clip_rect.size.x <= 0.0:
		return float(entry.get("start", 0.0))
	var length_beats = _get_display_length(entry)
	if length_beats <= 0.0:
		return float(entry.get("start", 0.0))
	var local_x = clamp(local_pos.x, clip_rect.position.x, clip_rect.position.x + clip_rect.size.x)
	var t = (local_x - clip_rect.position.x) / clip_rect.size.x
	var clip_start = float(entry.get("start", 0.0))
	return clip_start + clamp(t * length_beats, 0.0, length_beats)

func _pitch_for_clip_pos(track_index: int, entry: Dictionary, local_pos: Vector2) -> float:
	if track_index < 0 or entry.is_empty():
		return float(min_pitch + max_pitch) * 0.5
	var clip_rect = _clip_rect(track_index, entry)
	if clip_rect.size.y <= 0.0:
		return float(min_pitch + max_pitch) * 0.5
	var pitch_min = min_pitch
	var pitch_max = max_pitch
	var clip = entry.get("clip")
	if clip != null and clip.has_method("get"):
		var notes = clip.get("notes")
		if notes != null and not notes.is_empty():
			var local_min = pitch_max
			var local_max = pitch_min
			for note in notes:
				var note_pitch = int(note.get("pitch", pitch_min))
				local_min = min(local_min, note_pitch)
				local_max = max(local_max, note_pitch)
			if local_max >= local_min:
				pitch_min = local_min
				pitch_max = local_max
	var local_y = clamp(local_pos.y, clip_rect.position.y, clip_rect.position.y + clip_rect.size.y)
	var t = (local_y - clip_rect.position.y) / clip_rect.size.y
	var pitch = lerp(float(pitch_max), float(pitch_min), t)
	return pitch

func _track_index_at_pos(local_pos: Vector2) -> int:
	var y = local_pos.y + view_scroll_y - _content_top()
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
	var y = _content_top() - view_scroll_y
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
	var lane_y = _content_top() - view_scroll_y
	var visible_y = max(0.0, lane_y)
	var lane_height = max(0.0, size.y - visible_y)
	return Rect2(Vector2(label_width, visible_y), Vector2(width, lane_height))

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

func _is_track_solo(track: Node) -> bool:
	if track == null:
		return false
	return bool(track.get("is_solo"))

func _is_track_muted(track: Node) -> bool:
	if track == null:
		return false
	return bool(track.get("is_muted"))

func _has_any_solo_track() -> bool:
	for i in range(_get_track_count()):
		if _is_track_solo(_get_track(i)):
			return true
	return false

func _dim_color(color: Color, factor: float) -> Color:
	if factor >= 0.999:
		return color
	var gray = (color.r + color.g + color.b) / 3.0
	var gray_color = Color(gray, gray, gray, color.a)
	var mixed = color.lerp(gray_color, 1.0 - factor)
	mixed.a = color.a
	return mixed

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

func _label_rect_for_track(track_index: int) -> Rect2:
	var height = _get_track_height(track_index)
	var row_y = _row_y(track_index)
	var label_clip_height = _get_track_clip_height(height)
	var y = row_y + (height - label_clip_height) * 0.5
	return Rect2(Vector2(0.0, y), Vector2(label_width, label_clip_height))

func _set_track_height(track_index: int, height: float) -> void:
	var track = _get_track(track_index)
	if track == null:
		return
	var key = str(track.id)
	_track_heights[key] = clamp(height, min_row_height, max_row_height)
	emit_signal("content_height_changed")
	queue_redraw()

func _resize_track_index_at_pos(local_pos: Vector2) -> int:
	var y = local_pos.y + view_scroll_y - _content_top()
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

func _begin_global_resize(mouse_y: float) -> bool:
	if _get_track_count() <= 0:
		return false
	_global_resize_active = true
	_global_resize_start_y = mouse_y
	_global_resize_base_row = row_height
	_global_resize_base_heights.clear()
	for i in range(_get_track_count()):
		var track = _get_track(i)
		if track == null:
			continue
		_global_resize_base_heights[str(track.id)] = _get_track_height(i)
	return true

func _update_global_resize(mouse_y: float) -> void:
	if not _global_resize_active:
		return
	var delta = mouse_y - _global_resize_start_y
	row_height = clamp(_global_resize_base_row + delta, min_row_height, max_row_height)
	for i in range(_get_track_count()):
		var track = _get_track(i)
		if track == null:
			continue
		var key = str(track.id)
		var base = float(_global_resize_base_heights.get(key, row_height))
		_track_heights[key] = clamp(base + delta, min_row_height, max_row_height)
	emit_signal("content_height_changed")
	queue_redraw()

func _end_global_resize() -> void:
	_global_resize_active = false
	_global_resize_base_heights.clear()

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

func _tempo_map_height() -> float:
	return max(0.0, tempo_map_height) if show_tempo_map else 0.0

func _tempo_slot_height() -> float:
	var slot_height = max(0.0, tempo_header_height) + _tempo_map_height()
	if show_tempo_map:
		slot_height += TEMPO_DIVIDER_HEIGHT
	return slot_height

func _content_top() -> float:
	return top_padding + _tempo_slot_height()

func _update_hover_clip(local_pos: Vector2) -> void:
	var hit = _hit_test_clip(local_pos)
	var next_track := -1
	var next_clip := -1
	if not hit.is_empty():
		next_track = int(hit.get("track_index", -1))
		next_clip = int(hit.get("clip_index", -1))
	if next_track == _hover_track_index and next_clip == _hover_clip_index:
		return
	_hover_track_index = next_track
	_hover_clip_index = next_clip
	queue_redraw()

func _update_hover_label(local_pos: Vector2) -> void:
	var next_track := -1
	if local_pos.x <= label_width:
		next_track = _track_index_at_pos(local_pos)
	if next_track == _hover_label_track_index:
		return
	_hover_label_track_index = next_track
	queue_redraw()

func _label_button_hit(local_pos: Vector2) -> Dictionary:
	if local_pos.x > label_width:
		return {}
	var track_index = _track_index_at_pos(local_pos)
	if track_index < 0:
		return {}
	var label_rect = _label_rect_for_track(track_index)
	if not label_rect.has_point(local_pos):
		return {}
	var rects = _label_button_rects(label_rect)
	if rects.is_empty():
		return {}
	if rects["solo"].has_point(local_pos):
		return {"track_index": track_index, "action": "solo"}
	if rects["mute"].has_point(local_pos):
		return {"track_index": track_index, "action": "mute"}
	return {}

func _toggle_track_solo(track_index: int) -> void:
	var track = _get_track(track_index)
	if track == null:
		return
	var enabled = false
	if track.has_method("get"):
		enabled = bool(track.get("is_solo"))
	if track.has_method("set_solo"):
		track.call("set_solo", not enabled)
	else:
		track.set("is_solo", not enabled)
		if track.has_signal("changed"):
			track.emit_signal("changed")
	queue_redraw()

func _toggle_track_mute(track_index: int) -> void:
	var track = _get_track(track_index)
	if track == null:
		return
	var enabled = false
	if track.has_method("get"):
		enabled = bool(track.get("is_muted"))
	if track.has_method("set_muted"):
		track.call("set_muted", not enabled)
	else:
		track.set("is_muted", not enabled)
		if track.has_signal("changed"):
			track.emit_signal("changed")
	queue_redraw()

func _on_tempo_toggle_toggled(pressed: bool) -> void:
	set_show_tempo_map(pressed)

func _update_tempo_header_layout() -> void:
	if tempo_header == null:
		return
	var map_y = top_padding - view_scroll_y
	var header_height = max(0.0, tempo_header_height)
	tempo_header.position = Vector2(0.0, map_y)
	tempo_header.size = Vector2(size.x, header_height)

func _tempo_map_rect() -> Rect2:
	var map_height = _tempo_map_height()
	var map_y = top_padding - view_scroll_y + max(0.0, tempo_header_height)
	return Rect2(Vector2(0.0, map_y), Vector2(size.x, map_height))

func _is_in_tempo_map(local_pos: Vector2) -> bool:
	if not show_tempo_map:
		return false
	var rect = _tempo_map_rect()
	return rect.has_point(local_pos)

func _tempo_display_range() -> Vector2:
	var span = (TEMPO_BPM_MAX - TEMPO_BPM_MIN) / clamp(_tempo_zoom, TEMPO_ZOOM_MIN, TEMPO_ZOOM_MAX)
	var center = (TEMPO_BPM_MIN + TEMPO_BPM_MAX) * 0.5
	var min_bpm = clamp(center - span * 0.5, TEMPO_BPM_MIN, TEMPO_BPM_MAX - span)
	var max_bpm = clamp(min_bpm + span, TEMPO_BPM_MIN, TEMPO_BPM_MAX)
	return Vector2(min_bpm, max_bpm)

func _tempo_time_from_pos(local_pos: Vector2) -> float:
	if pixels_per_beat <= 0.0:
		return 0.0
	var lane_left = label_width
	var local_x = local_pos.x - lane_left
	return max(0.0, (view_scroll_x + local_x) / pixels_per_beat)

func _tempo_bpm_from_pos(local_pos: Vector2) -> float:
	var rect = _tempo_map_rect()
	var inner = Rect2(
		Vector2(label_width + tempo_map_padding, rect.position.y + tempo_map_padding),
		Vector2(max(0.0, size.x - label_width - tempo_map_padding * 2.0), max(0.0, rect.size.y - tempo_map_padding * 2.0))
	)
	if inner.size.y <= 0.0:
		return TEMPO_BPM_MIN
	var tempo_range = _tempo_display_range()
	var t = 1.0 - clamp((local_pos.y - inner.position.y) / inner.size.y, 0.0, 1.0)
	return clamp(lerp(tempo_range.x, tempo_range.y, t), TEMPO_BPM_MIN, TEMPO_BPM_MAX)

func _get_tempo_events() -> Array:
	if project_model != null and project_model.transport != null and project_model.transport.has_method("get_tempo_events"):
		var events = project_model.transport.get_tempo_events()
		if events is Array and not events.is_empty():
			return events
	var fallback_bpm = 120.0
	if project_model != null and project_model.transport != null:
		fallback_bpm = float(project_model.transport.tempo)
	return [{"time": 0.0, "bpm": fallback_bpm}]

func _tempo_bpm_at(time_beats: float) -> float:
	var events = _get_tempo_events()
	if events.is_empty():
		return 120.0
	var current = float(events[0].get("bpm", 120.0))
	for event in events:
		var t = float(event.get("time", 0.0))
		if time_beats + 0.00001 >= t:
			current = float(event.get("bpm", current))
		else:
			break
	return max(1.0, current)

func _set_tempo_events(events: Array) -> void:
	if project_model == null or project_model.transport == null:
		return
	if project_model.transport.has_method("set_tempo_events"):
		project_model.transport.set_tempo_events(events)
	queue_redraw()

func _set_tempo_point(time_beats: float, bpm: float, _step: float) -> void:
	var events = _get_tempo_events()
	var updated := false
	for i in range(events.size()):
		var entry = events[i]
		var t = float(entry.get("time", 0.0))
		if is_equal_approx(t, time_beats):
			entry["bpm"] = bpm
			events[i] = entry
			updated = true
			break
	if not updated:
		events.append({"time": time_beats, "bpm": bpm})
	events.sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	_set_tempo_events(events)

func _remove_tempo_points_near(time_beats: float, tolerance: float) -> void:
	var events = _get_tempo_events()
	if events.size() <= 1:
		return
	var next: Array = []
	for entry in events:
		var t = float(entry.get("time", 0.0))
		if abs(t - time_beats) > tolerance:
			next.append(entry)
	if next.is_empty():
		next.append(events[0])
	_set_tempo_events(next)

func _snap_time(time_beats: float, step: float) -> float:
	if step <= 0.0:
		return time_beats
	return round(time_beats / step) * step

func _tempo_draw_at(local_pos: Vector2) -> void:
	var time = _tempo_time_from_pos(local_pos)
	var bpm = _tempo_bpm_from_pos(local_pos)
	var step = max(0.0, snap_step_beats)
	var snapped_time = _snap_time(time, step)
	if is_equal_approx(snapped_time, _tempo_last_draw_time):
		return
	if _tempo_last_draw_time < 0.0:
		_tempo_last_draw_time = snapped_time
		_tempo_last_draw_bpm = bpm
		_set_tempo_point(snapped_time, bpm, step)
		return
	var delta = snapped_time - _tempo_last_draw_time
	var step_dir = step if delta >= 0.0 else -step
	if step <= 0.0 or step_dir == 0.0:
		return
	var t = _tempo_last_draw_time + step_dir
	while (step_dir > 0.0 and t <= snapped_time) or (step_dir < 0.0 and t >= snapped_time):
		var alpha = 0.0 if is_equal_approx(snapped_time, _tempo_last_draw_time) else (t - _tempo_last_draw_time) / delta
		var interp_bpm = lerp(_tempo_last_draw_bpm, bpm, alpha)
		_set_tempo_point(t, interp_bpm, step)
		t += step_dir
	_tempo_last_draw_time = snapped_time
	_tempo_last_draw_bpm = bpm

func _tempo_delete_at(local_pos: Vector2) -> void:
	var time = _tempo_time_from_pos(local_pos)
	var step = max(0.0, snap_step_beats)
	var snapped_time = _snap_time(time, step)
	var tolerance = max(TEMPO_DELETE_TOLERANCE_BEATS, step * 0.45)
	if _tempo_last_delete_time < 0.0 or step <= 0.0:
		_remove_tempo_points_near(snapped_time, tolerance)
		_tempo_last_delete_time = snapped_time
		return
	if is_equal_approx(snapped_time, _tempo_last_delete_time):
		return
	var delta = snapped_time - _tempo_last_delete_time
	var step_dir = step if delta >= 0.0 else -step
	if step_dir == 0.0:
		return
	var t = _tempo_last_delete_time + step_dir
	while (step_dir > 0.0 and t <= snapped_time) or (step_dir < 0.0 and t >= snapped_time):
		_remove_tempo_points_near(t, tolerance)
		t += step_dir
	_tempo_last_delete_time = snapped_time

func _tempo_update_zoom_drag(local_pos: Vector2) -> void:
	var delta = local_pos.y - _tempo_zoom_last_y
	_tempo_zoom_last_y = local_pos.y
	if abs(delta) < 0.001:
		return
	_tempo_zoom = clamp(_tempo_zoom + (-delta * TEMPO_ZOOM_DRAG_SCALE), TEMPO_ZOOM_MIN, TEMPO_ZOOM_MAX)
	queue_redraw()

func _handle_tempo_map_input(event: InputEvent) -> bool:
	if not show_tempo_map:
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return false
	var pos = event.position if event is InputEventMouse else null
	if pos != null and not _is_in_tempo_map(pos):
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_tempo_zoom_dragging = event.pressed
			if _tempo_zoom_dragging:
				_tempo_zoom_last_y = event.position.y
			accept_event()
			return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_tempo_drawing = true
				_tempo_draw_at(event.position)
			else:
				_tempo_drawing = false
				_tempo_last_draw_time = -1.0
				_tempo_last_draw_bpm = 0.0
			accept_event()
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_tempo_deleting = true
				_tempo_last_delete_time = -1.0
				_tempo_delete_at(event.position)
			else:
				_tempo_deleting = false
				_tempo_last_delete_time = -1.0
			accept_event()
			return true
	if event is InputEventMouseMotion:
		if _tempo_zoom_dragging:
			_tempo_update_zoom_drag(event.position)
			accept_event()
			return true
		if _tempo_drawing:
			_tempo_draw_at(event.position)
			accept_event()
			return true
		if _tempo_deleting:
			_tempo_delete_at(event.position)
			accept_event()
			return true
	return false

func _draw_external_drag_preview(track_index: int, lane_rect: Rect2, dim_factor: float) -> void:
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
	border = _dim_color(border, dim_factor)
	draw_rect(clipped, border, false, 2.0)
	_draw_clip_notes(entry, clip_rect, lane_rect, dim_factor)

func _remove_or_unplace_clip(track_index: int, entry: Dictionary) -> void:
	var track = _get_track(track_index)
	if track == null:
		return
	var clip = entry.get("clip")
	if clip == null:
		return
	if track.has_method("remove_clip_from_arrangement"):
		track.call("remove_clip_from_arrangement", clip)
