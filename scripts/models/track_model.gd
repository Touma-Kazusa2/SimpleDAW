extends Node

signal changed

var id: String = ""
var track_name: String = "Track"
var clips: Array = []
var arrangement: Array = []

func add_clip(clip: Node, start_beats: float = 0.0, length_beats: float = -1.0) -> void:
	if clip == null:
		return
	clips.append(clip)
	var resolved_length = length_beats
	if resolved_length < 0.0:
		resolved_length = _get_clip_length_beats(clip)
	arrangement.append({
		"clip": clip,
		"clip_id": clip.id,
		"start": start_beats,
		"length": resolved_length
	})
	if clip.has_signal("changed"):
		clip.connect("changed", Callable(self, "_on_clip_changed"))
	emit_signal("changed")

func set_clip_placement(clip: Node, start_beats: float, length_beats: float) -> void:
	var index = _find_arrangement_index(clip)
	if index < 0:
		return
	arrangement[index]["start"] = start_beats
	arrangement[index]["length"] = length_beats
	emit_signal("changed")

func get_clip_placement(clip: Node) -> Dictionary:
	var index = _find_arrangement_index(clip)
	if index < 0:
		return {}
	return arrangement[index]

func _find_arrangement_index(clip: Node) -> int:
	if clip == null:
		return -1
	for i in range(arrangement.size()):
		if arrangement[i].get("clip") == clip:
			return i
	return -1

func _get_clip_length_beats(clip: Node) -> float:
	if clip == null:
		return 0.0
	var value = clip.get("clip_length_beats")
	if value is float or value is int:
		return float(value)
	return 0.0

func _on_clip_changed() -> void:
	emit_signal("changed")
