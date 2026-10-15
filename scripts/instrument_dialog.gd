extends AcceptDialog

signal midi_input(event: InputEventMIDI)

func _ready() -> void:
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMIDI:
		emit_signal("midi_input", event)
		var viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
