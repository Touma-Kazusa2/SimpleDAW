extends Control

@export var pixels_per_beat: float = 120.0
@export var beats_per_measure: int = 4
@export var visible_beats: int = 32
@export var view_scroll_x: float = 0.0
@export var view_scroll_y: float = 0.0
@export var view_width: float = 0.0

const COLOR_BG = Color(0.06, 0.06, 0.07)
const COLOR_BOX_FILL = Color(0.12, 0.22, 0.45, 0.9)
const COLOR_BOX_BORDER = Color(0.35, 0.6, 0.95, 0.9)
const COLOR_TEXT = Color(0.93, 0.96, 1.0, 0.95)

var model: Node = null
var roll: Control = null
var editor: LineEdit = null
var editing_index := -1
var _redraw_pending := false
var _comment_style: StyleBox = null
var _row_by_index: Array = []
var _layout_dirty := true
var _row_count := 0

const COMMENT_MATCH_EPS := 0.001

@export var box_height: float = 28.0
@export var box_padding: float = 6.0
@export var row_spacing: float = 8.0
@export var top_padding: float = 8.0
@export var box_corner_radius: float = 6.0
@export var bottom_padding: float = 4.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	editor = LineEdit.new()
	editor.visible = false
	editor.focus_mode = Control.FOCUS_ALL
	editor.caret_blink = true
	editor.clip_contents = true
	editor.text_submitted.connect(_on_text_submitted)
	editor.focus_exited.connect(_on_text_focus_exited)
	add_child(editor)
	_init_comment_style()

func set_from_roll(roll_node: Control) -> void:
	if roll_node == null:
		return
	roll = roll_node
	pixels_per_beat = float(roll_node.get("pixels_per_beat"))
	beats_per_measure = int(roll_node.get("beats_per_measure"))
	visible_beats = int(roll_node.get("visible_beats"))
	set_model(roll_node.get_node_or_null("EnvelopeModel"))
	_request_redraw()

func set_model(next_model: Node) -> void:
	if model:
		var callable = Callable(self, "_on_model_changed")
		if model.is_connected("changed", callable):
			model.disconnect("changed", callable)
	model = next_model
	if model:
		model.connect("changed", Callable(self, "_on_model_changed"))
	_request_redraw()

func _on_model_changed() -> void:
	_layout_dirty = true
	_request_redraw()

func set_view(scroll_x: float, width: float) -> void:
	view_scroll_x = scroll_x
	view_width = width
	_request_redraw()

func set_view_scroll_y(scroll_y: float) -> void:
	view_scroll_y = max(0.0, scroll_y)
	if editor != null and editor.visible and editing_index >= 0:
		_refresh_editor_layout()
	_request_redraw()

func add_comment(start_beats: float, end_beats: float) -> void:
	if model == null or not model.has_method("add_comment"):
		return
	model.call("add_comment", start_beats, end_beats, "")
	_request_redraw()

func _gui_input(event: InputEvent) -> void:
	if model == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.double_click:
			var index = _comment_index_at_pos(event.position)
			if index >= 0:
				_begin_edit(index)
				accept_event()
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var idx = _comment_index_at_pos(event.position)
		if idx >= 0:
			_remove_comment(idx)
			accept_event()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	_draw_comments()

func _draw_comments() -> void:
	if model == null or not model.has_method("get_comments"):
		return
	var comments = model.call("get_comments") as Array
	if comments.is_empty():
		return
	_ensure_layout(comments)
	var clip_width = size.x
	if view_width > 0.0:
		clip_width = min(size.x, view_width)
	var offset_x = -view_scroll_x
	for i in range(comments.size()):
		var entry = comments[i]
		if editor != null and editor.visible and editing_index == i:
			continue
		var row = _row_by_index[i] if i < _row_by_index.size() else i
		var start_beats = float(entry.get("start", 0.0))
		var end_beats = float(entry.get("end", 0.0))
		var text = String(entry.get("text", ""))
		var x0 = start_beats * pixels_per_beat + offset_x
		var x1 = end_beats * pixels_per_beat + offset_x
		var row_y = top_padding + row * (box_height + row_spacing) - view_scroll_y
		var rect = Rect2(Vector2(min(x0, x1), row_y), Vector2(abs(x1 - x0), box_height))
		var view_rect = Rect2(Vector2.ZERO, Vector2(clip_width, size.y))
		var clipped = rect.intersection(view_rect)
		if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
			continue
		if _comment_style == null:
			_init_comment_style()
		if _comment_style != null:
			draw_style_box(_comment_style, clipped)
		else:
			draw_rect(clipped, COLOR_BOX_FILL, true)
			draw_rect(clipped, COLOR_BOX_BORDER, false, 1.0)
		var font = get_theme_default_font()
		var font_size = get_theme_default_font_size()
		var pad_left = box_padding
		var pad_right = box_padding
		if _comment_style != null:
			pad_left = _comment_style.get_content_margin(SIDE_LEFT)
			pad_right = _comment_style.get_content_margin(SIDE_RIGHT)
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, clipped.size.x, font_size)
		var text_x = clipped.position.x + pad_left
		var text_y = clipped.position.y + (clipped.size.y - text_size.y) * 0.5 + font.get_ascent(font_size)
		var text_pos = Vector2(text_x, text_y)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, clipped.size.x - pad_left - pad_right, font_size, COLOR_TEXT)

func _comment_index_at_pos(local_pos: Vector2) -> int:
	if model == null or not model.has_method("get_comments"):
		return -1
	var comments = model.call("get_comments") as Array
	if comments.is_empty():
		return -1
	_ensure_layout(comments)
	var clip_width = size.x
	if view_width > 0.0:
		clip_width = min(size.x, view_width)
	var offset_x = -view_scroll_x
	for i in range(comments.size()):
		var row = _row_by_index[i] if i < _row_by_index.size() else i
		var entry = comments[i]
		var start_beats = float(entry.get("start", 0.0))
		var end_beats = float(entry.get("end", 0.0))
		var x0 = start_beats * pixels_per_beat + offset_x
		var x1 = end_beats * pixels_per_beat + offset_x
		var row_y = top_padding + row * (box_height + row_spacing) - view_scroll_y
		var rect = Rect2(Vector2(min(x0, x1), row_y), Vector2(abs(x1 - x0), box_height))
		var view_rect = Rect2(Vector2.ZERO, Vector2(clip_width, size.y))
		var clipped = rect.intersection(view_rect)
		if clipped.has_point(local_pos):
			return i
	return -1

func _begin_edit(index: int) -> void:
	if editor == null or model == null or not model.has_method("get_comments"):
		return
	var comments = model.call("get_comments") as Array
	if index < 0 or index >= comments.size():
		return
	_ensure_layout(comments)
	var entry = comments[index]
	var start_beats = float(entry.get("start", 0.0))
	var end_beats = float(entry.get("end", 0.0))
	var offset_x = -view_scroll_x
	var x0 = start_beats * pixels_per_beat + offset_x
	var x1 = end_beats * pixels_per_beat + offset_x
	var row = _row_by_index[index] if index < _row_by_index.size() else index
	var row_y = top_padding + row * (box_height + row_spacing) - view_scroll_y
	var rect = Rect2(Vector2(min(x0, x1), row_y), Vector2(abs(x1 - x0), box_height))
	editor.position = rect.position
	editor.size = rect.size
	editor.text = String(entry.get("text", ""))
	editor.visible = true
	editor.grab_focus()
	editor.select_all()
	editing_index = index
	_request_redraw()

func _commit_edit() -> void:
	if editor == null or editing_index < 0 or model == null or not model.has_method("set_comment_text"):
		return
	model.call("set_comment_text", editing_index, editor.text)
	editor.visible = false
	editing_index = -1
	_request_redraw()

func _refresh_editor_layout() -> void:
	if editor == null or model == null or not model.has_method("get_comments"):
		return
	var comments = model.call("get_comments") as Array
	if editing_index < 0 or editing_index >= comments.size():
		return
	_ensure_layout(comments)
	var entry = comments[editing_index]
	var start_beats = float(entry.get("start", 0.0))
	var end_beats = float(entry.get("end", 0.0))
	var offset_x = -view_scroll_x
	var x0 = start_beats * pixels_per_beat + offset_x
	var x1 = end_beats * pixels_per_beat + offset_x
	var row = _row_by_index[editing_index] if editing_index < _row_by_index.size() else editing_index
	var row_y = top_padding + row * (box_height + row_spacing) - view_scroll_y
	var rect = Rect2(Vector2(min(x0, x1), row_y), Vector2(abs(x1 - x0), box_height))
	editor.position = rect.position
	editor.size = rect.size

func _on_text_submitted(_text: String) -> void:
	_commit_edit()

func _on_text_focus_exited() -> void:
	_commit_edit()

func _input(event: InputEvent) -> void:
	if editor == null or not editor.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not editor.get_global_rect().has_point(get_global_mouse_position()):
			_commit_edit()

func _remove_comment(index: int) -> void:
	if model == null or not model.has_method("remove_comment"):
		return
	model.call("remove_comment", index)

func _init_comment_style() -> void:
	_comment_style = null
	if _comment_style == null:
		_comment_style = StyleBoxFlat.new()
		_comment_style.bg_color = COLOR_BOX_FILL
		_comment_style.border_color = COLOR_BOX_BORDER
		_comment_style.border_width_top = 1
		_comment_style.border_width_right = 1
		_comment_style.border_width_bottom = 1
		_comment_style.border_width_left = 1
		_comment_style.set_corner_radius_all(int(box_corner_radius))
		_comment_style.set_content_margin(SIDE_LEFT, box_padding)
		_comment_style.set_content_margin(SIDE_RIGHT, box_padding)
		_comment_style.set_content_margin(SIDE_TOP, 2.0)
		_comment_style.set_content_margin(SIDE_BOTTOM, 2.0)
	_apply_editor_style()

func _apply_editor_style() -> void:
	if editor == null or _comment_style == null:
		return
	editor.add_theme_stylebox_override("normal", _comment_style)
	editor.add_theme_stylebox_override("focus", _comment_style)
	editor.add_theme_stylebox_override("read_only", _comment_style)
	editor.add_theme_color_override("font_color", COLOR_TEXT)
	editor.add_theme_color_override("font_selected_color", COLOR_TEXT)

func get_required_height_for_range(start_beats: float, end_beats: float) -> float:
	if model == null or not model.has_method("get_comments"):
		return 0.0
	var idx = _find_comment_index_by_range(start_beats, end_beats)
	if idx < 0:
		return 0.0
	var comments = model.call("get_comments") as Array
	_ensure_layout(comments)
	var row = _row_by_index[idx] if idx < _row_by_index.size() else idx
	return top_padding + (row + 1) * box_height + row * row_spacing + bottom_padding

func get_content_height() -> float:
	if model == null or not model.has_method("get_comments"):
		return 0.0
	var comments = model.call("get_comments") as Array
	if comments.is_empty():
		return 0.0
	_ensure_layout(comments)
	if _row_count <= 0:
		return 0.0
	var rows = float(_row_count)
	return top_padding + rows * box_height + max(0.0, rows - 1.0) * row_spacing + bottom_padding

func _find_comment_index_by_range(start_beats: float, end_beats: float) -> int:
	var comments = model.call("get_comments") as Array
	if comments.is_empty():
		return -1
	var start_time = min(start_beats, end_beats)
	var end_time = max(start_beats, end_beats)
	for i in range(comments.size()):
		var entry = comments[i]
		var entry_start = float(entry.get("start", 0.0))
		var entry_end = float(entry.get("end", 0.0))
		if is_equal_approx(entry_start, start_time) and is_equal_approx(entry_end, end_time):
			return i
		if abs(entry_start - start_time) <= COMMENT_MATCH_EPS and abs(entry_end - end_time) <= COMMENT_MATCH_EPS:
			return i
	return -1

func _request_redraw() -> void:
	if _redraw_pending:
		return
	_redraw_pending = true
	call_deferred("_flush_redraw")

func _ensure_layout(comments: Array) -> void:
	if not _layout_dirty and _row_by_index.size() == comments.size():
		return
	_layout_dirty = false
	_row_by_index.clear()
	_row_by_index.resize(comments.size())
	_row_count = 0
	if comments.is_empty():
		return
	var order: Array = []
	for i in range(comments.size()):
		order.append(i)
	order.sort_custom(func(a, b):
		var a_entry = comments[a]
		var b_entry = comments[b]
		var a_start = float(a_entry.get("start", 0.0))
		var b_start = float(b_entry.get("start", 0.0))
		if is_equal_approx(a_start, b_start):
			var a_end = float(a_entry.get("end", 0.0))
			var b_end = float(b_entry.get("end", 0.0))
			return a_end < b_end
		return a_start < b_start
	)
	var row_ends: Array = []
	for idx in order:
		var entry = comments[idx]
		var start_beats = float(entry.get("start", 0.0))
		var end_beats = float(entry.get("end", 0.0))
		var placed = false
		for r in range(row_ends.size()):
			if start_beats >= float(row_ends[r]):
				_row_by_index[idx] = r
				row_ends[r] = end_beats
				placed = true
				break
		if not placed:
			_row_by_index[idx] = row_ends.size()
			row_ends.append(end_beats)
	_row_count = row_ends.size()

func _flush_redraw() -> void:
	_redraw_pending = false
	queue_redraw()
