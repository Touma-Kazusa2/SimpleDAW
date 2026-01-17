extends Control

signal selection_committed(start_beats: float, end_beats: float)
signal selection_cleared
signal panel_toggled(is_open: bool)
signal panel_height_changed(height: float)

@export var snap_threshold: float = 12.0
@export var drag_threshold: float = 6.0
@export var snap_step_beats: float = 1.0
@export var snap_enabled: bool = true
@export var max_panel_height: float = -1.0

var panel: Control = null
var panel_height: float = 0.0

var pixels_per_beat: float = 120.0
var visible_beats: int = 32
var view_scroll_x: float = 0.0
var view_width: float = 0.0

var selection_start: float = -1.0
var selection_end: float = -1.0

var _dragging := false
var _drag_axis := ""
var _drag_start_pos := Vector2.ZERO
var _drag_start_height := 0.0
var _drag_start_x := 0.0
var _drag_start_global := Vector2.ZERO
var _drag_start_local_x := 0.0
var _last_vertical_delta := 0.0
var _panel_was_open := false

func setup(target_panel: Control) -> void:
	panel = target_panel
	if panel:
		panel_height = panel.custom_minimum_size.y
	queue_redraw()

func update_from_roll(ppb: float, beats: int, scroll_x: float, width: float) -> void:
	pixels_per_beat = ppb
	visible_beats = beats
	view_scroll_x = scroll_x
	view_width = width
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_axis = ""
			_drag_start_pos = event.position
			_drag_start_global = event.global_position
			_drag_start_local_x = event.position.x
			_drag_start_x = event.position.x
			_drag_start_height = _current_panel_height()
			_panel_was_open = _drag_start_height > 0.0
			_last_vertical_delta = 0.0
			accept_event()
		else:
			if _dragging:
				_finalize_drag(_get_stable_local(event.global_position))
				_dragging = false
				_drag_axis = ""
				accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		clear_selection()
		emit_signal("selection_cleared")
		accept_event()
		return
	if event is InputEventMouseMotion and _dragging:
		_update_drag(_get_stable_local(event.global_position))
		accept_event()

func _update_drag(pos: Vector2) -> void:
	var delta = Vector2(
		pos.x - _drag_start_pos.x,
		pos.y - _drag_start_pos.y
	)
	if _drag_axis == "":
		if abs(delta.y) >= drag_threshold:
			_drag_axis = "vertical"
		elif abs(delta.x) >= drag_threshold:
			_drag_axis = "horizontal"
		else:
			return
	if _drag_axis == "vertical":
		_update_vertical_drag(pos)
	elif _drag_axis == "horizontal":
		_update_horizontal_drag(pos.x)

func _update_vertical_drag(local_pos: Vector2) -> void:
	if panel == null:
		return
	var delta_y = local_pos.y - _drag_start_pos.y
	_last_vertical_delta = delta_y
	var next_height = max(0.0, _drag_start_height + delta_y)
	if max_panel_height > 0.0:
		next_height = min(next_height, max_panel_height)
	panel.custom_minimum_size.y = next_height
	panel.visible = next_height > 0.0
	panel_height = next_height
	emit_signal("panel_height_changed", panel_height)
	if panel.get_parent() is Control:
		(panel.get_parent() as Control).queue_redraw()

func _update_horizontal_drag(current_x: float) -> void:
	if pixels_per_beat <= 0.0:
		return
	var local_start = _drag_start_x
	var local_end = current_x
	var start_beats = (view_scroll_x + min(local_start, local_end)) / pixels_per_beat
	var end_beats = (view_scroll_x + max(local_start, local_end)) / pixels_per_beat
	start_beats = _snap_beats(start_beats)
	end_beats = _snap_beats(end_beats)
	start_beats = clamp(start_beats, 0.0, float(visible_beats))
	end_beats = clamp(end_beats, 0.0, float(visible_beats))
	_emit_selection_preview(start_beats, end_beats)

func _finalize_drag(pos: Vector2) -> void:
	if _drag_axis == "vertical":
		_finalize_vertical()
	elif _drag_axis == "horizontal":
		_finalize_horizontal(pos.x)

func _finalize_vertical() -> void:
	if panel == null:
		return
	if max_panel_height > 0.0:
		panel_height = min(panel_height, max_panel_height)
	if abs(_last_vertical_delta) < drag_threshold:
		if _panel_was_open:
			panel_height = _drag_start_height
			panel.custom_minimum_size.y = panel_height
			panel.visible = panel_height > 0.0
		return
	if _panel_was_open:
		if panel_height <= snap_threshold:
			panel_height = 0.0
			panel.custom_minimum_size.y = 0.0
			panel.visible = false
		else:
			panel.custom_minimum_size.y = panel_height
			panel.visible = true
	else:
		if max_panel_height > 0.0:
			panel_height = min(panel_height, max_panel_height)
		panel.custom_minimum_size.y = panel_height
		panel.visible = panel_height > 0.0
	if panel.get_parent() is Control:
		(panel.get_parent() as Control).queue_redraw()
	emit_signal("panel_toggled", panel_height > 0.0)
	emit_signal("panel_height_changed", panel_height)

func toggle_panel() -> bool:
	var next_open = not is_panel_open()
	set_panel_open(next_open)
	return next_open

func set_panel_open(open: bool) -> void:
	if panel == null:
		return
	if open:
		if max_panel_height > 0.0:
			panel_height = min(panel_height, max_panel_height)
		panel.custom_minimum_size.y = panel_height
		panel.visible = true
	else:
		panel_height = 0.0
		panel.custom_minimum_size.y = 0.0
		panel.visible = false
	if panel.get_parent() is Control:
		(panel.get_parent() as Control).queue_redraw()
	emit_signal("panel_toggled", panel_height > 0.0)
	emit_signal("panel_height_changed", panel_height)

func is_panel_open() -> bool:
	return panel_height > 0.0

func _finalize_horizontal(current_x: float) -> void:
	if pixels_per_beat <= 0.0:
		return
	var local_start = _drag_start_x
	var local_end = current_x
	if abs(local_end - local_start) <= drag_threshold:
		return
	var start_beats = (view_scroll_x + min(local_start, local_end)) / pixels_per_beat
	var end_beats = (view_scroll_x + max(local_start, local_end)) / pixels_per_beat
	start_beats = _snap_beats(start_beats)
	end_beats = _snap_beats(end_beats)
	start_beats = clamp(start_beats, 0.0, float(visible_beats))
	end_beats = clamp(end_beats, 0.0, float(visible_beats))
	if is_equal_approx(start_beats, end_beats):
		var step = max(0.0, snap_step_beats)
		if step > 0.0:
			if end_beats >= start_beats:
				end_beats = clamp(start_beats + step, 0.0, float(visible_beats))
			else:
				start_beats = clamp(end_beats + step, 0.0, float(visible_beats))
	_emit_selection_preview(start_beats, end_beats)
	emit_signal("selection_committed", start_beats, end_beats)

func _emit_selection_preview(start_beats: float, end_beats: float) -> void:
	set_selection(start_beats, end_beats)

func _current_panel_height() -> float:
	if panel == null:
		return 0.0
	if panel.visible:
		return panel.custom_minimum_size.y
	return 0.0

func _get_stable_local(global_pos: Vector2) -> Vector2:
	var delta_global_x = global_pos.x - _drag_start_global.x
	var delta_global_y = global_pos.y - _drag_start_global.y
	return Vector2(
		_drag_start_local_x + delta_global_x,
		_drag_start_pos.y + delta_global_y
	)

func _snap_beats(beats: float) -> float:
	if not snap_enabled:
		return beats
	var step = max(0.0, snap_step_beats)
	if step <= 0.0:
		return beats
	return round(beats / step) * step

func toggle_snap() -> bool:
	snap_enabled = !snap_enabled
	return snap_enabled

func is_snap_enabled() -> bool:
	return snap_enabled

func get_snap_step() -> float:
	return snap_step_beats

func set_selection(start_beats: float, end_beats: float) -> void:
	selection_start = clamp(min(start_beats, end_beats), 0.0, float(visible_beats))
	selection_end = clamp(max(start_beats, end_beats), 0.0, float(visible_beats))
	queue_redraw()

func clear_selection() -> void:
	selection_start = -1.0
	selection_end = -1.0
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var bg = Color(0.08, 0.08, 0.09)
	var edge = Color(0.9, 0.9, 0.95, 0.18)
	draw_rect(Rect2(Vector2.ZERO, size), bg, true)
	draw_line(Vector2(0.0, size.y - 1.0), Vector2(size.x, size.y - 1.0), edge, 1.0)
	_draw_selection()

func _draw_selection() -> void:
	if selection_start < 0.0 or selection_end <= selection_start:
		return
	var offset_x = -view_scroll_x
	var x0 = selection_start * pixels_per_beat + offset_x
	var x1 = selection_end * pixels_per_beat + offset_x
	var rect = Rect2(Vector2(x0, 0.0), Vector2(x1 - x0, size.y))
	var clip_width = size.x
	if view_width > 0.0:
		clip_width = min(size.x, view_width)
	var view_rect = Rect2(Vector2.ZERO, Vector2(clip_width, size.y))
	var clipped = rect.intersection(view_rect)
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		return
	var fill = Color(0.95, 0.55, 0.2, 0.18)
	var border = Color(0.95, 0.55, 0.2, 0.8)
	var inset = 1.0
	var inner = Rect2(
		clipped.position + Vector2(inset, inset),
		clipped.size - Vector2(inset * 2.0, inset * 2.0)
	)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	draw_rect(inner, fill, true)
	var epsilon = 0.5
	var left_clipped = clipped.position.x > rect.position.x + epsilon
	var right_clipped = (clipped.position.x + clipped.size.x) < (rect.position.x + rect.size.x - epsilon)
	var top_y = inner.position.y
	var bottom_y = inner.position.y + inner.size.y
	var left_x = inner.position.x
	var right_x = inner.position.x + inner.size.x
	draw_line(Vector2(left_x, top_y), Vector2(right_x, top_y), border, 1.0)
	draw_line(Vector2(left_x, bottom_y), Vector2(right_x, bottom_y), border, 1.0)
	if not left_clipped:
		draw_line(Vector2(left_x, top_y), Vector2(left_x, bottom_y), border, 1.0)
	if not right_clipped:
		draw_line(Vector2(right_x, top_y), Vector2(right_x, bottom_y), border, 1.0)

func set_selection_from_roll(start_beats: float, end_beats: float) -> void:
	set_selection(start_beats, end_beats)
