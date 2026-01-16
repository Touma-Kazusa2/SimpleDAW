extends Control

@export var color: Color = Color(1.0, 0.2, 0.2)
@export var line_width: float = 3.0

func _draw() -> void:
	var half = line_width * 0.5
	draw_line(Vector2(-half, 0), Vector2(-half, size.y), color, line_width)
