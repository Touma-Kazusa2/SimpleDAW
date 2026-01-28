extends VBoxContainer

signal slot_focused(slot_index: int)
signal scroll_x_changed(slot_index: int, scroll_x: float, view_width: float)
signal track_changed(slot_index: int, track_index: int)
signal clip_changed(slot_index: int, clip_index: int)
signal arrangement_selection_preview(slot_index: int, start_beats: float, end_beats: float)
signal arrangement_selection_committed(slot_index: int, start_beats: float, end_beats: float)
signal snap_changed(slot_index: int, enabled: bool, step: float)

const PIANO_ROLL_SCENE = preload("res://piano_roll.tscn")
const CLIP_MODEL = preload("res://scripts/models/clip_model.gd")
const SNAPSHOT_BUILDER = preload("res://scripts/engine_snapshot_builder.gd")
const ICON_MODE_ROLL = preload("res://Lucid V1.2/PNG/Flat/16/Grid.png")
const ICON_MODE_ENVELOPE = preload("res://Lucid V1.2/PNG/Flat/16/Signal-1.png")
const ICON_MODE_COMMENT = preload("res://Lucid V1.2/PNG/Flat/16/Message.png")
const ICON_MODE_STEP = preload("res://Lucid V1.2/PNG/Flat/16/Signal-2.png")
const ICON_MODE_ARRANGEMENT = preload("res://Lucid V1.2/PNG/Flat/16/List.png")
const ICON_MODE_PIANO = preload("res://Lucid V1.2/PNG/Flat/16/Music-0.png")
const ICON_MODE_ADSR = preload("res://Lucid V1.2/PNG/Flat/16/Signal-0.png")
const ICON_MODE_3D = preload("res://Lucid V1.2/PNG/Flat/16/Stack.png")
const DEFAULT_PARAM_NAME := "Volume"
const PARAM_DISPLAY_NAMES := {
	"Volume": "Volume",
	"Pan": "Pan",
	"Balance": "Balance",
	"Expression": "Expression",
	"Mod": "Modulation",
	"Pitch": "Pitch",
	"CC1": "Modulation (CC1)",
	"CC2": "Breath (CC2)",
	"CC4": "Foot (CC4)",
	"CC5": "Portamento (CC5)",
	"CC7": "Volume (CC7)",
	"CC8": "Balance (CC8)",
	"CC10": "Pan (CC10)",
	"CC11": "Expression (CC11)",
	"CC64": "Sustain (CC64)",
	"CC65": "Portamento (CC65)",
	"CC66": "Sostenuto (CC66)",
	"CC67": "Soft (CC67)",
	"CC68": "Legato (CC68)",
	"CC69": "Hold 2 (CC69)",
	"CC91": "Reverb (CC91)",
	"CC93": "Chorus (CC93)"
}

@export var slot_index: int = 0

var track_selector: OptionButton = null
var mode_button: Button = null
var tab_bar: TabBar = null
var add_clip_button: Button = null
@onready var h_scroll_row: Control = $"HScrollRow"
@onready var h_scroll_collapse_spacer: Control = $"HScrollCollapseSpacer"
@onready var h_scroll_spacer: Control = $"HScrollRow/HScrollSpacer"
@onready var h_scroll: Control = $"HScrollRow/HScrollFrame/HScroll"
@onready var panel_row: Control = $"PanelRow"
@onready var panel_frame: Control = $"PanelRow/PanelFrame"
@onready var panel_spacer: Control = $"PanelRow/PanelSpacer"
@onready var envelope_param_frame: Control = $"PanelRow/PanelSpacer/EnvelopeParamFrame"
@onready var envelope_param_select: OptionButton = $"PanelRow/PanelSpacer/EnvelopeParamFrame/EnvelopeParamSelect"
@onready var envelope_add_button: Button = $"PanelRow/PanelSpacer/EnvelopeAddButton"
@onready var panel_v_scroll: Control = $"PanelRow/PanelRightSpacer/PanelVScroll"
@onready var envelope_lane: Control = $"PanelRow/PanelFrame/EnvelopeLane"
@onready var comment_lane: Control = $"PanelRow/PanelFrame/CommentLane"
@onready var step_lane: Control = $"PanelRow/PanelFrame/StepLane"
@onready var arrangement_lane: Control = $"PanelRow/PanelFrame/ArrangementLane"
@onready var adsr_lane: Control = $"PanelRow/PanelFrame/AdsrLane"
@onready var piano_lane: Control = $"PanelRow/PanelFrame/PianoLane"
@onready var three_d_lane: Control = $"PanelRow/PanelFrame/ThreeDLane"
@onready var roll_frame_row: Control = $"RollFrameRow"
@onready var roll_frame_overlay: Control = $"RollFrameRow/RollFrame/RollFrameOverlay"
@onready var roll_container: Control = $"RollFrameRow/RollFrame/RollClip/RollRow/RollContainer"
@onready var v_scroll: Control = $"RollFrameRow/VScroll"

var project_model: Node = null
var soundfont_manager: Node = null
var active_track: Node = null
var active_track_index: int = 0
var active_clip_index: int = 0
var panel_mode: String = "roll"
var _program_helper: EngineSnapshotBuilder = SNAPSHOT_BUILDER.new()

var piano_roll: Control = null
var notes_model: Node = null
var envelope_model: Node = null

var updating_scrollbars := false
var updating_panel_scroll := false
var suppress_scroll_signal := false
var panel_scroll_y_comment: float = 0.0
var panel_scroll_y_3d: float = -1.0
var panel_scroll_y_arrangement: float = 0.0
var panel_scroll_y_envelope: float = 0.0
var panel_scroll_y_adsr: float = 0.0
var panel_view_height_3d: float = 0.0
var _3d_first_entry := true
var shared_view_beats: int = -1
const H_SCROLL_HIDE_PADDING := 2.0
var h_scroll_default_min_height: float = 16.0
var is_collapsed := false
var _hovered := false
var _keyboard_width := 0.0
var arrangement_pixels_per_beat := -1.0
var arrangement_scroll_x := 0.0
var arrangement_max_x := 0.0
var arrangement_view_width := 0.0
var piano_scroll_x := 0.0
const ARRANGEMENT_ZOOM_STEP := 10.0
const ARRANGEMENT_MIN_PPB := 2.0
const ARRANGEMENT_MAX_PPB := 320.0
const ARRANGEMENT_RESET_PPB := 2.0
const FRAME_COLOR_ACTIVE = Color(0.95, 0.55, 0.2, 0.95)
const FRAME_COLOR_INACTIVE = Color(0.45, 0.45, 0.5, 0.55)
var arrangement_zoom_restore_ppb := -1.0
var focus_highlight := false
const HISTORY_LIMIT := 5
var history: Array = []
var history_index := -1
var history_suppress := false
var envelope_param_names: Array = []
var _updating_track_selector := false
var _updating_tab_bar := false

func _ready() -> void:
	_ensure_roll()
	_init_controls()
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process_input(true)
	_apply_panel_mode()
	_update_panel_mode_label()
	_sync_scrollbars()
	_update_panel_scrollbar()
	_cache_h_scroll_min_height()
	_position_h_scroll_row()
	_update_h_scroll_visibility()
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not resized.is_connected(_on_slot_resized):
		resized.connect(_on_slot_resized)
	_update_focus_frames()
	_record_history(true)
	_refresh_envelope_param_select()

func bind_controls(
	next_track_selector: OptionButton,
	next_mode_button: Button,
	next_tab_bar: TabBar,
	next_add_clip_button: Button
) -> void:
	track_selector = next_track_selector
	mode_button = next_mode_button
	tab_bar = next_tab_bar
	add_clip_button = next_add_clip_button
	_init_controls()
	_refresh_track_selector()
	_refresh_tab_bar()
	_update_panel_mode_label()

func _position_h_scroll_row() -> void:
	if h_scroll_row == null:
		return
	if slot_index == 1:
		move_child(h_scroll_row, get_child_count() - 1)

func _on_slot_resized() -> void:
	_update_h_scroll_visibility(size.y)
	_update_panel_scrollbar()
	if arrangement_lane != null:
		_update_arrangement_scrollbar()
	if panel_mode == "piano":
		_update_piano_scrollbar()
	if panel_mode == "adsr":
		_update_adsr_scrollbar()
	if not suppress_scroll_signal:
		emit_signal("scroll_x_changed", slot_index, get_scroll_x(), get_view_width())

func refresh_layout_metrics() -> void:
	_update_h_scroll_visibility(size.y)
	_update_panel_scrollbar()
	if arrangement_lane != null:
		_update_arrangement_scrollbar()

func update_h_scroll_visibility_for_height(panel_height: float, _allow_unhide: bool = true) -> void:
	_update_h_scroll_visibility(panel_height)

func _update_h_scroll_visibility(panel_height: float = -1.0) -> void:
	if h_scroll_row == null:
		return
	if is_collapsed:
		h_scroll_row.visible = false
		if h_scroll_collapse_spacer != null:
			h_scroll_collapse_spacer.visible = false
			h_scroll_collapse_spacer.custom_minimum_size.y = 0.0
		return
	if panel_mode == "3d" or panel_mode == "envelope":
		_set_h_scroll_collapsed(true)
		if h_scroll_collapse_spacer != null:
			h_scroll_collapse_spacer.visible = false
			h_scroll_collapse_spacer.custom_minimum_size.y = 0.0
		return
	if panel_height < 0.0:
		panel_height = size.y
	if panel_height <= 0.0:
		_set_h_scroll_collapsed(true)
		return
	var close_threshold = h_scroll_default_min_height + H_SCROLL_HIDE_PADDING
	_set_h_scroll_collapsed(panel_height <= close_threshold)

func _cache_h_scroll_min_height() -> void:
	if h_scroll_row == null:
		return
	h_scroll_default_min_height = h_scroll_row.custom_minimum_size.y
	if h_scroll_default_min_height <= 0.0:
		h_scroll_default_min_height = h_scroll_row.size.y
	if h_scroll_default_min_height <= 0.0:
		h_scroll_default_min_height = 16.0
	if h_scroll_collapse_spacer != null:
		h_scroll_collapse_spacer.custom_minimum_size.y = h_scroll_default_min_height

func _set_h_scroll_collapsed(collapsed: bool) -> void:
	if h_scroll_row == null:
		return
	if h_scroll_collapse_spacer != null:
		h_scroll_collapse_spacer.visible = collapsed
		if collapsed:
			h_scroll_collapse_spacer.custom_minimum_size.y = h_scroll_default_min_height
		else:
			h_scroll_collapse_spacer.custom_minimum_size.y = 0.0
	h_scroll_row.visible = not collapsed
	if collapsed:
		if h_scroll_row.custom_minimum_size.y > 0.0:
			h_scroll_row.custom_minimum_size.y = 0.0
	else:
		if not is_equal_approx(h_scroll_row.custom_minimum_size.y, h_scroll_default_min_height):
			h_scroll_row.custom_minimum_size.y = h_scroll_default_min_height

func set_collapsed(collapsed: bool) -> void:
	if is_collapsed == collapsed:
		return
	is_collapsed = collapsed
	custom_minimum_size.y = 0.0
	if collapsed:
		if panel_row != null:
			panel_row.visible = false
		if roll_frame_row != null:
			roll_frame_row.visible = false
		if h_scroll_row != null:
			h_scroll_row.visible = false
		if h_scroll_collapse_spacer != null:
			h_scroll_collapse_spacer.visible = false
			h_scroll_collapse_spacer.custom_minimum_size.y = 0.0
	else:
		_apply_panel_mode()
		_set_h_scroll_collapsed(false)
	if get_parent() is Container:
		(get_parent() as Container).queue_sort()

func _ensure_roll() -> void:
	if roll_container == null:
		return
	if roll_container.get_child_count() == 0:
		piano_roll = PIANO_ROLL_SCENE.instantiate()
		roll_container.add_child(piano_roll)
	else:
		piano_roll = roll_container.get_child(0) as Control
	if piano_roll != null:
		piano_roll.set("enable_local_space_playback", false)
	notes_model = piano_roll.get_node_or_null("NotesModel") if piano_roll else null
	envelope_model = piano_roll.get_node_or_null("EnvelopeModel") if piano_roll else null
	if envelope_lane != null and envelope_lane.has_method("set_from_roll"):
		envelope_lane.call("set_from_roll", piano_roll)
	if envelope_lane != null and envelope_lane.has_signal("content_height_changed"):
		var envelope_height_callable = Callable(self, "_on_envelope_height_changed")
		if not envelope_lane.is_connected("content_height_changed", envelope_height_callable):
			envelope_lane.connect("content_height_changed", envelope_height_callable)
	if comment_lane != null and comment_lane.has_method("set_from_roll"):
		comment_lane.call("set_from_roll", piano_roll)
	if step_lane != null and step_lane.has_method("set_from_roll"):
		step_lane.call("set_from_roll", piano_roll)
	if adsr_lane != null and adsr_lane.has_method("set_from_roll"):
		adsr_lane.call("set_from_roll", piano_roll)
	if h_scroll != null and h_scroll.has_method("set_roll"):
		h_scroll.call("set_roll", piano_roll)
	if v_scroll != null and v_scroll.has_method("set_roll"):
		v_scroll.call("set_roll", piano_roll)
	if piano_roll != null and piano_roll.has_signal("scroll_changed"):
		var callable = Callable(self, "_on_roll_scroll_changed")
		if not piano_roll.is_connected("scroll_changed", callable):
			piano_roll.connect("scroll_changed", callable)
	if piano_roll != null and piano_roll.has_signal("snap_changed"):
		var snap_callable = Callable(self, "_on_roll_snap_changed")
		if not piano_roll.is_connected("snap_changed", snap_callable):
			piano_roll.connect("snap_changed", snap_callable)

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
	if envelope_param_select != null and envelope_param_select.has_signal("item_selected"):
		var param_callable = Callable(self, "_on_envelope_param_selected")
		if not envelope_param_select.is_connected("item_selected", param_callable):
			envelope_param_select.connect("item_selected", param_callable)
	if envelope_add_button != null and envelope_add_button.has_signal("pressed"):
		var add_callable = Callable(self, "_on_envelope_add_pressed")
		if not envelope_add_button.is_connected("pressed", add_callable):
			envelope_add_button.connect("pressed", add_callable)
	if arrangement_lane != null:
		if arrangement_lane.has_signal("clip_selected"):
			var clip_callable = Callable(self, "_on_arrangement_clip_selected")
			if not arrangement_lane.is_connected("clip_selected", clip_callable):
				arrangement_lane.connect("clip_selected", clip_callable)
		if arrangement_lane.has_signal("track_selected"):
			var track_callable = Callable(self, "_on_arrangement_track_selected")
			if not arrangement_lane.is_connected("track_selected", track_callable):
				arrangement_lane.connect("track_selected", track_callable)
		if arrangement_lane.has_signal("content_height_changed"):
			var height_callable = Callable(self, "_on_arrangement_height_changed")
			if not arrangement_lane.is_connected("content_height_changed", height_callable):
				arrangement_lane.connect("content_height_changed", height_callable)
		if arrangement_lane.has_signal("selection_preview"):
			var selection_preview_callable = Callable(self, "_on_arrangement_selection_preview")
			if not arrangement_lane.is_connected("selection_preview", selection_preview_callable):
				arrangement_lane.connect("selection_preview", selection_preview_callable)
		if arrangement_lane.has_signal("selection_committed"):
			var selection_committed_callable = Callable(self, "_on_arrangement_selection_committed")
			if not arrangement_lane.is_connected("selection_committed", selection_committed_callable):
				arrangement_lane.connect("selection_committed", selection_committed_callable)
		if arrangement_lane.has_signal("zoom_request"):
			var zoom_callable = Callable(self, "_on_arrangement_zoom_request")
			if not arrangement_lane.is_connected("zoom_request", zoom_callable):
				arrangement_lane.connect("zoom_request", zoom_callable)
		if arrangement_lane.has_signal("zoom_reset_requested"):
			var reset_callable = Callable(self, "_on_arrangement_zoom_reset")
			if not arrangement_lane.is_connected("zoom_reset_requested", reset_callable):
				arrangement_lane.connect("zoom_reset_requested", reset_callable)
		if arrangement_lane.has_signal("scroll_request"):
			var scroll_callable = Callable(self, "_on_arrangement_scroll_request")
			if not arrangement_lane.is_connected("scroll_request", scroll_callable):
				arrangement_lane.connect("scroll_request", scroll_callable)
	if step_lane != null and step_lane.has_signal("config_changed"):
		var config_callable = Callable(self, "_on_step_config_changed")
		if not step_lane.is_connected("config_changed", config_callable):
			step_lane.connect("config_changed", config_callable)
	if piano_lane != null and piano_lane.has_signal("content_changed"):
		var piano_callable = Callable(self, "_on_piano_content_changed")
		if not piano_lane.is_connected("content_changed", piano_callable):
			piano_lane.connect("content_changed", piano_callable)
	if three_d_lane != null and three_d_lane.has_signal("camera_changed"):
		var camera_callable = Callable(self, "_on_three_d_camera_changed")
		if not three_d_lane.is_connected("camera_changed", camera_callable):
			three_d_lane.connect("camera_changed", camera_callable)
	if three_d_lane != null and three_d_lane.has_signal("resized"):
		var resize_callable = Callable(self, "_on_three_d_lane_resized")
		if not three_d_lane.is_connected("resized", resize_callable):
			three_d_lane.connect("resized", resize_callable)

func set_project_model(next_model: Node) -> void:
	if project_model != null and project_model.has_signal("changed"):
		var callable = Callable(self, "_on_project_model_changed")
		if project_model.is_connected("changed", callable):
			project_model.disconnect("changed", callable)
	project_model = next_model
	active_track = null
	active_track_index = 0
	active_clip_index = 0
	if project_model != null and project_model.has_signal("changed"):
		project_model.connect("changed", Callable(self, "_on_project_model_changed"))
	if arrangement_lane != null and arrangement_lane.has_method("set_project_model"):
		arrangement_lane.call("set_project_model", project_model)
	_refresh_track_selector()
	if project_model != null and project_model.tracks.size() > 0:
		_set_active_track_index(active_track_index)

func set_soundfont_manager(manager: Node) -> void:
	soundfont_manager = manager
	_refresh_adsr_preset_source()
	_update_panel_scrollbar()

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

func set_beats_per_measure(value: int) -> void:
	if piano_roll == null:
		return
	var beats = max(1, value)
	if int(piano_roll.get("beats_per_measure")) == beats:
		return
	piano_roll.set("beats_per_measure", beats)
	if piano_roll.has_method("_apply_config"):
		piano_roll.call("_apply_config")
	_sync_roll_params_to_lanes()

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
	if arrangement_lane != null:
		_update_arrangement_scrollbar()

func set_shared_scroll_suppressed(enabled: bool) -> void:
	suppress_scroll_signal = enabled

func set_scroll_x(value: float, from_shared: bool = false) -> void:
	if panel_mode == "piano":
		piano_scroll_x = value
		if piano_lane != null and piano_lane.has_method("set_scroll_x"):
			piano_lane.call("set_scroll_x", piano_scroll_x)
		if not suppress_scroll_signal:
			emit_signal("scroll_x_changed", slot_index, piano_scroll_x, get_view_width())
		return
	if piano_roll == null:
		return
	var prev = suppress_scroll_signal
	if from_shared:
		suppress_scroll_signal = true
	piano_roll.call("set_scroll_x", value)
	suppress_scroll_signal = prev

func get_scroll_x() -> float:
	if panel_mode == "piano":
		return piano_scroll_x
	if piano_roll == null:
		return 0.0
	return float(piano_roll.call("get_scroll_x"))

func get_view_width() -> float:
	if piano_roll == null:
		return 0.0
	var roll_panel = piano_roll.get_node_or_null("RollPanel") as Control
	var roll_width = roll_panel.size.x if roll_panel else 0.0
	if roll_frame_row != null and roll_frame_row.visible:
		return roll_width
	if panel_frame != null and panel_frame.size.x > 0.0:
		return panel_frame.size.x
	return roll_width

func get_active_clip() -> Node:
	if active_track == null:
		return null
	return _get_or_create_clip_for_track(active_track, active_clip_index)

func get_roll() -> Control:
	return piano_roll

func handle_midi_note(pitch: int, is_note_on: bool) -> void:
	if piano_lane == null or panel_mode != "piano":
		return
	if is_note_on and piano_lane.has_method("note_on"):
		piano_lane.call("note_on", pitch)
	elif not is_note_on and piano_lane.has_method("note_off"):
		piano_lane.call("note_off", pitch)

func get_notes_pitch_range() -> Dictionary:
	if notes_model == null or notes_model.notes.is_empty():
		return {}
	var min_pitch := 100000
	var max_pitch := -100000
	for note in notes_model.notes:
		var pitch = int(note.get("pitch", 0))
		if pitch < min_pitch:
			min_pitch = pitch
		if pitch > max_pitch:
			max_pitch = pitch
	if max_pitch < min_pitch:
		return {}
	return {"min": min_pitch, "max": max_pitch}

func get_roll_pitch_bounds() -> Dictionary:
	if piano_roll == null:
		return {}
	return {
		"min": int(piano_roll.get("min_pitch")),
		"max": int(piano_roll.get("max_pitch"))
	}

func get_step_pitch() -> int:
	if step_lane != null:
		return int(step_lane.get("step_pitch"))
	return 60

func is_step_lane_visible() -> bool:
	return step_lane != null and step_lane.visible

func center_roll_on_pitch(pitch: float, retries: int = 2) -> void:
	if piano_roll == null:
		return
	var key_height = float(piano_roll.get("key_height"))
	if key_height <= 0.0:
		return
	var min_pitch = int(piano_roll.get("min_pitch"))
	var max_pitch = int(piano_roll.get("max_pitch"))
	if max_pitch < min_pitch:
		return
	var clamped_pitch = clamp(pitch, float(min_pitch), float(max_pitch))
	var roll_panel = piano_roll.get_node_or_null("RollPanel") as Control
	var view_height = roll_panel.size.y if roll_panel != null else 0.0
	if view_height <= 0.0:
		if retries > 0:
			call_deferred("center_roll_on_pitch", pitch, retries - 1)
		return
	var pitch_y = (float(max_pitch) - clamped_pitch) * key_height + (key_height * 0.5)
	var target_scroll = pitch_y - (view_height * 0.5)
	piano_roll.call("set_scroll_y", target_scroll)

func align_roll_top_to_pitch(pitch: float) -> void:
	if piano_roll == null:
		return
	var key_height = float(piano_roll.get("key_height"))
	if key_height <= 0.0:
		return
	var min_pitch = int(piano_roll.get("min_pitch"))
	var max_pitch = int(piano_roll.get("max_pitch"))
	if max_pitch < min_pitch:
		return
	var clamped_pitch = clamp(pitch, float(min_pitch), float(max_pitch))
	var pitch_y = (float(max_pitch) - clamped_pitch) * key_height
	piano_roll.call("set_scroll_y", pitch_y)

func get_roll_params() -> Dictionary:
	if piano_roll == null:
		return {}
	if panel_mode == "arrangement":
		return {
			"ppb": float(arrangement_pixels_per_beat if arrangement_pixels_per_beat > 0.0 else ARRANGEMENT_RESET_PPB),
			"beats": int(piano_roll.get("visible_beats")),
			"scroll_x": arrangement_scroll_x,
			"view_width": arrangement_view_width
		}
	return {
		"ppb": float(piano_roll.get("pixels_per_beat")),
		"beats": int(piano_roll.get("visible_beats")),
		"scroll_x": float(piano_roll.call("get_scroll_x")),
		"view_width": get_view_width()
	}

func get_keyboard_width() -> float:
	if piano_roll != null and piano_roll.has_method("get_keyboard_width"):
		return float(piano_roll.call("get_keyboard_width"))
	return 0.0

func get_roll_right_padding() -> float:
	return v_scroll.size.x if v_scroll != null else 0.0

func get_active_clip_length() -> float:
	var clip = get_active_clip()
	if clip == null:
		return 0.0
	return float(clip.clip_length_beats)

func set_roll_playhead_time(time_beats: float) -> void:
	if piano_roll == null:
		return
	if piano_roll.has_method("set_playhead_time"):
		piano_roll.call("set_playhead_time", time_beats)

func set_arrangement_playhead_time(time_beats: float) -> void:
	if arrangement_lane == null:
		return
	if arrangement_lane.has_method("set_playhead_time"):
		arrangement_lane.call("set_playhead_time", time_beats)

func get_roll_playhead_time() -> float:
	if piano_roll != null and piano_roll.has_method("get_playhead_time_beats"):
		return float(piano_roll.call("get_playhead_time_beats"))
	return 0.0

func get_arrangement_playhead_time() -> float:
	if arrangement_lane != null and arrangement_lane.has_method("get_playhead_time_beats"):
		return float(arrangement_lane.call("get_playhead_time_beats"))
	return -1.0

func get_panel_mode() -> String:
	return panel_mode

func set_panel_mode(mode: String) -> void:
	if panel_mode == mode:
		return
	panel_mode = mode
	_apply_panel_mode()
	_record_history(true)

func set_track_name(label: String) -> void:
	if active_track == null:
		return
	if active_track.has_method("set_track_name"):
		active_track.call("set_track_name", label)
	else:
		active_track.track_name = label
		if active_track.has_signal("changed"):
			active_track.emit_signal("changed")
	_refresh_track_selector()

func set_clip_name(label: String) -> void:
	var clip = get_active_clip()
	if clip == null:
		return
	if clip.has_method("set_clip_name"):
		clip.call("set_clip_name", label)
	else:
		clip.clip_name = label
		if clip.has_signal("changed"):
			clip.emit_signal("changed")
	_refresh_tab_bar()

func _on_track_selected(index: int) -> void:
	if _updating_track_selector:
		return
	_emit_focus()
	_set_active_track_index(index)

func _on_tab_changed(index: int) -> void:
	if _updating_tab_bar:
		return
	_emit_focus()
	_set_active_clip_index(index)

func _on_add_clip_pressed() -> void:
	_emit_focus()
	if active_track == null:
		return
	var next_index = active_track.clips.size() + 1
	var label = "Clip %d" % next_index
	var length_beats = _default_clip_length_beats()
	_create_clip_for_track(active_track, label, length_beats)
	_refresh_tab_bar()
	_set_active_clip_index(active_track.clips.size() - 1)

func add_clip_for_track(track_index: int) -> void:
	if track_index < 0:
		return
	if track_index != active_track_index:
		select_track(track_index)
	_on_add_clip_pressed()

func _on_mode_pressed() -> void:
	_emit_focus()
	var next_mode = "roll"
	if panel_mode == "roll":
		next_mode = "envelope"
	elif panel_mode == "envelope":
		next_mode = "adsr"
	elif panel_mode == "adsr":
		next_mode = "comment"
	elif panel_mode == "comment":
		next_mode = "step"
	elif panel_mode == "step":
		next_mode = "arrangement"
	elif panel_mode == "arrangement":
		next_mode = "piano"
	elif panel_mode == "piano":
		next_mode = "3d"
	else:
		next_mode = "roll"
	set_panel_mode(next_mode)

func _on_arrangement_clip_selected(track_index: int, clip_index: int) -> void:
	_emit_focus()
	_set_active_track_index(track_index)
	_set_active_clip_index(clip_index)

func _on_arrangement_track_selected(track_index: int) -> void:
	_emit_focus()
	_set_active_track_index(track_index)

func _on_arrangement_height_changed() -> void:
	_update_panel_scrollbar()

func _on_arrangement_selection_preview(start_beats: float, end_beats: float) -> void:
	emit_signal("arrangement_selection_preview", slot_index, start_beats, end_beats)

func _on_arrangement_selection_committed(start_beats: float, end_beats: float) -> void:
	emit_signal("arrangement_selection_committed", slot_index, start_beats, end_beats)

func _on_arrangement_zoom_request(local_x: float, direction: int) -> void:
	if arrangement_lane == null:
		return
	if arrangement_pixels_per_beat <= 0.0:
		if piano_roll != null:
			arrangement_pixels_per_beat = max(1.0, float(piano_roll.get("pixels_per_beat")) * 0.25)
		else:
			arrangement_pixels_per_beat = ARRANGEMENT_RESET_PPB
	var old_ppb = arrangement_pixels_per_beat
	var delta = ARRANGEMENT_ZOOM_STEP * (1.0 if direction >= 0 else -1.0)
	arrangement_pixels_per_beat = clamp(old_ppb + delta, ARRANGEMENT_MIN_PPB, ARRANGEMENT_MAX_PPB)
	if is_equal_approx(old_ppb, arrangement_pixels_per_beat):
		return
	var anchor_beat = 0.0
	if old_ppb > 0.0:
		anchor_beat = (arrangement_scroll_x + local_x) / old_ppb
	arrangement_scroll_x = max(0.0, anchor_beat * arrangement_pixels_per_beat - local_x)
	_update_arrangement_scrollbar()
	_record_history(false)

func _on_arrangement_zoom_reset(local_x: float) -> void:
	if arrangement_lane == null:
		return
	var old_ppb = arrangement_pixels_per_beat
	if arrangement_zoom_restore_ppb > 0.0:
		arrangement_pixels_per_beat = arrangement_zoom_restore_ppb
		arrangement_zoom_restore_ppb = -1.0
	else:
		arrangement_pixels_per_beat = ARRANGEMENT_RESET_PPB
	if arrangement_view_width > 0.0 and old_ppb > 0.0:
		var anchor_beat = (arrangement_scroll_x + local_x) / old_ppb
		arrangement_scroll_x = max(0.0, anchor_beat * arrangement_pixels_per_beat - local_x)
	else:
		arrangement_scroll_x = 0.0
	_update_arrangement_scrollbar()
	_record_history(false)

func _on_arrangement_scroll_request(delta_x: float, delta_y: float) -> void:
	if panel_mode != "arrangement":
		return
	if delta_x != 0.0:
		arrangement_scroll_x = clamp(arrangement_scroll_x + delta_x, 0.0, arrangement_max_x)
		if h_scroll != null:
			updating_scrollbars = true
			h_scroll.value = arrangement_scroll_x
			h_scroll.queue_redraw()
			updating_scrollbars = false
		if arrangement_lane != null and arrangement_lane.has_method("set_view"):
			arrangement_lane.call("set_view", arrangement_scroll_x, arrangement_view_width)
		if not suppress_scroll_signal:
			emit_signal("scroll_x_changed", slot_index, arrangement_scroll_x, arrangement_view_width)
	if delta_y != 0.0:
		if panel_row == null or panel_v_scroll == null or arrangement_lane == null:
			return
		var view_height = arrangement_lane.size.y if arrangement_lane.size.y > 0.0 else panel_row.size.y
		var content_height = 0.0
		if arrangement_lane.has_method("get_content_height"):
			content_height = float(arrangement_lane.call("get_content_height"))
		var max_y = max(0.0, content_height - view_height)
		panel_scroll_y_arrangement = clamp(panel_scroll_y_arrangement + delta_y, 0.0, max_y)
		updating_panel_scroll = true
		panel_v_scroll.value = panel_scroll_y_arrangement
		panel_v_scroll.queue_redraw()
		updating_panel_scroll = false
		_apply_panel_scroll()

func _on_three_d_lane_resized() -> void:
	call_deferred("_update_panel_scrollbar")

func _on_three_d_camera_changed() -> void:
	if panel_mode != "3d":
		return
	_record_history(false)

func _on_step_config_changed() -> void:
	if panel_mode != "step":
		return
	_record_history(false)

func _on_piano_content_changed() -> void:
	if panel_mode != "piano":
		return
	_update_piano_scrollbar()

func _set_active_track_index(index: int) -> void:
	if project_model == null:
		return
	if index < 0 or index >= project_model.tracks.size():
		return
	active_track_index = index
	active_track = project_model.tracks[index]
	if adsr_lane != null and adsr_lane.has_method("set_track"):
		adsr_lane.call("set_track", active_track)
	_refresh_adsr_preset_source()
	_update_panel_scrollbar()
	_refresh_track_selector()
	_refresh_tab_bar()
	if tab_bar != null:
		_set_active_clip_index(clamp(active_clip_index, 0, tab_bar.get_tab_count() - 1))
	else:
		_set_active_clip_index(active_clip_index)
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
			_updating_tab_bar = true
			tab_bar.current_tab = clamped
			_updating_tab_bar = false
	if piano_roll != null and piano_roll.has_method("set_clip_model"):
		piano_roll.call("set_clip_model", clip)
	_apply_view_beats()
	_sync_roll_params_to_lanes()
	_sync_scrollbars()
	_update_panel_scrollbar()
	if arrangement_lane != null and arrangement_lane.has_method("set_selection"):
		arrangement_lane.call("set_selection", active_track_index, active_clip_index)
	_refresh_envelope_param_select()
	emit_signal("clip_changed", slot_index, active_clip_index)
	_record_history(false)

func _refresh_track_selector() -> void:
	if track_selector == null or project_model == null:
		return
	_updating_track_selector = true
	track_selector.clear()
	for i in range(project_model.tracks.size()):
		var track = project_model.tracks[i]
		var label = "Track %d" % (i + 1)
		if track != null:
			label = str(track.track_name)
		track_selector.add_item(label, i)
	if project_model.tracks.size() > 0:
		track_selector.select(clamp(active_track_index, 0, project_model.tracks.size() - 1))
	_updating_track_selector = false

func _refresh_tab_bar() -> void:
	if tab_bar == null:
		return
	_updating_tab_bar = true
	while tab_bar.get_tab_count() > 0:
		tab_bar.remove_tab(0)
	if active_track == null:
		_updating_tab_bar = false
		return
	if active_track.clips.is_empty():
		var length_beats = _default_clip_length_beats()
		_create_clip_for_track(active_track, "Clip 1", length_beats)
	for i in range(active_track.clips.size()):
		var clip = active_track.clips[i]
		var label = "Clip %d" % (i + 1)
		if clip != null and str(clip.clip_name) != "":
			label = str(clip.clip_name)
		tab_bar.add_tab(label)
	var clamped = clamp(active_clip_index, 0, tab_bar.get_tab_count() - 1)
	tab_bar.current_tab = clamped
	_updating_tab_bar = false

func _get_or_create_clip_for_track(track: Node, clip_index: int) -> Node:
	if track == null:
		return null
	while track.clips.size() <= clip_index:
		var next_name = "Clip %d" % (track.clips.size() + 1)
		var length_beats = _default_clip_length_beats()
		_create_clip_for_track(track, next_name, length_beats)
	var clip = track.clips[clip_index]
	if clip == null:
		var fallback_name = "Clip %d" % (clip_index + 1)
		var fallback_length = _default_clip_length_beats()
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
	if track.has_method("add_clip_unplaced"):
		track.call("add_clip_unplaced", clip)
	return clip

func _default_clip_length_beats() -> float:
	if piano_roll != null:
		var beats_per_measure = int(piano_roll.get("beats_per_measure"))
		if beats_per_measure > 0:
			return float(beats_per_measure * 4)
	return 16.0

func _apply_view_beats() -> void:
	if piano_roll == null:
		return
	var clip_length = get_active_clip_length()
	var view_beats = int(ceil(max(1.0, clip_length)))
	var should_sync = true
	if shared_view_beats > 0:
		view_beats = int(ceil(max(float(shared_view_beats), clip_length)))
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
	if panel_mode == "piano":
		_update_piano_scrollbar()
		return
	if piano_roll == null:
		return
	_sync_roll_params_to_lanes()
	if panel_mode == "arrangement":
		_update_arrangement_scrollbar()
		return
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
	_keyboard_width = keyboard_width
	if h_scroll_spacer != null:
		h_scroll_spacer.custom_minimum_size = Vector2(max(0.0, keyboard_width), 0.0)
	_update_panel_spacer()
	if h_scroll != null and panel_mode != "arrangement":
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
	var min_pitch = int(piano_roll.get("min_pitch"))
	var max_pitch = int(piano_roll.get("max_pitch"))
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
	if adsr_lane != null:
		if adsr_lane.has_method("set_roll_params"):
			adsr_lane.call("set_roll_params", ppb, beats, beats_per_measure)
		elif adsr_lane.has_method("set_from_roll"):
			adsr_lane.call("set_from_roll", piano_roll)
	if step_lane != null:
		step_lane.set("pixels_per_beat", ppb)
		step_lane.set("visible_beats", beats)
		step_lane.set("beats_per_measure", beats_per_measure)
		step_lane.queue_redraw()
	if arrangement_lane != null:
		if arrangement_pixels_per_beat <= 0.0:
			arrangement_pixels_per_beat = max(1.0, ppb * 0.25)
		arrangement_lane.set("pixels_per_beat", arrangement_pixels_per_beat)
		arrangement_lane.set("beats_per_measure", beats_per_measure)
		if arrangement_lane.has_method("set_pitch_range"):
			arrangement_lane.call("set_pitch_range", min_pitch, max_pitch)
		arrangement_lane.queue_redraw()

func _update_envelope_view(scroll_x: float, view_width: float) -> void:
	if piano_roll == null:
		return
	if envelope_lane != null and envelope_lane.has_method("set_view"):
		envelope_lane.call("set_view", scroll_x, view_width)
	if comment_lane != null and comment_lane.has_method("set_view"):
		comment_lane.call("set_view", scroll_x, view_width)
	if step_lane != null and step_lane.has_method("set_view"):
		step_lane.call("set_view", scroll_x, view_width)
	if adsr_lane != null and adsr_lane.has_method("set_view"):
		adsr_lane.call("set_view", scroll_x, view_width)
	if arrangement_lane != null and arrangement_lane.has_method("set_view"):
		var use_scroll = arrangement_scroll_x if panel_mode == "arrangement" else scroll_x
		var use_width = arrangement_view_width if panel_mode == "arrangement" else view_width
		arrangement_lane.call("set_view", use_scroll, use_width)

func _on_h_scroll_changed(value: float) -> void:
	if updating_scrollbars:
		return
	if panel_mode == "piano":
		var content_width = 0.0
		if piano_lane != null and piano_lane.has_method("get_content_width"):
			content_width = float(piano_lane.call("get_content_width"))
		var view_width = piano_lane.size.x if piano_lane != null else 0.0
		var max_x = max(0.0, content_width - view_width)
		piano_scroll_x = clamp(value, 0.0, max_x)
		if piano_lane != null and piano_lane.has_method("set_scroll_x"):
			piano_lane.call("set_scroll_x", piano_scroll_x)
		if not suppress_scroll_signal:
			emit_signal("scroll_x_changed", slot_index, piano_scroll_x, view_width)
		_record_history(false)
		return
	if piano_roll == null:
		return
	if panel_mode == "arrangement":
		arrangement_scroll_x = clamp(value, 0.0, arrangement_max_x)
		if arrangement_lane != null and arrangement_lane.has_method("set_view"):
			arrangement_lane.call("set_view", arrangement_scroll_x, arrangement_view_width)
		if not suppress_scroll_signal:
			emit_signal("scroll_x_changed", slot_index, arrangement_scroll_x, arrangement_view_width)
		_record_history(false)
		return
	piano_roll.call("set_scroll_x", value)
	var roll_panel = piano_roll.get_node_or_null("RollPanel") as Control
	var roll_view_width = roll_panel.size.x if roll_panel else 0.0
	_update_envelope_view(value, roll_view_width)
	_record_history(false)

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
		emit_signal("scroll_x_changed", slot_index, scroll_x, get_view_width())
	if panel_mode != "arrangement":
		_record_history(false)

func _on_roll_snap_changed(enabled: bool, step: float) -> void:
	emit_signal("snap_changed", slot_index, enabled, step)

func _on_panel_v_scroll_changed(value: float) -> void:
	if updating_panel_scroll:
		return
	if panel_mode != "comment" and panel_mode != "3d" and panel_mode != "arrangement" and panel_mode != "adsr":
		return
	_set_current_panel_scroll_y(value)
	_apply_panel_scroll()
	_record_history(false)

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
	if envelope_lane != null:
		var next_scroll_env = _current_panel_scroll_y() if panel_mode == "envelope" else 0.0
		if envelope_lane.has_method("set_view_scroll_y"):
			envelope_lane.call("set_view_scroll_y", next_scroll_env)
	if arrangement_lane != null:
		var next_scroll_arr = _current_panel_scroll_y() if panel_mode == "arrangement" else 0.0
		if arrangement_lane.has_method("set_view_scroll_y"):
			arrangement_lane.call("set_view_scroll_y", next_scroll_arr)
		if panel_mode == "arrangement":
			var clamped = float(arrangement_lane.get("view_scroll_y"))
			if not is_equal_approx(clamped, next_scroll_arr):
				panel_scroll_y_arrangement = clamped
				if panel_v_scroll != null:
					updating_panel_scroll = true
					panel_v_scroll.value = clamped
					updating_panel_scroll = false
	if adsr_lane != null:
		var next_scroll_adsr = _current_panel_scroll_y() if panel_mode == "adsr" else 0.0
		if adsr_lane.has_method("set_view_scroll_y"):
			adsr_lane.call("set_view_scroll_y", next_scroll_adsr)

func _update_panel_scrollbar() -> void:
	if panel_v_scroll == null or panel_row == null:
		return
	var view_height = panel_row.size.y
	if panel_mode == "3d" and panel_frame != null and panel_frame.size.y > 0.0:
		view_height = panel_frame.size.y
	if panel_mode == "arrangement" and arrangement_lane != null and arrangement_lane.size.y > 0.0:
		view_height = arrangement_lane.size.y
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
	var is_envelope = panel_mode == "envelope" and envelope_lane != null
	var is_adsr = panel_mode == "adsr" and adsr_lane != null
	var is_scrollable = is_comment or is_3d or is_arrangement or is_envelope or is_adsr
	var content_height = 0.0
	if is_comment and comment_lane.has_method("get_content_height"):
		content_height = float(comment_lane.call("get_content_height"))
	elif is_3d and three_d_lane.has_method("get_content_height"):
		content_height = float(three_d_lane.call("get_content_height"))
	elif is_arrangement and arrangement_lane.has_method("get_content_height"):
		content_height = float(arrangement_lane.call("get_content_height"))
	elif is_envelope and envelope_lane.has_method("get_content_height"):
		content_height = float(envelope_lane.call("get_content_height"))
	elif is_adsr and adsr_lane.has_method("get_content_height"):
		content_height = float(adsr_lane.call("get_content_height"))
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
	if panel_mode == "envelope":
		return panel_scroll_y_envelope
	if panel_mode == "adsr":
		return panel_scroll_y_adsr
	return 0.0

func _set_current_panel_scroll_y(value: float) -> void:
	if panel_mode == "comment":
		panel_scroll_y_comment = value
	elif panel_mode == "3d":
		panel_scroll_y_3d = value
	elif panel_mode == "arrangement":
		panel_scroll_y_arrangement = value
	elif panel_mode == "envelope":
		panel_scroll_y_envelope = value
	elif panel_mode == "adsr":
		panel_scroll_y_adsr = value

func _apply_panel_mode() -> void:
	if roll_frame_row != null:
		roll_frame_row.visible = panel_mode == "roll"
	if panel_row != null:
		panel_row.visible = panel_mode != "roll"
	if envelope_lane != null:
		envelope_lane.visible = panel_mode == "envelope"
	if adsr_lane != null:
		adsr_lane.visible = panel_mode == "adsr"
	if comment_lane != null:
		comment_lane.visible = panel_mode == "comment"
	if step_lane != null:
		step_lane.visible = panel_mode == "step"
	if arrangement_lane != null:
		arrangement_lane.visible = panel_mode == "arrangement"
	if piano_lane != null:
		piano_lane.visible = panel_mode == "piano"
	if three_d_lane != null:
		three_d_lane.visible = panel_mode == "3d"
	_update_envelope_param_visibility()
	_update_panel_mode_label()
	_update_panel_spacer()
	_update_panel_scrollbar()
	if panel_mode == "3d":
		if _3d_first_entry:
			_3d_first_entry = false
			panel_scroll_y_3d = -1.0
		call_deferred("_update_panel_scrollbar")
	_update_h_scroll_visibility(size.y)
	if panel_mode == "arrangement":
		_update_arrangement_scrollbar()
	if panel_mode == "adsr":
		_update_adsr_scrollbar()
	if panel_mode == "piano":
		_update_piano_scrollbar()
	if not suppress_scroll_signal:
		emit_signal("scroll_x_changed", slot_index, get_scroll_x(), get_view_width())

func _update_panel_mode_label() -> void:
	if mode_button == null:
		return
	mode_button.text = ""
	if panel_mode == "roll":
		mode_button.icon = ICON_MODE_ROLL
	elif panel_mode == "comment":
		mode_button.icon = ICON_MODE_COMMENT
	elif panel_mode == "step":
		mode_button.icon = ICON_MODE_STEP
	elif panel_mode == "arrangement":
		mode_button.icon = ICON_MODE_ARRANGEMENT
	elif panel_mode == "piano":
		mode_button.icon = ICON_MODE_PIANO
	elif panel_mode == "adsr":
		mode_button.icon = ICON_MODE_ADSR
	elif panel_mode == "3d":
		mode_button.icon = ICON_MODE_3D
	else:
		mode_button.icon = ICON_MODE_ENVELOPE

func _update_panel_spacer() -> void:
	var spacer_width = _keyboard_width if panel_mode == "comment" or panel_mode == "envelope" or panel_mode == "step" else 0.0
	if panel_spacer != null:
		panel_spacer.custom_minimum_size = Vector2(max(0.0, spacer_width), 0.0)
	if envelope_param_frame != null:
		var max_width = max(0.0, spacer_width)
		envelope_param_frame.custom_minimum_size.x = min(80.0, max_width)
		envelope_param_frame.custom_minimum_size.y = 24.0
	if envelope_param_select != null:
		envelope_param_select.clip_text = true
		envelope_param_select.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if envelope_add_button != null:
		envelope_add_button.custom_minimum_size = Vector2(24.0, 24.0)
	if arrangement_lane != null:
		arrangement_lane.set("label_width", max(0.0, _keyboard_width))

func _update_envelope_param_visibility() -> void:
	if envelope_param_frame == null:
		return
	envelope_param_frame.visible = panel_mode == "envelope"
	if envelope_add_button != null:
		envelope_add_button.visible = panel_mode == "envelope"

func _param_display_name(param_name: String) -> String:
	if PARAM_DISPLAY_NAMES.has(param_name):
		return String(PARAM_DISPLAY_NAMES[param_name])
	var normalized = param_name.strip_edges()
	if normalized.begins_with("cc") or normalized.begins_with("CC"):
		var digits = normalized.replace("cc", "").replace("CC", "")
		var cc_num = digits.to_int()
		var key = "CC%d" % cc_num
		if PARAM_DISPLAY_NAMES.has(key):
			return String(PARAM_DISPLAY_NAMES[key])
		return "CC%d" % cc_num
	return normalized

func get_param_display_name(param_name: String) -> String:
	return _param_display_name(param_name)

func _refresh_envelope_param_select() -> void:
	if envelope_param_select == null:
		return
	var params: Array = []
	var current = DEFAULT_PARAM_NAME
	if envelope_model != null:
		if envelope_model.has_method("get_param_names"):
			params = envelope_model.call("get_param_names")
		if envelope_model.has_method("get_current_param"):
			current = String(envelope_model.call("get_current_param"))
	if params.is_empty():
		params = [DEFAULT_PARAM_NAME]
	params.sort()
	var names_changed = params.size() != envelope_param_names.size()
	if not names_changed:
		for i in range(params.size()):
			if String(params[i]) != String(envelope_param_names[i]):
				names_changed = true
				break
	if names_changed:
		envelope_param_select.clear()
		envelope_param_names = []
		for i in range(params.size()):
			var param_name = String(params[i])
			var label = _param_display_name(param_name)
			envelope_param_select.add_item(label)
			envelope_param_select.set_item_metadata(i, param_name)
			envelope_param_names.append(param_name)
	var selected_index := -1
	for i in range(envelope_param_names.size()):
		if String(envelope_param_names[i]) == current:
			selected_index = i
			break
	if selected_index < 0 and envelope_param_select.item_count > 0:
		selected_index = 0
	if selected_index >= 0:
		envelope_param_select.select(selected_index)
	if selected_index >= 0:
		var selected_param = String(envelope_param_select.get_item_metadata(selected_index))
		envelope_param_select.tooltip_text = _param_display_name(selected_param)

func select_envelope_param(param_name: String) -> void:
	if envelope_model == null:
		return
	if envelope_model.has_method("set_current_param"):
		envelope_model.call("set_current_param", param_name)
	_refresh_envelope_param_select()

func _on_envelope_param_selected(index: int) -> void:
	if envelope_model == null or envelope_param_select == null:
		return
	var param = envelope_param_select.get_item_metadata(index)
	if param == null:
		return
	if envelope_model.has_method("set_current_param"):
		envelope_model.call("set_current_param", String(param))
	envelope_param_select.tooltip_text = _param_display_name(String(param))
	_refresh_envelope_param_select()

func _on_envelope_add_pressed() -> void:
	if envelope_model == null:
		return
	var existing: Array = []
	if envelope_model.has_method("get_param_names"):
		existing = envelope_model.call("get_param_names")
	var index := 1
	var param_name := "Param %d" % index
	while existing.has(param_name):
		index += 1
		param_name = "Param %d" % index
	if envelope_model.has_method("ensure_param"):
		envelope_model.call("ensure_param", param_name)
	if envelope_model.has_method("set_current_param"):
		envelope_model.call("set_current_param", param_name)
	_refresh_envelope_param_select()

func _on_envelope_height_changed() -> void:
	if panel_mode == "envelope":
		_update_panel_scrollbar()

func _update_arrangement_scrollbar() -> void:
	if arrangement_lane == null:
		return
	if arrangement_pixels_per_beat <= 0.0:
		if piano_roll != null:
			arrangement_pixels_per_beat = max(1.0, float(piano_roll.get("pixels_per_beat")) * 0.25)
		else:
			arrangement_pixels_per_beat = 30.0
	arrangement_lane.set("pixels_per_beat", arrangement_pixels_per_beat)
	var label_width = float(arrangement_lane.get("label_width"))
	var lane_width = max(0.0, arrangement_lane.size.x - label_width)
	arrangement_view_width = lane_width
	var content_beats = 0.0
	if arrangement_lane.has_method("get_content_length_beats"):
		content_beats = float(arrangement_lane.call("get_content_length_beats"))
	var target_beats = max(0.0, content_beats * 2.0)
	var content_width = target_beats * max(0.0, arrangement_pixels_per_beat)
	arrangement_max_x = max(0.0, content_width - arrangement_view_width)
	arrangement_scroll_x = clamp(arrangement_scroll_x, 0.0, arrangement_max_x)
	if panel_mode == "arrangement" and h_scroll != null:
		updating_scrollbars = true
		h_scroll.min_value = 0.0
		h_scroll.max_value = arrangement_max_x
		h_scroll.page = max(arrangement_view_width, 0.0)
		h_scroll.value = arrangement_scroll_x
		h_scroll.visible = true
		h_scroll.queue_redraw()
		updating_scrollbars = false
	if arrangement_lane.has_method("set_view"):
		arrangement_lane.call("set_view", arrangement_scroll_x, arrangement_view_width)
	if panel_mode == "arrangement" and not suppress_scroll_signal:
		emit_signal("scroll_x_changed", slot_index, arrangement_scroll_x, arrangement_view_width)

func _update_piano_scrollbar() -> void:
	if piano_lane == null:
		return
	var view_width = piano_lane.size.x
	var content_width = 0.0
	if piano_lane.has_method("get_content_width"):
		content_width = float(piano_lane.call("get_content_width"))
	var max_x = max(0.0, content_width - view_width)
	piano_scroll_x = clamp(piano_scroll_x, 0.0, max_x)
	if h_scroll_spacer != null:
		h_scroll_spacer.custom_minimum_size = Vector2(0.0, 0.0)
	if h_scroll != null:
		updating_scrollbars = true
		h_scroll.min_value = 0.0
		h_scroll.max_value = max_x
		h_scroll.page = max(view_width, 0.0)
		h_scroll.value = piano_scroll_x
		h_scroll.visible = true
		h_scroll.queue_redraw()
		updating_scrollbars = false
	if piano_lane.has_method("set_scroll_x"):
		piano_lane.call("set_scroll_x", piano_scroll_x)
	if not suppress_scroll_signal:
		emit_signal("scroll_x_changed", slot_index, piano_scroll_x, view_width)

func _update_adsr_scrollbar() -> void:
	if piano_roll == null or h_scroll == null:
		return
	var roll_panel = piano_roll.get_node_or_null("RollPanel") as Control
	var view_width = roll_panel.size.x if roll_panel else 0.0
	var scroll_x = float(piano_roll.call("get_scroll_x"))
	var max_x = float(piano_roll.call("get_max_scroll_x"))
	updating_scrollbars = true
	h_scroll.min_value = 0.0
	h_scroll.max_value = max_x
	h_scroll.page = max(view_width, 0.0)
	h_scroll.value = clamp(scroll_x, 0.0, max_x)
	h_scroll.visible = true
	h_scroll.queue_redraw()
	updating_scrollbars = false
	_update_envelope_view(scroll_x, view_width)

func _refresh_adsr_preset_source() -> void:
	if adsr_lane == null:
		return
	var player: Node = null
	if soundfont_manager != null and soundfont_manager.has_method("get_route_for_track"):
		var route = soundfont_manager.call("get_route_for_track", active_track_index, active_track)
		if route is Dictionary:
			player = route.get("player")
	var program = _resolve_track_program_index()
	if adsr_lane.has_method("set_preset_source"):
		adsr_lane.call("set_preset_source", player, program)

func _resolve_track_program_index() -> int:
	if active_track == null:
		return 0
	var label := ""
	if active_track.has_method("get"):
		label = str(active_track.get("track_name"))
	elif "track_name" in active_track:
		label = str(active_track.track_name)
	if _program_helper != null and _program_helper.has_method("program_index_from_label"):
		return int(_program_helper.call("program_index_from_label", label))
	return 0

func set_arrangement_zoom_fit() -> void:
	if arrangement_lane == null:
		return
	var label_width = float(arrangement_lane.get("label_width"))
	var lane_width = max(0.0, arrangement_lane.size.x - label_width)
	var content_beats = 0.0
	if arrangement_lane.has_method("get_content_length_beats"):
		content_beats = float(arrangement_lane.call("get_content_length_beats"))
	var target_beats = max(1.0, content_beats * 2.0)
	if lane_width > 0.0:
		arrangement_pixels_per_beat = max(0.1, lane_width / target_beats)
	arrangement_scroll_x = 0.0
	_update_arrangement_scrollbar()

func prepare_arrangement_zoom_fit() -> void:
	if arrangement_pixels_per_beat > 0.0:
		arrangement_zoom_restore_ppb = arrangement_pixels_per_beat
	elif piano_roll != null:
		arrangement_zoom_restore_ppb = max(1.0, float(piano_roll.get("pixels_per_beat")) * 0.25)
	else:
		arrangement_zoom_restore_ppb = ARRANGEMENT_RESET_PPB
	set_arrangement_zoom_fit()
	_record_history(true)

func _on_selection_committed(start_beats: float, end_beats: float) -> void:
	if piano_roll == null:
		return
	var start_time = min(start_beats, end_beats)
	piano_roll.call("set_playhead_time", start_time)

func handle_selection_committed(start_beats: float, end_beats: float) -> void:
	_on_selection_committed(start_beats, end_beats)

func _on_selection_double_clicked(start_beats: float, end_beats: float) -> void:
	open_comment_range(start_beats, end_beats)

func open_comment_range(start_beats: float, end_beats: float) -> void:
	if comment_lane == null:
		return
	set_panel_mode("comment")
	if comment_lane.has_method("add_comment"):
		comment_lane.call("add_comment", start_beats, end_beats)

func set_selection_range(start_beats: float, end_beats: float) -> void:
	if arrangement_lane != null and arrangement_lane.has_method("set_selection_range"):
		arrangement_lane.call("set_selection_range", start_beats, end_beats)

func history_back() -> void:
	_apply_history_step(-1)

func history_forward() -> void:
	_apply_history_step(1)

func can_history_back() -> bool:
	return history_index > 0

func can_history_forward() -> bool:
	return history_index >= 0 and history_index < history.size() - 1

func _apply_history_step(delta: int) -> void:
	if history.is_empty():
		return
	var next_index = clamp(history_index + delta, 0, history.size() - 1)
	if next_index == history_index:
		return
	history_index = next_index
	_apply_history_state(history[history_index])

func _record_history(force_new: bool = false) -> void:
	if history_suppress:
		return
	var state = _build_history_state()
	if history_index >= 0 and not force_new and _history_identity_match(history[history_index], state):
		history[history_index] = state
	else:
		while history.size() > history_index + 1:
			history.remove_at(history.size() - 1)
		history.append(state)
		history_index = history.size() - 1
		if history.size() > HISTORY_LIMIT:
			history.remove_at(0)
			history_index = max(0, history_index - 1)
	_update_history_buttons()

func _history_identity_match(left: Dictionary, right: Dictionary) -> bool:
	return (
		String(left.get("panel_mode", "")) == String(right.get("panel_mode", ""))
		and int(left.get("track_index", -1)) == int(right.get("track_index", -1))
		and int(left.get("clip_index", -1)) == int(right.get("clip_index", -1))
	)

func _build_history_state() -> Dictionary:
	var state = {
		"panel_mode": panel_mode,
		"track_index": active_track_index,
		"clip_index": active_clip_index,
		"roll_scroll_x": get_scroll_x(),
		"roll_scroll_y": float(piano_roll.call("get_scroll_y")) if piano_roll != null else 0.0,
		"piano_scroll_x": piano_scroll_x,
		"step_pitch": int(step_lane.get("step_pitch")) if step_lane != null else 60,
		"step_divisions": int(step_lane.get("steps_per_measure")) if step_lane != null else 4,
		"arr_ppb": arrangement_pixels_per_beat,
		"arr_scroll_x": arrangement_scroll_x,
		"arr_scroll_y": panel_scroll_y_arrangement,
		"comment_scroll_y": panel_scroll_y_comment,
		"three_d_scroll_y": panel_scroll_y_3d
	}
	if three_d_lane != null and three_d_lane.has_method("get_camera_state"):
		state["three_d_camera"] = three_d_lane.call("get_camera_state")
	return state

func _apply_history_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	history_suppress = true
	var track_index = int(state.get("track_index", active_track_index))
	if project_model != null:
		track_index = clamp(track_index, 0, project_model.tracks.size() - 1)
	_set_active_track_index(track_index)
	_set_active_clip_index(int(state.get("clip_index", active_clip_index)))
	var next_mode = String(state.get("panel_mode", panel_mode))
	if panel_mode != next_mode:
		panel_mode = next_mode
		_apply_panel_mode()
	if step_lane != null:
		if state.has("step_pitch"):
			step_lane.set("step_pitch", int(state.get("step_pitch", step_lane.get("step_pitch"))))
		if state.has("step_divisions"):
			step_lane.set("steps_per_measure", int(state.get("step_divisions", step_lane.get("steps_per_measure"))))
	if piano_roll != null:
		if state.has("roll_scroll_x"):
			piano_roll.call("set_scroll_x", float(state["roll_scroll_x"]))
		if state.has("roll_scroll_y"):
			piano_roll.call("set_scroll_y", float(state["roll_scroll_y"]))
	arrangement_pixels_per_beat = float(state.get("arr_ppb", arrangement_pixels_per_beat))
	arrangement_scroll_x = float(state.get("arr_scroll_x", arrangement_scroll_x))
	piano_scroll_x = float(state.get("piano_scroll_x", piano_scroll_x))
	panel_scroll_y_arrangement = float(state.get("arr_scroll_y", panel_scroll_y_arrangement))
	panel_scroll_y_comment = float(state.get("comment_scroll_y", panel_scroll_y_comment))
	panel_scroll_y_3d = float(state.get("three_d_scroll_y", panel_scroll_y_3d))
	if three_d_lane != null and state.has("three_d_camera"):
		three_d_lane.call("set_camera_state", state["three_d_camera"])
	_sync_scrollbars()
	if panel_mode == "piano":
		_update_piano_scrollbar()
	_update_panel_scrollbar()
	history_suppress = false
	_update_history_buttons()

func _update_history_buttons() -> void:
	pass

func _emit_focus() -> void:
	emit_signal("slot_focused", slot_index)

func _on_mouse_entered() -> void:
	_hovered = true

func _on_mouse_exited() -> void:
	_hovered = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var inside = get_global_rect().has_point(event.position)
		if inside and not _hovered:
			_hovered = true
		elif not inside and _hovered:
			_hovered = false
	if event is InputEventMouseButton and event.pressed:
		var rect = get_global_rect()
		if rect.has_point(event.position):
			_emit_focus()

func set_focus_highlight(enabled: bool) -> void:
	if focus_highlight == enabled:
		return
	focus_highlight = enabled
	_update_focus_frames()

func _update_focus_frames() -> void:
	var color = FRAME_COLOR_ACTIVE if focus_highlight else FRAME_COLOR_INACTIVE
	if roll_frame_overlay != null:
		roll_frame_overlay.set("border_color", color)
		roll_frame_overlay.queue_redraw()
	if panel_frame != null:
		var overlay = panel_frame.get_node_or_null("PanelFrameOverlay")
		if overlay != null:
			overlay.set("border_color", color)
			overlay.queue_redraw()
