extends Control

@export var attack_sec: float = 0.02
@export var decay_sec: float = 0.2
@export var sustain_db: float = -6.0
@export var release_sec: float = 0.3

const COLOR_BG = Color(0.06, 0.06, 0.07)
const COLOR_GRID = Color(1.0, 1.0, 1.0, 0.08)
const COLOR_CURVE = Color(0.95, 0.55, 0.2, 0.9)
const COLOR_FILL = Color(0.95, 0.55, 0.2, 0.2)
const COLOR_AXIS = Color(1.0, 1.0, 1.0, 0.18)
const PADDING := 8.0

func set_adsr_values(a: float, d: float, s_db: float, r: float) -> void:
	attack_sec = max(0.0, a)
	decay_sec = max(0.0, d)
	sustain_db = clamp(s_db, -80.0, 0.0)
	release_sec = max(0.0, r)
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	_draw_grid()
	var rect = Rect2(Vector2(PADDING, PADDING), Vector2(size.x - PADDING * 2.0, size.y - PADDING * 2.0))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var sustain_level = clamp((sustain_db + 80.0) / 80.0, 0.0, 1.0)
	var total_time = max(0.001, attack_sec + decay_sec + release_sec + 1.0)
	var a_x = rect.position.x + rect.size.x * (attack_sec / total_time)
	var d_x = rect.position.x + rect.size.x * ((attack_sec + decay_sec) / total_time)
	var s_x = rect.position.x + rect.size.x * ((attack_sec + decay_sec + 1.0) / total_time)
	var r_x = rect.position.x + rect.size.x
	var top_y = rect.position.y
	var sustain_y = rect.position.y + rect.size.y * (1.0 - sustain_level)
	var bottom_y = rect.position.y + rect.size.y
	var points = [
		Vector2(rect.position.x, bottom_y),
		Vector2(a_x, top_y),
		Vector2(d_x, sustain_y),
		Vector2(s_x, sustain_y),
		Vector2(r_x, bottom_y)
	]
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], COLOR_CURVE, 2.0)
	var fill_poly = PackedVector2Array([points[0], points[1], points[2], points[3], points[4], Vector2(points[4].x, bottom_y), Vector2(points[0].x, bottom_y)])
	draw_colored_polygon(fill_poly, COLOR_FILL)
	draw_line(Vector2(rect.position.x, bottom_y), Vector2(rect.position.x, top_y), COLOR_AXIS, 1.0)
	draw_line(Vector2(rect.position.x, bottom_y), Vector2(rect.position.x + rect.size.x, bottom_y), COLOR_AXIS, 1.0)

func _draw_grid() -> void:
	var cols = 6
	var rows = 4
	for i in range(1, cols):
		var x = (size.x / cols) * i
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), COLOR_GRID, 1.0)
	for j in range(1, rows):
		var y = (size.y / rows) * j
		draw_line(Vector2(0.0, y), Vector2(size.x, y), COLOR_GRID, 1.0)
