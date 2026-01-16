extends Control

@export var pixels_per_beat: float = 120.0
@export var key_height: float = 16.0
@export var min_pitch: int = 36
@export var max_pitch: int = 96
@export var beats_per_measure: int = 4
@export var visible_beats: int = 32
@export var view_scroll_x: float = 0.0
@export var view_width: float = 0.0
@export var playhead_time_beats: float = 0.0
@export var active_note_scale: float = 1.6
@export var active_note_attack_beats: float = 0.35
@export var active_note_release_beats: float = 0.4
@export var active_note_brighten: float = 0.5
@export var active_note_squash: float = 0.35
@export var debug_force_swell: bool = false
@export var show_velocity: bool = false
@export var noise_enabled: bool = false
@export var noise_opacity: float = 0.08
@export var noise_size: int = 64
@export var noise_texture_path: String = "res://assets/blue_noise_128.png"

var model: Node = null
var noise_texture: Texture2D = null

const NOTE_BORDER = Color(0.15, 0.2, 0.25)
const NOTE_TEXT_COLOR = Color(0.1, 0.1, 0.12)
const VELOCITY_BAR_COLOR = Color(0.98, 0.85, 0.2, 0.9)
const VELOCITY_BAR_BORDER = Color(0.0, 0.0, 0.0, 0.9)
const MIN_LABEL_KEY_HEIGHT := 12.0

func set_model(notes_model: Node) -> void:
	if model:
		model.disconnect("changed", Callable(self, "_on_model_changed"))
	model = notes_model
	if model:
		model.connect("changed", Callable(self, "_on_model_changed"))
	queue_redraw()

func _on_model_changed() -> void:
	queue_redraw()

func _draw() -> void:
	var font = get_theme_default_font()
	var font_size = int(clamp(key_height * 0.7, 8.0, 18.0))
	if model == null:
		return
	var active_notes: Array = []
	for note in model.notes:
		var start_beats = note["start"]
		var duration_beats = note["duration"]
		var intensity = _get_note_swell(start_beats, duration_beats, playhead_time_beats)
		if intensity > 0.0:
			active_notes.append(note)
		else:
			_draw_note(note, intensity, font, font_size)
	for note in active_notes:
		var start_beats = note["start"]
		var duration_beats = note["duration"]
		var intensity = _get_note_swell(start_beats, duration_beats, playhead_time_beats)
		_draw_note(note, intensity, font, font_size)

func _draw_note(note: Dictionary, intensity: float, font: Font, font_size: int) -> void:
	var start_beats = note["start"]
	var duration_beats = note["duration"]
	var pitch = note["pitch"]
	var x = start_beats * pixels_per_beat
	var y = (max_pitch - int(pitch)) * key_height
	var width = duration_beats * pixels_per_beat
	var rect = Rect2(Vector2(x, y), Vector2(width, key_height))
	var track_tint = note.get("track_tint", Color(1.0, 1.0, 1.0))
	var track_mix = float(note.get("track_mix", 0.0))
	var color = NotePalette.color_for_pitch(int(pitch), track_tint, track_mix)
	var draw_rect_area = rect
	var swell = 1.0 + (active_note_scale - 1.0) * intensity
	if swell > 1.0:
		var scale_y = swell
		var scale_x = 1.0 + (swell - 1.0) * active_note_squash
		var new_size = Vector2(rect.size.x * scale_x, rect.size.y * scale_y)
		draw_rect_area = Rect2(rect.position + (rect.size - new_size) * 0.5, new_size)
	var bright_color = color.lerp(Color(1.0, 1.0, 1.0), clamp(active_note_brighten * intensity, 0.0, 0.8))
	draw_rect(draw_rect_area, bright_color, true)
	if noise_enabled and noise_opacity > 0.0:
		var texture = _get_noise_texture()
		if texture:
			draw_texture_rect(texture, draw_rect_area, true, Color(1.0, 1.0, 1.0, noise_opacity))
	draw_rect(draw_rect_area, NOTE_BORDER, false, 1.0)
	if show_velocity:
		var velocity = int(note.get("velocity", 127))
		var velocity_t = clamp(float(velocity) / 127.0, 0.0, 1.0)
		var bar_half = 3.0
		var usable_width = max(0.0, draw_rect_area.size.x - bar_half * 2.0)
		var line_x = draw_rect_area.position.x + bar_half + usable_width * velocity_t
		var bar_rect = Rect2(
			Vector2(floor(line_x - bar_half), floor(draw_rect_area.position.y + 1.0)),
			Vector2(bar_half * 2.0, max(0.0, floor(draw_rect_area.size.y - 2.0)))
		)
		draw_rect(bar_rect, VELOCITY_BAR_COLOR, true)
		var hatch_step = 3.0
		var hatch_height = max(0.0, bar_rect.size.y - hatch_step)
		if hatch_height > 0.0:
			var hatch_y = bar_rect.position.y
			while hatch_y <= bar_rect.position.y + hatch_height:
				draw_line(
					Vector2(bar_rect.position.x, hatch_y + hatch_step),
					Vector2(bar_rect.position.x + bar_rect.size.x, hatch_y),
					Color(0.0, 0.0, 0.0, 0.5),
					1.0
				)
				hatch_y += hatch_step
		draw_line(
			Vector2(bar_rect.position.x, bar_rect.position.y),
			Vector2(bar_rect.position.x, bar_rect.position.y + bar_rect.size.y),
			VELOCITY_BAR_BORDER,
			1.0
		)
		draw_line(
			Vector2(bar_rect.position.x + bar_rect.size.x, bar_rect.position.y),
			Vector2(bar_rect.position.x + bar_rect.size.x, bar_rect.position.y + bar_rect.size.y),
			VELOCITY_BAR_BORDER,
			1.0
		)
	if key_height >= MIN_LABEL_KEY_HEIGHT and draw_rect_area.size.x >= font_size * 1.2:
		var label = NotePalette.name_for_pitch(int(pitch))
		var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var text_x = draw_rect_area.position.x + 4.0
		var text_y = draw_rect_area.position.y + (draw_rect_area.size.y - text_size.y) * 0.5 + font.get_ascent(font_size)
		if view_width > 0.0:
			var min_x = view_scroll_x + 2.0
			var max_x = view_scroll_x + view_width - text_size.x - 2.0
			if max_x < min_x:
				text_x = min_x
			else:
				text_x = clamp(text_x, min_x, max_x)
		var text_pos = Vector2(text_x, text_y)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, NOTE_TEXT_COLOR)

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

func _get_note_swell(start_beats: float, duration_beats: float, time_beats: float) -> float:
	if debug_force_swell:
		return 1.0
	var end_beats = start_beats + duration_beats
	if time_beats < start_beats or time_beats >= end_beats:
		return 0.0
	if active_note_scale <= 1.0:
		return 0.0
	var attack = max(active_note_attack_beats, 0.0)
	var release = max(active_note_release_beats, 0.0)
	var local = time_beats - start_beats
	var remaining = end_beats - time_beats
	var attack_t = 1.0 if attack == 0.0 else clamp(local / attack, 0.0, 1.0)
	var release_t = 1.0 if release == 0.0 else clamp(remaining / release, 0.0, 1.0)
	var pulse = min(_smoothstep(attack_t), _smoothstep(release_t))
	return clamp(pulse, 0.0, 1.0)

func _smoothstep(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
