extends Control

const ICON_SNAP_ON = preload("res://Lucid V1.2/PNG/Flat/16/Grid.png")
const ICON_SNAP_OFF = preload("res://Lucid V1.2/PNG/Flat/16/Slash.png")
const PROJECT_MODEL = preload("res://scripts/models/project_model.gd")
const CLIP_MODEL = preload("res://scripts/models/clip_model.gd")
const MIDI_IMPORTER = preload("res://scripts/midi_importer.gd")
const MIDI_EXPORTER = preload("res://scripts/midi_exporter.gd")
const PLAYBACK_ENGINE = preload("res://scripts/playback_engine.gd")
const SOUNDFONT_MANAGER = preload("res://scripts/soundfont_manager.gd")
const SELECTION_BAR_GAP := 4.0
const PANEL_COLLAPSE_THRESHOLD := 6.0
const DEBUG_SYNC := false
const DEFAULT_SOUNDFONT_PATH := ""
const PLAYBACK_MODE_TRACKS := "tracks"
const PLAYBACK_MODE_CLIP := "clip"
const MIDI_BUILD_BUDGET_MS := 22
const MIDI_BUILD_UNITS_PER_FRAME := 2000
const TRACK_TREE_BUILD_BUDGET_MS := 22
const ADSR_TIME_MAX := 10.0
const ADSR_SUSTAIN_MIN_DB := -80.0
const ADSR_SUSTAIN_MAX_DB := 0.0

@onready var browser_panel: Control = $"RootLayout/MainSplit/BrowserPanel"
@onready var browser_toggle: Button = $"RootLayout/TopBar/TopBarContent/BrowserToggle"
@onready var add_track_button: Button = get_node_or_null("RootLayout/TopBar/TopBarContent/AddTrackButton")
@onready var import_midi_button: Button = get_node_or_null("RootLayout/TopBar/TopBarContent/ImportMidiButton")
@onready var midi_device_option: OptionButton = get_node_or_null("RootLayout/TopBar/TopBarContent/MidiDeviceOption")
@onready var midi_refresh_button: Button = get_node_or_null("RootLayout/TopBar/TopBarContent/MidiRefreshButton")
@onready var record_button: Button = get_node_or_null("RootLayout/TopBar/TopBarContent/RecordButton")
@onready var shared_scroll_button: Button = get_node_or_null("RootLayout/TopBar/TopBarContent/SharedScrollButton")
@onready var track_name_edit: LineEdit = get_node_or_null("RootLayout/TopBar/TopBarContent/TrackNameEdit")
@onready var clip_name_edit: LineEdit = get_node_or_null("RootLayout/TopBar/TopBarContent/ClipNameEdit")
@onready var play_button: Button = get_node_or_null("RootLayout/TopBar/TopBarContent/PlayButton")
@onready var pause_button: Button = get_node_or_null("RootLayout/TopBar/TopBarContent/PauseButton")
@onready var stop_button: Button = get_node_or_null("RootLayout/TopBar/TopBarContent/StopButton")
@onready var loading_overlay: Control = get_node_or_null("LoadingOverlay")
@onready var loading_label: Label = get_node_or_null("LoadingOverlay/LoadingCenter/LoadingBox/LoadingLabel")
@onready var loading_bar: ProgressBar = get_node_or_null("LoadingOverlay/LoadingCenter/LoadingBox/LoadingBar")
@onready var soundfont_button: Button = get_node_or_null("RootLayout/MainSplit/RightSplit/TransportPanel/TransportContent/TransportBar/SoundFontButton")
@onready var root_layout: Control = $"RootLayout"
@onready var top_bar: Control = $"RootLayout/TopBar"
@onready var main_split: SplitContainer = $"RootLayout/MainSplit"
@onready var track_tree: Tree = $"RootLayout/MainSplit/BrowserPanel/BrowserContent/TrackTree"
@onready var track_up_button: Button = get_node_or_null("RootLayout/MainSplit/BrowserPanel/BrowserContent/TrackButtons/TrackUpButton")
@onready var track_down_button: Button = get_node_or_null("RootLayout/MainSplit/BrowserPanel/BrowserContent/TrackButtons/TrackDownButton")
@onready var track_remove_button: Button = get_node_or_null("RootLayout/MainSplit/BrowserPanel/BrowserContent/TrackButtons/TrackRemoveButton")
@onready var selection_snap_button: Button = get_node_or_null("RootLayout/MainSplit/RightSplit/TransportPanel/TransportContent/TransportBar/SelectionSnapButton")
@onready var panel_a_track_selector: OptionButton = get_node_or_null("RootLayout/MainSplit/RightSplit/TransportPanel/TransportContent/PanelControlsA/PanelATrackSelector")
@onready var panel_a_mode_button: Button = get_node_or_null("RootLayout/TopBar/TopBarContent/PanelAModeButton")
@onready var panel_a_clip_tabs: TabBar = get_node_or_null("RootLayout/MainSplit/RightSplit/TransportPanel/TransportContent/PanelControlsA/PanelAClipTabs")
@onready var panel_a_add_clip_button: Button = get_node_or_null("RootLayout/MainSplit/RightSplit/TransportPanel/TransportContent/PanelControlsA/PanelAAddClipButton")
@onready var panel_b_track_selector: OptionButton = get_node_or_null("RootLayout/MainSplit/RightSplit/TransportPanel/TransportContent/PanelControlsB/PanelBTrackSelector")
@onready var panel_b_mode_button: Button = get_node_or_null("RootLayout/TopBar/TopBarContent/PanelBModeButton")
@onready var panel_b_clip_tabs: TabBar = get_node_or_null("RootLayout/MainSplit/RightSplit/TransportPanel/TransportContent/PanelControlsB/PanelBClipTabs")
@onready var panel_b_add_clip_button: Button = get_node_or_null("RootLayout/MainSplit/RightSplit/TransportPanel/TransportContent/PanelControlsB/PanelBAddClipButton")
@onready var panel_split: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/PanelSplit"
@onready var panel_split_container: SplitContainer = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/PanelSplit/PanelSplitContainer"
@onready var right_split: SplitContainer = $"RootLayout/MainSplit/RightSplit"
@onready var transport_panel: Control = get_node_or_null("RootLayout/MainSplit/RightSplit/TransportPanel")
@onready var selection_bar_row: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/PanelSplit/SelectionBarRow"
@onready var selection_bar_spacer: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/PanelSplit/SelectionBarRow/SelectionBarSpacer"
@onready var history_back_button: Button = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/PanelSplit/SelectionBarRow/SelectionBarSpacer/HistoryBackButton"
@onready var history_forward_button: Button = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/PanelSplit/SelectionBarRow/SelectionBarSpacer/HistoryForwardButton"
@onready var panel_sync_button: Button = get_node_or_null("RootLayout/TopBar/TopBarContent/PanelSyncButton")
@onready var selection_bar_right_spacer: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/PanelSplit/SelectionBarRow/SelectionBarRightSpacer"
@onready var selection_bar: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/PanelSplit/SelectionBarRow/SelectionBarFrame/SelectionBar"
@onready var panel_slot_a: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/PanelSplit/PanelSplitContainer/PanelSlotA"
@onready var panel_slot_b: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/PanelSplit/PanelSplitContainer/PanelSlotB"
@onready var midi_import_dialog: FileDialog = get_node_or_null("MidiImportDialog")
@onready var soundfont_dialog: FileDialog = get_node_or_null("SoundFontDialog")
@onready var midi_player: Node = get_node_or_null("MidiPlayer")
var playback_engine: Node = null
var soundfont_manager: Node = null

var project_model: Node = null
var active_slot: Node = null
var shared_scroll_enabled := false
var updating_track_list := false
var updating_name_fields := false
var syncing_shared_scroll := false
var slot_selection_ranges: Dictionary = {}
var tree_item_by_track_id: Dictionary = {}
var tree_item_by_clip_id: Dictionary = {}
var panel_fullscreen_enabled := false
var panel_fullscreen_split_offset := 0
var panel_fullscreen_slot: Node = null
var panel_fullscreen_refreshing := false
var panel_fullscreen_ui_state: Dictionary = {}
var _split_dragging := false
var _split_drag_frame := -1
var soundfont_path := DEFAULT_SOUNDFONT_PATH
var playback_mode := ""
var playback_slot: Node = null
var _initial_panel_collapse_done := false
var _pending_track_refresh := false
var _midi_import_thread: Thread = null
var _midi_import_path := ""
var _importing_count := 0
var _importing_prev_master_db := 0.0
var _importing_master_muted := false
var _import_block_hold := false
var _loading_visible := false
var _loading_visible_since_ms := 0
var _loading_show_deadline_ms := 0
var _loading_hide_deadline_ms := 0
var _loading_delay_ms := 180
var _loading_min_ms := 240
var _midi_build_importer: RefCounted = null
var _midi_build_project: Node = null
var _midi_build_entries: Array = []
var _midi_build_index := 0
var _midi_build_current_entry: Dictionary = {}
var _midi_build_current_track: Node = null
var _midi_build_current_clip: Node = null
var _midi_build_note_index := 0
var _midi_build_cc_index := 0
var _midi_build_total_units := 0
var _midi_build_units_done := 0
var _track_tree_building := false
var _track_tree_build_root: TreeItem = null
var _track_tree_build_tracks: Array = []
var _track_tree_build_index := 0
var _midi_device_names: Array = []
var _selected_midi_device_index := -1
var _midi_has_device_field := false
var _is_recording := false
var _record_start_time_sec := 0.0
var _record_start_beats := 0.0
var _record_active_notes: Dictionary = {}

func _ready() -> void:
	set_process_input(true)
	_ensure_project_model()
	_init_controls()
	_init_panel_slots()
	_init_selection_bar()
	_refresh_track_list()
	_update_browser_toggle_label()
	_set_active_slot(panel_slot_a)
	_update_shared_scroll_label()
	_apply_transport_to_slots()
	_setup_midi_player()
	_setup_midi_input()
	_setup_soundfont_manager()
	_setup_playback_engine()
	_update_soundfont_button()
	call_deferred("_collapse_top_panel_initial")

func _process(_delta: float) -> void:
	_update_playback_playhead()
	_flush_split_drag()
	_poll_midi_import_thread()
	_process_midi_import_build()
	_process_track_tree_build()
	_update_loading_state()
	_update_recording_notes()

func _input(event: InputEvent) -> void:
	if _is_import_blocking():
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMIDI:
		_handle_midi_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle_panel_fullscreen()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE:
			_toggle_transport_playback()
			get_viewport().set_input_as_handled()

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
	if import_midi_button != null and import_midi_button.has_signal("pressed"):
		var import_callable = Callable(self, "_on_import_midi_pressed")
		if not import_midi_button.is_connected("pressed", import_callable):
			import_midi_button.connect("pressed", import_callable)
	if midi_device_option != null and midi_device_option.has_signal("item_selected"):
		var device_callable = Callable(self, "_on_midi_device_selected")
		if not midi_device_option.is_connected("item_selected", device_callable):
			midi_device_option.connect("item_selected", device_callable)
	if midi_refresh_button != null and midi_refresh_button.has_signal("pressed"):
		var refresh_callable = Callable(self, "_on_midi_refresh_pressed")
		if not midi_refresh_button.is_connected("pressed", refresh_callable):
			midi_refresh_button.connect("pressed", refresh_callable)
	if record_button != null and record_button.has_signal("toggled"):
		record_button.toggle_mode = true
		var record_callable = Callable(self, "_on_record_toggled")
		if not record_button.is_connected("toggled", record_callable):
			record_button.connect("toggled", record_callable)
	if midi_import_dialog != null:
		midi_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
		midi_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		midi_import_dialog.title = "Import MIDI"
		midi_import_dialog.filters = PackedStringArray(["*.mid ; MIDI files", "*.midi ; MIDI files"])
		if not midi_import_dialog.file_selected.is_connected(_on_midi_import_file_selected):
			midi_import_dialog.file_selected.connect(_on_midi_import_file_selected)
	if soundfont_dialog != null:
		soundfont_dialog.access = FileDialog.ACCESS_FILESYSTEM
		soundfont_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		soundfont_dialog.title = "Select SoundFont"
		soundfont_dialog.filters = PackedStringArray(["*.sf2 ; SoundFont files"])
		if not soundfont_dialog.file_selected.is_connected(_on_soundfont_file_selected):
			soundfont_dialog.file_selected.connect(_on_soundfont_file_selected)
	if shared_scroll_button != null and shared_scroll_button.has_signal("pressed"):
		shared_scroll_button.toggle_mode = true
		var shared_callable = Callable(self, "_on_shared_scroll_pressed")
		if not shared_scroll_button.is_connected("pressed", shared_callable):
			shared_scroll_button.connect("pressed", shared_callable)
	if selection_snap_button != null and selection_snap_button.has_signal("pressed"):
		var snap_callable = Callable(self, "_on_selection_snap_pressed")
		if not selection_snap_button.is_connected("pressed", snap_callable):
			selection_snap_button.connect("pressed", snap_callable)
	if track_tree != null:
		if track_tree.has_signal("track_item_selected"):
			var track_callable = Callable(self, "_on_track_tree_track_selected")
			if not track_tree.is_connected("track_item_selected", track_callable):
				track_tree.connect("track_item_selected", track_callable)
		if track_tree.has_signal("clip_item_selected"):
			var clip_callable = Callable(self, "_on_track_tree_clip_selected")
			if not track_tree.is_connected("clip_item_selected", clip_callable):
				track_tree.connect("clip_item_selected", clip_callable)
		if track_tree.has_signal("automation_item_selected"):
			var automation_callable = Callable(self, "_on_track_tree_automation_selected")
			if not track_tree.is_connected("automation_item_selected", automation_callable):
				track_tree.connect("automation_item_selected", automation_callable)
		if track_tree.has_signal("soundfont_item_selected"):
			var sf_callable = Callable(self, "_on_track_tree_soundfont_selected")
			if not track_tree.is_connected("soundfont_item_selected", sf_callable):
				track_tree.connect("soundfont_item_selected", sf_callable)
		if track_tree.has_signal("add_track_selected"):
			var add_track_callable = Callable(self, "_on_track_tree_add_track_selected")
			if not track_tree.is_connected("add_track_selected", add_track_callable):
				track_tree.connect("add_track_selected", add_track_callable)
		if track_tree.has_signal("add_clip_selected"):
			var add_clip_callable = Callable(self, "_on_track_tree_add_clip_selected")
			if not track_tree.is_connected("add_clip_selected", add_clip_callable):
				track_tree.connect("add_clip_selected", add_clip_callable)
		if track_tree.has_signal("clip_drag_started"):
			var drag_callable = Callable(self, "_on_browser_clip_drag_started")
			if not track_tree.is_connected("clip_drag_started", drag_callable):
				track_tree.connect("clip_drag_started", drag_callable)
		if track_tree.has_signal("clip_drag_ended"):
			var drag_end_callable = Callable(self, "_on_browser_clip_drag_ended")
			if not track_tree.is_connected("clip_drag_ended", drag_end_callable):
				track_tree.connect("clip_drag_ended", drag_end_callable)
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
	if play_button != null and play_button.has_signal("pressed"):
		var play_callable = Callable(self, "_on_play_pressed")
		if not play_button.is_connected("pressed", play_callable):
			play_button.connect("pressed", play_callable)
	if pause_button != null and pause_button.has_signal("pressed"):
		var pause_callable = Callable(self, "_on_pause_pressed")
		if not pause_button.is_connected("pressed", pause_callable):
			pause_button.connect("pressed", pause_callable)
	if stop_button != null and stop_button.has_signal("pressed"):
		var stop_callable = Callable(self, "_on_stop_pressed")
		if not stop_button.is_connected("pressed", stop_callable):
			stop_button.connect("pressed", stop_callable)
	if soundfont_button != null and soundfont_button.has_signal("pressed"):
		var sf_callable = Callable(self, "_on_soundfont_pressed")
		if not soundfont_button.is_connected("pressed", sf_callable):
			soundfont_button.connect("pressed", sf_callable)

func _bind_panel_controls(
	slot: Node,
	track_selector: OptionButton,
	mode_button: Button,
	tab_bar: TabBar,
	add_clip_button: Button
) -> void:
	if slot == null:
		return
	if slot.has_method("bind_controls"):
		slot.call("bind_controls", track_selector, mode_button, tab_bar, add_clip_button)

func _init_panel_slots() -> void:
	_bind_panel_controls(panel_slot_a, panel_a_track_selector, panel_a_mode_button, panel_a_clip_tabs, panel_a_add_clip_button)
	_bind_panel_controls(panel_slot_b, panel_b_track_selector, panel_b_mode_button, panel_b_clip_tabs, panel_b_add_clip_button)
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
		if slot.has_signal("arrangement_selection_preview"):
			var preview_callable = Callable(self, "_on_arrangement_selection_preview")
			if not slot.is_connected("arrangement_selection_preview", preview_callable):
				slot.connect("arrangement_selection_preview", preview_callable)
		if slot.has_signal("arrangement_selection_committed"):
			var committed_callable = Callable(self, "_on_arrangement_selection_committed")
			if not slot.is_connected("arrangement_selection_committed", committed_callable):
				slot.connect("arrangement_selection_committed", committed_callable)
		if slot.has_signal("snap_changed"):
			var snap_callable = Callable(self, "_on_slot_snap_changed")
			if not slot.is_connected("snap_changed", snap_callable):
				slot.connect("snap_changed", snap_callable)

func _init_selection_bar() -> void:
	if selection_bar == null:
		return
	if selection_bar.has_signal("selection_committed"):
		var committed_callable = Callable(self, "_on_selection_committed")
		if not selection_bar.is_connected("selection_committed", committed_callable):
			selection_bar.connect("selection_committed", committed_callable)
	if selection_bar.has_signal("selection_double_clicked"):
		var double_callable = Callable(self, "_on_selection_double_clicked")
		if not selection_bar.is_connected("selection_double_clicked", double_callable):
			selection_bar.connect("selection_double_clicked", double_callable)
	if selection_bar.has_signal("selection_cleared"):
		var cleared_callable = Callable(self, "_on_selection_cleared")
		if not selection_bar.is_connected("selection_cleared", cleared_callable):
			selection_bar.connect("selection_cleared", cleared_callable)
	if selection_bar.has_signal("panel_height_changed"):
		var height_callable = Callable(self, "_on_selection_bar_height_changed")
		if not selection_bar.is_connected("panel_height_changed", height_callable):
			selection_bar.connect("panel_height_changed", height_callable)
	if panel_split_container != null and panel_split_container.has_signal("dragged"):
		var dragged_callable = Callable(self, "_on_split_container_dragged")
		if not panel_split_container.is_connected("dragged", dragged_callable):
			panel_split_container.connect("dragged", dragged_callable)
	if panel_split != null and panel_split.has_signal("resized"):
		var resized_callable = Callable(self, "_on_panel_split_resized")
		if not panel_split.is_connected("resized", resized_callable):
			panel_split.connect("resized", resized_callable)
	if panel_slot_a != null and panel_slot_a.has_signal("resized"):
		var slot_resized_callable = Callable(self, "_on_panel_split_resized")
		if not panel_slot_a.is_connected("resized", slot_resized_callable):
			panel_slot_a.connect("resized", slot_resized_callable)
	if panel_slot_b != null and panel_slot_b.has_signal("resized"):
		var slot_b_resized_callable = Callable(self, "_on_panel_split_resized")
		if not panel_slot_b.is_connected("resized", slot_b_resized_callable):
			panel_slot_b.connect("resized", slot_b_resized_callable)
	if history_back_button != null and history_back_button.has_signal("pressed"):
		var back_callable = Callable(self, "_on_history_back_pressed")
		if not history_back_button.is_connected("pressed", back_callable):
			history_back_button.connect("pressed", back_callable)
	if history_forward_button != null and history_forward_button.has_signal("pressed"):
		var forward_callable = Callable(self, "_on_history_forward_pressed")
		if not history_forward_button.is_connected("pressed", forward_callable):
			history_forward_button.connect("pressed", forward_callable)
	if panel_sync_button != null and panel_sync_button.has_signal("pressed"):
		var sync_callable = Callable(self, "_on_panel_sync_pressed")
		if not panel_sync_button.is_connected("pressed", sync_callable):
			panel_sync_button.connect("pressed", sync_callable)
	call_deferred("_prime_selection_bar_split")
	call_deferred("_update_selection_bar_layout")

func _prime_selection_bar_split() -> void:
	if selection_bar == null or panel_split_container == null:
		return
	if panel_split_container.size.y <= 0.0:
		call_deferred("_prime_selection_bar_split")
		return
	if selection_bar.has_method("setup_split"):
		selection_bar.call("setup_split", panel_split_container)

func _collapse_top_panel_initial() -> void:
	if _initial_panel_collapse_done:
		return
	if panel_split_container == null or selection_bar_row == null:
		return
	if panel_split_container.size.y <= 0.0:
		call_deferred("_collapse_top_panel_initial")
		return
	_initial_panel_collapse_done = true
	var bar_height = selection_bar_row.custom_minimum_size.y
	if bar_height <= 0.0:
		bar_height = selection_bar_row.size.y
	if bar_height <= 0.0:
		bar_height = 18.0
	var separation = bar_height + (SELECTION_BAR_GAP * 2.0)
	panel_split_container.add_theme_constant_override("separation", int(round(separation)))
	var available = max(0.0, panel_split_container.size.y - separation)
	panel_split_container.split_offset = -int(round(available * 0.5))
	if panel_slot_a != null and panel_slot_a.has_method("set_collapsed"):
		panel_slot_a.call("set_collapsed", true)
	_update_selection_bar_layout()

func _slot_index(slot: Node) -> int:
	if slot == null:
		return -1
	return 1 if slot == panel_slot_b else 0

func _store_selection_for_slot(slot: Node, selection_range: Array) -> void:
	var index = _slot_index(slot)
	if index < 0:
		return
	if selection_range.size() == 2:
		slot_selection_ranges[index] = [float(selection_range[0]), float(selection_range[1])]
	else:
		slot_selection_ranges.erase(index)

func _selection_for_slot(slot: Node) -> Array:
	var index = _slot_index(slot)
	if index < 0:
		return []
	return slot_selection_ranges.get(index, [])

func _sync_selection_bar_from_active_slot() -> void:
	if selection_bar == null or active_slot == null:
		return
	if active_slot.has_method("get_roll_params"):
		var params = active_slot.call("get_roll_params")
		if params is Dictionary and not params.is_empty():
			selection_bar.call(
				"update_from_roll",
				float(params.get("ppb", 0.0)),
				int(params.get("beats", 0)),
				float(params.get("scroll_x", 0.0)),
				float(params.get("view_width", 0.0))
			)
	_sync_selection_bar_spacers(active_slot)
	var selection_range = _selection_for_slot(active_slot)
	if selection_range.size() == 2:
		selection_bar.call("set_selection", float(selection_range[0]), float(selection_range[1]))
		if active_slot.has_method("set_selection_range"):
			active_slot.call("set_selection_range", float(selection_range[0]), float(selection_range[1]))
	elif selection_bar.has_method("clear_selection"):
		selection_bar.call("clear_selection")
		if active_slot.has_method("set_selection_range"):
			active_slot.call("set_selection_range", -1.0, -1.0)

func _sync_selection_bar_spacers(slot: Node) -> void:
	if slot == null:
		return
	if selection_bar_spacer != null and slot.has_method("get_keyboard_width"):
		selection_bar_spacer.custom_minimum_size.x = max(0.0, float(slot.call("get_keyboard_width")))
	if selection_bar_right_spacer != null and slot.has_method("get_roll_right_padding"):
		selection_bar_right_spacer.custom_minimum_size.x = max(0.0, float(slot.call("get_roll_right_padding")))

func _update_history_buttons() -> void:
	if history_back_button == null or history_forward_button == null:
		return
	var can_back = false
	var can_forward = false
	if active_slot != null:
		if active_slot.has_method("can_history_back"):
			can_back = bool(active_slot.call("can_history_back"))
		if active_slot.has_method("can_history_forward"):
			can_forward = bool(active_slot.call("can_history_forward"))
	history_back_button.disabled = not can_back
	history_forward_button.disabled = not can_forward

func _on_selection_bar_height_changed(_height: float) -> void:
	_update_selection_bar_layout()

func _on_split_container_dragged(_offset: int) -> void:
	_split_dragging = true
	_split_drag_frame = Engine.get_process_frames()

func _on_panel_split_resized() -> void:
	if _split_dragging:
		return
	_update_selection_bar_layout()

func _flush_split_drag() -> void:
	if not _split_dragging:
		return
	var frame = Engine.get_process_frames()
	if frame <= _split_drag_frame + 1:
		return
	_split_dragging = false
	_update_selection_bar_layout()

func _update_selection_bar_layout() -> void:
	if panel_split == null or panel_split_container == null or selection_bar_row == null or panel_slot_a == null:
		return
	var bar_height = selection_bar_row.custom_minimum_size.y
	if bar_height <= 0.0:
		bar_height = selection_bar_row.size.y
	if bar_height <= 0.0:
		bar_height = 18.0
	var separation = bar_height + (SELECTION_BAR_GAP * 2.0)
	panel_split_container.add_theme_constant_override("separation", int(round(separation)))
	if panel_fullscreen_enabled:
		if not panel_fullscreen_refreshing:
			_apply_panel_fullscreen_split_offset(separation)
			panel_fullscreen_refreshing = true
			call_deferred("_update_selection_bar_layout")
			return
		panel_fullscreen_refreshing = false
	if panel_split.size.x <= 0.0:
		return
	var panel_height = panel_slot_a.size.y
	var y_offset = panel_height + ((separation - bar_height) * 0.5)
	var max_y = max(0.0, panel_split.size.y - bar_height)
	selection_bar_row.position = Vector2(0.0, clamp(y_offset, 0.0, max_y))
	selection_bar_row.custom_minimum_size.y = bar_height
	_update_slot_scroll_visibility()
	_update_panel_collapsed(separation)
	for slot in [panel_slot_a, panel_slot_b]:
		if slot != null and slot.has_method("refresh_layout_metrics"):
			slot.call_deferred("refresh_layout_metrics")

func _toggle_panel_fullscreen() -> void:
	if panel_fullscreen_enabled:
		_exit_panel_fullscreen()
	else:
		_enter_panel_fullscreen(active_slot)

func _enter_panel_fullscreen(slot: Node) -> void:
	if panel_split_container == null or slot == null:
		return
	panel_fullscreen_enabled = true
	panel_fullscreen_slot = slot
	panel_fullscreen_split_offset = panel_split_container.split_offset
	_store_panel_fullscreen_ui_state()
	_apply_panel_fullscreen_ui_state()
	_update_selection_bar_layout()

func _exit_panel_fullscreen() -> void:
	if panel_split_container == null:
		return
	panel_fullscreen_enabled = false
	panel_fullscreen_slot = null
	panel_split_container.split_offset = panel_fullscreen_split_offset
	_restore_panel_fullscreen_ui_state()
	if panel_slot_a != null and panel_slot_a.has_method("set_collapsed"):
		panel_slot_a.call("set_collapsed", false)
	if panel_slot_b != null and panel_slot_b.has_method("set_collapsed"):
		panel_slot_b.call("set_collapsed", false)
	_update_selection_bar_layout()

func _apply_panel_fullscreen_split_offset(separation: float) -> void:
	if panel_split_container == null or panel_fullscreen_slot == null:
		return
	var available = max(0.0, panel_split_container.size.y - separation)
	var offset = int(round(available * 0.5))
	panel_split_container.split_offset = offset if panel_fullscreen_slot == panel_slot_a else -offset
	panel_split_container.queue_sort()

func _store_panel_fullscreen_ui_state() -> void:
	if not panel_fullscreen_ui_state.is_empty():
		return
	var offsets = {
		"left": root_layout.offset_left if root_layout != null else 0.0,
		"top": root_layout.offset_top if root_layout != null else 0.0,
		"right": root_layout.offset_right if root_layout != null else 0.0,
		"bottom": root_layout.offset_bottom if root_layout != null else 0.0
	}
	panel_fullscreen_ui_state = {
		"root_offsets": offsets,
		"top_bar_visible": top_bar.visible if top_bar != null else true,
		"browser_visible": browser_panel.visible if browser_panel != null else true,
		"transport_visible": transport_panel.visible if transport_panel != null else true,
		"main_split_offset": main_split.split_offset if main_split != null else 0,
		"right_split_offset": right_split.split_offset if right_split != null else 0
	}

func _apply_panel_fullscreen_ui_state() -> void:
	if root_layout != null:
		root_layout.offset_left = 0.0
		root_layout.offset_top = 0.0
		root_layout.offset_right = 0.0
		root_layout.offset_bottom = 0.0
	if top_bar != null:
		top_bar.visible = false
	if browser_panel != null:
		browser_panel.visible = false
	if transport_panel != null:
		transport_panel.visible = false
	_apply_panel_fullscreen_split_containers()

func _restore_panel_fullscreen_ui_state() -> void:
	if panel_fullscreen_ui_state.is_empty():
		return
	var offsets = panel_fullscreen_ui_state.get("root_offsets", {})
	if root_layout != null and offsets is Dictionary:
		root_layout.offset_left = float(offsets.get("left", root_layout.offset_left))
		root_layout.offset_top = float(offsets.get("top", root_layout.offset_top))
		root_layout.offset_right = float(offsets.get("right", root_layout.offset_right))
		root_layout.offset_bottom = float(offsets.get("bottom", root_layout.offset_bottom))
	if top_bar != null:
		top_bar.visible = bool(panel_fullscreen_ui_state.get("top_bar_visible", true))
	if browser_panel != null:
		browser_panel.visible = bool(panel_fullscreen_ui_state.get("browser_visible", true))
	if transport_panel != null:
		transport_panel.visible = bool(panel_fullscreen_ui_state.get("transport_visible", true))
	if main_split != null:
		main_split.split_offset = int(panel_fullscreen_ui_state.get("main_split_offset", main_split.split_offset))
	if right_split != null:
		right_split.split_offset = int(panel_fullscreen_ui_state.get("right_split_offset", right_split.split_offset))
	panel_fullscreen_ui_state.clear()

func _apply_panel_fullscreen_split_containers() -> void:
	if main_split != null:
		var width = main_split.size.x
		if width > 0.0:
			main_split.split_offset = -int(round(width * 0.5))
		else:
			call_deferred("_apply_panel_fullscreen_split_containers")
			return
	if right_split != null:
		var height = right_split.size.y
		if height > 0.0:
			right_split.split_offset = -int(round(height * 0.5))
		else:
			call_deferred("_apply_panel_fullscreen_split_containers")

func _update_slot_scroll_visibility() -> void:
	if panel_slot_a != null and panel_slot_a.has_method("update_h_scroll_visibility_for_height"):
		panel_slot_a.call("update_h_scroll_visibility_for_height", panel_slot_a.size.y)
	if panel_slot_b != null and panel_slot_b.has_method("update_h_scroll_visibility_for_height"):
		panel_slot_b.call("update_h_scroll_visibility_for_height", panel_slot_b.size.y)

func _update_panel_collapsed(separation: float) -> void:
	if panel_split_container == null:
		return
	var available = max(0.0, panel_split_container.size.y - separation)
	var split_offset = float(panel_split_container.split_offset)
	var first_size = clamp((available * 0.5) + split_offset, 0.0, available)
	var second_size = max(0.0, available - first_size)
	var collapse_top = first_size <= PANEL_COLLAPSE_THRESHOLD
	var collapse_bottom = second_size <= PANEL_COLLAPSE_THRESHOLD
	if panel_slot_a != null and panel_slot_a.has_method("set_collapsed"):
		panel_slot_a.call("set_collapsed", collapse_top)
	if panel_slot_b != null and panel_slot_b.has_method("set_collapsed"):
		panel_slot_b.call("set_collapsed", collapse_bottom)

func _on_project_model_changed() -> void:
	if _pending_track_refresh:
		return
	_pending_track_refresh = true
	call_deferred("_flush_project_model_changed")

func _flush_project_model_changed() -> void:
	_pending_track_refresh = false
	_refresh_track_list()
	_update_name_edits()
	_sync_track_list_to_active_slot()
	_update_soundfont_button()
	if shared_scroll_enabled:
		_update_shared_view_beats()

func _set_active_slot(slot: Node) -> void:
	if slot == null:
		return
	if selection_bar != null and active_slot != null and selection_bar.has_method("get_selection_range"):
		_store_selection_for_slot(active_slot, selection_bar.call("get_selection_range"))
	active_slot = slot
	if panel_slot_a != null and panel_slot_a.has_method("set_focus_highlight"):
		panel_slot_a.call("set_focus_highlight", active_slot == panel_slot_a)
	if panel_slot_b != null and panel_slot_b.has_method("set_focus_highlight"):
		panel_slot_b.call("set_focus_highlight", active_slot == panel_slot_b)
	_sync_track_list_to_active_slot()
	_update_name_edits()
	_sync_selection_bar_from_active_slot()
	_sync_selection_snap_from_active_roll()
	_update_selection_snap_label()
	_update_history_buttons()
	_update_soundfont_button()

func _on_slot_focused(slot_index: int) -> void:
	var slot = _slot_by_index(slot_index)
	if slot != null:
		_set_active_slot(slot)

func _on_slot_scroll_x_changed(slot_index: int, scroll_x: float, _view_width: float) -> void:
	if active_slot == _slot_by_index(slot_index):
		_sync_selection_bar_from_active_slot()
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
		_sync_selection_bar_from_active_slot()
		_update_soundfont_button()
	if shared_scroll_enabled:
		_update_shared_view_beats()

func _on_slot_clip_changed(slot_index: int, _clip_index: int) -> void:
	if active_slot == _slot_by_index(slot_index):
		_update_name_edits()
		_sync_selection_bar_from_active_slot()
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
	_sync_selection_bar_from_active_slot()

func _on_selection_snap_pressed() -> void:
	if selection_bar == null or not selection_bar.has_method("toggle_snap"):
		return
	var enabled = bool(selection_bar.call("toggle_snap"))
	_update_selection_snap_label(enabled)
	_apply_snap_to_active_roll(enabled, selection_bar.call("get_snap_step") if selection_bar.has_method("get_snap_step") else -1.0)

func _update_selection_snap_label(force_enabled: Variant = null) -> void:
	if selection_snap_button == null:
		return
	var enabled = false
	if force_enabled is bool:
		enabled = force_enabled
	elif selection_bar != null and selection_bar.has_method("is_snap_enabled"):
		enabled = bool(selection_bar.call("is_snap_enabled"))
	selection_snap_button.text = ""
	selection_snap_button.icon = ICON_SNAP_ON if enabled else ICON_SNAP_OFF

func _on_slot_snap_changed(slot_index: int, enabled: bool, step: float) -> void:
	if active_slot != _slot_by_index(slot_index):
		return
	if selection_bar != null and selection_bar.has_method("set_snap_enabled"):
		selection_bar.call("set_snap_enabled", enabled)
	if selection_bar != null and selection_bar.has_method("set_snap_step") and step > 0.0:
		selection_bar.call("set_snap_step", step)
	_update_selection_snap_label(enabled)

func _sync_selection_snap_from_active_roll() -> void:
	if selection_bar == null or active_slot == null:
		return
	var roll = active_slot.call("get_roll") if active_slot.has_method("get_roll") else null
	if roll == null:
		return
	var controller = roll.get_node_or_null("InputController")
	if controller == null:
		return
	var enabled = bool(controller.call("is_snap_enabled")) if controller.has_method("is_snap_enabled") else false
	if selection_bar.has_method("set_snap_enabled"):
		selection_bar.call("set_snap_enabled", enabled)
	if selection_bar.has_method("set_snap_step") and controller.has_method("get_snap_step"):
		var step = float(controller.call("get_snap_step"))
		if step > 0.0:
			selection_bar.call("set_snap_step", step)
	_update_selection_snap_label(enabled)

func _apply_snap_to_active_roll(enabled: bool, step: float) -> void:
	if active_slot == null:
		return
	var roll = active_slot.call("get_roll") if active_slot.has_method("get_roll") else null
	if roll == null:
		return
	var controller = roll.get_node_or_null("InputController")
	if controller == null:
		return
	if controller.has_method("toggle_snap"):
		var current = bool(controller.call("is_snap_enabled")) if controller.has_method("is_snap_enabled") else false
		if current != enabled:
			controller.call("toggle_snap")
		if enabled and step > 0.0 and controller.has_method("get_snap_step"):
			var safety := 0
			while safety < 8 and not is_equal_approx(float(controller.call("get_snap_step")), step):
				controller.call("cycle_snap_step")
				safety += 1

func _on_selection_committed(start_beats: float, end_beats: float) -> void:
	if active_slot == null:
		return
	_store_selection_for_slot(active_slot, [start_beats, end_beats])
	if active_slot.has_method("set_selection_range"):
		active_slot.call("set_selection_range", start_beats, end_beats)
	if active_slot.has_method("handle_selection_committed"):
		active_slot.call("handle_selection_committed", start_beats, end_beats)
	elif active_slot.has_method("_on_selection_committed"):
		active_slot.call("_on_selection_committed", start_beats, end_beats)

func _on_selection_cleared() -> void:
	if active_slot == null:
		return
	_store_selection_for_slot(active_slot, [])
	if active_slot.has_method("set_selection_range"):
		active_slot.call("set_selection_range", -1.0, -1.0)

func _on_arrangement_selection_preview(slot_index: int, start_beats: float, end_beats: float) -> void:
	var slot = _slot_by_index(slot_index)
	if slot == null:
		return
	_set_active_slot(slot)
	if selection_bar != null and selection_bar.has_method("set_selection"):
		selection_bar.call("set_selection", start_beats, end_beats)

func _on_arrangement_selection_committed(slot_index: int, start_beats: float, end_beats: float) -> void:
	var slot = _slot_by_index(slot_index)
	if slot == null:
		return
	_set_active_slot(slot)
	if selection_bar != null and selection_bar.has_method("set_selection"):
		selection_bar.call("set_selection", start_beats, end_beats)
	_on_selection_committed(start_beats, end_beats)

func _on_selection_double_clicked(start_beats: float, end_beats: float) -> void:
	if active_slot == null:
		return
	var other_slot = panel_slot_b if active_slot == panel_slot_a else panel_slot_a
	if other_slot == null:
		return
	var track_index = int(active_slot.call("get_active_track_index"))
	var clip_index = int(active_slot.call("get_active_clip_index"))
	other_slot.call("select_track", track_index)
	other_slot.call("select_clip", clip_index)
	other_slot.call("open_comment_range", start_beats, end_beats)

func _on_history_back_pressed() -> void:
	if active_slot == null:
		return
	if active_slot.has_method("history_back"):
		active_slot.call("history_back")
		_sync_selection_bar_from_active_slot()
		_update_history_buttons()

func _on_history_forward_pressed() -> void:
	if active_slot == null:
		return
	if active_slot.has_method("history_forward"):
		active_slot.call("history_forward")
		_sync_selection_bar_from_active_slot()
		_update_history_buttons()

func _on_panel_sync_pressed() -> void:
	if active_slot == null:
		return
	if not active_slot.has_method("get_panel_mode"):
		return
	var mode = String(active_slot.call("get_panel_mode"))
	if DEBUG_SYNC:
		print("PanelSync: active_mode=", mode)
	if not _is_syncable_panel_mode(mode):
		return
	var is_step = mode == "step"
	if not is_step and active_slot.has_method("is_step_lane_visible"):
		is_step = bool(active_slot.call("is_step_lane_visible"))
	var step_pitch = 60.0
	if is_step and active_slot.has_method("get_step_pitch"):
		step_pitch = float(active_slot.call("get_step_pitch"))
	var target_slot = panel_slot_b if active_slot == panel_slot_a else panel_slot_a
	if target_slot == null:
		return
	if DEBUG_SYNC:
		print("PanelSync: target_slot=", target_slot.name if target_slot else "null")
	if target_slot.has_method("select_track") and active_slot.has_method("get_active_track_index"):
		target_slot.call("select_track", int(active_slot.call("get_active_track_index")))
	if target_slot.has_method("select_clip") and active_slot.has_method("get_active_clip_index"):
		target_slot.call("select_clip", int(active_slot.call("get_active_clip_index")))
	if target_slot.has_method("set_panel_mode"):
		target_slot.call("set_panel_mode", "roll")
	_enable_shared_scroll()
	_apply_panel_sync_vertical(active_slot, target_slot, is_step, step_pitch)

func _is_syncable_panel_mode(mode: String) -> bool:
	return mode == "envelope" or mode == "comment" or mode == "step"

func _enable_shared_scroll() -> void:
	if shared_scroll_button != null:
		shared_scroll_button.button_pressed = true
	shared_scroll_enabled = true
	_update_shared_scroll_label()
	_apply_shared_scroll()

func _apply_panel_sync_vertical(source_slot: Node, target_slot: Node, is_step: bool, step_pitch: float) -> void:
	if source_slot == null or target_slot == null:
		return
	if DEBUG_SYNC:
		print("PanelSync: is_step=", is_step)
	if is_step:
		if not target_slot.has_method("center_roll_on_pitch"):
			return
		if DEBUG_SYNC:
			print("PanelSync: step_pitch=", step_pitch)
		target_slot.call_deferred("center_roll_on_pitch", step_pitch)
		return
	if not target_slot.has_method("align_roll_top_to_pitch"):
		return
	var pitch_range: Dictionary = {}
	if source_slot.has_method("get_notes_pitch_range"):
		pitch_range = source_slot.call("get_notes_pitch_range")
	if pitch_range.is_empty() and source_slot.has_method("get_roll_pitch_bounds"):
		pitch_range = source_slot.call("get_roll_pitch_bounds")
	if pitch_range.is_empty():
		return
	var max_pitch = float(pitch_range.get("max", 0))
	target_slot.call_deferred("align_roll_top_to_pitch", max_pitch)

func _refresh_track_list() -> void:
	if track_tree == null:
		return
	updating_track_list = true
	track_tree.clear()
	tree_item_by_track_id.clear()
	tree_item_by_clip_id.clear()
	_track_tree_build_root = track_tree.create_item()
	_track_tree_build_root.set_text(0, _project_label())
	_track_tree_build_root.set_metadata(0, {"type": "project"})
	var add_track_item = track_tree.create_item(_track_tree_build_root)
	add_track_item.set_text(0, "+ Add Track")
	add_track_item.set_custom_color(0, Color(0.6, 0.85, 0.6))
	add_track_item.set_metadata(0, {"type": "add_track"})
	_track_tree_build_tracks = project_model.tracks.duplicate() if project_model != null else []
	_track_tree_build_index = 0
	_track_tree_building = true
	if _track_tree_build_tracks.is_empty():
		_finish_track_tree_build()

func _process_track_tree_build() -> void:
	if not _track_tree_building:
		return
	var start_ms = Time.get_ticks_msec()
	while _track_tree_build_index < _track_tree_build_tracks.size():
		var i = _track_tree_build_index
		var track = _track_tree_build_tracks[i]
		_build_track_tree_item(i, track, _track_tree_build_root)
		_track_tree_build_index += 1
		if Time.get_ticks_msec() - start_ms >= TRACK_TREE_BUILD_BUDGET_MS:
			return
	_finish_track_tree_build()

func _finish_track_tree_build() -> void:
	_track_tree_building = false
	_track_tree_build_tracks.clear()
	_track_tree_build_root = null
	updating_track_list = false
	_sync_track_list_to_active_slot()
	if _import_block_hold:
		_import_block_hold = false
		_update_loading_state()
		_update_input_blocking()

func _build_track_tree_item(track_index: int, track: Node, root: TreeItem) -> void:
	var label = "Track %d" % (track_index + 1)
	if track != null:
		label = str(track.track_name)
	var track_item = track_tree.create_item(root)
	track_item.set_text(0, label)
	var track_id = ""
	if track != null:
		track_id = track.id
	track_item.set_metadata(0, {
		"type": "track",
		"track_index": track_index,
		"track_id": track_id
	})
	if track_id != "":
		tree_item_by_track_id[track_id] = track_item
	var soundfont_item = track_tree.create_item(track_item)
	soundfont_item.set_text(0, _soundfont_label_for_track(track))
	soundfont_item.set_custom_color(0, Color(0.7, 0.8, 0.7))
	soundfont_item.set_metadata(0, {
		"type": "soundfont",
		"track_index": track_index
	})
	var clips_item = track_tree.create_item(track_item)
	clips_item.set_text(0, "Clips")
	clips_item.set_custom_color(0, Color(0.7, 0.7, 0.85))
	clips_item.set_metadata(0, {
		"type": "clips",
		"track_index": track_index
	})
	var add_clip_item = track_tree.create_item(clips_item)
	add_clip_item.set_text(0, "+ Add Clip")
	add_clip_item.set_custom_color(0, Color(0.6, 0.85, 0.6))
	add_clip_item.set_metadata(0, {
		"type": "add_clip",
		"track_index": track_index
	})
	var clips: Array = []
	if track != null and track.has_method("get"):
		clips = track.clips
	for j in range(clips.size()):
		var clip = clips[j]
		var clip_label = "Clip %d" % (j + 1)
		if clip != null and str(clip.clip_name) != "":
			clip_label = str(clip.clip_name)
		var clip_item = track_tree.create_item(clips_item)
		clip_item.set_text(0, clip_label)
		if clip != null and clip.has_method("get") and not bool(clip.get("is_used")):
			clip_item.set_custom_color(0, Color(0.65, 0.65, 0.7))
		clip_item.set_metadata(0, {
			"type": "clip",
			"track_index": track_index,
			"clip_index": j,
			"clip": clip,
			"clip_id": clip.id
		})
		tree_item_by_clip_id[clip.id] = clip_item
		var params: Array = []
		if clip != null and clip.has_method("get_param_names"):
			params = clip.call("get_param_names")
		params.sort()
		for param in params:
			var param_name = String(param)
			var param_label = _automation_label(param_name)
			var automation_item = track_tree.create_item(clip_item)
			automation_item.set_text(0, "Auto: %s" % param_label)
			automation_item.set_custom_color(0, Color(0.6, 0.7, 0.85, 0.85))
			automation_item.set_metadata(0, {
				"type": "automation",
				"track_index": track_index,
				"clip_index": j,
				"clip": clip,
				"param": param_name
			})

func _automation_label(param_name: String) -> String:
	var slot = panel_slot_a if panel_slot_a != null else panel_slot_b
	if slot != null and slot.has_method("get_param_display_name"):
		return String(slot.call("get_param_display_name", param_name))
	return param_name

func _sync_track_list_to_active_slot() -> void:
	if track_tree == null or active_slot == null:
		return
	var index = int(active_slot.call("get_active_track_index"))
	if index < 0 or project_model == null or index >= project_model.tracks.size():
		return
	updating_track_list = true
	var track = project_model.tracks[index]
	var track_item = tree_item_by_track_id.get(track.id)
	if track_item != null:
		track_tree.set_selected(track_item, 0)
		track_tree.ensure_cursor_is_visible()
	var clip_index = int(active_slot.call("get_active_clip_index"))
	if clip_index >= 0 and clip_index < track.clips.size():
		var clip = track.clips[clip_index]
		var clip_item = tree_item_by_clip_id.get(clip.id)
		if clip_item != null:
			track_tree.set_selected(clip_item, 0)
			track_tree.ensure_cursor_is_visible()
	updating_track_list = false

func _on_track_tree_track_selected(index: int) -> void:
	if updating_track_list or active_slot == null:
		return
	active_slot.call("select_track", index)

func _on_track_tree_clip_selected(track_index: int, clip_index: int, _clip: Node) -> void:
	if updating_track_list or active_slot == null:
		return
	active_slot.call("select_track", track_index)
	active_slot.call("select_clip", clip_index)

func _on_track_tree_automation_selected(track_index: int, clip_index: int, clip: Node, param_name: String) -> void:
	if updating_track_list:
		return
	var slot = active_slot if active_slot != null else panel_slot_a
	if slot == null:
		return
	_set_active_slot(slot)
	if slot.has_method("select_track"):
		slot.call("select_track", track_index)
	if slot.has_method("select_clip"):
		slot.call("select_clip", clip_index)
	if slot.has_method("set_panel_mode"):
		slot.call("set_panel_mode", "envelope")
	if clip != null and clip.has_method("ensure_param"):
		clip.call("ensure_param", param_name)
	if slot.has_method("select_envelope_param"):
		slot.call("select_envelope_param", param_name)

func _on_track_tree_soundfont_selected(track_index: int) -> void:
	if updating_track_list or active_slot == null:
		return
	active_slot.call("select_track", track_index)
	_on_soundfont_pressed()

func _on_track_tree_add_track_selected() -> void:
	if updating_track_list:
		return
	_on_add_track_pressed()

func _on_track_tree_add_clip_selected(track_index: int) -> void:
	if updating_track_list:
		return
	var slot = active_slot if active_slot != null else panel_slot_a
	if slot != null and slot.has_method("add_clip_for_track"):
		slot.call("add_clip_for_track", track_index)

func _on_browser_clip_drag_started(_track_index: int, _clip_index: int, _clip: Node) -> void:
	var hovered_slot = active_slot if active_slot != null else panel_slot_a
	var target_slot = panel_slot_b if hovered_slot == panel_slot_a else panel_slot_a
	if target_slot == null:
		return
	var hovered_is_arrangement = hovered_slot != null and hovered_slot.has_method("get_panel_mode") and hovered_slot.call("get_panel_mode") == "arrangement"
	var target_is_arrangement = target_slot.has_method("get_panel_mode") and target_slot.call("get_panel_mode") == "arrangement"
	if hovered_is_arrangement or target_is_arrangement:
		var arrangement_slot = hovered_slot if hovered_is_arrangement else target_slot
		if arrangement_slot != null:
			if arrangement_slot.has_method("prepare_arrangement_zoom_fit"):
				arrangement_slot.call("prepare_arrangement_zoom_fit")
			elif arrangement_slot.has_method("set_arrangement_zoom_fit"):
				arrangement_slot.call("set_arrangement_zoom_fit")
		return
	if target_slot.has_method("set_panel_mode"):
		target_slot.call("set_panel_mode", "arrangement")
	if target_slot.has_method("set_arrangement_zoom_fit"):
		target_slot.call("set_arrangement_zoom_fit")

func _on_browser_clip_drag_ended() -> void:
	pass

func _on_import_midi_pressed() -> void:
	if midi_import_dialog == null:
		return
	midi_import_dialog.popup_centered_ratio(0.6)

func _on_midi_import_file_selected(path: String) -> void:
	if _midi_import_thread != null or _midi_build_project != null:
		push_warning("MIDI import already running.")
		return
	_start_midi_import(path)

func _set_importing(active: bool) -> void:
	if active:
		_importing_count += 1
	else:
		_importing_count = max(0, _importing_count - 1)
	_update_import_mute()
	_update_loading_state()
	_update_input_blocking()

func _update_import_mute() -> void:
	var bus_index = AudioServer.get_bus_index("Master")
	if bus_index < 0:
		return
	if _importing_master_muted:
		AudioServer.set_bus_volume_db(bus_index, _importing_prev_master_db)
		_importing_master_muted = false

func _is_import_blocking() -> bool:
	return _importing_count > 0 or _import_block_hold

func _update_input_blocking() -> void:
	var viewport = get_viewport()
	if viewport == null:
		return
	viewport.gui_disable_input = _is_import_blocking()

func _update_loading_state() -> void:
	if loading_overlay == null:
		return
	var now = Time.get_ticks_msec()
	var wants_loading = _is_import_blocking()
	if wants_loading:
		_loading_hide_deadline_ms = 0
		if _loading_visible:
			_loading_show_deadline_ms = 0
		else:
			if _loading_show_deadline_ms == 0:
				_loading_show_deadline_ms = now + _loading_delay_ms
			if now >= _loading_show_deadline_ms:
				_show_loading_overlay(now)
		_update_loading_progress()
		return
	_loading_show_deadline_ms = 0
	if _loading_visible:
		if _loading_hide_deadline_ms == 0:
			_loading_hide_deadline_ms = max(now, _loading_visible_since_ms + _loading_min_ms)
		if now >= _loading_hide_deadline_ms:
			_hide_loading_overlay()
	else:
		_loading_hide_deadline_ms = 0
	_update_loading_progress()

func _update_loading_progress() -> void:
	if loading_bar == null:
		return
	if _midi_build_project != null:
		if _midi_build_total_units > 0:
			loading_bar.max_value = float(_midi_build_total_units)
			loading_bar.value = float(_midi_build_units_done)
		elif _midi_build_entries.size() > 0:
			loading_bar.max_value = float(_midi_build_entries.size())
			loading_bar.value = float(_midi_build_index)
		else:
			loading_bar.max_value = 100.0
			loading_bar.value = 0.0
		return
	loading_bar.max_value = 100.0
	loading_bar.value = 0.0

func _show_loading_overlay(now_ms: int) -> void:
	if _loading_visible:
		return
	_loading_visible = true
	_loading_visible_since_ms = now_ms
	_loading_hide_deadline_ms = 0
	loading_overlay.visible = true
	if loading_label != null:
		loading_label.text = "loading"

func _hide_loading_overlay() -> void:
	if not _loading_visible:
		return
	_loading_visible = false
	_loading_visible_since_ms = 0
	_loading_show_deadline_ms = 0
	_loading_hide_deadline_ms = 0
	loading_overlay.visible = false

func _start_midi_import(path: String) -> void:
	_set_importing(true)
	_midi_import_path = path
	var thread = Thread.new()
	var callable = Callable(self, "_thread_import_midi").bind(path)
	var result = thread.start(callable)
	if result != OK:
		_handle_midi_import_result(_import_midi_sync(path))
		return
	_midi_import_thread = thread

func _thread_import_midi(path: String) -> Dictionary:
	var importer = MIDI_IMPORTER.new()
	return importer.import_project_data(path)

func _import_midi_sync(path: String) -> Dictionary:
	var importer = MIDI_IMPORTER.new()
	return importer.import_project_data(path)

func _poll_midi_import_thread() -> void:
	if _midi_import_thread == null:
		return
	if not _thread_is_finished(_midi_import_thread):
		return
	var result = _midi_import_thread.wait_to_finish()
	_midi_import_thread = null
	if result is Dictionary:
		_handle_midi_import_result(result)
	else:
		_handle_midi_import_result({})

func _thread_is_finished(thread: Thread) -> bool:
	if thread == null:
		return true
	if thread.has_method("is_alive"):
		return not thread.call("is_alive")
	if thread.has_method("is_started"):
		return not thread.call("is_started")
	if thread.has_method("is_active"):
		return not thread.call("is_active")
	return true

func _handle_midi_import_result(data: Dictionary) -> void:
	if data.is_empty():
		push_warning("MIDI import failed: %s" % _midi_import_path)
		_set_importing(false)
		return
	_start_midi_import_build(data)

func _start_midi_import_build(data: Dictionary) -> void:
	var importer = MIDI_IMPORTER.new()
	var build_entries = importer.prepare_build_entries(data)
	var project = PROJECT_MODEL.new()
	var transport = project.transport
	if transport != null:
		var tempo_events: Array = data.get("tempo_events", [])
		var signature_events: Array = data.get("signature_events", [])
		if transport.has_method("set_tempo_events"):
			transport.call("set_tempo_events", tempo_events)
		if transport.has_method("set_time_signature_events"):
			transport.call("set_time_signature_events", signature_events)
	_midi_build_importer = importer
	_midi_build_project = project
	_midi_build_entries = build_entries
	_midi_build_index = 0
	_midi_build_current_entry = {}
	_midi_build_current_track = null
	_midi_build_current_clip = null
	_midi_build_note_index = 0
	_midi_build_cc_index = 0
	_midi_build_units_done = 0
	_midi_build_total_units = 0
	for item in build_entries:
		var entry = item.get("entry", {})
		if entry is Dictionary:
			var notes: Array = entry.get("notes", [])
			var cc_events: Array = entry.get("cc", [])
			if notes is Array:
				_midi_build_total_units += notes.size()
			if cc_events is Array:
				_midi_build_total_units += cc_events.size()
	if build_entries.is_empty():
		_midi_build_project.create_track("Track 1")
		_finish_midi_import_build()

func _process_midi_import_build() -> void:
	if _midi_build_project == null:
		return
	var start_ms = Time.get_ticks_msec()
	var processed_units := 0
	while true:
		if _midi_build_index >= _midi_build_entries.size():
			_finish_midi_import_build()
			return
		if _midi_build_current_clip == null:
			var item = _midi_build_entries[_midi_build_index]
			_midi_build_current_entry = item.get("entry", {})
			var label = String(item.get("label", "Track"))
			_midi_build_current_track = _midi_build_project.create_track(label)
			_midi_build_current_clip = _create_import_clip(_midi_build_current_track)
			_midi_build_note_index = 0
			_midi_build_cc_index = 0
		var entry = _midi_build_current_entry
		var notes: Array = entry.get("notes", [])
		var cc_events: Array = entry.get("cc", [])
		while _midi_build_note_index < notes.size():
			var note = notes[_midi_build_note_index]
			var note_index = _midi_build_current_clip.notes.size()
			_midi_build_current_clip.add_note(
				int(note.get("pitch", 0)),
				float(note.get("start", 0.0)),
				float(note.get("duration", 0.0)),
				0
			)
			_midi_build_current_clip.update_velocity(note_index, int(note.get("velocity", 100)))
			_midi_build_note_index += 1
			_midi_build_units_done += 1
			processed_units += 1
			if processed_units >= MIDI_BUILD_UNITS_PER_FRAME or Time.get_ticks_msec() - start_ms >= MIDI_BUILD_BUDGET_MS:
				return
		while _midi_build_cc_index < cc_events.size():
			var cc = cc_events[_midi_build_cc_index]
			var param = "CC%d" % int(cc.get("number", 0))
			var value = clamp(float(cc.get("value", 0)) / 127.0, 0.0, 1.0)
			_midi_build_current_clip.set_point_for_param(param, float(cc.get("time", 0.0)), value, 0.0)
			_midi_build_cc_index += 1
			_midi_build_units_done += 1
			processed_units += 1
			if processed_units >= MIDI_BUILD_UNITS_PER_FRAME or Time.get_ticks_msec() - start_ms >= MIDI_BUILD_BUDGET_MS:
				return
		_midi_build_current_clip.clip_length_beats = max(1.0, float(entry.get("max_end_beats", 0.0)))
		_midi_build_current_clip.end_bulk_update()
		if _midi_build_current_track != null and _midi_build_current_track.has_method("add_clip"):
			_midi_build_current_track.call("add_clip", _midi_build_current_clip, 0.0, float(_midi_build_current_clip.clip_length_beats))
		_midi_build_current_clip = null
		_midi_build_current_track = null
		_midi_build_current_entry = {}
		_midi_build_index += 1
		if processed_units >= MIDI_BUILD_UNITS_PER_FRAME or Time.get_ticks_msec() - start_ms >= MIDI_BUILD_BUDGET_MS:
			return

func _create_import_clip(track: Node) -> Node:
	var clip = CLIP_MODEL.new()
	var clip_index = track.clips.size() if track != null else 0
	var track_id = track.id if track != null else "track"
	clip.id = "clip_%s_%d" % [str(track_id), clip_index + 1]
	clip.clip_name = "Clip 1"
	clip.clip_start_beats = 0.0
	clip.begin_bulk_update()
	return clip

func _finish_midi_import_build() -> void:
	var next_project = _midi_build_project
	_midi_build_project = null
	_midi_build_entries.clear()
	_midi_build_index = 0
	_midi_build_current_entry = {}
	_midi_build_current_track = null
	_midi_build_current_clip = null
	_midi_build_note_index = 0
	_midi_build_cc_index = 0
	_midi_build_total_units = 0
	_midi_build_units_done = 0
	_midi_build_importer = null
	if next_project == null:
		_set_importing(false)
		return
	if playback_engine != null and bool(playback_engine.call("get_is_playing")):
		playback_engine.call("pause")
	_replace_project_model(next_project, false)
	_set_playhead_for_playback(0.0)
	_import_block_hold = true
	_set_importing(false)

func _setup_midi_player() -> void:
	if midi_player == null:
		return
	if midi_player.has_signal("finished"):
		var finished_callable = Callable(self, "_on_midi_finished")
		if not midi_player.is_connected("finished", finished_callable):
			midi_player.connect("finished", finished_callable)

func _setup_midi_input() -> void:
	_detect_midi_device_field()
	OS.open_midi_inputs()
	_refresh_midi_devices()

func _detect_midi_device_field() -> void:
	var probe = InputEventMIDI.new()
	for prop in probe.get_property_list():
		if prop.get("name", "") == "device":
			_midi_has_device_field = true
			return
	_midi_has_device_field = false

func _refresh_midi_devices() -> void:
	_midi_device_names = OS.get_connected_midi_inputs()
	if midi_device_option == null:
		return
	midi_device_option.clear()
	midi_device_option.add_item("All Devices", -1)
	for i in range(_midi_device_names.size()):
		midi_device_option.add_item(String(_midi_device_names[i]), i)
	if _selected_midi_device_index < 0:
		midi_device_option.select(0)
		return
	for i in range(midi_device_option.item_count):
		if midi_device_option.get_item_id(i) == _selected_midi_device_index:
			midi_device_option.select(i)
			return
	midi_device_option.select(0)
	_selected_midi_device_index = -1

func _on_midi_refresh_pressed() -> void:
	OS.open_midi_inputs()
	_refresh_midi_devices()

func _on_midi_device_selected(index: int) -> void:
	if midi_device_option == null:
		return
	_selected_midi_device_index = midi_device_option.get_item_id(index)

func _setup_soundfont_manager() -> void:
	if soundfont_manager != null:
		return
	soundfont_manager = SOUNDFONT_MANAGER.new()
	soundfont_manager.name = "SoundfontManager"
	add_child(soundfont_manager)
	if soundfont_manager.has_method("register_base_player"):
		soundfont_manager.call("register_base_player", midi_player)
	if soundfont_manager.has_method("set_project_model"):
		soundfont_manager.call("set_project_model", project_model)
	if soundfont_manager.has_method("set_default_soundfont_path"):
		soundfont_manager.call("set_default_soundfont_path", soundfont_path)
	if playback_engine != null and playback_engine.has_method("set_track_router"):
		playback_engine.call("set_track_router", soundfont_manager)
	if panel_slot_a != null and panel_slot_a.has_method("set_soundfont_manager"):
		panel_slot_a.call("set_soundfont_manager", soundfont_manager)
	if panel_slot_b != null and panel_slot_b.has_method("set_soundfont_manager"):
		panel_slot_b.call("set_soundfont_manager", soundfont_manager)

func _setup_playback_engine() -> void:
	if playback_engine != null:
		return
	playback_engine = PLAYBACK_ENGINE.new()
	playback_engine.name = "PlaybackEngine"
	add_child(playback_engine)
	if playback_engine.has_method("setup"):
		playback_engine.call("setup", project_model, midi_player, soundfont_manager)
	elif soundfont_manager != null and playback_engine.has_method("set_track_router"):
		playback_engine.call("set_track_router", soundfont_manager)
	if playback_engine.has_signal("finished"):
		var finished_callable = Callable(self, "_on_playback_finished")
		if not playback_engine.is_connected("finished", finished_callable):
			playback_engine.connect("finished", finished_callable)

func _on_play_pressed() -> void:
	if playback_engine == null or project_model == null:
		return
	var mode = _resolve_playback_mode()
	playback_mode = mode
	playback_slot = active_slot if mode == PLAYBACK_MODE_CLIP else null
	var track_index = 0
	var clip_index = 0
	if active_slot != null and active_slot.has_method("get_active_track_index"):
		track_index = int(active_slot.call("get_active_track_index"))
	if active_slot != null and active_slot.has_method("get_active_clip_index"):
		clip_index = int(active_slot.call("get_active_clip_index"))
	playback_engine.call("set_playback_target", mode, track_index, clip_index)
	if mode == PLAYBACK_MODE_CLIP:
		_set_arrangement_playhead_time(-1.0)
	var start_beats = _get_playhead_start_beats(mode)
	_set_playhead_for_playback(start_beats)
	playback_engine.call("play", start_beats)

func _on_pause_pressed() -> void:
	if playback_engine == null:
		return
	if bool(playback_engine.call("get_is_playing")):
		playback_engine.call("pause")
	else:
		playback_engine.call("resume")

func _on_stop_pressed() -> void:
	if playback_engine == null:
		return
	playback_engine.call("stop")
	_set_playhead_for_playback(0.0)

func _toggle_transport_playback() -> void:
	if playback_engine == null:
		return
	if bool(playback_engine.call("get_is_playing")):
		_on_pause_pressed()
		return
	_on_play_pressed()

func _on_soundfont_pressed() -> void:
	if soundfont_dialog == null:
		return
	var current_path = _resolve_active_soundfont_path()
	if current_path != "":
		soundfont_dialog.current_path = current_path
	soundfont_dialog.popup_centered_ratio(0.6)

func _on_soundfont_file_selected(path: String) -> void:
	if path == "":
		return
	if not _is_soundfont_path_valid(path):
		push_warning("SoundFont not found: %s" % path)
		return
	call_deferred("_apply_soundfont_selection", path)

func _apply_soundfont_selection(path: String) -> void:
	soundfont_path = path
	_apply_soundfont()
	_update_soundfont_button()

func _on_soundfont_load_started(_path: String) -> void:
	pass

func _on_soundfont_load_finished(_path: String, _success: bool) -> void:
	pass

func _apply_soundfont() -> void:
	var track = _get_active_track()
	if track != null and track.has_method("set_soundfont_path"):
		track.call("set_soundfont_path", soundfont_path)
	if soundfont_manager != null and soundfont_manager.has_method("set_default_soundfont_path"):
		soundfont_manager.call("set_default_soundfont_path", soundfont_path)
	elif midi_player != null and midi_player.has_method("set_soundfont") and _is_soundfont_path_valid(soundfont_path):
		midi_player.call("set_soundfont", soundfont_path)

func _update_soundfont_button() -> void:
	if soundfont_button == null:
		return
	soundfont_button.text = "SF"
	var track_path = _get_active_track_soundfont_path()
	var resolved_path = _resolve_active_soundfont_path()
	var label = resolved_path.get_file() if resolved_path != "" else ""
	if _is_soundfont_path_valid(track_path):
		soundfont_button.tooltip_text = "SoundFont (Track): %s" % label
	elif label != "":
		soundfont_button.tooltip_text = "SoundFont (Default): %s" % label
	else:
		soundfont_button.tooltip_text = "SoundFont"

func _get_active_track() -> Node:
	if active_slot != null and active_slot.has_method("get_active_track"):
		return active_slot.call("get_active_track")
	return null

func _track_by_index(track_index: int) -> Node:
	if project_model == null:
		return null
	if track_index < 0 or track_index >= project_model.tracks.size():
		return null
	return project_model.tracks[track_index]

func _get_active_track_soundfont_path() -> String:
	var track = _get_active_track()
	if track != null and track.has_method("get"):
		return str(track.get("soundfont_path"))
	return ""

func _soundfont_label_for_track(track: Node) -> String:
	var track_path := ""
	if track != null and track.has_method("get"):
		track_path = str(track.get("soundfont_path"))
	if track_path != "":
		var file_name = track_path.get_file()
		if _is_soundfont_path_valid(track_path):
			return "SF: %s" % file_name
		return "SF: (missing) %s" % file_name
	if _is_soundfont_path_valid(soundfont_path):
		return "SF: (default) %s" % soundfont_path.get_file()
	return "SF: (none)"

func _project_label() -> String:
	if project_model == null:
		return "Project"
	var label = str(project_model.name)
	if label == "" or label == "ProjectModel":
		return "Project"
	return label

func _resolve_active_soundfont_path() -> String:
	var track_path = _get_active_track_soundfont_path()
	if _is_soundfont_path_valid(track_path):
		return track_path
	if _is_soundfont_path_valid(soundfont_path):
		return soundfont_path
	return ""

func _is_soundfont_path_valid(path: String) -> bool:
	return path != "" and FileAccess.file_exists(path)

func _resolve_playback_mode() -> String:
	if active_slot != null and active_slot.has_method("get_panel_mode"):
		var mode = String(active_slot.call("get_panel_mode"))
		if mode == "arrangement":
			return PLAYBACK_MODE_TRACKS
	return PLAYBACK_MODE_CLIP

func _set_playhead_for_playback(time_beats: float) -> void:
	var mode = playback_mode
	if mode == "":
		mode = _resolve_playback_mode()
	if mode == PLAYBACK_MODE_TRACKS:
		_set_arrangement_playhead_time(time_beats)
	else:
		_set_clip_playhead_time(time_beats)

func _set_clip_playhead_time(time_beats: float) -> void:
	var target = playback_slot if playback_slot != null else active_slot
	if target != null and target.has_method("set_roll_playhead_time"):
		target.call("set_roll_playhead_time", time_beats)

func _set_arrangement_playhead_time(time_beats: float) -> void:
	for slot in [panel_slot_a, panel_slot_b]:
		if slot != null and slot.has_method("set_arrangement_playhead_time"):
			slot.call("set_arrangement_playhead_time", time_beats)

func _update_playback_playhead() -> void:
	if playback_engine == null:
		return
	if not bool(playback_engine.call("get_is_playing")):
		return
	var beats = float(playback_engine.call("get_playhead_beats"))
	_set_playhead_for_playback(beats)

func _on_midi_finished() -> void:
	_set_playhead_for_playback(0.0)

func _on_playback_finished() -> void:
	_set_playhead_for_playback(0.0)

func _handle_midi_input(event: InputEventMIDI) -> void:
	if not _matches_selected_midi_device(event):
		return
	var is_note_on = event.message == MIDI_MESSAGE_NOTE_ON and event.velocity > 0
	var is_note_off = event.message == MIDI_MESSAGE_NOTE_OFF or (
		event.message == MIDI_MESSAGE_NOTE_ON and event.velocity <= 0
	)
	if not (is_note_on or is_note_off):
		return
	var route = _resolve_active_track_route()
	var target_player = route.get("player", midi_player)
	var channel = int(route.get("channel", 0))
	var track = route.get("track")
	if is_note_on:
		if _track_has_adsr_override(track):
			_apply_track_adsr_to_player(track, target_player, channel)
	_send_live_midi_note(target_player, channel, int(event.pitch), int(event.velocity), is_note_on)
	_forward_midi_to_piano(int(event.pitch), is_note_on)
	if _is_recording:
		_record_midi_note(int(event.pitch), int(event.velocity), is_note_on, channel)

func _matches_selected_midi_device(event: InputEventMIDI) -> bool:
	if _selected_midi_device_index < 0:
		return true
	if not _midi_has_device_field:
		return true
	return int(event.device) == _selected_midi_device_index

func _resolve_active_track_route() -> Dictionary:
	var track_index := 0
	if active_slot != null and active_slot.has_method("get_active_track_index"):
		track_index = int(active_slot.call("get_active_track_index"))
	var track = _track_by_index(track_index)
	if soundfont_manager != null and soundfont_manager.has_method("get_route_for_track"):
		var route = soundfont_manager.call("get_route_for_track", track_index, track)
		if route is Dictionary:
			if not route.has("track_index"):
				route["track_index"] = track_index
			if not route.has("track"):
				route["track"] = track
			return route
	return {
		"player": midi_player,
		"channel": track_index % 16,
		"track_index": track_index,
		"track": track
	}

func _send_live_midi_note(player: Node, channel: int, pitch: int, velocity: int, is_note_on: bool) -> void:
	if player == null or not player.has_method("receive_raw_midi_message"):
		return
	var midi_event = InputEventMIDI.new()
	midi_event.channel = channel
	if is_note_on:
		midi_event.message = MIDI_MESSAGE_NOTE_ON
		midi_event.pitch = pitch
		midi_event.velocity = velocity
	else:
		midi_event.message = MIDI_MESSAGE_NOTE_OFF
		midi_event.pitch = pitch
		midi_event.velocity = 0
	player.call("receive_raw_midi_message", midi_event)

func _apply_track_adsr_to_player(track: Node, player: Node, channel: int) -> void:
	if track == null or player == null:
		return
	if not player.has_method("set_channel_adsr_override"):
		return
	if not track.has_method("get_adsr_default_value"):
		return
	var attack = _adsr_value_to_seconds(float(track.call("get_adsr_default_value", "Attack")))
	var decay = _adsr_value_to_seconds(float(track.call("get_adsr_default_value", "Decay")))
	var release = _adsr_value_to_seconds(float(track.call("get_adsr_default_value", "Release")))
	var sustain = _adsr_value_to_db(float(track.call("get_adsr_default_value", "Sustain")))
	player.call("set_channel_adsr_override", channel, attack, decay, sustain, release)

func _track_has_adsr_override(track: Node) -> bool:
	if track == null:
		return false
	if track.has_method("has_adsr_override"):
		return bool(track.call("has_adsr_override"))
	return false

func _adsr_value_to_seconds(value: float) -> float:
	return clamp(value, 0.0, 1.0) * ADSR_TIME_MAX

func _adsr_value_to_db(value: float) -> float:
	return lerp(ADSR_SUSTAIN_MIN_DB, ADSR_SUSTAIN_MAX_DB, clamp(value, 0.0, 1.0))

func _forward_midi_to_piano(pitch: int, is_note_on: bool) -> void:
	if active_slot == null or not active_slot.has_method("handle_midi_note"):
		return
	active_slot.call("handle_midi_note", pitch, is_note_on)

func _on_record_toggled(enabled: bool) -> void:
	if enabled:
		_start_recording()
	else:
		_stop_recording()

func _start_recording() -> void:
	_is_recording = true
	_record_active_notes.clear()
	_record_start_time_sec = Time.get_ticks_msec() / 1000.0
	_record_start_beats = _resolve_record_start_beats()

func _stop_recording() -> void:
	if not _is_recording:
		return
	var end_time = _resolve_record_time_beats()
	for key in _record_active_notes.keys():
		_finalize_recorded_note(key, end_time)
	_record_active_notes.clear()
	_is_recording = false

func _record_midi_note(pitch: int, velocity: int, is_note_on: bool, channel: int) -> void:
	var clip = _get_record_target_clip()
	if clip == null:
		return
	var time_beats = _resolve_record_time_beats()
	var key = "%d_%d" % [channel, pitch]
	if is_note_on:
		if _record_active_notes.has(key):
			_finalize_recorded_note(key, time_beats)
		var note_index = clip.notes.size()
		clip.add_note(pitch, time_beats, 0.0, channel)
		clip.update_velocity(note_index, velocity)
		_record_active_notes[key] = {
			"index": note_index,
			"start": time_beats,
			"pitch": pitch,
			"clip": clip
		}
	else:
		_finalize_recorded_note(key, time_beats)

func _finalize_recorded_note(key: String, end_time: float) -> void:
	if not _record_active_notes.has(key):
		return
	var info = _record_active_notes[key]
	var clip = info.get("clip", null)
	if clip == null:
		_record_active_notes.erase(key)
		return
	var index = int(info.get("index", -1))
	var start_time = float(info.get("start", 0.0))
	var pitch = int(info.get("pitch", 0))
	var duration = max(0.0, end_time - start_time)
	if duration <= 0.0:
		duration = 0.01
	clip.update_note(index, pitch, start_time, duration)
	_record_active_notes.erase(key)

func _resolve_record_start_beats() -> float:
	if active_slot != null and active_slot.has_method("get_roll_playhead_time"):
		return float(active_slot.call("get_roll_playhead_time"))
	return 0.0

func _resolve_record_time_beats() -> float:
	var time_beats := 0.0
	if playback_engine != null and bool(playback_engine.call("get_is_playing")):
		time_beats = float(playback_engine.call("get_playhead_beats"))
	else:
		var tempo := 120.0
		if project_model != null and project_model.transport != null:
			tempo = float(project_model.transport.tempo)
		var elapsed_sec = (Time.get_ticks_msec() / 1000.0) - _record_start_time_sec
		time_beats = _record_start_beats + (elapsed_sec * tempo / 60.0)
	return _map_record_time_to_clip(time_beats)

func _update_recording_notes() -> void:
	if not _is_recording:
		return
	if _record_active_notes.is_empty():
		return
	var time_beats = _resolve_record_time_beats()
	for key in _record_active_notes.keys():
		var info = _record_active_notes[key]
		var clip = info.get("clip", null)
		if clip == null:
			continue
		var index = int(info.get("index", -1))
		var start_time = float(info.get("start", 0.0))
		var pitch = int(info.get("pitch", 0))
		var duration = max(0.0, time_beats - start_time)
		if duration <= 0.0:
			duration = 0.01
		clip.update_note(index, pitch, start_time, duration)

func _map_record_time_to_clip(global_beats: float) -> float:
	if playback_mode != PLAYBACK_MODE_TRACKS:
		return max(0.0, global_beats)
	var track = _get_active_track()
	var clip = _get_record_target_clip()
	if track == null or clip == null:
		return max(0.0, global_beats)
	if track.has_method("get_clip_placement"):
		var placement = track.call("get_clip_placement", clip)
		if placement is Dictionary:
			var start = float(placement.get("start", 0.0))
			return max(0.0, global_beats - start)
	return max(0.0, global_beats)

func _get_record_target_clip() -> Node:
	if active_slot != null and active_slot.has_method("get_active_clip"):
		return active_slot.call("get_active_clip")
	return null

func _exit_tree() -> void:
	if _midi_import_thread != null:
		_midi_import_thread.wait_to_finish()
		_midi_import_thread = null
	_importing_count = 0
	_import_block_hold = false
	_update_import_mute()
	_hide_loading_overlay()
	_update_input_blocking()

func _get_playhead_start_beats(mode: String) -> float:
	if active_slot == null:
		return 0.0
	var beats = 0.0
	if mode == PLAYBACK_MODE_TRACKS:
		if active_slot.has_method("get_arrangement_playhead_time"):
			beats = float(active_slot.call("get_arrangement_playhead_time"))
	else:
		if active_slot.has_method("get_roll_playhead_time"):
			beats = float(active_slot.call("get_roll_playhead_time"))
	if beats < 0.0:
		beats = 0.0
	return beats

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

func _replace_project_model(next_model: Node, refresh_track_list: bool = true) -> void:
	if next_model == null:
		return
	if project_model != null and project_model.has_signal("changed"):
		var callable = Callable(self, "_on_project_model_changed")
		if project_model.is_connected("changed", callable):
			project_model.disconnect("changed", callable)
	if project_model != null and project_model.get_parent() == self:
		remove_child(project_model)
		project_model.queue_free()
	project_model = next_model
	project_model.name = "ProjectModel"
	add_child(project_model)
	if project_model.has_signal("changed"):
		project_model.connect("changed", Callable(self, "_on_project_model_changed"))
	if playback_engine != null and playback_engine.has_method("set_project_model"):
		playback_engine.call("set_project_model", project_model)
	if soundfont_manager != null and soundfont_manager.has_method("set_project_model"):
		soundfont_manager.call("set_project_model", project_model)
	slot_selection_ranges.clear()
	for slot in [panel_slot_a, panel_slot_b]:
		if slot == null or not slot.has_method("set_project_model"):
			continue
		slot.call("set_project_model", project_model)
		if slot.has_method("select_track"):
			slot.call("select_track", 0)
		if slot.has_method("select_clip"):
			slot.call("select_clip", 0)
	if refresh_track_list:
		_refresh_track_list()
	elif not _pending_track_refresh:
		_pending_track_refresh = true
		call_deferred("_flush_project_model_changed")
	_set_active_slot(panel_slot_a)
	_apply_transport_to_slots()
	if shared_scroll_enabled:
		_update_shared_view_beats()

func _apply_transport_to_slots() -> void:
	if project_model == null:
		return
	var transport = project_model.transport
	if transport == null:
		return
	var numerator = int(transport.time_signature_numerator)
	var denominator = int(transport.time_signature_denominator)
	if denominator <= 0:
		denominator = 4
	var beats_per_measure = int(round(float(numerator) * 4.0 / float(denominator)))
	beats_per_measure = max(1, beats_per_measure)
	for slot in [panel_slot_a, panel_slot_b]:
		if slot != null and slot.has_method("set_beats_per_measure"):
			slot.call("set_beats_per_measure", beats_per_measure)

func _slot_by_index(slot_index: int) -> Node:
	return panel_slot_a if slot_index == 0 else panel_slot_b
