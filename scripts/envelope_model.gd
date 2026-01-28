extends Node

signal changed

const CLIP_MODEL = preload("res://scripts/models/clip_model.gd")
const DEFAULT_PARAM := "Volume"
const DEFAULT_VALUE := 0.5

var clip: Node = null
var current_param: String = DEFAULT_PARAM
var points: Array = []
var comments: Array = []

func get_current_default_value() -> float:
	return DEFAULT_VALUE

func set_current_param(param_name: String) -> bool:
	if clip != null and clip.has_method("set_current_param"):
		return bool(clip.call("set_current_param", param_name))
	if param_name == "":
		return false
	current_param = param_name
	emit_signal("changed")
	return true

func get_current_param() -> String:
	if clip != null and clip.has_method("get_current_param"):
		return String(clip.call("get_current_param"))
	return current_param

func get_param_names() -> Array:
	if clip != null and clip.has_method("get_param_names"):
		return clip.call("get_param_names")
	if current_param == "":
		return [DEFAULT_PARAM]
	return [current_param]

func ensure_param(param_name: String) -> void:
	if clip != null and clip.has_method("ensure_param"):
		clip.call("ensure_param", param_name)

func get_points() -> Array:
	if clip != null and clip.has_method("get_points"):
		return clip.call("get_points")
	return points

func get_comments() -> Array:
	if clip != null and clip.has_method("get_comments"):
		return clip.call("get_comments")
	return comments

func add_comment(start_beats: float, end_beats: float, text: String) -> void:
	if clip != null and clip.has_method("add_comment"):
		clip.call("add_comment", start_beats, end_beats, text)
		return
	var start_time = min(start_beats, end_beats)
	var end_time = max(start_beats, end_beats)
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
	if clip != null and clip.has_method("set_comment_text"):
		clip.call("set_comment_text", index, text)
		return
	if index < 0 or index >= comments.size():
		return
	comments[index]["text"] = text
	emit_signal("changed")

func remove_comment(index: int) -> void:
	if clip != null and clip.has_method("remove_comment"):
		clip.call("remove_comment", index)
		return
	if index < 0 or index >= comments.size():
		return
	comments.remove_at(index)
	emit_signal("changed")

func set_point(time_beats: float, value: float, step: float) -> void:
	if clip != null and clip.has_method("set_point"):
		clip.call("set_point", time_beats, value, step)
		return
	var snapped_time = _snap_time(time_beats, step)
	var clamped_value = clamp(value, 0.0, 1.0)
	var index = _find_point_index(snapped_time, step * 0.5)
	if index >= 0:
		if is_equal_approx(float(points[index]["value"]), clamped_value):
			return
		points[index]["value"] = clamped_value
	else:
		points.append({"time": snapped_time, "value": clamped_value})
		points.sort_custom(func(a, b): return a["time"] < b["time"])
	emit_signal("changed")

func remove_points_near(time_beats: float, tolerance: float) -> int:
	if clip != null and clip.has_method("remove_points_near"):
		return int(clip.call("remove_points_near", time_beats, tolerance))
	if points.is_empty():
		return 0
	var removed = 0
	for i in range(points.size() - 1, -1, -1):
		var t = float(points[i]["time"])
		if abs(t - time_beats) <= tolerance:
			points.remove_at(i)
			removed += 1
	if removed > 0:
		emit_signal("changed")
	return removed

func _find_point_index(time_beats: float, tolerance: float) -> int:
	if points.is_empty():
		return -1
	for i in range(points.size()):
		var t = float(points[i]["time"])
		if abs(t - time_beats) <= tolerance:
			return i
	return -1

func _snap_time(time_beats: float, step: float) -> float:
	if step <= 0.0:
		return time_beats
	return round(time_beats / step) * step

func set_clip(next_clip: Node) -> void:
	if clip != null and clip.has_signal("changed"):
		var callable = Callable(self, "_on_clip_changed")
		if clip.is_connected("changed", callable):
			clip.disconnect("changed", callable)
	clip = next_clip
	if clip == null:
		return
	if clip.has_signal("changed"):
		clip.connect("changed", Callable(self, "_on_clip_changed"))
	emit_signal("changed")

func _on_clip_changed() -> void:
	emit_signal("changed")
