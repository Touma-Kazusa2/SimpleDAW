extends Control

@export var enabled: bool = false

var last_pos: Vector2 = Vector2(-1, -1)

func set_last_pos(pos: Vector2) -> void:
	last_pos = pos
	queue_redraw()

func _draw() -> void:
	if not enabled:
		return
	if last_pos.x < 0 or last_pos.y < 0:
		return
	var color = Color(1.0, 0.6, 0.2)
	draw_circle(last_pos, 4.0, color)
	draw_line(last_pos + Vector2(-8, 0), last_pos + Vector2(8, 0), color, 1.0)
	draw_line(last_pos + Vector2(0, -8), last_pos + Vector2(0, 8), color, 1.0)