extends Control

const TRACK_ADSR_MODEL = preload("res://scripts/track_adsr_model.gd")
const ADSR_TIME_MAX := 10.0
const SUSTAIN_MIN_DB := -80.0
const SUSTAIN_MAX_DB := 0.0
const NOTE_NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

var adsr_model: Node = TRACK_ADSR_MODEL.new()
var _zone_data: Array = []
var _selected_zone: Dictionary = {}
var _last_scroll_y := 0.0

@onready var scroll_clip: Control = $ScrollClip
@onready var content: Control = $ScrollClip/Content
@onready var layout: Control = $ScrollClip/Content/Layout
@onready var adsr_graph: Control = $ScrollClip/Content/Layout/TopRow/AdsrGraph
@onready var enable_toggle: CheckBox = $ScrollClip/Content/Layout/TopRow/ControlColumn/EnableRow/EnableToggle
@onready var zone_tree: Tree = $ScrollClip/Content/Layout/ZoneFrame/ZoneTree
@onready var param_select: OptionButton = $ScrollClip/Content/Layout/AutomationHeader/ParamSelect
@onready var automation_lane: Control = $ScrollClip/Content/Layout/AutomationFrame/AutomationLane
@onready var attack_slider: HSlider = $ScrollClip/Content/Layout/TopRow/ControlColumn/AttackRow/AttackSlider
@onready var decay_slider: HSlider = $ScrollClip/Content/Layout/TopRow/ControlColumn/DecayRow/DecaySlider
@onready var sustain_slider: HSlider = $ScrollClip/Content/Layout/TopRow/ControlColumn/SustainRow/SustainSlider
@onready var release_slider: HSlider = $ScrollClip/Content/Layout/TopRow/ControlColumn/ReleaseRow/ReleaseSlider
@onready var attack_value: Label = $ScrollClip/Content/Layout/TopRow/ControlColumn/AttackRow/AttackValue
@onready var decay_value: Label = $ScrollClip/Content/Layout/TopRow/ControlColumn/DecayRow/DecayValue
@onready var sustain_value: Label = $ScrollClip/Content/Layout/TopRow/ControlColumn/SustainRow/SustainValue
@onready var release_value: Label = $ScrollClip/Content/Layout/TopRow/ControlColumn/ReleaseRow/ReleaseValue

var _updating := false

func _ready() -> void:
	if adsr_model != null:
		adsr_model.connect("changed", Callable(self, "_on_model_changed"))
	_refresh_param_select()
	_bind_sliders()
	_bind_toggle()
	_refresh_toggle_state()
	_update_graph_from_model()
	if automation_lane != null:
		automation_lane.call("set_model", adsr_model)
	if zone_tree != null and not zone_tree.item_selected.is_connected(_on_zone_selected):
		zone_tree.item_selected.connect(_on_zone_selected)
	if not resized.is_connected(_on_panel_resized):
		resized.connect(_on_panel_resized)
	call_deferred("_initialize_layout")

func set_track(track: Node) -> void:
	if adsr_model != null and adsr_model.has_method("set_track"):
		adsr_model.call("set_track", track)
	_refresh_param_select()
	_refresh_slider_values()
	_refresh_toggle_state()
	_update_graph_from_model()

func set_from_roll(roll_node: Control) -> void:
	if roll_node == null or automation_lane == null:
		return
	automation_lane.set("pixels_per_beat", float(roll_node.get("pixels_per_beat")))
	automation_lane.set("beats_per_measure", int(roll_node.get("beats_per_measure")))
	automation_lane.set("visible_beats", int(roll_node.get("visible_beats")))
	automation_lane.call("set_model", adsr_model)
	var lane_width = automation_lane.size.x if automation_lane != null else 0.0
	automation_lane.call("set_view", float(roll_node.call("get_scroll_x")), lane_width)
	automation_lane.call("_request_redraw")

func set_roll_params(pixels_per_beat: float, visible_beats: int, beats_per_measure: int) -> void:
	if automation_lane == null:
		return
	automation_lane.set("pixels_per_beat", pixels_per_beat)
	automation_lane.set("visible_beats", visible_beats)
	automation_lane.set("beats_per_measure", beats_per_measure)

func set_view(scroll_x: float, view_width: float) -> void:
	if automation_lane == null:
		return
	var lane_width = automation_lane.size.x if automation_lane != null else view_width
	automation_lane.call("set_view", scroll_x, lane_width)

func set_preset_source(player: Node, program: int) -> void:
	var bank = player.get("bank") if player != null and player.has_method("get") else null
	_zone_data = _build_zone_list(bank, program)
	_refresh_zone_tree()
	_apply_zone_display()

func set_view_scroll_y(scroll_y: float) -> void:
	if layout == null or content == null:
		return
	var content_height = get_content_height()
	var view_height = size.y
	var max_y = max(0.0, content_height - view_height)
	var clamped = clamp(scroll_y, 0.0, max_y)
	_last_scroll_y = clamped
	_apply_layout_sizes(content_height)
	content.position = Vector2(0.0, -clamped)
	if automation_lane != null:
		var lane_extra = _get_lane_scroll_extra()
		var lane_scroll = clamp(clamped - _get_lane_top_offset(), 0.0, lane_extra)
		automation_lane.call("set_view_scroll_y", lane_scroll)

func get_content_height() -> float:
	if layout == null:
		return size.y
	var content_height = layout.get_combined_minimum_size().y
	var lane_extra = _get_lane_scroll_extra()
	return max(content_height + lane_extra, size.y)

func _initialize_layout() -> void:
	_apply_layout_sizes(get_content_height())
	set_view_scroll_y(_last_scroll_y)

func _on_panel_resized() -> void:
	_apply_layout_sizes(get_content_height())
	set_view_scroll_y(_last_scroll_y)

func _apply_layout_sizes(content_height: float) -> void:
	if scroll_clip == null or content == null or layout == null:
		return
	var width = max(0.0, scroll_clip.size.x)
	content.size = Vector2(width, content_height)
	layout.size = Vector2(width, content_height)

func _get_lane_top_offset() -> float:
	if automation_lane == null:
		return 0.0
	return automation_lane.position.y

func _get_lane_scroll_extra() -> float:
	if automation_lane == null or not automation_lane.has_method("get_content_height"):
		return 0.0
	var lane_content = float(automation_lane.call("get_content_height"))
	var lane_view = automation_lane.size.y
	return max(0.0, lane_content - lane_view)

func _bind_sliders() -> void:
	if attack_slider != null:
		attack_slider.value_changed.connect(_on_attack_changed)
	if decay_slider != null:
		decay_slider.value_changed.connect(_on_decay_changed)
	if sustain_slider != null:
		sustain_slider.value_changed.connect(_on_sustain_changed)
	if release_slider != null:
		release_slider.value_changed.connect(_on_release_changed)
	if param_select != null and not param_select.item_selected.is_connected(_on_param_selected):
		param_select.item_selected.connect(_on_param_selected)

func _bind_toggle() -> void:
	if enable_toggle != null and not enable_toggle.toggled.is_connected(_on_enable_toggled):
		enable_toggle.toggled.connect(_on_enable_toggled)

func _refresh_param_select() -> void:
	if param_select == null:
		return
	param_select.clear()
	var params: Array = []
	if adsr_model != null and adsr_model.has_method("get_param_names"):
		params = adsr_model.call("get_param_names")
	for i in range(params.size()):
		param_select.add_item(String(params[i]), i)
	param_select.select(0)
	if adsr_model != null and adsr_model.has_method("set_current_param"):
		adsr_model.call("set_current_param", "Attack")

func _refresh_toggle_state() -> void:
	if enable_toggle == null or adsr_model == null:
		return
	var track = adsr_model.get("track") if adsr_model.has_method("get") else null
	var enabled := false
	if track != null and track.has_method("has_adsr_override"):
		enabled = bool(track.call("has_adsr_override"))
	_updating = true
	enable_toggle.button_pressed = enabled
	_updating = false
	_set_controls_enabled(enabled)

func _on_param_selected(index: int) -> void:
	if adsr_model == null or not adsr_model.has_method("set_current_param"):
		return
	var label = param_select.get_item_text(index)
	adsr_model.call("set_current_param", label)
	if automation_lane != null:
		automation_lane.call("_request_redraw")

func _on_attack_changed(value: float) -> void:
	_set_param_value("Attack", value)

func _on_decay_changed(value: float) -> void:
	_set_param_value("Decay", value)

func _on_sustain_changed(value: float) -> void:
	_set_param_value("Sustain", value)

func _on_release_changed(value: float) -> void:
	_set_param_value("Release", value)

func _set_param_value(param_name: String, value: float) -> void:
	if _updating:
		return
	if enable_toggle != null and not enable_toggle.button_pressed:
		return
	if adsr_model != null and adsr_model.has_method("set_current_param"):
		adsr_model.call("set_current_param", param_name)
	if adsr_model != null and adsr_model.has_method("set_current_default_value"):
		adsr_model.call("set_current_default_value", value)
	_update_graph_from_model()
	_refresh_slider_values()

func _refresh_slider_values() -> void:
	if adsr_model == null:
		return
	_updating = true
	attack_slider.value = _get_param_default("Attack")
	decay_slider.value = _get_param_default("Decay")
	sustain_slider.value = _get_param_default("Sustain")
	release_slider.value = _get_param_default("Release")
	attack_value.text = _format_time(_to_seconds(attack_slider.value))
	decay_value.text = _format_time(_to_seconds(decay_slider.value))
	sustain_value.text = _format_db(_to_db(sustain_slider.value))
	release_value.text = _format_time(_to_seconds(release_slider.value))
	_updating = false
	_refresh_toggle_state()

func _refresh_zone_tree() -> void:
	if zone_tree == null:
		return
	zone_tree.clear()
	var root = zone_tree.create_item()
	if _zone_data.is_empty():
		return
	for i in range(_zone_data.size()):
		var zone = _zone_data[i]
		var item = zone_tree.create_item(root)
		item.set_text(0, _format_zone_label(zone))
		item.set_metadata(0, i)
	zone_tree.set_column_titles_visible(false)
	var first = root.get_first_child()
	if first != null:
		zone_tree.set_selected(first, 0)
		_selected_zone = _zone_data[0]

func _on_zone_selected() -> void:
	if zone_tree == null:
		return
	var item = zone_tree.get_selected()
	if item == null:
		return
	var idx = int(item.get_metadata(0))
	if idx < 0 or idx >= _zone_data.size():
		return
	_selected_zone = _zone_data[idx]
	_apply_zone_display()

func _apply_zone_display() -> void:
	if enable_toggle != null and enable_toggle.button_pressed:
		_update_graph_from_model()
		_refresh_slider_values()
		return
	if _selected_zone.is_empty():
		return
	var a = float(_selected_zone.get("attack", 0.0))
	var d = float(_selected_zone.get("decay", 0.0))
	var s_db = float(_selected_zone.get("sustain_db", 0.0))
	var r = float(_selected_zone.get("release", 0.0))
	if adsr_graph != null:
		adsr_graph.call("set_adsr_values", a, d, s_db, r)
	if attack_value != null:
		attack_value.text = _format_time(a)
	if decay_value != null:
		decay_value.text = _format_time(d)
	if sustain_value != null:
		sustain_value.text = _format_db(s_db)
	if release_value != null:
		release_value.text = _format_time(r)

func _build_zone_list(bank: Object, program: int) -> Array:
	if bank == null or not bank.has_method("get_preset"):
		return []
	var preset = bank.call("get_preset", int(program), 0)
	if preset == null:
		return []
	var zones: Array = []
	var active: Array = []
	for key in range(128):
		var instruments = preset.instruments[key]
		var layers: Array = []
		if instruments != null:
			for inst in instruments:
				if inst == null:
					continue
				layers.append(_describe_instrument(inst))
		layers.sort_custom(func(a, b): return int(a["vel_min"]) < int(b["vel_min"]))
		if layers.is_empty():
			for zone in active:
				zones.append(_finish_zone(zone))
			active.clear()
			continue
		while active.size() > layers.size():
			zones.append(_finish_zone(active.pop_back()))
		for i in range(layers.size()):
			var desc = layers[i]
			if i >= active.size():
				active.append({"start": key, "end": key, "desc": desc})
				continue
			var zone = active[i]
			if _zone_desc_equal(zone["desc"], desc):
				zone["end"] = key
				active[i] = zone
			else:
				zones.append(_finish_zone(zone))
				active[i] = {"start": key, "end": key, "desc": desc}
	for zone in active:
		zones.append(_finish_zone(zone))
	return zones

func _describe_instrument(inst: Object) -> Dictionary:
	var adsr = _extract_adsr(inst)
	return {
		"vel_min": int(inst.vel_range_min),
		"vel_max": int(inst.vel_range_max),
		"attack": adsr.get("attack", 0.0),
		"decay": adsr.get("decay", 0.0),
		"sustain_db": adsr.get("sustain_db", 0.0),
		"release": adsr.get("release", 0.0)
	}

func _extract_adsr(inst: Object) -> Dictionary:
	var attack := 0.0
	var decay := 0.0
	var sustain_db := 0.0
	var release := 0.0
	var ads_state = inst.ads_state
	if ads_state.size() >= 3:
		attack = float(ads_state[1].time)
		decay = float(ads_state[2].time) - float(ads_state[1].time)
		sustain_db = float(ads_state[2].volume_db)
	elif ads_state.size() >= 2:
		attack = 0.0
		decay = float(ads_state[1].time)
		sustain_db = float(ads_state[1].volume_db)
	var release_state = inst.release_state
	if release_state.size() >= 2:
		release = float(release_state[1].time)
	return {
		"attack": max(0.0, attack),
		"decay": max(0.0, decay),
		"sustain_db": sustain_db,
		"release": max(0.0, release)
	}

func _finish_zone(zone: Dictionary) -> Dictionary:
	var desc = zone.get("desc", {})
	return {
		"key_start": int(zone.get("start", 0)),
		"key_end": int(zone.get("end", 0)),
		"vel_min": int(desc.get("vel_min", 0)),
		"vel_max": int(desc.get("vel_max", 127)),
		"attack": float(desc.get("attack", 0.0)),
		"decay": float(desc.get("decay", 0.0)),
		"sustain_db": float(desc.get("sustain_db", 0.0)),
		"release": float(desc.get("release", 0.0))
	}

func _zone_desc_equal(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("vel_min", -1)) != int(b.get("vel_min", -2)):
		return false
	if int(a.get("vel_max", -1)) != int(b.get("vel_max", -2)):
		return false
	if not is_equal_approx(float(a.get("attack", 0.0)), float(b.get("attack", 0.0))):
		return false
	if not is_equal_approx(float(a.get("decay", 0.0)), float(b.get("decay", 0.0))):
		return false
	if not is_equal_approx(float(a.get("sustain_db", 0.0)), float(b.get("sustain_db", 0.0))):
		return false
	if not is_equal_approx(float(a.get("release", 0.0)), float(b.get("release", 0.0))):
		return false
	return true

func _format_zone_label(zone: Dictionary) -> String:
	var start_key = int(zone.get("key_start", 0))
	var end_key = int(zone.get("key_end", start_key))
	var start_label = _note_label(start_key)
	var end_label = _note_label(end_key)
	var vel_min = int(zone.get("vel_min", 0))
	var vel_max = int(zone.get("vel_max", 127))
	return "%s-%s | vel %d-%d" % [start_label, end_label, vel_min, vel_max]

func _note_label(key: int) -> String:
	var clamped = clamp(key, 0, 127)
	var octave = int(floor(clamped / 12.0)) - 1
	var note_name = NOTE_NAMES[int(clamped % 12)]
	return "%s%d" % [note_name, octave]

func _set_controls_enabled(enabled: bool) -> void:
	if attack_slider != null:
		attack_slider.editable = enabled
	if decay_slider != null:
		decay_slider.editable = enabled
	if sustain_slider != null:
		sustain_slider.editable = enabled
	if release_slider != null:
		release_slider.editable = enabled
	if param_select != null:
		param_select.disabled = not enabled
	if automation_lane != null:
		automation_lane.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		automation_lane.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.5)

func _on_enable_toggled(enabled: bool) -> void:
	if _updating:
		return
	var track = adsr_model.get("track") if adsr_model != null and adsr_model.has_method("get") else null
	if track != null and track.has_method("set_adsr_override_enabled"):
		track.call("set_adsr_override_enabled", enabled)
	_set_controls_enabled(enabled)
	_apply_zone_display()

func _get_param_default(param_name: String) -> float:
	if adsr_model == null:
		return 0.0
	if adsr_model.has_method("get_default_value_for_param"):
		return float(adsr_model.call("get_default_value_for_param", param_name))
	return 0.0

func _update_graph_from_model() -> void:
	if adsr_graph == null:
		return
	var a = _to_seconds(_get_param_default("Attack"))
	var d = _to_seconds(_get_param_default("Decay"))
	var s = _to_db(_get_param_default("Sustain"))
	var r = _to_seconds(_get_param_default("Release"))
	adsr_graph.call("set_adsr_values", a, d, s, r)

func _to_seconds(value: float) -> float:
	return clamp(value, 0.0, 1.0) * ADSR_TIME_MAX

func _to_db(value: float) -> float:
	var t = clamp(value, 0.0, 1.0)
	return lerp(SUSTAIN_MIN_DB, SUSTAIN_MAX_DB, t)

func _format_time(seconds: float) -> String:
	return "%.2fs" % seconds

func _format_db(db: float) -> String:
	return "%.0fdB" % db

func _on_model_changed() -> void:
	_refresh_slider_values()
	_update_graph_from_model()
