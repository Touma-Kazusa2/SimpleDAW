extends Control

signal content_changed

const WHITE_NOTES := [0, 2, 4, 5, 7, 9, 11]
const BLACK_NOTES := [1, 3, 6, 8, 10]
const NOTE_NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

@export var white_key_width: float = 20.0
@export var black_key_width_ratio: float = 0.6
@export var black_key_height_ratio: float = 0.62
@export var key_height: float = 120.0
@export var waterfall_speed: float = 280.0
@export var show_note_labels: bool = true
@export var start_key: int = 21
@export var end_key: int = 108
@export var key_width_step: float = 2.0
@export var key_width_min: float = 10.0
@export var key_width_max: float = 40.0

const COLOR_WHITE = Color(0.92, 0.92, 0.94)
const COLOR_WHITE_ACTIVE = Color(0.98, 0.8, 0.45)
const COLOR_WHITE_BORDER = Color(0.08, 0.08, 0.1)
const COLOR_BLACK = Color(0.12, 0.12, 0.14)
const COLOR_BLACK_ACTIVE = Color(0.9, 0.6, 0.25)
const COLOR_BLACK_BORDER = Color(0.04, 0.04, 0.05)
const COLOR_WATERFALL = Color(0.95, 0.55, 0.2, 0.6)
const COLOR_WATERFALL_ACTIVE = Color(0.95, 0.65, 0.3, 0.85)
const LABEL_WHITE = Color(0.12, 0.12, 0.16)
const LABEL_BLACK = Color(0.9, 0.9, 0.92)

var _white_keys: Array = []
var _black_keys: Array = []
var _scroll_x := 0.0
var _content_width := 0.0
var _active_notes: Dictionary = {}
var _waterfall_notes: Array = []
var _now_sec := 0.0

func _ready() -> void:
	set_process(true)
	_rebuild_layout()
	custom_minimum_size.y = key_height
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)

func _process(_delta: float) -> void:
	_now_sec = Time.get_ticks_msec() / 1000.0
	_prune_waterfall()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.shift_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_key_width(key_width_step)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_key_width(-key_width_step)
			accept_event()

func _on_resized() -> void:
	queue_redraw()

func _rebuild_layout() -> void:
	_white_keys.clear()
	_black_keys.clear()
	custom_minimum_size.y = key_height
	var white_index := 0
	for pitch in range(start_key, end_key + 1):
		var note = pitch % 12
		if WHITE_NOTES.has(note):
			var x = float(white_index) * white_key_width
			_white_keys.append({
				"pitch": pitch,
				"x": x
			})
			white_index += 1
		else:
			var x_black = (float(white_index) - 1.0) * white_key_width + white_key_width * 0.65
			_black_keys.append({
				"pitch": pitch,
				"x": x_black
			})
	_content_width = float(white_index) * white_key_width
	_scroll_x = clamp(_scroll_x, 0.0, get_max_scroll_x())
	emit_signal("content_changed")
	queue_redraw()

func _adjust_key_width(delta: float) -> void:
	var next_width = clamp(white_key_width + delta, key_width_min, key_width_max)
	if is_equal_approx(next_width, white_key_width):
		return
	white_key_width = next_width
	_rebuild_layout()

func get_content_width() -> float:
	return _content_width

func get_scroll_x() -> float:
	return _scroll_x

func get_max_scroll_x() -> float:
	return max(0.0, _content_width - size.x)

func set_scroll_x(value: float) -> void:
	_scroll_x = clamp(value, 0.0, get_max_scroll_x())
	queue_redraw()

func note_on(pitch: int) -> void:
	_active_notes[pitch] = true
	_add_waterfall_note(pitch)
	queue_redraw()

func note_off(pitch: int) -> void:
	_active_notes.erase(pitch)
	_release_waterfall_note(pitch)
	queue_redraw()

func clear_active_notes() -> void:
	_active_notes.clear()
	for note in _waterfall_notes:
		note["release_time"] = _now_sec
	queue_redraw()

func _add_waterfall_note(pitch: int) -> void:
	var x = _pitch_to_x(pitch)
	var width = white_key_width if _is_white(pitch) else white_key_width * black_key_width_ratio
	_waterfall_notes.append({
		"pitch": pitch,
		"start_time": _now_sec,
		"release_time": -1.0,
		"x": x,
		"width": width
	})

func _release_waterfall_note(pitch: int) -> void:
	for i in range(_waterfall_notes.size() - 1, -1, -1):
		var note = _waterfall_notes[i]
		if int(note.get("pitch", -1)) == pitch and float(note.get("release_time", -1.0)) < 0.0:
			note["release_time"] = _now_sec
			_waterfall_notes[i] = note
			return

func _prune_waterfall() -> void:
	var height = _waterfall_height()
	if height <= 0.0:
		return
	var keep: Array = []
	for note in _waterfall_notes:
		var start_time = float(note.get("start_time", _now_sec))
		var release_time = float(note.get("release_time", -1.0))
		var bottom = (_now_sec - start_time) * waterfall_speed
		var length = bottom if release_time < 0.0 else (release_time - start_time) * waterfall_speed
		var top = bottom - length
		if top <= height:
			keep.append(note)
	_waterfall_notes = keep

func _waterfall_height() -> float:
	return max(0.0, size.y - key_height)

func _pitch_to_x(pitch: int) -> float:
	var white_index := 0
	for p in range(start_key, pitch + 1):
		var note = p % 12
		if WHITE_NOTES.has(note):
			white_index += 1
	return max(0.0, float(white_index - 1)) * white_key_width

func _is_white(pitch: int) -> bool:
	return WHITE_NOTES.has(pitch % 12)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var key_height_local = min(key_height, size.y)
	var waterfall_height = _waterfall_height()
	if waterfall_height > 0.0:
		_draw_waterfall(waterfall_height)
	for key in _white_keys:
		var x = float(key["x"]) - _scroll_x
		var rect = Rect2(Vector2(x, waterfall_height), Vector2(white_key_width, key_height_local))
		if rect.position.x > size.x or rect.position.x + rect.size.x < 0.0:
			continue
		var pitch = int(key["pitch"])
		var color = COLOR_WHITE_ACTIVE if _active_notes.has(pitch) else COLOR_WHITE
		draw_rect(rect, color, true)
		draw_rect(rect, COLOR_WHITE_BORDER, false, 1.0)
		_draw_key_label(pitch, rect, false)
	var black_width = white_key_width * black_key_width_ratio
	var black_height = key_height_local * black_key_height_ratio
	for key in _black_keys:
		var x_black = float(key["x"]) - _scroll_x
		var rect_black = Rect2(Vector2(x_black, waterfall_height), Vector2(black_width, black_height))
		if rect_black.position.x > size.x or rect_black.position.x + rect_black.size.x < 0.0:
			continue
		var pitch = int(key["pitch"])
		var color_black = COLOR_BLACK_ACTIVE if _active_notes.has(pitch) else COLOR_BLACK
		draw_rect(rect_black, color_black, true)
		draw_rect(rect_black, COLOR_BLACK_BORDER, false, 1.0)
		_draw_key_label(pitch, rect_black, true)

func _draw_key_label(pitch: int, rect: Rect2, is_black: bool) -> void:
	if not show_note_labels:
		return
	var font = get_theme_default_font()
	if font == null:
		return
	var label = NOTE_NAMES[pitch % 12]
	var font_size = int(clamp(rect.size.y * 0.2, 8.0, 14.0))
	var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
	var x = rect.position.x + (rect.size.x - text_size.x) * 0.5
	var y = rect.position.y + rect.size.y - text_size.y - 2.0 + font.get_ascent(font_size)
	var color = LABEL_BLACK if is_black else LABEL_WHITE
	draw_string(font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_waterfall(height: float) -> void:
	if height <= 0.0:
		return
	for note in _waterfall_notes:
		var start_time = float(note.get("start_time", _now_sec))
		var release_time = float(note.get("release_time", -1.0))
		var bottom = (_now_sec - start_time) * waterfall_speed
		var length = bottom if release_time < 0.0 else (release_time - start_time) * waterfall_speed
		var top = bottom - length
		if bottom < 0.0 or top > height:
			continue
		var x = float(note.get("x", 0.0)) - _scroll_x
		var width = float(note.get("width", white_key_width))
		var draw_top = clamp(top, 0.0, height)
		var draw_bottom = clamp(bottom, 0.0, height)
		var draw_height = max(1.0, draw_bottom - draw_top)
		var rect = Rect2(Vector2(x, draw_top), Vector2(width, draw_height))
		if rect.position.x > size.x or rect.position.x + rect.size.x < 0.0:
			continue
		var is_active = float(note.get("release_time", -1.0)) < 0.0
		var color = COLOR_WATERFALL_ACTIVE if is_active else COLOR_WATERFALL
		draw_rect(rect, color, true)
