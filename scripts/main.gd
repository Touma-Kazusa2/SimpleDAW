extends Control

const DEBUG_LOGS := false

@export var bpm: float = 120.0
@export var pixels_per_beat: float = 120.0
@export var key_height: float = 16.0
@export var min_pitch: int = 36 # C2
@export var max_pitch: int = 96 # C7
@export var beats_per_measure: int = 4
@export var visible_beats: int = 32
@export var keyboard_width: float = 80.0
@export var input_debug_enabled: bool = false

const MIN_KEY_HEIGHT := 8.0
const MAX_KEY_HEIGHT := 40.0
const MIN_PIXELS_PER_BEAT := 40.0
const MAX_PIXELS_PER_BEAT := 320.0
const KEY_HEIGHT_DRAG_SCALE := 0.05
const SCROLL_STEP_X := 80.0
const SCROLL_STEP_Y := 64.0

var is_playing: bool = false
var current_time_beats: float = 0.0
var ctrl_modifier_active: bool = false
var scroll_x: float = 0.0
var scroll_y: float = 0.0
var velocity_mode: bool = false
var last_view_width: float = 0.0
var last_content_height: float = 0.0
var shift_modifier_active: bool = false

@onready var grid = $RollPanel/RollContent/Grid
@onready var notes_view = $RollPanel/RollContent/NotesLayer
@onready var playhead = $RollPanel/RollContent/Playhead
@onready var notes_model = $NotesModel
@onready var input_controller = $InputController
@onready var roll_content = $RollPanel/RollContent
@onready var roll_panel = $RollPanel
@onready var piano_keyboard = $PianoKeyboard
@onready var input_debug = $RollPanel/RollContent/InputDebug

func _ready() -> void:
	grid.z_as_relative = false
	notes_view.z_as_relative = false
	playhead.z_as_relative = false
	input_debug.z_as_relative = false
	grid.z_index = -10
	notes_view.z_index = 10
	playhead.z_index = 20
	input_debug.z_index = 30
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	_apply_config()
	notes_view.set_model(notes_model)
	notes_view.show_velocity = true
	input_controller.setup(notes_model, roll_content)
	input_controller.debug_enabled = input_debug_enabled
	input_debug.enabled = input_debug_enabled
	var gui_callable = Callable(input_controller, "_on_roll_gui_input")
	if not roll_content.gui_input.is_connected(gui_callable):
		roll_content.gui_input.connect(gui_callable)
	var playhead_time_callable = Callable(self, "_on_playhead_time_changed")
	if not input_controller.is_connected("playhead_time_changed", playhead_time_callable):
		input_controller.connect("playhead_time_changed", playhead_time_callable)
	var playhead_start_callable = Callable(self, "_on_playhead_drag_started")
	if not input_controller.is_connected("playhead_drag_started", playhead_start_callable):
		input_controller.connect("playhead_drag_started", playhead_start_callable)
	var debug_callable = Callable(input_debug, "set_last_pos")
	if not input_controller.is_connected("debug_click", debug_callable):
		input_controller.connect("debug_click", debug_callable)
	_update_playhead()

func _apply_config() -> void:
	var prev_height = last_content_height
	var grid_width = visible_beats * pixels_per_beat
	var grid_height = (max_pitch - min_pitch + 1) * key_height

	roll_content.set_anchors_preset(Control.PRESET_TOP_LEFT)
	roll_content.offset_left = 0.0
	roll_content.offset_top = 0.0
	roll_content.custom_minimum_size = Vector2(grid_width, grid_height)
	roll_content.size = roll_content.custom_minimum_size
	last_content_height = grid_height
	var next_scroll_y = scroll_y
	if prev_height > 0.0 and grid_height > 0.0:
		next_scroll_y = scroll_y * (grid_height / prev_height)
	_set_scroll_position(scroll_x, next_scroll_y)
	piano_keyboard.custom_minimum_size = Vector2(keyboard_width, grid_height)
	_update_layout()

	grid.pixels_per_beat = pixels_per_beat
	grid.key_height = key_height
	grid.min_pitch = min_pitch
	grid.max_pitch = max_pitch
	grid.beats_per_measure = beats_per_measure
	grid.visible_beats = visible_beats
	grid.queue_redraw()

	notes_view.pixels_per_beat = pixels_per_beat
	notes_view.key_height = key_height
	notes_view.min_pitch = min_pitch
	notes_view.max_pitch = max_pitch
	notes_view.beats_per_measure = beats_per_measure
	notes_view.visible_beats = visible_beats
	notes_view.queue_redraw()

	playhead.queue_redraw()

	piano_keyboard.key_height = key_height
	piano_keyboard.min_pitch = min_pitch
	piano_keyboard.max_pitch = max_pitch
	piano_keyboard.queue_redraw()

	input_controller.set_grid_params(
		pixels_per_beat,
		key_height,
		min_pitch,
		max_pitch,
		visible_beats
	)
	last_view_width = roll_panel.size.x
	_sync_viewport()

func _process(delta: float) -> void:
	if is_playing:
		var next_time = current_time_beats + (bpm / 60.0) * delta
		if next_time > visible_beats:
			next_time = 0.0
			is_playing = false
		_set_playhead_time(next_time)
	_sync_viewport()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_CTRL:
			ctrl_modifier_active = event.pressed
		elif event.keycode == KEY_SHIFT:
			shift_modifier_active = event.pressed
		elif event.pressed and event.keycode == KEY_LEFT:
			_set_scroll_x(scroll_x - SCROLL_STEP_X)
			_print_scroll_state("left")
		elif event.pressed and event.keycode == KEY_RIGHT:
			_set_scroll_x(scroll_x + SCROLL_STEP_X)
			_print_scroll_state("right")
		elif event.pressed and event.keycode == KEY_UP:
			_set_scroll_y(scroll_y - SCROLL_STEP_Y)
			_print_scroll_state("up")
		elif event.pressed and event.keycode == KEY_DOWN:
			_set_scroll_y(scroll_y + SCROLL_STEP_Y)
			_print_scroll_state("down")
		elif event.pressed and event.keycode == KEY_SPACE:
			is_playing = !is_playing
		elif event.pressed and event.keycode == KEY_HOME:
			is_playing = false
			_set_playhead_time(0.0)
		elif event.pressed and event.keycode == KEY_G:
			var enabled = input_controller.toggle_snap()
			if enabled:
				if input_controller.get_snap_step() <= 0.0:
					input_controller.cycle_snap_step()
				var step = input_controller.get_snap_step()
				var label = "free" if step <= 0.0 else str(step)
				if DEBUG_LOGS:
					print("Snap on:", label)
			else:
				if DEBUG_LOGS:
					print("Snap off")
		elif event.pressed and event.keycode == KEY_K:
			visible_beats += beats_per_measure * 4
			_apply_config()
		elif event.pressed and event.keycode == KEY_L:
			velocity_mode = !velocity_mode
			input_controller.velocity_mode = velocity_mode

	if event is InputEventMouseButton and event.pressed:
		var wheel_up = event.button_index == MOUSE_BUTTON_WHEEL_UP
		var wheel_down = event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		if wheel_up or wheel_down:
			if ctrl_modifier_active:
				var mouse_local = roll_panel.get_local_mouse_position()
				var content_x = scroll_x + mouse_local.x
				var delta = 1.0 if wheel_up else -1.0
				pixels_per_beat = clamp(pixels_per_beat + (delta * 10.0), MIN_PIXELS_PER_BEAT, MAX_PIXELS_PER_BEAT)
				_apply_config()
				_restore_scroll_from_anchor(content_x, mouse_local.x)
				get_viewport().set_input_as_handled()
			elif shift_modifier_active:
				var scroll_delta = SCROLL_STEP_Y * (1.0 if wheel_down else -1.0)
				_set_scroll_y(scroll_y + scroll_delta)
				_print_scroll_state("shift+wheel")
				get_viewport().set_input_as_handled()
			else:
				var scroll_delta = SCROLL_STEP_X * (1.0 if wheel_down else -1.0)
				_set_scroll_x(scroll_x + scroll_delta)
				_print_scroll_state("wheel")
				get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			var delta = -event.relative.y * KEY_HEIGHT_DRAG_SCALE
			if abs(delta) > 0.001:
				key_height = clamp(key_height + delta, MIN_KEY_HEIGHT, MAX_KEY_HEIGHT)
				_apply_config()

func _update_playhead() -> void:
	playhead.position.x = current_time_beats * pixels_per_beat

func _set_playhead_time(time_beats: float) -> void:
	current_time_beats = time_beats
	_update_playhead()
	notes_view.playhead_time_beats = current_time_beats
	notes_view.queue_redraw()
	input_controller.playhead_time_beats = current_time_beats

func _set_scroll_x(value: float) -> void:
	_set_scroll_position(value, scroll_y)

func _set_scroll_y(value: float) -> void:
	_set_scroll_position(scroll_x, value)

func _set_scroll_position(next_x: float, next_y: float) -> void:
	if roll_content == null or roll_panel == null:
		return
	var max_x = max(0.0, roll_content.size.x - roll_panel.size.x)
	var max_y = max(0.0, roll_content.size.y - roll_panel.size.y)
	scroll_x = clamp(next_x, 0.0, max_x)
	scroll_y = clamp(next_y, 0.0, max_y)
	roll_content.position = Vector2(-scroll_x, -scroll_y)
	_sync_viewport()

func _update_layout() -> void:
	if roll_panel == null or piano_keyboard == null:
		return
	var view_size = size
	piano_keyboard.position = Vector2.ZERO
	piano_keyboard.size = Vector2(keyboard_width, view_size.y)
	roll_panel.position = Vector2(keyboard_width, 0.0)
	roll_panel.size = Vector2(max(0.0, view_size.x - keyboard_width), view_size.y)

func _on_resized() -> void:
	_update_layout()
	_sync_viewport()

func _print_scroll_state(source: String) -> void:
	var max_x = max(0.0, roll_content.size.x - roll_panel.size.x)
	var max_y = max(0.0, roll_content.size.y - roll_panel.size.y)
	if DEBUG_LOGS:
		print("Scroll(", source, "): x=", scroll_x, "/", max_x, " y=", scroll_y, "/", max_y)

func _restore_scroll_from_anchor(content_x: float, mouse_local_x: float) -> void:
	_set_scroll_x(content_x - mouse_local_x)

func _sync_viewport() -> void:
	if roll_panel == null or notes_view == null:
		return
	var view_width = roll_panel.size.x
	var needs_redraw = false
	if view_width != last_view_width:
		last_view_width = view_width
		needs_redraw = true
	if notes_view.view_scroll_x != scroll_x:
		notes_view.view_scroll_x = scroll_x
		needs_redraw = true
	notes_view.view_width = view_width
	if piano_keyboard.view_scroll_y != scroll_y:
		piano_keyboard.view_scroll_y = scroll_y
		piano_keyboard.queue_redraw()
	if needs_redraw:
		notes_view.queue_redraw()

func _on_playhead_drag_started() -> void:
	is_playing = false

func _on_playhead_time_changed(time_beats: float) -> void:
	_set_playhead_time(time_beats)
