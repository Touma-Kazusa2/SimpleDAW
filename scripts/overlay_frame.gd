extends Control

@export var border_color: Color = Color(0.95, 0.55, 0.2, 0.95)
@export var border_width: float = 5.0
@export var border_expand: float = 0.0
@export var corner_radius: float = 4.0


var _style_box := StyleBoxFlat.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_as_relative = false
	z_index = 100
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var rect = Rect2(Vector2(-border_expand, -border_expand), size + Vector2(border_expand * 2.0, border_expand * 2.0))
	_style_box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_style_box.border_color = border_color
	_style_box.border_width_left = int(border_width)
	_style_box.border_width_top = int(border_width)
	_style_box.border_width_right = int(border_width)
	_style_box.border_width_bottom = int(border_width)
	var radius = max(corner_radius, 0.0)
	_style_box.corner_radius_top_left = int(radius)
	_style_box.corner_radius_top_right = int(radius)
	_style_box.corner_radius_bottom_right = int(radius)
	_style_box.corner_radius_bottom_left = int(radius)
	_style_box.draw(get_canvas_item(), rect)
