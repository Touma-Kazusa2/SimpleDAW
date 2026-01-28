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
var automation_by_param: Dictionary = {}
var source_clip: Node = null
var source_clip_id: String = ""
var is_linked := false
var is_used := false
var owner_track_id: String = ""
var _bulk_update_depth := 0
var _bulk_update_pending := false

func set_clip_name(label: String) -> void:
	if clip_name == label:
		return
	clip_name = label
	_emit_changed()

func _init() -> void:
	_ensure_param(DEFAULT_PARAM)

func _on_automation_changed() -> void:
	_emit_changed()

func set_source_clip(source: Node) -> void:
	if source_clip != null and source_clip.has_signal("changed"):
		var callable = Callable(self, "_on_source_clip_changed")
		if source_clip.is_connected("changed", callable):
			source_clip.disconnect("changed", callable)
	source_clip = source
	is_linked = source_clip != null
	is_used = source_clip != null
	source_clip_id = ""
	if source_clip != null:
		if source_clip.has_method("get"):
			source_clip_id = str(source_clip.get("id"))
		notes = source_clip.get("notes") if source_clip.has_method("get") else notes
		comments = source_clip.get("comments") if source_clip.has_method("get") else comments
		if source_clip.has_method("get_current_param"):
			current_param = String(source_clip.call("get_current_param"))
		if source_clip.has_signal("changed"):
			source_clip.connect("changed", Callable(self, "_on_source_clip_changed"))
	_emit_changed()

func _on_source_clip_changed() -> void:
	if source_clip != null and source_clip.has_method("get"):
		clip_length_beats = float(source_clip.get("clip_length_beats"))
	_emit_changed()

func _proxy_to_source(method_name: String, args: Array) -> bool:
	if source_clip == null or source_clip == self:
		return false
	if source_clip.has_method(method_name):
		source_clip.callv(method_name, args)
		_emit_changed()
		return true
	return false

func get_current_default_value() -> float:
	return DEFAULT_VALUE

func set_current_param(param_name: String) -> bool:
	if _proxy_to_source("set_current_param", [param_name]):
		return true
	if param_name == "":
		return false
	current_param = param_name
	_ensure_param(param_name)
	_emit_changed()
	return true

func get_current_param() -> String:
	return current_param

func get_param_names() -> Array:
	if source_clip != null and source_clip.has_method("get_param_names"):
		return source_clip.call("get_param_names")
	var names = automation_by_param.keys()
	names.sort()
	return names

func ensure_param(param_name: String) -> void:
	if _proxy_to_source("ensure_param", [param_name]):
		return
	if param_name == "":
		return
	_ensure_param(param_name)

func get_points() -> Array:
	if source_clip != null and source_clip.has_method("get_points"):
		return source_clip.call("get_points")
	var automation = _get_automation(current_param, false)
	return automation.get_points() if automation != null else []

func get_points_for_param(param_name: String) -> Array:
	if source_clip != null and source_clip.has_method("get_points_for_param"):
		return source_clip.call("get_points_for_param", param_name)
	if param_name == "":
		return []
	var automation = _get_automation(param_name, false)
	return automation.get_points() if automation != null else []

func set_point(time_beats: float, value: float, step: float) -> void:
	if _proxy_to_source("set_point", [time_beats, value, step]):
		return
	var automation = _get_automation(current_param, true)
	if automation == null:
		return
	automation.set_point(time_beats, value, step)

func set_point_for_param(param_name: String, time_beats: float, value: float, step: float) -> void:
	if _proxy_to_source("set_point_for_param", [param_name, time_beats, value, step]):
		return
	if param_name == "":
		return
	var automation = _get_automation(param_name, true)
	if automation == null:
		return
	automation.set_point(time_beats, value, step)

func remove_points_near(time_beats: float, tolerance: float) -> int:
	if source_clip != null and source_clip.has_method("remove_points_near"):
		return int(source_clip.call("remove_points_near", time_beats, tolerance))
	var automation = _get_automation(current_param, false)
	if automation == null:
		return 0
	return automation.remove_points_near(time_beats, tolerance)

func _ensure_param(param_name: String) -> void:
	if automation_by_param.has(param_name):
		return
	var automation = AUTOMATION_MODEL.new()
	automation_by_param[param_name] = automation
	_connect_automation(automation)

func _get_automation(param_name: String, create: bool) -> Node:
	if automation_by_param.has(param_name):
		return automation_by_param[param_name]
	if not create:
		return null
	var automation = AUTOMATION_MODEL.new()
	automation_by_param[param_name] = automation
	_connect_automation(automation)
	return automation

func _connect_automation(automation: Node) -> void:
	if automation == null or not automation.has_signal("changed"):
		return
	var callable = Callable(self, "_on_automation_changed")
	if not automation.is_connected("changed", callable):
		automation.connect("changed", callable)

func add_note(pitch: int, note_start_beats: float, duration_beats: float, track_id: int = 0) -> void:
	if _proxy_to_source("add_note", [pitch, note_start_beats, duration_beats, track_id]):
		return
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
	_emit_changed()

func update_note(index: int, pitch: int, note_start_beats: float, duration_beats: float) -> void:
	if _proxy_to_source("update_note", [index, pitch, note_start_beats, duration_beats]):
		return
	if index < 0 or index >= notes.size():
		return
	_ensure_length(note_start_beats + duration_beats)
	notes[index]["pitch"] = pitch
	notes[index]["start"] = note_start_beats
	notes[index]["duration"] = duration_beats
	_emit_changed()

func update_velocity(index: int, velocity: int) -> void:
	if _proxy_to_source("update_velocity", [index, velocity]):
		return
	if index < 0 or index >= notes.size():
		return
	notes[index]["velocity"] = clamp(velocity, 0, 127)
	_emit_changed()

func delete_note(index: int) -> void:
	if _proxy_to_source("delete_note", [index]):
		return
	if index < 0 or index >= notes.size():
		return
	notes.remove_at(index)
	_emit_changed()

func _ensure_length(required_beats: float) -> void:
	if required_beats <= clip_length_beats:
		return
	clip_length_beats = required_beats

func get_comments() -> Array:
	return comments

func add_comment(range_start_beats: float, range_end_beats: float, text: String) -> void:
	if _proxy_to_source("add_comment", [range_start_beats, range_end_beats, text]):
		return
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
	_emit_changed()

func set_comment_text(index: int, text: String) -> void:
	if _proxy_to_source("set_comment_text", [index, text]):
		return
	if index < 0 or index >= comments.size():
		return
	comments[index]["text"] = text
	_emit_changed()

func remove_comment(index: int) -> void:
	if _proxy_to_source("remove_comment", [index]):
		return
	if index < 0 or index >= comments.size():
		return
	comments.remove_at(index)
	_emit_changed()

func begin_bulk_update() -> void:
	_bulk_update_depth += 1

func end_bulk_update() -> void:
	if _bulk_update_depth <= 0:
		_bulk_update_depth = 0
		return
	_bulk_update_depth -= 1
	if _bulk_update_depth == 0 and _bulk_update_pending:
		_bulk_update_pending = false
		emit_signal("changed")

func _emit_changed() -> void:
	if _bulk_update_depth > 0:
		_bulk_update_pending = true
		return
	emit_signal("changed")
