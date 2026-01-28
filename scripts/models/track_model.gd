extends Node

signal changed

const CLIP_MODEL = preload("res://scripts/models/clip_model.gd")
const AUTOMATION_MODEL = preload("res://scripts/models/automation_model.gd")

const ADSR_PARAMS := ["Attack", "Decay", "Sustain", "Release"]
const ADSR_DEFAULTS := {
	"Attack": 0.02,
	"Decay": 0.2,
	"Sustain": 0.8,
	"Release": 0.3
}

var id: String = ""
var track_name: String = "Track"
var soundfont_path: String = ""
var clips: Array = []
var arrangement: Array = []
var adsr_defaults: Dictionary = {}
var adsr_by_param: Dictionary = {}
var adsr_override_enabled := false

func set_track_name(label: String) -> void:
	if track_name == label:
		return
	track_name = label
	emit_signal("changed")

func set_soundfont_path(path: String) -> void:
	if soundfont_path == path:
		return
	soundfont_path = path
	emit_signal("changed")

func get_adsr_param_names() -> Array:
	return ADSR_PARAMS.duplicate()

func get_adsr_default_value(param_name: String) -> float:
	if adsr_defaults.has(param_name):
		return float(adsr_defaults[param_name])
	if ADSR_DEFAULTS.has(param_name):
		return float(ADSR_DEFAULTS[param_name])
	return 0.0

func set_adsr_default_value(param_name: String, value: float) -> void:
	if param_name == "":
		return
	var clamped = clamp(value, 0.0, 1.0)
	if is_equal_approx(get_adsr_default_value(param_name), clamped):
		return
	adsr_defaults[param_name] = clamped
	adsr_override_enabled = true
	emit_signal("changed")

func get_adsr_points_for_param(param_name: String) -> Array:
	if param_name == "":
		return []
	_ensure_adsr_param(param_name)
	var automation = adsr_by_param.get(param_name)
	return automation.get_points() if automation != null else []

func set_adsr_point(param_name: String, time_beats: float, value: float, step: float) -> void:
	if param_name == "":
		return
	_ensure_adsr_param(param_name)
	var automation = adsr_by_param.get(param_name)
	if automation == null:
		return
	automation.set_point(time_beats, value, step)
	adsr_override_enabled = true

func remove_adsr_points_near(param_name: String, time_beats: float, tolerance: float) -> int:
	if param_name == "":
		return 0
	_ensure_adsr_param(param_name)
	var automation = adsr_by_param.get(param_name)
	if automation == null:
		return 0
	return automation.remove_points_near(time_beats, tolerance)

func has_adsr_override() -> bool:
	return adsr_override_enabled

func set_adsr_override_enabled(enabled: bool) -> void:
	if adsr_override_enabled == enabled:
		return
	adsr_override_enabled = enabled
	emit_signal("changed")

func get_adsr_defaults() -> Dictionary:
	var data := {}
	for param in ADSR_PARAMS:
		data[param] = get_adsr_default_value(param)
	return data

func get_adsr_automation_data() -> Dictionary:
	var data := {}
	for param in ADSR_PARAMS:
		var points = get_adsr_points_for_param(param)
		data[param] = points.duplicate(true)
	return data

func _ensure_adsr_param(param_name: String) -> void:
	if adsr_by_param.has(param_name):
		return
	var automation = AUTOMATION_MODEL.new()
	adsr_by_param[param_name] = automation
	_connect_adsr_automation(automation)

func _connect_adsr_automation(automation: Node) -> void:
	if automation == null or not automation.has_signal("changed"):
		return
	var callable = Callable(self, "_on_adsr_changed")
	if not automation.is_connected("changed", callable):
		automation.connect("changed", callable)

func _on_adsr_changed() -> void:
	emit_signal("changed")

func add_clip(clip: Node, start_beats: float = 0.0, length_beats: float = -1.0) -> void:
	if clip == null:
		return
	clips.append(clip)
	if clip.has_method("set"):
		clip.set("is_used", true)
		clip.set("owner_track_id", id)
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

func add_clip_unplaced(clip: Node) -> void:
	if clip == null:
		return
	clips.append(clip)
	if clip.has_method("set"):
		clip.set("is_used", false)
		clip.set("owner_track_id", id)
	if clip.has_signal("changed"):
		clip.connect("changed", Callable(self, "_on_clip_changed"))
	emit_signal("changed")

func place_clip(clip: Node, start_beats: float, length_beats: float = -1.0) -> Node:
	if clip == null:
		return null
	var is_used = false
	var owner_id = ""
	if clip.has_method("get"):
		is_used = bool(clip.get("is_used"))
		owner_id = str(clip.get("owner_track_id"))
	if is_used:
		return add_linked_clip(clip, start_beats, length_beats)
	if owner_id != "" and owner_id != id:
		return add_linked_clip(clip, start_beats, length_beats)
	var resolved_length = length_beats
	if resolved_length < 0.0:
		resolved_length = _get_clip_length_beats(clip)
	arrangement.append({
		"clip": clip,
		"clip_id": clip.id,
		"start": start_beats,
		"length": resolved_length
	})
	if clip.has_method("set"):
		clip.set("is_used", true)
		clip.set("owner_track_id", id)
	emit_signal("changed")
	return clip

func add_linked_clip(source_clip: Node, start_beats: float, length_beats: float = -1.0) -> Node:
	if source_clip == null:
		return null
	var clip = CLIP_MODEL.new()
	clip.id = "clip_%s_%d" % [id, clips.size() + 1]
	clip.clip_name = str(source_clip.clip_name)
	clip.clip_length_beats = float(source_clip.clip_length_beats)
	clip.set_source_clip(source_clip)
	clip.is_used = true
	clip.owner_track_id = id
	var resolved_length = length_beats
	if resolved_length < 0.0:
		resolved_length = float(source_clip.clip_length_beats)
	clips.append(clip)
	arrangement.append({
		"clip": clip,
		"clip_id": clip.id,
		"start": start_beats,
		"length": resolved_length,
		"linked": true,
		"source_id": str(source_clip.id)
	})
	if clip.has_signal("changed"):
		clip.connect("changed", Callable(self, "_on_clip_changed"))
	emit_signal("changed")
	return clip

func remove_clip_from_arrangement(clip: Node) -> void:
	var index = _find_arrangement_index(clip)
	if index < 0:
		return
	arrangement.remove_at(index)
	if clip != null and clip.has_method("get") and bool(clip.get("is_linked")):
		clips.erase(clip)
	else:
		if clip != null and clip.has_method("set"):
			clip.set("is_used", false)
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
