extends Control

@onready var browser_panel: Control = $"RootLayout/MainSplit/BrowserPanel"
@onready var browser_toggle: Button = $"RootLayout/TopBar/TopBarContent/BrowserToggle"
@onready var piano_roll: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/RollRow/PianoRoll"
@onready var h_scroll_spacer: Control = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/HScrollRow/HScrollSpacer"
@onready var h_scroll: HScrollBar = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/HScrollRow/HScroll"
@onready var v_scroll: VScrollBar = $"RootLayout/MainSplit/RightSplit/PianoRollPanel/RollArea/RollRow/VScroll"

var updating_scrollbars := false

func _ready() -> void:
	_update_browser_toggle_label()
	if piano_roll and piano_roll.has_signal("scroll_changed"):
		piano_roll.connect("scroll_changed", Callable(self, "_on_roll_scroll_changed"))
	_sync_scrollbars()

func _on_browser_toggle_pressed() -> void:
	browser_panel.visible = not browser_panel.visible
	_update_browser_toggle_label()

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
	h_scroll.page = view_width
	h_scroll.value = scroll_x
	h_scroll.visible = max_x > 0.0
	v_scroll.min_value = 0.0
	v_scroll.max_value = max_y
	v_scroll.page = view_height
	v_scroll.value = scroll_y
	v_scroll.visible = max_y > 0.0
	updating_scrollbars = false

func _update_browser_toggle_label() -> void:
	browser_toggle.text = "B"
