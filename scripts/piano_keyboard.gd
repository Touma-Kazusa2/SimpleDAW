extends Control

@export var key_height: float = 16.0
@export var min_pitch: int = 36
@export var max_pitch: int = 96
@export var view_scroll_y: float = 0.0
@export var noise_enabled: bool = true
@export var noise_opacity: float = 0.06
@export var noise_size: int = 64
@export var noise_texture_path: String = "res://assets/blue_noise_128.png"

const COLOR_WHITE = Color(0.93, 0.93, 0.94)
const COLOR_WHITE_TOP = Color(0.98, 0.98, 0.99)
const COLOR_WHITE_BOTTOM = Color(0.85, 0.85, 0.86)
const COLOR_BLACK = Color(0.18, 0.18, 0.2)
const COLOR_BLACK_TOP = Color(0.28, 0.28, 0.3)
const COLOR_BORDER = Color(0.1, 0.1, 0.12)
const COLOR_OCTAVE_MARK = Color(0.35, 0.55, 0.85)
const BLACK_KEYS = [1, 3, 6, 8, 10]
const MIN_LABEL_KEY_HEIGHT := 12.0
const FULL_LABEL_KEY_HEIGHT := 16.0
const LABEL_COLOR = Color(0.1, 0.1, 0.12)
const LABEL_COLOR_LIGHT = Color(0.95, 0.95, 0.95)

var noise_texture: Texture2D = null

func _draw() -> void:
	var total_keys = max_pitch - min_pitch + 1
	var width = size.x
	draw_rect(Rect2(Vector2.ZERO, Vector2(width, size.y)), COLOR_WHITE, true)
	var font = get_theme_default_font()
	var font_size = int(clamp(key_height * 0.7, 8.0, 18.0))

	for i in range(total_keys):
		var pitch = max_pitch - i
		var y = i * key_height - view_scroll_y
		var is_black = BLACK_KEYS.has(pitch % 12)
		var rect_width = width * 0.65 if is_black else width
		var rect = Rect2(Vector2(0, y), Vector2(rect_width, key_height))
		var color = COLOR_BLACK if is_black else COLOR_WHITE
		draw_rect(rect, color, true)
		if is_black:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, max(1.0, rect.size.y * 0.22))), COLOR_BLACK_TOP, true)
		else:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, max(1.0, rect.size.y * 0.18))), COLOR_WHITE_TOP, true)
			draw_rect(Rect2(Vector2(rect.position.x, rect.position.y + rect.size.y - 1.0), Vector2(rect.size.x, 1.0)), COLOR_WHITE_BOTTOM, true)
		draw_rect(Rect2(Vector2(0, y), Vector2(width, key_height)), COLOR_BORDER, false, 1.0)
		if pitch % 12 == 0:
			draw_rect(Rect2(Vector2(width - 3.0, y), Vector2(3.0, key_height)), COLOR_OCTAVE_MARK, true)
		if key_height >= MIN_LABEL_KEY_HEIGHT:
			var octave = int(floor(pitch / 12.0)) - 1
			var label = NotePalette.name_for_pitch(pitch)
			if key_height >= FULL_LABEL_KEY_HEIGHT:
				label += str(octave)
			var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
			var text_x = 4.0
			var text_y = y + (key_height - text_size.y) * 0.5 + font.get_ascent(font_size)
			var text_pos = Vector2(text_x, text_y)
			var label_color = LABEL_COLOR_LIGHT if is_black else LABEL_COLOR
			draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, label_color)
	if noise_enabled and noise_opacity > 0.0:
		var texture = _get_noise_texture()
		if texture:
			draw_texture_rect(texture, Rect2(Vector2.ZERO, Vector2(width, size.y)), true, Color(1.0, 1.0, 1.0, noise_opacity))

func _get_noise_texture() -> Texture2D:
	if noise_texture and noise_texture.get_width() == noise_size:
		return noise_texture
	if noise_texture_path != "" and ResourceLoader.exists(noise_texture_path):
		noise_texture = load(noise_texture_path)
		return noise_texture
	if noise_size <= 0:
		return null
	var image = Image.create(noise_size, noise_size, false, Image.FORMAT_RGBA8)
	for y in range(noise_size):
		for x in range(noise_size):
			var v = 0.45 + randf() * 0.1
			image.set_pixel(x, y, Color(v, v, v, 1.0))
	noise_texture = ImageTexture.create_from_image(image)
	return noise_texture
