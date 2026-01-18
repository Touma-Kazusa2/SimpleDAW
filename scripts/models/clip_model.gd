extends Node

signal changed

const DEFAULT_VELOCITY := 100
const DEFAULT_PARAM := "Volume"
const DEFAULT_VALUE := 0.5
const AUTOMATION_MODEL = preload("res://scripts/models/automation_model.gd")

var id: String = ""
var clip_name: String = ""
var clip_start_beats: float = 0.0
var clip_length_beats: float = 0.0

var notes: Array = []
var comments: Array = []
var current_param: String = DEFAULT_PARAM
var automation: Node = null

func _init() -> void:
	automation = AUTOMATION_MODEL.new()
	automation.connect("changed", Callable(self, "_on_automation_changed"))

func _on_automation_changed() -> void:
	emit_signal("changed")

func get_current_default_value() -> float:
	return DEFAULT_VALUE

func set_current_param(param_name: String) -> bool:
	if param_name != DEFAULT_PARAM:
		return false
	current_param = param_name
	emit_signal("changed")
	return true

func get_points() -> Array:
	return automation.get_points() if automation != null else []

func set_point(time_beats: float, value: float, step: float) -> void:
	if automation == null:
		return
	automation.set_point(time_beats, value, step)

func remove_points_near(time_beats: float, tolerance: float) -> int:
	if automation == null:
		return 0
	return automation.remove_points_near(time_beats, tolerance)

func add_note(pitch: int, note_start_beats: float, duration_beats: float, track_id: int = 0) -> void:
	_ensure_length(note_start_beats + duration_beats)
	notes.append({
		"pitch": pitch,
		"start": note_start_beats,
		"duration": duration_beats,
		"velocity": DEFAULT_VELOCITY,
		"track_id": track_id,
		"track_tint": Color(1.0, 1.0, 1.0),
		"track_mix": 0.0
	})
	emit_signal("changed")

func update_note(index: int, pitch: int, note_start_beats: float, duration_beats: float) -> void:
	if index < 0 or index >= notes.size():
		return
	_ensure_length(note_start_beats + duration_beats)
	notes[index]["pitch"] = pitch
	notes[index]["start"] = note_start_beats
	notes[index]["duration"] = duration_beats
	emit_signal("changed")

func update_velocity(index: int, velocity: int) -> void:
	if index < 0 or index >= notes.size():
		return
	notes[index]["velocity"] = clamp(velocity, 0, 127)
	emit_signal("changed")

func delete_note(index: int) -> void:
	if index < 0 or index >= notes.size():
		return
	notes.remove_at(index)
	emit_signal("changed")

func _ensure_length(required_beats: float) -> void:
	if required_beats <= clip_length_beats:
		return
	clip_length_beats = required_beats

func get_comments() -> Array:
	return comments

func add_comment(range_start_beats: float, range_end_beats: float, text: String) -> void:
	var start_time = min(range_start_beats, range_end_beats)
	var end_time = max(range_start_beats, range_end_beats)
	if end_time <= start_time:
		return
	comments.append({
		"start": start_time,
		"end": end_time,
		"text": text
	})
	comments.sort_custom(func(a, b): return a["start"] < b["start"])
	emit_signal("changed")

func set_comment_text(index: int, text: String) -> void:
	if index < 0 or index >= comments.size():
		return
	comments[index]["text"] = text
	emit_signal("changed")

func remove_comment(index: int) -> void:
	if index < 0 or index >= comments.size():
		return
	comments.remove_at(index)
	emit_signal("changed")
