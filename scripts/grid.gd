extends Control

@export var pixels_per_beat: float = 120.0
@export var key_height: float = 16.0
@export var min_pitch: int = 36
@export var max_pitch: int = 96
@export var beats_per_measure: int = 4
@export var visible_beats: int = 32
@export var view_scroll_x: float = 0.0
@export var view_scroll_y: float = 0.0
@export var view_width: float = 0.0
@export var view_height: float = 0.0

const COLOR_BG = Color(0.08, 0.08, 0.09)
const COLOR_GRID = Color(0.2, 0.2, 0.22)
const COLOR_MEASURE = Color(0.6, 0.6, 0.63)
const COLOR_OCTAVE = Color(0.62, 0.62, 0.66)

func _draw() -> void:
	var total_width = visible_beats * pixels_per_beat
	var total_height = (max_pitch - min_pitch + 1) * key_height
	var draw_x0 = 0.0
	var draw_y0 = 0.0
	var draw_x1 = total_width
	var draw_y1 = total_height
	if view_width > 0.0:
		draw_x0 = clamp(view_scroll_x, 0.0, total_width)
		draw_x1 = clamp(view_scroll_x + view_width, 0.0, total_width)
	if view_height > 0.0:
		draw_y0 = clamp(view_scroll_y, 0.0, total_height)
		draw_y1 = clamp(view_scroll_y + view_height, 0.0, total_height)
	if draw_x1 <= draw_x0 or draw_y1 <= draw_y0:
		return
	draw_rect(Rect2(Vector2(draw_x0, draw_y0), Vector2(draw_x1 - draw_x0, draw_y1 - draw_y0)), COLOR_BG, true)

	var beat_start = int(floor(draw_x0 / pixels_per_beat))
	var beat_end = int(ceil(draw_x1 / pixels_per_beat))
	beat_start = clamp(beat_start, 0, visible_beats)
	beat_end = clamp(beat_end, 0, visible_beats)
	for beat in range(beat_start, beat_end + 1):
		var x = beat * pixels_per_beat
		var color = COLOR_MEASURE if beat % beats_per_measure == 0 else COLOR_GRID
		draw_line(Vector2(x, draw_y0), Vector2(x, draw_y1), color, 1.0)

	var total_keys = max_pitch - min_pitch + 1
	var key_start = int(floor(draw_y0 / key_height))
	var key_end = int(ceil(draw_y1 / key_height))
	key_start = clamp(key_start, 0, total_keys)
	key_end = clamp(key_end, 0, total_keys)
	for i in range(key_start, key_end + 1):
		var y = i * key_height
		var pitch = max_pitch - i
		var color = COLOR_OCTAVE if pitch % 12 == 11 else COLOR_GRID
		draw_line(Vector2(draw_x0, y), Vector2(draw_x1, y), color, 1.0)
