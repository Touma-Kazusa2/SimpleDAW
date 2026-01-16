extends Control

@onready var browser_panel: Control = $"MainSplit/BrowserPanel"
@onready var browser_toggle: Button = $"MainSplit/RightSplit/TransportPanel/TransportBar/BrowserToggle"

func _ready() -> void:
	_update_browser_toggle_label()

func _on_browser_toggle_pressed() -> void:
	browser_panel.visible = not browser_panel.visible
	_update_browser_toggle_label()

func _update_browser_toggle_label() -> void:
	browser_toggle.text = "隐藏浏览器" if browser_panel.visible else "显示浏览器"
