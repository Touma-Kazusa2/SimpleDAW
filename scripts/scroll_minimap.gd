extends Control

@export var vertical: bool = false

const INTERVAL_UTILS = preload("res://scripts/interval_utils.gd")

const COLOR_FILL = Color(0.85, 0.2, 0.2, 0.6)

var roll: Control = null
var notes_model: Node = null

func set_roll(target: Control) -> void:
	roll = target
	notes_model = null
	if roll:
		notes_model = roll.get_node_or_null("NotesModel")
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if roll == null or notes_model == null:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if notes_model.notes.is_empty():
		return
	if vertical:
		_draw_vertical()
	else:
		_draw_horizontal()

func _draw_horizontal() -> void:
	var total_beats = float(roll.get("visible_beats"))
	if total_beats <= 0.0:
		return
	var intervals: Array = []
	for note in notes_model.notes:
		var start = float(note.get("start", 0.0))
		var duration = float(note.get("duration", 0.0))
		var end = start + duration
		if end <= 0.0 or start >= total_beats:
			continue
		intervals.append([max(0.0, start), min(total_beats, end)])
	var merged = INTERVAL_UTILS.merge_intervals(intervals)
	for seg in merged:
		var x0 = (seg[0] / total_beats) * size.x
		var x1 = (seg[1] / total_beats) * size.x
		var w = max(1.0, x1 - x0)
		draw_rect(Rect2(Vector2(x0, 0.0), Vector2(w, size.y)), COLOR_FILL, true)

func _draw_vertical() -> void:
	var min_pitch = int(roll.get("min_pitch"))
	var max_pitch = int(roll.get("max_pitch"))
	if max_pitch < min_pitch:
		return
	var total_keys = max_pitch - min_pitch + 1
	var intervals: Array = []
	for note in notes_model.notes:
		var pitch = int(note.get("pitch", min_pitch))
		var idx = max_pitch - pitch
		if idx < 0 or idx >= total_keys:
			continue
		intervals.append([float(idx), float(idx + 1)])
	var merged = INTERVAL_UTILS.merge_intervals(intervals)
	for seg in merged:
		var y0 = (seg[0] / float(total_keys)) * size.y
		var y1 = (seg[1] / float(total_keys)) * size.y
		var h = max(1.0, y1 - y0)
		draw_rect(Rect2(Vector2(0.0, y0), Vector2(size.x, h)), COLOR_FILL, true)
