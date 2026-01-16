class_name NotePalette
extends RefCounted

const NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTE_COLORS = [
	Color(0.25, 0.55, 0.95), # C
	Color(0.85, 0.35, 0.35), # C#
	Color(0.35, 0.75, 0.45), # D
	Color(0.85, 0.55, 0.2),  # D#
	Color(0.85, 0.8, 0.3),   # E
	Color(0.3, 0.7, 0.9),    # F
	Color(0.6, 0.35, 0.85),  # F#
	Color(0.35, 0.85, 0.7),  # G
	Color(0.9, 0.45, 0.8),   # G#
	Color(0.9, 0.6, 0.4),    # A
	Color(0.6, 0.75, 0.9),   # A#
	Color(0.75, 0.55, 0.4)   # B
]

static func name_for_pitch(pitch: int) -> String:
	return NOTE_NAMES[int(pitch) % 12]

static func color_for_pitch(pitch: int, track_tint: Color = Color(1.0, 1.0, 1.0), track_mix: float = 0.0) -> Color:
	var base = NOTE_COLORS[int(pitch) % 12]
	var mix = clamp(track_mix, 0.0, 1.0)
	if mix <= 0.0:
		return base
	return base.lerp(track_tint, mix)
