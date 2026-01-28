extends Control

signal camera_changed

@export var target_path: NodePath
@export var camera_path: NodePath

const VIEWPORT_BASE = Vector2i(1024, 768)

var rotating := false
var last_pos := Vector2.ZERO
var yaw := 0.0
var pitch := 0.0
var distance := 4.0
var _layout_pending := false
var view_scroll_y := 0.0

@onready var viewport: SubViewport = $"Viewport"
@onready var viewport_texture: TextureRect = $"ViewportTexture"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	if viewport_texture != null:
		viewport_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_configure_viewport()
	_apply_camera()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	_request_layout()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			rotating = event.pressed
			last_pos = event.position
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = max(1.5, distance - 0.3)
			_apply_camera()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = min(12.0, distance + 0.3)
			_apply_camera()
			accept_event()
	elif event is InputEventMouseMotion and rotating:
		var delta = event.position - last_pos
		last_pos = event.position
		yaw -= delta.x * 0.01
		pitch = clamp(pitch - delta.y * 0.01, -1.2, 1.2)
		_apply_camera()
		accept_event()

func _apply_camera() -> void:
	var target = get_node_or_null(target_path) as Node3D
	var camera = get_node_or_null(camera_path) as Camera3D
	if target == null or camera == null:
		return
	var x = distance * cos(pitch) * sin(yaw)
	var y = distance * sin(pitch)
	var z = distance * cos(pitch) * cos(yaw)
	camera.global_position = target.global_position + Vector3(x, y, z)
	camera.look_at(target.global_position, Vector3.UP)
	emit_signal("camera_changed")

func _configure_viewport() -> void:
	if viewport == null:
		return
	viewport.size = VIEWPORT_BASE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if viewport_texture != null:
		viewport_texture.texture = viewport.get_texture()
		viewport_texture.size = Vector2(VIEWPORT_BASE.x, VIEWPORT_BASE.y)

func _on_resized() -> void:
	_request_layout()

func _request_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	call_deferred("_apply_layout")

func _apply_layout() -> void:
	_layout_pending = false
	if viewport_texture == null:
		return
	var width = max(1.0, size.x)
	var height = max(1.0, width * 0.5625)
	var viewport_size = Vector2(width, height)
	if viewport != null:
		viewport.size = Vector2i(int(round(width)), int(round(height)))
	viewport_texture.size = viewport_size
	var x = 0.0
	var base_offset_y = max(0.0, size.y - height)
	var y = base_offset_y - view_scroll_y
	viewport_texture.position = Vector2(round(x), round(y))

func get_content_height() -> float:
	var width = max(1.0, size.x)
	return max(1.0, width * 0.5625)

func set_view_scroll_y(scroll_y: float) -> void:
	view_scroll_y = max(0.0, scroll_y)
	_request_layout()

func get_camera_state() -> Dictionary:
	return {
		"yaw": yaw,
		"pitch": pitch,
		"distance": distance
	}

func set_camera_state(state: Dictionary) -> void:
	if state == null:
		return
	yaw = float(state.get("yaw", yaw))
	pitch = float(state.get("pitch", pitch))
	distance = float(state.get("distance", distance))
	_apply_camera()
