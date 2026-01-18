extends Node

signal changed

var points: Array = []

func get_points() -> Array:
	return points

func set_point(time_beats: float, value: float, step: float) -> void:
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
