extends Control

const ICON_SNAP_ON = preload("res://Lucid V1.2/PNG/Flat/16/Grid.png")
const ICON_SNAP_OFF = preload("res://Lucid V1.2/PNG/Flat/16/Slash.png")
const PROJECT_MODEL = preload("res://scripts/models/project_model.gd")

@onready var browser_panel: Control = $"RootLayout/MainSplit/BrowserPanel"
@onready var browser_toggle: Button = $"RootLayout/TopBar/TopBarContent/BrowserToggle"
@onready var add_track_button: Button = get_node_or_null("RootLayout/TopBar/TopBarContent/AddTrackButton")
@onready var shared_scroll_button: Button = get_node_or_null("RootLayout/TopBar/TopBarContent/SharedScrollButton")
@onready var track_name_edit: LineEdit = get_node_or_null("RootLayout/TopBar/TopBarContent/TrackNameEdit")
@onready var clip_name_edit: LineEdit = get_node_or_null("RootLayout/TopBar/TopBarContent/ClipNameEdit")
@onready var track_list: ItemList = $"RootLayout/MainSplit/BrowserPanel/BrowserContent/TrackList"
@onready var track_up_button: Button = $"RootLayout/MainSplit/BrowserPanel/BrowserContent/TrackButtons/TrackUpButton"
@onready var track_down_button: Button = $"RootLayout/MainSplit/BrowserPanel/BrowserContent/TrackButtons/TrackDownButton"
@onready var track_remove_button: Button = $"RootLayout/MainSplit/BrowserPanel/BrowserContent/TrackButtons/TrackRemoveButton"
@onready var selection_snap_button: Button = $"RootLayout/MainSplit/RightSplit/TransportPanel/TransportBar/SelectionSnapButton"
@onready var panel_slot_a: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/PanelSplit/PanelSlotA"
@onready var panel_slot_b: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/PanelSplit/PanelSlotB"

var project_model: Node = null
var active_slot: Node = null
var shared_scroll_enabled := false
var updating_track_list := false
var updating_name_fields := false
var syncing_shared_scroll := false

func _ready() -> void:
	_ensure_project_model()
	_init_controls()
	_init_panel_slots()
	_refresh_track_list()
	_update_browser_toggle_label()
	_set_active_slot(panel_slot_a)
	_update_shared_scroll_label()

func _ensure_project_model() -> void:
	if project_model != null:
		return
	project_model = PROJECT_MODEL.new()
	project_model.name = "ProjectModel"
	add_child(project_model)
	if project_model.tracks.is_empty():
		project_model.create_track("Track 1")
	if project_model.has_signal("changed"):
		project_model.connect("changed", Callable(self, "_on_project_model_changed"))

func _init_controls() -> void:
	if browser_toggle != null and browser_toggle.has_signal("pressed"):
		var callable = Callable(self, "_on_browser_toggle_pressed")
		if not browser_toggle.is_connected("pressed", callable):
			browser_toggle.connect("pressed", callable)
	if add_track_button != null and add_track_button.has_signal("pressed"):
		var add_callable = Callable(self, "_on_add_track_pressed")
		if not add_track_button.is_connected("pressed", add_callable):
			add_track_button.connect("pressed", add_callable)
	if shared_scroll_button != null and shared_scroll_button.has_signal("pressed"):
		shared_scroll_button.toggle_mode = true
		var shared_callable = Callable(self, "_on_shared_scroll_pressed")
		if not shared_scroll_button.is_connected("pressed", shared_callable):
			shared_scroll_button.connect("pressed", shared_callable)
	if selection_snap_button != null and selection_snap_button.has_signal("pressed"):
		var snap_callable = Callable(self, "_on_selection_snap_pressed")
		if not selection_snap_button.is_connected("pressed", snap_callable):
			selection_snap_button.connect("pressed", snap_callable)
	if track_list != null and track_list.has_signal("item_selected"):
		var list_callable = Callable(self, "_on_track_list_selected")
		if not track_list.is_connected("item_selected", list_callable):
			track_list.connect("item_selected", list_callable)
	if track_up_button != null and track_up_button.has_signal("pressed"):
		var up_callable = Callable(self, "_on_track_move_up_pressed")
		if not track_up_button.is_connected("pressed", up_callable):
			track_up_button.connect("pressed", up_callable)
	if track_down_button != null and track_down_button.has_signal("pressed"):
		var down_callable = Callable(self, "_on_track_move_down_pressed")
		if not track_down_button.is_connected("pressed", down_callable):
			track_down_button.connect("pressed", down_callable)
	if track_remove_button != null and track_remove_button.has_signal("pressed"):
		var remove_callable = Callable(self, "_on_track_remove_pressed")
		if not track_remove_button.is_connected("pressed", remove_callable):
			track_remove_button.connect("pressed", remove_callable)
	if track_name_edit != null:
		if not track_name_edit.text_submitted.is_connected(_on_track_name_submitted):
			track_name_edit.text_submitted.connect(_on_track_name_submitted)
		if not track_name_edit.focus_exited.is_connected(_on_track_name_focus_exited):
			track_name_edit.focus_exited.connect(_on_track_name_focus_exited)
	if clip_name_edit != null:
		if not clip_name_edit.text_submitted.is_connected(_on_clip_name_submitted):
			clip_name_edit.text_submitted.connect(_on_clip_name_submitted)
		if not clip_name_edit.focus_exited.is_connected(_on_clip_name_focus_exited):
			clip_name_edit.focus_exited.connect(_on_clip_name_focus_exited)

func _init_panel_slots() -> void:
	for slot in [panel_slot_a, panel_slot_b]:
		if slot == null:
			continue
		if slot.has_method("set_project_model"):
			slot.call("set_project_model", project_model)
		if slot.has_signal("slot_focused"):
			var focus_callable = Callable(self, "_on_slot_focused")
			if not slot.is_connected("slot_focused", focus_callable):
				slot.connect("slot_focused", focus_callable)
		if slot.has_signal("scroll_x_changed"):
			var scroll_callable = Callable(self, "_on_slot_scroll_x_changed")
			if not slot.is_connected("scroll_x_changed", scroll_callable):
				slot.connect("scroll_x_changed", scroll_callable)
		if slot.has_signal("track_changed"):
			var track_callable = Callable(self, "_on_slot_track_changed")
			if not slot.is_connected("track_changed", track_callable):
				slot.connect("track_changed", track_callable)
		if slot.has_signal("clip_changed"):
			var clip_callable = Callable(self, "_on_slot_clip_changed")
			if not slot.is_connected("clip_changed", clip_callable):
				slot.connect("clip_changed", clip_callable)

func _on_project_model_changed() -> void:
	_refresh_track_list()
	_update_name_edits()
	_sync_track_list_to_active_slot()
	if shared_scroll_enabled:
		_update_shared_view_beats()

func _set_active_slot(slot: Node) -> void:
	if slot == null:
		return
	active_slot = slot
	_sync_track_list_to_active_slot()
	_update_name_edits()
	_update_selection_snap_label()

func _on_slot_focused(slot_index: int) -> void:
	var slot = _slot_by_index(slot_index)
	if slot != null:
		_set_active_slot(slot)

func _on_slot_scroll_x_changed(slot_index: int, scroll_x: float, _view_width: float) -> void:
	if not shared_scroll_enabled or syncing_shared_scroll:
		return
	var target_slot = panel_slot_b if slot_index == 0 else panel_slot_a
	if target_slot == null:
		return
	syncing_shared_scroll = true
	target_slot.call("set_scroll_x", scroll_x, true)
	syncing_shared_scroll = false

func _on_slot_track_changed(slot_index: int, _track_index: int) -> void:
	if active_slot == _slot_by_index(slot_index):
		_sync_track_list_to_active_slot()
		_update_name_edits()
	if shared_scroll_enabled:
		_update_shared_view_beats()

func _on_slot_clip_changed(slot_index: int, _clip_index: int) -> void:
	if active_slot == _slot_by_index(slot_index):
		_update_name_edits()
	if shared_scroll_enabled:
		_update_shared_view_beats()

func _on_browser_toggle_pressed() -> void:
	browser_panel.visible = not browser_panel.visible
	_update_browser_toggle_label()

func _update_browser_toggle_label() -> void:
	if browser_toggle != null:
		browser_toggle.text = ""

func _on_shared_scroll_pressed() -> void:
	if shared_scroll_button == null:
		return
	shared_scroll_enabled = shared_scroll_button.button_pressed
	_update_shared_scroll_label()
	if shared_scroll_enabled:
		_apply_shared_scroll()
	else:
		_clear_shared_scroll()

func _update_shared_scroll_label() -> void:
	if shared_scroll_button == null:
		return
	shared_scroll_button.text = "Sync"

func _apply_shared_scroll() -> void:
	_update_shared_view_beats()
	var source_slot = active_slot if active_slot != null else panel_slot_a
	if source_slot == null:
		return
	var scroll_x = float(source_slot.call("get_scroll_x"))
	var target_slot = panel_slot_b if source_slot == panel_slot_a else panel_slot_a
	if target_slot != null:
		target_slot.call("set_scroll_x", scroll_x, true)

func _clear_shared_scroll() -> void:
	if panel_slot_a != null:
		panel_slot_a.call("clear_shared_view_beats")
	if panel_slot_b != null:
		panel_slot_b.call("clear_shared_view_beats")

func _update_shared_view_beats() -> void:
	if panel_slot_a == null or panel_slot_b == null:
		return
	var a_len = float(panel_slot_a.call("get_active_clip_length"))
	var b_len = float(panel_slot_b.call("get_active_clip_length"))
	var view_beats = int(ceil(max(a_len, b_len)))
	if view_beats <= 0:
		view_beats = 1
	panel_slot_a.call("set_shared_view_beats", view_beats)
	panel_slot_b.call("set_shared_view_beats", view_beats)

func _on_selection_snap_pressed() -> void:
	if active_slot == null:
		return
	var enabled = bool(active_slot.call("toggle_snap"))
	_update_selection_snap_label(enabled)

func _update_selection_snap_label(force_enabled: Variant = null) -> void:
	if selection_snap_button == null:
		return
	var enabled = false
	if force_enabled is bool:
		enabled = force_enabled
	elif active_slot != null:
		enabled = bool(active_slot.call("is_snap_enabled"))
	selection_snap_button.text = ""
	selection_snap_button.icon = ICON_SNAP_ON if enabled else ICON_SNAP_OFF

func _refresh_track_list() -> void:
	if track_list == null:
		return
	updating_track_list = true
	track_list.clear()
	if project_model != null:
		for i in range(project_model.tracks.size()):
			var track = project_model.tracks[i]
			var label = "Track %d" % (i + 1)
			if track != null:
				label = str(track.track_name)
			track_list.add_item(label)
	updating_track_list = false
	_sync_track_list_to_active_slot()

func _sync_track_list_to_active_slot() -> void:
	if track_list == null or active_slot == null:
		return
	var index = int(active_slot.call("get_active_track_index"))
	if index < 0 or index >= track_list.get_item_count():
		return
	updating_track_list = true
	track_list.select(index)
	track_list.ensure_current_is_visible()
	updating_track_list = false

func _on_track_list_selected(index: int) -> void:
	if updating_track_list or active_slot == null:
		return
	active_slot.call("select_track", index)

func _on_add_track_pressed() -> void:
	if project_model == null:
		return
	var next_index = project_model.tracks.size() + 1
	project_model.create_track("Track %d" % next_index)
	_refresh_track_list()
	if active_slot != null:
		active_slot.call("select_track", project_model.tracks.size() - 1)

func _on_track_move_up_pressed() -> void:
	_move_active_track(-1)

func _on_track_move_down_pressed() -> void:
	_move_active_track(1)

func _move_active_track(delta: int) -> void:
	if project_model == null or active_slot == null:
		return
	var count = project_model.tracks.size()
	if count <= 1:
		return
	var from_index = clamp(int(active_slot.call("get_active_track_index")), 0, count - 1)
	var to_index = clamp(from_index + delta, 0, count - 1)
	if from_index == to_index:
		return
	var track = project_model.tracks[from_index]
	project_model.tracks.remove_at(from_index)
	project_model.tracks.insert(to_index, track)
	if project_model.has_signal("changed"):
		project_model.emit_signal("changed")
	_resync_slots_after_reorder()

func _on_track_remove_pressed() -> void:
	if project_model == null or active_slot == null:
		return
	if project_model.tracks.size() <= 1:
		return
	var index = clamp(int(active_slot.call("get_active_track_index")), 0, project_model.tracks.size() - 1)
	project_model.tracks.remove_at(index)
	if project_model.tracks.is_empty():
		project_model.create_track("Track 1")
	if project_model.has_signal("changed"):
		project_model.emit_signal("changed")
	_refresh_track_list()
	_resync_slots_after_reorder()

func _resync_slots_after_reorder() -> void:
	for slot in [panel_slot_a, panel_slot_b]:
		if slot == null:
			continue
		var track = slot.call("get_active_track")
		var index = project_model.tracks.find(track)
		if index < 0:
			index = 0
		slot.call("select_track", index)

func _update_name_edits() -> void:
	if updating_name_fields:
		return
	updating_name_fields = true
	if track_name_edit != null:
		var track = active_slot.call("get_active_track") if active_slot != null else null
		track_name_edit.text = str(track.track_name) if track != null else ""
	if clip_name_edit != null:
		var clip = active_slot.call("get_active_clip") if active_slot != null else null
		if clip == null:
			clip_name_edit.text = ""
		else:
			var label = str(clip.clip_name)
			if label == "" and active_slot != null:
				label = "Clip %d" % (int(active_slot.call("get_active_clip_index")) + 1)
			clip_name_edit.text = label
	updating_name_fields = false

func _on_track_name_submitted(text: String) -> void:
	_commit_track_name(text)

func _on_track_name_focus_exited() -> void:
	if track_name_edit == null:
		return
	_commit_track_name(track_name_edit.text)

func _commit_track_name(text: String) -> void:
	if active_slot == null:
		return
	var track_label = text.strip_edges()
	if track_label == "":
		track_label = "Track %d" % (int(active_slot.call("get_active_track_index")) + 1)
	active_slot.call("set_track_name", track_label)
	_refresh_track_list()
	_update_name_edits()

func _on_clip_name_submitted(text: String) -> void:
	_commit_clip_name(text)

func _on_clip_name_focus_exited() -> void:
	if clip_name_edit == null:
		return
	_commit_clip_name(clip_name_edit.text)

func _commit_clip_name(text: String) -> void:
	if active_slot == null:
		return
	var clip_label = text.strip_edges()
	if clip_label == "":
		clip_label = "Clip %d" % (int(active_slot.call("get_active_clip_index")) + 1)
	active_slot.call("set_clip_name", clip_label)
	_update_name_edits()

func _slot_by_index(slot_index: int) -> Node:
	return panel_slot_a if slot_index == 0 else panel_slot_b
