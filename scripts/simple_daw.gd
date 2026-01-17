extends Control

const PIANO_ROLL_SCENE = preload("res://piano_roll.tscn")
const ICON_SNAP_ON = preload("res://Lucid V1.2/PNG/Flat/16/Grid.png")
const ICON_SNAP_OFF = preload("res://Lucid V1.2/PNG/Flat/16/Slash.png")
const ICON_CURVE_LINE = preload("res://Lucid V1.2/PNG/Flat/16/Signal-1.png")
const ICON_CURVE_BEZIER = preload("res://Lucid V1.2/PNG/Flat/16/Signal-2.png")

@onready var browser_panel: Control = $"RootLayout/MainSplit/BrowserPanel"
@onready var browser_toggle: Button = $"RootLayout/TopBar/TopBarContent/BrowserToggle"
@onready var tab_bar: TabBar = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/TabRow/RollTabs"
@onready var add_tab_button: Button = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/TabRow/AddTabButton"
@onready var roll_area: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea"
@onready var tab_row: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/TabRow"
@onready var h_scroll_row: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/HScrollRow"
@onready var envelope_bar_row: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/EnvelopeBarRow"
@onready var roll_stack: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/RollFrame/RollClip/RollRow/RollStack"
@onready var h_scroll_spacer: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/HScrollRow/HScrollSpacer"
@onready var h_scroll: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/HScrollRow/HScrollFrame/HScroll"
@onready var v_scroll: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/RollFrame/RollClip/RollRow/VScroll"
@onready var selection_snap_button: Button = $"RootLayout/MainSplit/RightSplit/TransportPanel/TransportBar/SelectionSnapButton"
@onready var envelope_bar_spacer: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/EnvelopeBarRow/EnvelopeBarSpacer"
@onready var envelope_lane_spacer: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/EnvelopeLaneRow/EnvelopeLaneSpacer"
@onready var envelope_drag_bar: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/EnvelopeBarRow/EnvelopeBarFrame/EnvelopeDragBar"
@onready var envelope_lane: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/EnvelopeLaneRow/EnvelopeLaneFrame/EnvelopeLane"
@onready var envelope_lane_overlay: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/EnvelopeLaneRow/EnvelopeLaneFrame/EnvelopeLaneOverlay"
@onready var roll_frame_overlay: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/RollFrame/RollFrameOverlay"
@onready var envelope_bar_right_spacer: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/EnvelopeBarRow/EnvelopeBarRightSpacer"
@onready var envelope_lane_right_spacer: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/EnvelopeLaneRow/EnvelopeLaneRightSpacer"
@onready var curve_mode_button: Button = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/EnvelopeLaneRow/EnvelopeLaneRightSpacer/CurveModeButton"

var piano_roll: Control = null
var notes_model: Node = null

var updating_scrollbars := false
var active_roll_panel: Control = null

func _ready() -> void:
	_update_browser_toggle_label()
	_init_tabs()
	_sync_scrollbars()
	_init_envelope_lane()
	_update_selection_snap_label()
	_update_curve_mode_label()
	_update_envelope_panel_limit()

func _on_browser_toggle_pressed() -> void:
	browser_panel.visible = not browser_panel.visible
	_update_browser_toggle_label()

func _on_tab_changed(tab_index: int) -> void:
	_select_tab(tab_index)

func _on_add_tab_pressed() -> void:
	var roll = PIANO_ROLL_SCENE.instantiate()
	var label = "Roll %d" % (roll_stack.get_child_count() + 1)
	roll.name = label
	roll_stack.add_child(roll)
	tab_bar.add_tab(label)
	tab_bar.current_tab = tab_bar.get_tab_count() - 1
	_select_tab(tab_bar.current_tab)

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
	_update_scrollbars(scroll_x, scroll_y, max_x, max_y, view_width, view_height)
	_update_envelope_view(scroll_x, view_width)

func _init_tabs() -> void:
	if tab_bar == null or roll_stack == null:
		return
	while tab_bar.get_tab_count() > 0:
		tab_bar.remove_tab(0)
	for child in roll_stack.get_children():
		tab_bar.add_tab(child.name)
	if tab_bar.get_tab_count() == 0:
		for i in range(2):
			var roll = PIANO_ROLL_SCENE.instantiate()
			var label = "Roll %d" % (i + 1)
			roll.name = label
			roll_stack.add_child(roll)
			tab_bar.add_tab(label)
	tab_bar.current_tab = 0
	_select_tab(0)

func _select_tab(tab_index: int) -> void:
	if roll_stack == null:
		return
	var children = roll_stack.get_children()
	if tab_index < 0 or tab_index >= children.size():
		return
	for i in range(children.size()):
		var child = children[i] as CanvasItem
		if child:
			child.visible = i == tab_index
	_set_active_roll(children[tab_index])

func _set_active_roll(roll: Control) -> void:
	if piano_roll and piano_roll.has_signal("scroll_changed"):
		var callable = Callable(self, "_on_roll_scroll_changed")
		if piano_roll.is_connected("scroll_changed", callable):
			piano_roll.disconnect("scroll_changed", callable)
	if notes_model != null:
		var notes_callable = Callable(self, "_on_notes_changed")
		if notes_model.is_connected("changed", notes_callable):
			notes_model.disconnect("changed", notes_callable)
	piano_roll = roll
	if piano_roll and piano_roll.has_signal("scroll_changed"):
		piano_roll.connect("scroll_changed", Callable(self, "_on_roll_scroll_changed"))
	notes_model = piano_roll.get_node_or_null("NotesModel") if piano_roll else null
	if notes_model != null:
		notes_model.connect("changed", Callable(self, "_on_notes_changed"))
	if envelope_lane != null and envelope_lane.has_method("set_from_roll"):
		envelope_lane.call("set_from_roll", piano_roll)
	var next_panel = piano_roll.get_node_or_null("RollPanel") if piano_roll else null
	if active_roll_panel != null:
		var resized_callable = Callable(self, "_on_roll_panel_resized")
		if active_roll_panel.is_connected("resized", resized_callable):
			active_roll_panel.disconnect("resized", resized_callable)
	active_roll_panel = next_panel
	if active_roll_panel != null:
		active_roll_panel.connect("resized", Callable(self, "_on_roll_panel_resized"))
	if h_scroll != null and h_scroll.has_method("set_roll"):
		h_scroll.call("set_roll", piano_roll)
	if v_scroll != null and v_scroll.has_method("set_roll"):
		v_scroll.call("set_roll", piano_roll)
	_sync_scrollbars()
	if piano_roll != null:
		var roll_panel = piano_roll.get_node_or_null("RollPanel") as Control
		var view_width = roll_panel.size.x if roll_panel else 0.0
		var scroll_x = float(piano_roll.call("get_scroll_x"))
		_update_envelope_view(scroll_x, view_width)
		_restore_envelope_selection()

func _sync_scrollbars() -> void:
	if piano_roll == null:
		return
	var roll_panel = piano_roll.get_node("RollPanel") as Control
	var view_width = roll_panel.size.x if roll_panel else 0.0
	var view_height = roll_panel.size.y if roll_panel else 0.0
	var scroll_x = float(piano_roll.call("get_scroll_x"))
	var scroll_y = float(piano_roll.call("get_scroll_y"))
	var max_x = float(piano_roll.call("get_max_scroll_x"))
	var max_y = float(piano_roll.call("get_max_scroll_y"))
	_update_scrollbars(scroll_x, scroll_y, max_x, max_y, view_width, view_height)
	_update_envelope_view(scroll_x, view_width)
	_update_envelope_panel_limit()

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
		h_scroll_spacer.custom_minimum_size = Vector2(max(0.0, keyboard_width), 0)
	if envelope_bar_spacer != null:
		envelope_bar_spacer.custom_minimum_size = Vector2(max(0.0, keyboard_width - 4.0), 0)
	if envelope_lane_spacer != null:
		envelope_lane_spacer.custom_minimum_size = Vector2(max(0.0, keyboard_width - 4.0), 0)
	var right_padding = v_scroll.size.x if v_scroll != null else 0.0
	if envelope_bar_right_spacer != null:
		envelope_bar_right_spacer.custom_minimum_size = Vector2(max(0.0, right_padding), 0)
	if envelope_lane_right_spacer != null:
		var min_width = right_padding
		if curve_mode_button != null:
			min_width = max(min_width, curve_mode_button.custom_minimum_size.x)
		envelope_lane_right_spacer.custom_minimum_size = Vector2(max(0.0, min_width), 0)
	h_scroll.min_value = 0.0
	h_scroll.max_value = max_x
	h_scroll.page = max(view_width, 0.0)
	h_scroll.value = clamp(scroll_x, 0.0, max_x)
	h_scroll.visible = true
	h_scroll.queue_redraw()
	v_scroll.min_value = 0.0
	v_scroll.max_value = max_y
	v_scroll.page = max(view_height, 0.0)
	v_scroll.value = clamp(scroll_y, 0.0, max_y)
	v_scroll.visible = true
	v_scroll.queue_redraw()
	updating_scrollbars = false

func _update_browser_toggle_label() -> void:
	browser_toggle.text = ""


func _on_notes_changed() -> void:
	if h_scroll != null and h_scroll.has_method("queue_redraw"):
		h_scroll.call("queue_redraw")
	if v_scroll != null and v_scroll.has_method("queue_redraw"):
		v_scroll.call("queue_redraw")
	if envelope_lane != null and envelope_lane.has_method("queue_redraw"):
		envelope_lane.call("queue_redraw")

func _on_roll_panel_resized() -> void:
	_sync_scrollbars()
	_update_envelope_panel_limit()

func _init_envelope_lane() -> void:
	if envelope_drag_bar != null and envelope_drag_bar.has_method("setup"):
		envelope_drag_bar.call("setup", envelope_lane)
	if envelope_drag_bar != null and envelope_drag_bar.has_signal("panel_height_changed"):
		var height_callable = Callable(self, "_on_envelope_panel_height_changed")
		if not envelope_drag_bar.is_connected("panel_height_changed", height_callable):
			envelope_drag_bar.connect("panel_height_changed", height_callable)
	if envelope_lane != null:
		if envelope_lane.has_method("set_snap_provider"):
			envelope_lane.call("set_snap_provider", envelope_drag_bar)
		envelope_lane.visible = false
		envelope_lane.custom_minimum_size = Vector2(0.0, 0.0)
	_set_envelope_panel_controls(false)
	_update_envelope_panel_limit()

func _update_envelope_panel_limit() -> void:
	if envelope_drag_bar == null:
		return
	if roll_area == null or tab_row == null or h_scroll_row == null or envelope_bar_row == null:
		return
	var total_height = roll_area.size.y
	var reserved = tab_row.size.y + h_scroll_row.size.y + envelope_bar_row.size.y
	var separation = 0.0
	if roll_area is VBoxContainer:
		separation = float((roll_area as VBoxContainer).get_theme_constant("separation"))
	var row_count = 5.0
	var spacing = separation * max(0.0, row_count - 1.0)
	var roll_allowance = 0.0
	if roll_frame_overlay != null:
		roll_allowance = float(roll_frame_overlay.get("border_expand")) * 2.0
	var max_height = max(0.0, total_height - reserved - spacing - roll_allowance)
	envelope_drag_bar.set("max_panel_height", max_height)

func _update_envelope_view(scroll_x: float, view_width: float) -> void:
	if envelope_lane == null or envelope_drag_bar == null or piano_roll == null:
		return
	if envelope_lane.has_method("set_view"):
		envelope_lane.call("set_view", scroll_x, view_width)
	if envelope_lane.has_method("set_from_roll"):
		envelope_lane.call("set_from_roll", piano_roll)
	var ppb = float(piano_roll.get("pixels_per_beat"))
	var beats = int(piano_roll.get("visible_beats"))
	if envelope_drag_bar.has_method("update_from_roll"):
		envelope_drag_bar.call("update_from_roll", ppb, beats, scroll_x, view_width)

func _on_envelope_selection_committed(start_beats: float, end_beats: float) -> void:
	if piano_roll == null:
		return
	var start_time = min(start_beats, end_beats)
	piano_roll.call("set_playhead_time", start_time)
	_store_envelope_selection(start_beats, end_beats)

func _on_envelope_selection_cleared() -> void:
	if piano_roll == null:
		return
	_store_envelope_selection(-1.0, -1.0)

func _on_selection_snap_pressed() -> void:
	if envelope_drag_bar == null or not envelope_drag_bar.has_method("toggle_snap"):
		return
	var enabled = bool(envelope_drag_bar.call("toggle_snap"))
	_update_selection_snap_label(enabled)

func _on_envelope_panel_toggled(is_open: bool) -> void:
	_set_envelope_panel_controls(is_open)

func _on_envelope_panel_height_changed(height: float) -> void:
	if envelope_lane_overlay != null:
		envelope_lane_overlay.visible = height > 0.0

func _update_selection_snap_label(force_enabled: Variant = null) -> void:
	if selection_snap_button == null:
		return
	var enabled = false
	if force_enabled is bool:
		enabled = force_enabled
	elif envelope_drag_bar != null and envelope_drag_bar.has_method("is_snap_enabled"):
		enabled = bool(envelope_drag_bar.call("is_snap_enabled"))
	selection_snap_button.text = ""
	selection_snap_button.icon = ICON_SNAP_ON if enabled else ICON_SNAP_OFF

func _on_curve_mode_pressed() -> void:
	if envelope_lane == null or not envelope_lane.has_method("toggle_curve_mode"):
		return
	var mode = String(envelope_lane.call("toggle_curve_mode"))
	_update_curve_mode_label(mode)

func _update_curve_mode_label(force_mode: String = "") -> void:
	if curve_mode_button == null:
		return
	var mode = force_mode
	if mode == "" and envelope_lane != null:
		mode = str(envelope_lane.get("curve_mode"))
	curve_mode_button.text = ""
	curve_mode_button.icon = ICON_CURVE_BEZIER if mode == "bezier" else ICON_CURVE_LINE

func _set_envelope_panel_controls(is_open: bool) -> void:
	if curve_mode_button != null:
		curve_mode_button.visible = is_open
	if envelope_lane_overlay != null:
		envelope_lane_overlay.visible = is_open

func _store_envelope_selection(start_beats: float, end_beats: float) -> void:
	if piano_roll == null:
		return
	piano_roll.set_meta("envelope_selection_start", start_beats)
	piano_roll.set_meta("envelope_selection_end", end_beats)

func _restore_envelope_selection() -> void:
	if piano_roll == null or envelope_drag_bar == null:
		return
	var start = float(piano_roll.get_meta("envelope_selection_start", -1.0))
	var end = float(piano_roll.get_meta("envelope_selection_end", -1.0))
	if envelope_drag_bar.has_method("set_selection_from_roll"):
		envelope_drag_bar.call("set_selection_from_roll", start, end)
