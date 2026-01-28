extends Tree

signal track_item_selected(track_index: int)
signal clip_item_selected(track_index: int, clip_index: int, clip: Node)
signal automation_item_selected(track_index: int, clip_index: int, clip: Node, param_name: String)
signal soundfont_item_selected(track_index: int)
signal add_track_selected
signal add_clip_selected(track_index: int)
signal clip_drag_started(track_index: int, clip_index: int, clip: Node)
signal clip_drag_ended

func _ready() -> void:
	hide_root = false
	if not item_selected.is_connected(_on_item_selected):
		item_selected.connect(_on_item_selected)

func _on_item_selected() -> void:
	var item = get_selected()
	if item == null:
		return
	var data = item.get_metadata(0)
	if data is Dictionary:
		var kind = String(data.get("type", ""))
		if kind == "track":
			emit_signal("track_item_selected", int(data.get("track_index", -1)))
		elif kind == "clip":
			emit_signal(
				"clip_item_selected",
				int(data.get("track_index", -1)),
				int(data.get("clip_index", -1)),
				data.get("clip")
			)
		elif kind == "automation":
			emit_signal(
				"automation_item_selected",
				int(data.get("track_index", -1)),
				int(data.get("clip_index", -1)),
				data.get("clip"),
				String(data.get("param", ""))
			)
		elif kind == "soundfont":
			emit_signal("soundfont_item_selected", int(data.get("track_index", -1)))
		elif kind == "add_track":
			emit_signal("add_track_selected")
		elif kind == "add_clip":
			emit_signal("add_clip_selected", int(data.get("track_index", -1)))

func _get_drag_data(at_position: Vector2) -> Variant:
	var item = get_item_at_position(at_position)
	if item == null:
		return null
	var data = item.get_metadata(0)
	if not (data is Dictionary):
		return null
	if String(data.get("type", "")) != "clip":
		return null
	var clip = data.get("clip")
	if clip == null:
		return null
	var drag_data = {
		"type": "browser_clip",
		"clip": clip,
		"track_index": int(data.get("track_index", -1)),
		"clip_index": int(data.get("clip_index", -1))
	}
	set_drag_preview(_make_preview(item.get_text(0)))
	emit_signal("clip_drag_started", drag_data["track_index"], drag_data["clip_index"], clip)
	return drag_data

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		emit_signal("clip_drag_ended")

func _make_preview(label: String) -> Control:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.set_content_margin_all(6.0)
	panel.add_theme_stylebox_override("panel", style)
	var text = Label.new()
	text.text = label
	panel.add_child(text)
	return panel
