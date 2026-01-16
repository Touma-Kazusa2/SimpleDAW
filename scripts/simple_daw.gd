extends Control

const PIANO_ROLL_SCENE = preload("res://main.tscn")

@onready var browser_panel: Control = $"RootLayout/MainSplit/BrowserPanel"
@onready var browser_toggle: Button = $"RootLayout/TopBar/TopBarContent/BrowserToggle"
@onready var tab_bar: TabBar = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/TabRow/RollTabs"
@onready var add_tab_button: Button = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/TabRow/AddTabButton"
@onready var roll_stack: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/RollRow/RollStack"
@onready var h_scroll_spacer: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/HScrollRow/HScrollSpacer"
@onready var h_scroll: HScrollBar = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/HScrollRow/HScroll"
@onready var v_scroll: VScrollBar = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/RollRow/VScroll"

var piano_roll: Control = null

var updating_scrollbars := false
var _scroll_sync_cooldown := 0.0

func _ready() -> void:
	_update_browser_toggle_label()
	_init_tabs()
	_sync_scrollbars()

func _process(delta: float) -> void:
	_scroll_sync_cooldown -= delta
	if _scroll_sync_cooldown <= 0.0:
		_scroll_sync_cooldown = 0.2
		_sync_scrollbars()

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
	piano_roll = roll
	if piano_roll and piano_roll.has_signal("scroll_changed"):
		piano_roll.connect("scroll_changed", Callable(self, "_on_roll_scroll_changed"))
	_sync_scrollbars()

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
	h_scroll.min_value = 0.0
	h_scroll.max_value = max_x
	h_scroll.page = max(view_width, 0.0)
	h_scroll.value = clamp(scroll_x, 0.0, max_x)
	h_scroll.visible = max_x > 0.0
	v_scroll.min_value = 0.0
	v_scroll.max_value = max_y
	v_scroll.page = max(view_height, 0.0)
	v_scroll.value = clamp(scroll_y, 0.0, max_y)
	v_scroll.visible = max_y > 0.0
	updating_scrollbars = false

func _update_browser_toggle_label() -> void:
	browser_toggle.text = "B"
