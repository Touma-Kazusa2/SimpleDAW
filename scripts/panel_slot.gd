extends VBoxContainer

signal slot_focused(slot_index: int)
signal scroll_x_changed(slot_index: int, scroll_x: float, view_width: float)
signal track_changed(slot_index: int, track_index: int)
signal clip_changed(slot_index: int, clip_index: int)

const PIANO_ROLL_SCENE = preload("res://piano_roll.tscn")
const CLIP_MODEL = preload("res://scripts/models/clip_model.gd")
const ICON_MODE_ROLL = preload("res://Lucid V1.2/PNG/Flat/16/Grid.png")
const ICON_MODE_ENVELOPE = preload("res://Lucid V1.2/PNG/Flat/16/Signal-1.png")
const ICON_MODE_COMMENT = preload("res://Lucid V1.2/PNG/Flat/16/Message.png")
const ICON_MODE_ARRANGEMENT = preload("res://Lucid V1.2/PNG/Flat/16/List.png")
const ICON_MODE_3D = preload("res://Lucid V1.2/PNG/Flat/16/Stack.png")

@export var slot_index: int = 0

@onready var track_selector: OptionButton = $"HeaderRow/TrackSelector"
@onready var mode_button: Button = $"HeaderRow/ModeButton"
@onready var tab_bar: TabBar = $"TabRow/ClipTabs"
@onready var add_clip_button: Button = $"TabRow/AddClipButton"
@onready var tab_row: Control = $"TabRow"
@onready var h_scroll_row: Control = $"HScrollRow"
@onready var h_scroll_spacer: Control = $"HScrollRow/HScrollSpacer"
@onready var h_scroll: Control = $"HScrollRow/HScrollFrame/HScroll"
@onready var panel_row: Control = $"PanelRow"
@onready var panel_spacer: Control = $"PanelRow/PanelSpacer"
@onready var panel_v_scroll: Control = $"PanelRow/PanelRightSpacer/PanelVScroll"
@onready var envelope_lane: Control = $"PanelRow/PanelFrame/EnvelopeLane"
@onready var comment_lane: Control = $"PanelRow/PanelFrame/CommentLane"
@onready var arrangement_lane: Control = $"PanelRow/PanelFrame/ArrangementLane"
@onready var three_d_lane: Control = $"PanelRow/PanelFrame/ThreeDLane"
@onready var envelope_bar_row: Control = $"EnvelopeBarRow"
@onready var envelope_bar_spacer: Control = $"EnvelopeBarRow/EnvelopeBarSpacer"
@onready var envelope_drag_bar: Control = $"EnvelopeBarRow/EnvelopeBarFrame/EnvelopeDragBar"
@onready var roll_frame_row: Control = $"RollFrameRow"
@onready var roll_frame_overlay: Control = $"RollFrameRow/RollFrame/RollFrameOverlay"
@onready var roll_container: Control = $"RollFrameRow/RollFrame/RollClip/RollRow/RollContainer"
@onready var v_scroll: Control = $"RollFrameRow/VScroll"

var project_model: Node = null
var active_track: Node = null
var active_track_index: int = 0
var active_clip_index: int = 0
var panel_mode: String = "roll"

var piano_roll: Control = null
var notes_model: Node = null
var envelope_model: Node = null

var updating_scrollbars := false
var updating_panel_scroll := false
var suppress_scroll_signal := false
var panel_scroll_y_comment: float = 0.0
var panel_scroll_y_3d: float = -1.0
var panel_scroll_y_arrangement: float = 0.0
var panel_view_height_3d: float = 0.0
var shared_view_beats: int = -1

func _ready() -> void:
	_ensure_roll()
	_init_controls()
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process_input(true)
	_apply_panel_mode()
	_update_panel_mode_label()
	_sync_scrollbars()
	_update_panel_scrollbar()

func _ensure_roll() -> void:
	if roll_container == null:
		return
	if roll_container.get_child_count() == 0:
		piano_roll = PIANO_ROLL_SCENE.instantiate()
		roll_container.add_child(piano_roll)
	else:
		piano_roll = roll_container.get_child(0) as Control
	notes_model = piano_roll.get_node_or_null("NotesModel") if piano_roll else null
	envelope_model = piano_roll.get_node_or_null("EnvelopeModel") if piano_roll else null
	if piano_roll != null and piano_roll.has_signal("scroll_changed"):
		var callable = Callable(self, "_on_roll_scroll_changed")
		if not piano_roll.is_connected("scroll_changed", callable):
			piano_roll.connect("scroll_changed", callable)

func _init_controls() -> void:
	if track_selector != null and track_selector.has_signal("item_selected"):
		var callable = Callable(self, "_on_track_selected")
		if not track_selector.is_connected("item_selected", callable):
			track_selector.connect("item_selected", callable)
	if tab_bar != null and tab_bar.has_signal("tab_changed"):
		var tab_callable = Callable(self, "_on_tab_changed")
		if not tab_bar.is_connected("tab_changed", tab_callable):
			tab_bar.connect("tab_changed", tab_callable)
	if add_clip_button != null and add_clip_button.has_signal("pressed"):
		var add_callable = Callable(self, "_on_add_clip_pressed")
		if not add_clip_button.is_connected("pressed", add_callable):
			add_clip_button.connect("pressed", add_callable)
	if mode_button != null and mode_button.has_signal("pressed"):
		var mode_callable = Callable(self, "_on_mode_pressed")
		if not mode_button.is_connected("pressed", mode_callable):
			mode_button.connect("pressed", mode_callable)
	if h_scroll != null and h_scroll.has_signal("value_changed"):
		var scroll_callable = Callable(self, "_on_h_scroll_changed")
		if not h_scroll.is_connected("value_changed", scroll_callable):
			h_scroll.connect("value_changed", scroll_callable)
	if v_scroll != null and v_scroll.has_signal("value_changed"):
		var v_callable = Callable(self, "_on_v_scroll_changed")
		if not v_scroll.is_connected("value_changed", v_callable):
			v_scroll.connect("value_changed", v_callable)
	if panel_v_scroll != null and panel_v_scroll.has_signal("value_changed"):
		var panel_callable = Callable(self, "_on_panel_v_scroll_changed")
		if not panel_v_scroll.is_connected("value_changed", panel_callable):
			panel_v_scroll.connect("value_changed", panel_callable)
	if envelope_drag_bar != null:
		if envelope_drag_bar.has_method("setup"):
			envelope_drag_bar.call("setup", panel_row)
		if envelope_drag_bar.has_method("set_allow_panel_resize"):
			envelope_drag_bar.call("set_allow_panel_resize", false)
		if envelope_drag_bar.has_signal("selection_committed"):
			var committed_callable = Callable(self, "_on_selection_committed")
			if not envelope_drag_bar.is_connected("selection_committed", committed_callable):
				envelope_drag_bar.connect("selection_committed", committed_callable)
		if envelope_drag_bar.has_signal("selection_double_clicked"):
			var comment_callable = Callable(self, "_on_selection_double_clicked")
			if not envelope_drag_bar.is_connected("selection_double_clicked", comment_callable):
				envelope_drag_bar.connect("selection_double_clicked", comment_callable)
	if arrangement_lane != null:
		if arrangement_lane.has_signal("clip_selected"):
			var clip_callable = Callable(self, "_on_arrangement_clip_selected")
			if not arrangement_lane.is_connected("clip_selected", clip_callable):
				arrangement_lane.connect("clip_selected", clip_callable)
		if arrangement_lane.has_signal("track_selected"):
			var track_callable = Callable(self, "_on_arrangement_track_selected")
			if not arrangement_lane.is_connected("track_selected", track_callable):
				arrangement_lane.connect("track_selected", track_callable)

func set_project_model(next_model: Node) -> void:
	if project_model != null and project_model.has_signal("changed"):
		var callable = Callable(self, "_on_project_model_changed")
		if project_model.is_connected("changed", callable):
			project_model.disconnect("changed", callable)
	project_model = next_model
	if project_model != null and project_model.has_signal("changed"):
		project_model.connect("changed", Callable(self, "_on_project_model_changed"))
	if arrangement_lane != null and arrangement_lane.has_method("set_project_model"):
		arrangement_lane.call("set_project_model", project_model)
	_refresh_track_selector()
	_set_active_track_index(active_track_index)

func get_active_track() -> Node:
	return active_track

func get_active_track_index() -> int:
	return active_track_index

func get_active_clip_index() -> int:
	return active_clip_index

func select_track(index: int) -> void:
	_set_active_track_index(index)

func select_clip(index: int) -> void:
	_set_active_clip_index(index)

func set_shared_view_beats(value: int) -> void:
	shared_view_beats = value
	_apply_view_beats()

func clear_shared_view_beats() -> void:
	shared_view_beats = -1
	_apply_view_beats()

func _on_project_model_changed() -> void:
	if project_model == null:
		return
	var track_count = project_model.tracks.size()
	if track_count <= 0:
		return
	if active_track != null:
		var resolved_index = project_model.tracks.find(active_track)
		if resolved_index >= 0 and resolved_index != active_track_index:
			_set_active_track_index(resolved_index)
			return
	if active_track_index >= track_count:
		_set_active_track_index(track_count - 1)
		return
	_refresh_track_selector()
	_refresh_tab_bar()

func set_shared_scroll_suppressed(enabled: bool) -> void:
	suppress_scroll_signal = enabled

func set_scroll_x(value: float, from_shared: bool = false) -> void:
	if piano_roll == null:
		return
	var prev = suppress_scroll_signal
	if from_shared:
		suppress_scroll_signal = true
	piano_roll.call("set_scroll_x", value)
	suppress_scroll_signal = prev

func get_scroll_x() -> float:
	if piano_roll == null:
		return 0.0
	return float(piano_roll.call("get_scroll_x"))

func get_view_width() -> float:
	if piano_roll == null:
		return 0.0
	var roll_panel = piano_roll.get_node_or_null("RollPanel") as Control
	return roll_panel.size.x if roll_panel else 0.0

func get_active_clip() -> Node:
	if active_track == null:
		return null
	return _get_or_create_clip_for_track(active_track, active_clip_index)

func get_active_clip_length() -> float:
	var clip = get_active_clip()
	if clip == null:
		return 0.0
	return float(clip.clip_length_beats)

func set_track_name(label: String) -> void:
	if active_track == null:
		return
	active_track.track_name = label
	_refresh_track_selector()

func set_clip_name(label: String) -> void:
	var clip = get_active_clip()
	if clip == null:
		return
	clip.clip_name = label
	_refresh_tab_bar()

func toggle_snap() -> bool:
	if envelope_drag_bar != null and envelope_drag_bar.has_method("toggle_snap"):
		return bool(envelope_drag_bar.call("toggle_snap"))
	return false

func is_snap_enabled() -> bool:
	if envelope_drag_bar != null and envelope_drag_bar.has_method("is_snap_enabled"):
		return bool(envelope_drag_bar.call("is_snap_enabled"))
	return false

func _on_track_selected(index: int) -> void:
	_emit_focus()
	_set_active_track_index(index)

func _on_tab_changed(index: int) -> void:
	_emit_focus()
	_set_active_clip_index(index)

func _on_add_clip_pressed() -> void:
	_emit_focus()
	if active_track == null:
		return
	var next_index = active_track.clips.size() + 1
	var label = "Clip %d" % next_index
	var length_beats = float(piano_roll.get("visible_beats")) if piano_roll != null else 0.0
	_create_clip_for_track(active_track, label, length_beats)
	_refresh_tab_bar()
	_set_active_clip_index(active_track.clips.size() - 1)

func _on_mode_pressed() -> void:
	_emit_focus()
	if panel_mode == "roll":
		panel_mode = "envelope"
	elif panel_mode == "envelope":
		panel_mode = "comment"
	elif panel_mode == "comment":
		panel_mode = "arrangement"
	elif panel_mode == "arrangement":
		panel_mode = "3d"
	else:
		panel_mode = "roll"
	_apply_panel_mode()

func _on_arrangement_clip_selected(track_index: int, clip_index: int) -> void:
	_emit_focus()
	_set_active_track_index(track_index)
	_set_active_clip_index(clip_index)

func _on_arrangement_track_selected(track_index: int) -> void:
	_emit_focus()
	_set_active_track_index(track_index)

func _set_active_track_index(index: int) -> void:
	if project_model == null:
		return
	if index < 0 or index >= project_model.tracks.size():
		return
	active_track_index = index
	active_track = project_model.tracks[index]
	_refresh_track_selector()
	_refresh_tab_bar()
	_set_active_clip_index(clamp(active_clip_index, 0, tab_bar.get_tab_count() - 1))
	emit_signal("track_changed", slot_index, active_track_index)

func _set_active_clip_index(index: int) -> void:
	if active_track == null:
		return
	if index < 0:
		index = 0
	active_clip_index = index
	var clip = _get_or_create_clip_for_track(active_track, active_clip_index)
	if tab_bar != null:
		var clamped = clamp(active_clip_index, 0, tab_bar.get_tab_count() - 1)
		if tab_bar.current_tab != clamped:
			tab_bar.current_tab = clamped
	if piano_roll != null and piano_roll.has_method("set_clip_model"):
		piano_roll.call("set_clip_model", clip)
	_apply_view_beats()
	_sync_roll_params_to_lanes()
	_sync_scrollbars()
	_update_panel_scrollbar()
	if arrangement_lane != null and arrangement_lane.has_method("set_selection"):
		arrangement_lane.call("set_selection", active_track_index, active_clip_index)
	emit_signal("clip_changed", slot_index, active_clip_index)

func _refresh_track_selector() -> void:
	if track_selector == null or project_model == null:
		return
	track_selector.clear()
	for i in range(project_model.tracks.size()):
		var track = project_model.tracks[i]
		var label = "Track %d" % (i + 1)
		if track != null:
			label = str(track.track_name)
		track_selector.add_item(label, i)
	if project_model.tracks.size() > 0:
		track_selector.select(clamp(active_track_index, 0, project_model.tracks.size() - 1))

func _refresh_tab_bar() -> void:
	if tab_bar == null:
		return
	while tab_bar.get_tab_count() > 0:
		tab_bar.remove_tab(0)
	if active_track == null:
		return
	if active_track.clips.is_empty():
		var length_beats = float(piano_roll.get("visible_beats")) if piano_roll != null else 0.0
		_create_clip_for_track(active_track, "Clip 1", length_beats)
	for i in range(active_track.clips.size()):
		var clip = active_track.clips[i]
		var label = "Clip %d" % (i + 1)
		if clip != null and str(clip.clip_name) != "":
			label = str(clip.clip_name)
		tab_bar.add_tab(label)
	var clamped = clamp(active_clip_index, 0, tab_bar.get_tab_count() - 1)
	tab_bar.current_tab = clamped

func _get_or_create_clip_for_track(track: Node, clip_index: int) -> Node:
	if track == null:
		return null
	while track.clips.size() <= clip_index:
		var next_name = "Clip %d" % (track.clips.size() + 1)
		var length_beats = float(piano_roll.get("visible_beats")) if piano_roll != null else 0.0
		_create_clip_for_track(track, next_name, length_beats)
	var clip = track.clips[clip_index]
	if clip == null:
		var fallback_name = "Clip %d" % (clip_index + 1)
		var fallback_length = float(piano_roll.get("visible_beats")) if piano_roll != null else 0.0
		clip = _create_clip_for_track(track, fallback_name, fallback_length)
		if track.clips.size() > clip_index:
			track.clips[clip_index] = clip
	return clip

func _create_clip_for_track(track: Node, label: String, length_beats: float) -> Node:
	if track == null:
		return null
	var clip = CLIP_MODEL.new()
	clip.id = "clip_%s_%d" % [track.id, track.clips.size() + 1]
	clip.clip_name = label
	clip.clip_length_beats = length_beats
	clip.clip_start_beats = 0.0
	if track.has_method("add_clip"):
		track.call("add_clip", clip, 0.0, length_beats)
	return clip

func _apply_view_beats() -> void:
	if piano_roll == null:
		return
	var clip_length = get_active_clip_length()
	var view_beats = int(max(1.0, clip_length))
	var should_sync = true
	if shared_view_beats > 0:
		view_beats = int(max(float(shared_view_beats), clip_length))
		should_sync = false
	if clip_length <= 0.0:
		view_beats = int(piano_roll.get("visible_beats")) if piano_roll != null else view_beats
		should_sync = true
	if piano_roll.has_method("set_view_beats"):
		piano_roll.call("set_view_beats", view_beats, should_sync)
	else:
		piano_roll.set("visible_beats", view_beats)
		if piano_roll.has_method("_apply_config"):
			piano_roll.call("_apply_config")

func _sync_scrollbars() -> void:
	if piano_roll == null:
		return
	_sync_roll_params_to_lanes()
	var roll_panel = piano_roll.get_node_or_null("RollPanel") as Control
	var view_width = roll_panel.size.x if roll_panel else 0.0
	var view_height = roll_panel.size.y if roll_panel else 0.0
	var scroll_x = float(piano_roll.call("get_scroll_x"))
	var scroll_y = float(piano_roll.call("get_scroll_y"))
	var max_x = float(piano_roll.call("get_max_scroll_x"))
	var max_y = float(piano_roll.call("get_max_scroll_y"))
	_update_scrollbars(scroll_x, scroll_y, max_x, max_y, view_width, view_height)
	_update_envelope_view(scroll_x, view_width)
	_update_panel_scrollbar()

func _update_scrollbars(
	scroll_x: float,
	scroll_y: float,
	max_x: float,
	max_y: float,
	view_width: float,
	view_height: float
) -> void:
	updating_scrollbars = true
	var keyboard_width = 0.0
	if piano_roll != null and piano_roll.has_method("get_keyboard_width"):
		keyboard_width = float(piano_roll.call("get_keyboard_width"))
	if h_scroll_spacer != null:
		h_scroll_spacer.custom_minimum_size = Vector2(max(0.0, keyboard_width), 0.0)
	if panel_spacer != null:
		panel_spacer.custom_minimum_size = Vector2(max(0.0, keyboard_width), 0.0)
	if envelope_bar_spacer != null:
		envelope_bar_spacer.custom_minimum_size = Vector2(max(0.0, keyboard_width), 0.0)
	if h_scroll != null:
		h_scroll.min_value = 0.0
		h_scroll.max_value = max_x
		h_scroll.page = max(view_width, 0.0)
		h_scroll.value = clamp(scroll_x, 0.0, max_x)
		h_scroll.visible = true
		h_scroll.queue_redraw()
	if v_scroll != null:
		v_scroll.min_value = 0.0
		v_scroll.max_value = max_y
		v_scroll.page = max(view_height, 0.0)
		v_scroll.value = clamp(scroll_y, 0.0, max_y)
		v_scroll.visible = true
		v_scroll.queue_redraw()
	updating_scrollbars = false

func _sync_roll_params_to_lanes() -> void:
	if piano_roll == null:
		return
	var ppb = float(piano_roll.get("pixels_per_beat"))
	var beats = int(piano_roll.get("visible_beats"))
	var beats_per_measure = int(piano_roll.get("beats_per_measure"))
	if envelope_lane != null:
		envelope_lane.set("pixels_per_beat", ppb)
		envelope_lane.set("visible_beats", beats)
		envelope_lane.set("beats_per_measure", beats_per_measure)
		if envelope_lane.has_method("_request_redraw"):
			envelope_lane.call("_request_redraw")
		else:
			envelope_lane.queue_redraw()
	if comment_lane != null:
		comment_lane.set("pixels_per_beat", ppb)
		comment_lane.set("visible_beats", beats)
		comment_lane.set("beats_per_measure", beats_per_measure)
		if comment_lane.has_method("_request_redraw"):
			comment_lane.call("_request_redraw")
		else:
			comment_lane.queue_redraw()
	if arrangement_lane != null:
		arrangement_lane.set("pixels_per_beat", ppb)
		arrangement_lane.queue_redraw()

func _update_envelope_view(scroll_x: float, view_width: float) -> void:
	if piano_roll == null:
		return
	if envelope_lane != null and envelope_lane.has_method("set_view"):
		envelope_lane.call("set_view", scroll_x, view_width)
	if comment_lane != null and comment_lane.has_method("set_view"):
		comment_lane.call("set_view", scroll_x, view_width)
	if arrangement_lane != null and arrangement_lane.has_method("set_view"):
		arrangement_lane.call("set_view", scroll_x, view_width)
	if envelope_drag_bar != null and envelope_drag_bar.has_method("update_from_roll"):
		var ppb = float(piano_roll.get("pixels_per_beat"))
		var beats = int(piano_roll.get("visible_beats"))
		envelope_drag_bar.call("update_from_roll", ppb, beats, scroll_x, view_width)

func _on_h_scroll_changed(value: float) -> void:
	if updating_scrollbars or piano_roll == null:
		return
	piano_roll.call("set_scroll_x", value)
	var roll_panel = piano_roll.get_node_or_null("RollPanel") as Control
	var view_width = roll_panel.size.x if roll_panel else 0.0
	_update_envelope_view(value, view_width)

func _on_v_scroll_changed(value: float) -> void:
	if updating_scrollbars or piano_roll == null:
		return
	piano_roll.call("set_scroll_y", value)

func _on_roll_scroll_changed(
	scroll_x: float,
	scroll_y: float,
	max_x: float,
	max_y: float,
	view_width: float,
	view_height: float
) -> void:
	_sync_roll_params_to_lanes()
	_update_scrollbars(scroll_x, scroll_y, max_x, max_y, view_width, view_height)
	_update_envelope_view(scroll_x, view_width)
	if not suppress_scroll_signal:
		emit_signal("scroll_x_changed", slot_index, scroll_x, view_width)

func _on_panel_v_scroll_changed(value: float) -> void:
	if updating_panel_scroll:
		return
	if panel_mode != "comment" and panel_mode != "3d" and panel_mode != "arrangement":
		return
	_set_current_panel_scroll_y(value)
	_apply_panel_scroll()

func _apply_panel_scroll() -> void:
	if comment_lane != null:
		var next_scroll = _current_panel_scroll_y() if panel_mode == "comment" else 0.0
		if comment_lane.has_method("set_view_scroll_y"):
			comment_lane.call("set_view_scroll_y", next_scroll)
		else:
			comment_lane.set("view_scroll_y", next_scroll)
		if comment_lane.has_method("_request_redraw"):
			comment_lane.call("_request_redraw")
		else:
			comment_lane.queue_redraw()
	if three_d_lane != null:
		var next_scroll_3d = _current_panel_scroll_y() if panel_mode == "3d" else 0.0
		if three_d_lane.has_method("set_view_scroll_y"):
			three_d_lane.call("set_view_scroll_y", next_scroll_3d)
	if arrangement_lane != null:
		var next_scroll_arr = _current_panel_scroll_y() if panel_mode == "arrangement" else 0.0
		if arrangement_lane.has_method("set_view_scroll_y"):
			arrangement_lane.call("set_view_scroll_y", next_scroll_arr)

func _update_panel_scrollbar() -> void:
	if panel_v_scroll == null or panel_row == null:
		return
	var view_height = panel_row.size.y
	if view_height <= 0.0:
		updating_panel_scroll = true
		_set_current_panel_scroll_y(0.0)
		panel_v_scroll.value = 0.0
		panel_v_scroll.visible = true
		updating_panel_scroll = false
		panel_v_scroll.queue_redraw()
		return
	var is_comment = panel_mode == "comment" and comment_lane != null
	var is_3d = panel_mode == "3d" and three_d_lane != null
	var is_arrangement = panel_mode == "arrangement" and arrangement_lane != null
	var is_scrollable = is_comment or is_3d or is_arrangement
	var content_height = 0.0
	if is_comment and comment_lane.has_method("get_content_height"):
		content_height = float(comment_lane.call("get_content_height"))
	elif is_3d and three_d_lane.has_method("get_content_height"):
		content_height = float(three_d_lane.call("get_content_height"))
	elif is_arrangement and arrangement_lane.has_method("get_content_height"):
		content_height = float(arrangement_lane.call("get_content_height"))
	var max_y = max(0.0, content_height - view_height)
	updating_panel_scroll = true
	if not is_scrollable:
		_set_current_panel_scroll_y(0.0)
		max_y = 0.0
	else:
		if is_3d and panel_view_height_3d > 0.0 and not is_equal_approx(view_height, panel_view_height_3d):
			var delta = view_height - panel_view_height_3d
			panel_scroll_y_3d = max(0.0, panel_scroll_y_3d - delta)
		if is_3d:
			panel_view_height_3d = view_height
			if panel_scroll_y_3d < 0.0:
				panel_scroll_y_3d = max_y
		var next_scroll = _current_panel_scroll_y()
		next_scroll = clamp(next_scroll, 0.0, max_y)
		_set_current_panel_scroll_y(next_scroll)
	panel_v_scroll.min_value = 0.0
	panel_v_scroll.max_value = max_y
	panel_v_scroll.page = max(view_height, 0.0)
	panel_v_scroll.value = _current_panel_scroll_y()
	panel_v_scroll.visible = true
	panel_v_scroll.mouse_filter = Control.MOUSE_FILTER_STOP if is_scrollable else Control.MOUSE_FILTER_IGNORE
	updating_panel_scroll = false
	_apply_panel_scroll()
	panel_v_scroll.queue_redraw()

func _current_panel_scroll_y() -> float:
	if panel_mode == "comment":
		return panel_scroll_y_comment
	if panel_mode == "3d":
		return panel_scroll_y_3d
	if panel_mode == "arrangement":
		return panel_scroll_y_arrangement
	return 0.0

func _set_current_panel_scroll_y(value: float) -> void:
	if panel_mode == "comment":
		panel_scroll_y_comment = value
	elif panel_mode == "3d":
		panel_scroll_y_3d = value
	elif panel_mode == "arrangement":
		panel_scroll_y_arrangement = value

func _apply_panel_mode() -> void:
	if roll_frame_row != null:
		roll_frame_row.visible = panel_mode == "roll"
	if panel_row != null:
		panel_row.visible = panel_mode != "roll"
	if envelope_lane != null:
		envelope_lane.visible = panel_mode == "envelope"
	if comment_lane != null:
		comment_lane.visible = panel_mode == "comment"
	if arrangement_lane != null:
		arrangement_lane.visible = panel_mode == "arrangement"
	if three_d_lane != null:
		three_d_lane.visible = panel_mode == "3d"
	_update_panel_mode_label()
	_update_panel_scrollbar()

func _update_panel_mode_label() -> void:
	if mode_button == null:
		return
	mode_button.text = ""
	if panel_mode == "roll":
		mode_button.icon = ICON_MODE_ROLL
	elif panel_mode == "comment":
		mode_button.icon = ICON_MODE_COMMENT
	elif panel_mode == "arrangement":
		mode_button.icon = ICON_MODE_ARRANGEMENT
	elif panel_mode == "3d":
		mode_button.icon = ICON_MODE_3D
	else:
		mode_button.icon = ICON_MODE_ENVELOPE

func _on_selection_committed(start_beats: float, end_beats: float) -> void:
	if piano_roll == null:
		return
	var start_time = min(start_beats, end_beats)
	piano_roll.call("set_playhead_time", start_time)

func _on_selection_double_clicked(start_beats: float, end_beats: float) -> void:
	if comment_lane == null:
		return
	panel_mode = "comment"
	_apply_panel_mode()
	if comment_lane.has_method("add_comment"):
		comment_lane.call("add_comment", start_beats, end_beats)

func _emit_focus() -> void:
	emit_signal("slot_focused", slot_index)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var rect = get_global_rect()
		if rect.has_point(event.position):
			_emit_focus()
