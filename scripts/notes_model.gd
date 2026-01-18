extends Node

signal changed

const CLIP_MODEL = preload("res://scripts/models/clip_model.gd")

var clip: Node = null
var notes: Array = []

const DEFAULT_VELOCITY := 100

func add_note(pitch: int, start_beats: float, duration_beats: float, track_id: int = 0) -> void:
	_ensure_clip()
	if clip != null and clip.has_method("add_note"):
		clip.call("add_note", pitch, start_beats, duration_beats, track_id)
		return
	notes.append({
		"pitch": pitch,
		"start": start_beats,
		"duration": duration_beats,
		"velocity": DEFAULT_VELOCITY,
		"track_id": track_id,
		"track_tint": Color(1.0, 1.0, 1.0),
		"track_mix": 0.0
	})
	emit_signal("changed")

func update_note(index: int, pitch: int, start_beats: float, duration_beats: float) -> void:
	_ensure_clip()
	if clip != null and clip.has_method("update_note"):
		clip.call("update_note", index, pitch, start_beats, duration_beats)
		return
	if index < 0 or index >= notes.size():
		return
	notes[index]["pitch"] = pitch
	notes[index]["start"] = start_beats
	notes[index]["duration"] = duration_beats
	emit_signal("changed")

func update_velocity(index: int, velocity: int) -> void:
	_ensure_clip()
	if clip != null and clip.has_method("update_velocity"):
		clip.call("update_velocity", index, velocity)
		return
	if index < 0 or index >= notes.size():
		return
	notes[index]["velocity"] = clamp(velocity, 0, 127)
	emit_signal("changed")

func delete_note(index: int) -> void:
	_ensure_clip()
	if clip != null and clip.has_method("delete_note"):
		clip.call("delete_note", index)
		return
	if index < 0 or index >= notes.size():
		return
	notes.remove_at(index)
	emit_signal("changed")

func set_clip(next_clip: Node) -> void:
	if clip != null and clip.has_signal("changed"):
		var callable = Callable(self, "_on_clip_changed")
		if clip.is_connected("changed", callable):
			clip.disconnect("changed", callable)
	clip = next_clip
	if clip == null:
		return
	notes = clip.notes
	if clip.has_signal("changed"):
		clip.connect("changed", Callable(self, "_on_clip_changed"))
	emit_signal("changed")

func _ensure_clip() -> void:
	if clip != null:
		return
	clip = CLIP_MODEL.new()
	notes = clip.notes
	if clip.has_signal("changed"):
		clip.connect("changed", Callable(self, "_on_clip_changed"))

func _on_clip_changed() -> void:
	if clip != null:
		notes = clip.notes
	emit_signal("changed")
