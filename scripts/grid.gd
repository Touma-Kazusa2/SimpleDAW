extends Control

@export var pixels_per_beat: float = 120.0
@export var key_height: float = 16.0
@export var min_pitch: int = 36
@export var max_pitch: int = 96
@export var beats_per_measure: int = 4
@export var visible_beats: int = 32

const COLOR_BG = Color(0.08, 0.08, 0.09)
const COLOR_GRID = Color(0.2, 0.2, 0.22)
const COLOR_MEASURE = Color(0.35, 0.35, 0.38)
const COLOR_OCTAVE = Color(0.28, 0.28, 0.3)

func _draw() -> void:
	var width = visible_beats * pixels_per_beat
	var height = (max_pitch - min_pitch + 1) * key_height
	draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), COLOR_BG, true)

	for beat in range(visible_beats + 1):
		var x = beat * pixels_per_beat
		var color = COLOR_MEASURE if beat % beats_per_measure == 0 else COLOR_GRID
		draw_line(Vector2(x, 0), Vector2(x, height), color, 1.0)

	var total_keys = max_pitch - min_pitch + 1
	for i in range(total_keys + 1):
		var y = i * key_height
		var pitch = max_pitch - i
		var color = COLOR_OCTAVE if pitch % 12 == 0 else COLOR_GRID
		draw_line(Vector2(0, y), Vector2(width, y), color, 1.0)
