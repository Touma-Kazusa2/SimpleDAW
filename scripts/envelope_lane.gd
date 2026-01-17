extends Control

@export var pixels_per_beat: float = 120.0
@export var beats_per_measure: int = 4
@export var visible_beats: int = 32
@export var view_scroll_x: float = 0.0
@export var view_width: float = 0.0

const COLOR_BG = Color(0.06, 0.06, 0.07)
const COLOR_GRID = Color(1.0, 1.0, 1.0, 0.08)
const COLOR_MEASURE = Color(1.0, 1.0, 1.0, 0.18)
const COLOR_DEFAULT = Color(0.95, 0.55, 0.2, 0.8)
const COLOR_CURVE = Color(0.95, 0.55, 0.2, 0.9)
const COLOR_POINT = Color(0.98, 0.82, 0.25, 1.0)

var model: Node = null
var snap_provider: Node = null
var roll: Control = null
var is_drawing := false
var is_deleting := false
var last_draw_time := -1.0
var last_draw_value := 0.0
var curve_mode: String = "line"

const DEFAULT_VALUE := 0.5
const POINT_RADIUS := 3.0

@export var draw_step_beats: float = 0.25
@export var delete_tolerance_beats: float = 0.15

func set_from_roll(roll_node: Control) -> void:
	if roll_node == null:
		return
	self.roll = roll_node
	pixels_per_beat = float(roll_node.get("pixels_per_beat"))
	beats_per_measure = int(roll_node.get("beats_per_measure"))
	visible_beats = int(roll_node.get("visible_beats"))
	set_model(roll_node.get_node_or_null("EnvelopeModel"))
	queue_redraw()

func set_model(next_model: Node) -> void:
	if model:
		var callable = Callable(self, "_on_model_changed")
		if model.is_connected("changed", callable):
			model.disconnect("changed", callable)
	model = next_model
	if model:
		model.connect("changed", Callable(self, "_on_model_changed"))

func _on_model_changed() -> void:
	queue_redraw()

func set_snap_provider(next_provider: Node) -> void:
	snap_provider = next_provider

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_view(scroll_x: float, width: float) -> void:
	view_scroll_x = scroll_x
	view_width = width
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	_draw_grid()
	_draw_curve()

func _draw_grid() -> void:
	var total_width = visible_beats * pixels_per_beat
	if total_width <= 0.0:
		return
	var clip_width = size.x
	if view_width > 0.0:
		clip_width = min(size.x, view_width)
	var draw_x0 = 0.0
	var draw_x1 = total_width
	if view_width > 0.0:
		draw_x0 = clamp(view_scroll_x, 0.0, total_width)
		draw_x1 = clamp(view_scroll_x + view_width, 0.0, total_width)
	var beat_start = int(floor(draw_x0 / pixels_per_beat))
	var beat_end = int(ceil(draw_x1 / pixels_per_beat))
	beat_start = clamp(beat_start, 0, visible_beats)
	beat_end = clamp(beat_end, 0, visible_beats)
	var offset_x = -view_scroll_x
	for beat in range(beat_start, beat_end + 1):
		var x = beat * pixels_per_beat + offset_x
		var color = COLOR_MEASURE if beat % max(1, beats_per_measure) == 0 else COLOR_GRID
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), color, 1.0)
	for i in range(1, 4):
		var y = (size.y * i) / 4.0
		draw_line(Vector2(0.0, y), Vector2(clip_width, y), COLOR_GRID, 1.0)

func _draw_default_line() -> void:
	var value = DEFAULT_VALUE
	if model != null and model.has_method("get_current_default_value"):
		value = float(model.call("get_current_default_value"))
	var t = clamp(value, 0.0, 1.0)
	var y = (1.0 - t) * size.y
	var clip_width = size.x
	if view_width > 0.0:
		clip_width = min(size.x, view_width)
	draw_line(Vector2(0.0, y), Vector2(clip_width, y), COLOR_DEFAULT, 2.0)

func _draw_curve() -> void:
	if model == null or not model.has_method("get_points"):
		_draw_default_line()
		return
	var points = model.call("get_points") as Array
	if points.is_empty():
		_draw_default_line()
		return
	var clip_width = size.x
	if view_width > 0.0:
		clip_width = min(size.x, view_width)
	var offset_x = -view_scroll_x
	var prev_pos: Vector2 = Vector2.ZERO
	var has_prev = false
	var view_positions: Array = []
	for entry in points:
		var time_beats = float(entry.get("time", 0.0))
		var value = float(entry.get("value", DEFAULT_VALUE))
		var x = time_beats * pixels_per_beat + offset_x
		var y = (1.0 - clamp(value, 0.0, 1.0)) * size.y
		var pos = Vector2(x, y)
		view_positions.append(pos)
	if curve_mode == "bezier" and view_positions.size() >= 2:
		_draw_bezier_curve(view_positions, clip_width)
	else:
		for pos in view_positions:
			if has_prev:
				var seg_min_x = min(prev_pos.x, pos.x)
				var seg_max_x = max(prev_pos.x, pos.x)
				if seg_max_x >= -POINT_RADIUS and seg_min_x <= clip_width + POINT_RADIUS:
					draw_line(prev_pos, pos, COLOR_CURVE, 2.0)
			if pos.x >= -POINT_RADIUS and pos.x <= clip_width + POINT_RADIUS:
				draw_circle(pos, POINT_RADIUS, COLOR_POINT)
			prev_pos = pos
			has_prev = true

func _gui_input(event: InputEvent) -> void:
	if model == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if roll != null and roll.has_method("_on_roll_gui_input"):
				roll.call("_on_roll_gui_input", event)
				accept_event()
				return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_drawing = true
				_paint_at(event.position)
			else:
				is_drawing = false
				last_draw_time = -1.0
				last_draw_value = 0.0
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_deleting = true
				_delete_at(event.position)
			else:
				is_deleting = false
			accept_event()
	elif event is InputEventMouseMotion:
		if is_drawing:
			_paint_at(event.position)
			accept_event()
		elif is_deleting:
			_delete_at(event.position)
			accept_event()

func _paint_at(local_pos: Vector2) -> void:
	var time = _time_from_pos(local_pos.x)
	var value = _value_from_pos(local_pos.y)
	var step = _get_step_beats()
	var snapped_time = _snap_time(time, step)
	if is_equal_approx(snapped_time, last_draw_time):
		return
	if last_draw_time < 0.0:
		last_draw_time = snapped_time
		last_draw_value = value
		if model.has_method("set_point"):
			model.call("set_point", snapped_time, value, step)
		return
	var delta = snapped_time - last_draw_time
	var step_dir = step if delta >= 0.0 else -step
	if step <= 0.0 or step_dir == 0.0:
		return
	var t = last_draw_time + step_dir
	while (step_dir > 0.0 and t <= snapped_time) or (step_dir < 0.0 and t >= snapped_time):
		var alpha = 0.0 if is_equal_approx(snapped_time, last_draw_time) else (t - last_draw_time) / delta
		var interp_value = lerp(last_draw_value, value, alpha)
		if model.has_method("set_point"):
			model.call("set_point", t, interp_value, step)
		t += step_dir
	last_draw_time = snapped_time
	last_draw_value = value

func _delete_at(local_pos: Vector2) -> void:
	if not model.has_method("remove_points_near"):
		return
	var time = _time_from_pos(local_pos.x)
	var step = max(0.0, _get_step_beats())
	var snapped_time = _snap_time(time, step)
	var tolerance = max(delete_tolerance_beats, step * 0.45)
	model.call("remove_points_near", snapped_time, tolerance)

func _time_from_pos(local_x: float) -> float:
	if pixels_per_beat <= 0.0:
		return 0.0
	return (view_scroll_x + local_x) / pixels_per_beat

func _value_from_pos(local_y: float) -> float:
	if size.y <= 0.0:
		return DEFAULT_VALUE
	var t = 1.0 - (local_y / size.y)
	return clamp(t, 0.0, 1.0)

func _get_step_beats() -> float:
	return draw_step_beats

func _snap_time(time_beats: float, step: float) -> float:
	if step <= 0.0:
		return time_beats
	return round(time_beats / step) * step

func set_curve_mode(mode: String) -> void:
	if mode != "line" and mode != "bezier":
		return
	curve_mode = mode
	queue_redraw()

func toggle_curve_mode() -> String:
	curve_mode = "bezier" if curve_mode == "line" else "line"
	queue_redraw()
	return curve_mode

func _draw_bezier_curve(points: Array, clip_width: float) -> void:
	var curve = Curve2D.new()
	for i in range(points.size()):
		var p = points[i] as Vector2
		var prev = points[i - 1] as Vector2 if i > 0 else p
		var next = points[i + 1] as Vector2 if i < points.size() - 1 else p
		var tangent = (next - prev) * 0.25
		curve.add_point(p, -tangent, tangent)
	var baked = curve.tessellate(8)
	var prev_pos: Vector2 = Vector2.ZERO
	var has_prev = false
	for pos in baked:
		if has_prev:
			var seg_min_x = min(prev_pos.x, pos.x)
			var seg_max_x = max(prev_pos.x, pos.x)
			if seg_max_x >= -POINT_RADIUS and seg_min_x <= clip_width + POINT_RADIUS:
				draw_line(prev_pos, pos, COLOR_CURVE, 2.0)
		prev_pos = pos
		has_prev = true
	for pos in points:
		if pos.x >= -POINT_RADIUS and pos.x <= clip_width + POINT_RADIUS:
			draw_circle(pos, POINT_RADIUS, COLOR_POINT)
