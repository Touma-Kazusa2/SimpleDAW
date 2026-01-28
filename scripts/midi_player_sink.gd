extends RefCounted

class_name MidiPlayerSink

const MAX_CHANNELS := 16

var midi_player: Node = null

func _init(player: Node = null) -> void:
	midi_player = player

func set_player(player: Node) -> void:
	midi_player = player

func emit_events(events: Array) -> void:
	for event in events:
		_send_event(event)

func send_all_notes_off(players: Array) -> void:
	if players.is_empty() and midi_player != null:
		players = [midi_player]
	for player in players:
		if player == null or not player.has_method("receive_raw_midi_message"):
			continue
		for channel in range(MAX_CHANNELS):
			var midi_event = InputEventMIDI.new()
			midi_event.message = MIDI_MESSAGE_CONTROL_CHANGE
			midi_event.channel = channel
			midi_event.controller_number = 123
			midi_event.controller_value = 0
			player.call("receive_raw_midi_message", midi_event)

func _send_event(event: Dictionary) -> void:
	var player: Node = event.get("player", midi_player)
	if player == null or not player.has_method("receive_raw_midi_message"):
		return
	var event_type = String(event.get("type", ""))
	var channel = int(event.get("channel", 0)) % MAX_CHANNELS
	var midi_event = InputEventMIDI.new()
	midi_event.channel = channel
	match event_type:
		"note_on":
			midi_event.message = MIDI_MESSAGE_NOTE_ON
			midi_event.pitch = int(event.get("pitch", 0))
			midi_event.velocity = int(event.get("velocity", 100))
			player.call("receive_raw_midi_message", midi_event)
		"note_off":
			midi_event.message = MIDI_MESSAGE_NOTE_OFF
			midi_event.pitch = int(event.get("pitch", 0))
			midi_event.velocity = 0
			player.call("receive_raw_midi_message", midi_event)
		"cc":
			midi_event.message = MIDI_MESSAGE_CONTROL_CHANGE
			midi_event.controller_number = int(event.get("cc", 0))
			midi_event.controller_value = int(event.get("value", 0))
			player.call("receive_raw_midi_message", midi_event)
		"program":
			midi_event.message = MIDI_MESSAGE_PROGRAM_CHANGE
			midi_event.instrument = int(event.get("program", 0))
			player.call("receive_raw_midi_message", midi_event)
		"adsr_sustain":
			if player.has_method("set_channel_adsr_sustain"):
				player.call("set_channel_adsr_sustain", channel, float(event.get("value", 0.0)))
