extends Node

signal changed

const ADSR_PARAMS := ["Attack", "Decay", "Sustain", "Release"]

var track: Node = null
var current_param: String = "Attack"

func set_track(next_track: Node) -> void:
	if track != null and track.has_signal("changed"):
		var callable = Callable(self, "_on_track_changed")
		if track.is_connected("changed", callable):
			track.disconnect("changed", callable)
	track = next_track
	if track != null and track.has_signal("changed"):
		track.connect("changed", Callable(self, "_on_track_changed"))
	emit_signal("changed")

func get_param_names() -> Array:
	return ADSR_PARAMS.duplicate()

func get_current_param() -> String:
	return current_param

func set_current_param(param_name: String) -> bool:
	if param_name == "":
		return false
	current_param = param_name
	emit_signal("changed")
	return true

func get_current_default_value() -> float:
	if track == null:
		return 0.0
	if track.has_method("get_adsr_default_value"):
		return float(track.call("get_adsr_default_value", current_param))
	return 0.0

func get_default_value_for_param(param_name: String) -> float:
	if track == null:
		return 0.0
	if track.has_method("get_adsr_default_value"):
		return float(track.call("get_adsr_default_value", param_name))
	return 0.0

func set_current_default_value(value: float) -> void:
	if track == null:
		return
	if track.has_method("set_adsr_default_value"):
		track.call("set_adsr_default_value", current_param, value)

func get_points() -> Array:
	if track == null:
		return []
	if track.has_method("get_adsr_points_for_param"):
		return track.call("get_adsr_points_for_param", current_param)
	return []

func get_points_for_param(param_name: String) -> Array:
	if track == null:
		return []
	if track.has_method("get_adsr_points_for_param"):
		return track.call("get_adsr_points_for_param", param_name)
	return []

func set_point(time_beats: float, value: float, step: float) -> void:
	if track == null:
		return
	if track.has_method("set_adsr_point"):
		track.call("set_adsr_point", current_param, time_beats, value, step)

func remove_points_near(time_beats: float, tolerance: float) -> int:
	if track == null:
		return 0
	if track.has_method("remove_adsr_points_near"):
		return int(track.call("remove_adsr_points_near", current_param, time_beats, tolerance))
	return 0

func _on_track_changed() -> void:
	emit_signal("changed")
