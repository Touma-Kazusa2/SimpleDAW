extends RefCounted

class_name EngineCore

const DEFAULT_BPM := 120.0
const DEFAULT_PROGRAM := 0
const DEFAULT_BANK := 0
const DEFAULT_VELOCITY := 100
const MAX_CHANNELS := 16

var events: Array = []
var note_ranges: Array = []
var cc_events: Array = []
var adsr_events: Array = []
var program_events: Array = []
var tempo_events: Array = []
var max_event_beats := 0.0
var event_cursor := 0
var active_notes: Dictionary = {}

func set_snapshot(snapshot: Dictionary) -> void:
	events = snapshot.get("events", [])
	note_ranges = snapshot.get("note_ranges", [])
	cc_events = snapshot.get("cc_events", [])
	adsr_events = snapshot.get("adsr_events", [])
	program_events = snapshot.get("program_events", [])
	tempo_events = snapshot.get("tempo_events", [])
	max_event_beats = float(snapshot.get("max_event_beats", 0.0))
	event_cursor = 0

func reset_cursor(start_beats: float) -> void:
	event_cursor = 0
	while event_cursor < events.size():
		var time = float(events[event_cursor].get("time", 0.0))
		if time >= start_beats:
			break
		event_cursor += 1

func duplicate_active_notes() -> Dictionary:
	var copy: Dictionary = {}
	for player in active_notes.keys():
		var channel_map: Dictionary = active_notes[player]
		var channel_copy: Dictionary = {}
		for channel in channel_map.keys():
			var notes: Dictionary = channel_map[channel]
			var note_copy: Dictionary = {}
			for pitch in notes.keys():
				note_copy[pitch] = notes[pitch]
			channel_copy[int(channel)] = note_copy
		copy[player] = channel_copy
	return copy

func reset_active_notes() -> void:
	active_notes.clear()

func dispatch_events(from_beats: float, to_beats: float) -> Array:
	var emitted: Array = []
	if events.is_empty():
		return emitted
	if to_beats < from_beats:
		return emitted
	while event_cursor < events.size():
		var event = events[event_cursor]
		var time = float(event.get("time", 0.0))
		if time > to_beats:
			break
		event_cursor += 1
		if time <= from_beats:
			continue
		emitted.append(event)
		_apply_event_to_active_notes(event)
	return emitted

func build_chase_controls(time_beats: float) -> Array:
	var emitted: Array = []
	var program_by_player: Dictionary = {}
	for event in program_events:
		var event_time = float(event.get("time", 0.0))
		if event_time > time_beats:
			break
		var player: Node = event.get("player")
		if player == null:
			continue
		var program = int(event.get("program", DEFAULT_PROGRAM))
		var bank = int(event.get("bank", DEFAULT_BANK))
		if not program_by_player.has(player):
			program_by_player[player] = {}
		var player_map: Dictionary = program_by_player[player]
		player_map[int(event.get("channel", 0))] = {
			"program": program,
			"bank": bank
		}
		program_by_player[player] = player_map
	for player in program_by_player.keys():
		var channel_map: Dictionary = program_by_player[player]
		for channel in channel_map.keys():
			var program_data = channel_map[channel]
			emitted.append({
				"type": "program",
				"time": time_beats,
				"channel": int(channel),
				"program": int(program_data.get("program", DEFAULT_PROGRAM)),
				"bank": int(program_data.get("bank", DEFAULT_BANK)),
				"player": player
			})
	var last_cc: Dictionary = {}
	for cc_event in cc_events:
		var event_time = float(cc_event.get("time", 0.0))
		if event_time > time_beats:
			break
		var player: Node = cc_event.get("player")
		if player == null:
			continue
		var channel = int(cc_event.get("channel", 0)) % MAX_CHANNELS
		var cc_num = int(cc_event.get("cc", 0))
		if not last_cc.has(player):
			last_cc[player] = {}
		var player_map: Dictionary = last_cc[player]
		if not player_map.has(channel):
			player_map[channel] = {}
		var channel_map: Dictionary = player_map[channel]
		channel_map[cc_num] = int(cc_event.get("value", 0))
		player_map[channel] = channel_map
		last_cc[player] = player_map
	for player in last_cc.keys():
		var player_map: Dictionary = last_cc[player]
		for channel in player_map.keys():
			var channel_map: Dictionary = player_map[channel]
			for cc_num in channel_map.keys():
				emitted.append({
					"type": "cc",
					"time": time_beats,
					"channel": int(channel),
					"cc": int(cc_num),
					"value": int(channel_map[cc_num]),
					"player": player
				})
	var last_adsr: Dictionary = {}
	for adsr_event in adsr_events:
		var event_time = float(adsr_event.get("time", 0.0))
		if event_time > time_beats:
			break
		var player: Node = adsr_event.get("player")
		if player == null:
			continue
		var channel = int(adsr_event.get("channel", 0)) % MAX_CHANNELS
		if not last_adsr.has(player):
			last_adsr[player] = {}
		var player_map: Dictionary = last_adsr[player]
		player_map[channel] = float(adsr_event.get("value", 0.0))
		last_adsr[player] = player_map
	for player in last_adsr.keys():
		var player_map: Dictionary = last_adsr[player]
		for channel in player_map.keys():
			emitted.append({
				"type": "adsr_sustain",
				"time": time_beats,
				"channel": int(channel),
				"value": float(player_map[channel]),
				"player": player
			})
	return emitted

func build_chase_notes(time_beats: float, skip_notes: Dictionary) -> Array:
	var emitted: Array = []
	for note in note_ranges:
		var start = float(note.get("start", 0.0))
		var end = float(note.get("end", 0.0))
		if start < time_beats and end > time_beats:
			var player: Node = note.get("player")
			if player == null:
				continue
			var channel = int(note.get("channel", 0)) % MAX_CHANNELS
			var pitch = int(note.get("pitch", 0))
			var player_skip: Dictionary = skip_notes.get(player, {})
			var channel_skip: Dictionary = player_skip.get(channel, {})
			if channel_skip.has(pitch):
				continue
			var velocity = int(note.get("velocity", DEFAULT_VELOCITY))
			emitted.append({
				"type": "note_on",
				"time": time_beats,
				"channel": channel,
				"pitch": pitch,
				"velocity": velocity,
				"player": player
			})
			_track_active_note(player, channel, pitch, velocity)
	return emitted

func reconcile_active_notes(time_beats: float, prev_active: Dictionary) -> Array:
	var emitted: Array = []
	var next_active = active_notes_at(time_beats)
	for player in prev_active.keys():
		var prev_channels: Dictionary = prev_active[player]
		var next_channels: Dictionary = next_active.get(player, {})
		for channel in prev_channels.keys():
			var prev_notes: Dictionary = prev_channels[channel]
			var next_notes: Dictionary = next_channels.get(channel, {})
			for pitch in prev_notes.keys():
				if not next_notes.has(pitch):
					emitted.append({
						"type": "note_off",
						"time": time_beats,
						"channel": int(channel),
						"pitch": int(pitch),
						"velocity": 0,
						"player": player
					})
	for player in next_active.keys():
		var next_channels: Dictionary = next_active[player]
		var prev_channels: Dictionary = prev_active.get(player, {})
		for channel in next_channels.keys():
			var next_notes: Dictionary = next_channels[channel]
			var prev_notes: Dictionary = prev_channels.get(channel, {})
			for pitch in next_notes.keys():
				if not prev_notes.has(pitch):
					var velocity = int(next_notes.get(pitch, DEFAULT_VELOCITY))
					emitted.append({
						"type": "note_on",
						"time": time_beats,
						"channel": int(channel),
						"pitch": int(pitch),
						"velocity": velocity,
						"player": player
					})
	active_notes = next_active
	return emitted

func active_notes_at(time_beats: float) -> Dictionary:
	var active: Dictionary = {}
	for note in note_ranges:
		var start = float(note.get("start", 0.0))
		var end = float(note.get("end", 0.0))
		if start < time_beats and end > time_beats:
			var player: Node = note.get("player")
			if player == null:
				continue
			var channel = int(note.get("channel", 0)) % MAX_CHANNELS
			var pitch = int(note.get("pitch", 0))
			var velocity = int(note.get("velocity", DEFAULT_VELOCITY))
			if not active.has(player):
				active[player] = {}
			var channel_map: Dictionary = active[player]
			if not channel_map.has(channel):
				channel_map[channel] = {}
			var note_map: Dictionary = channel_map[channel]
			note_map[pitch] = velocity
			channel_map[channel] = note_map
			active[player] = channel_map
	return active

func is_finished(playhead_beats: float) -> bool:
	return event_cursor >= events.size() and playhead_beats >= max_event_beats and active_notes.is_empty()

func advance_beats(current_beats: float, delta_seconds: float) -> float:
	var remaining = max(0.0, delta_seconds)
	var t = current_beats
	while remaining > 0.0:
		var bpm = tempo_at(t)
		var seconds_per_beat = 60.0 / max(1.0, bpm)
		var next_tempo_time = next_tempo_time_after(t)
		if next_tempo_time < 0.0:
			t += remaining / seconds_per_beat
			remaining = 0.0
		else:
			var beats_to_next = max(0.0, next_tempo_time - t)
			var seconds_to_next = beats_to_next * seconds_per_beat
			if beats_to_next > 0.0 and seconds_to_next <= remaining:
				t = next_tempo_time
				remaining -= seconds_to_next
			else:
				t += remaining / seconds_per_beat
				remaining = 0.0
	return t

func tempo_at(time_beats: float) -> float:
	var bpm = DEFAULT_BPM
	for event in tempo_events:
		var event_time = float(event.get("time", 0.0))
		if event_time <= time_beats:
			bpm = float(event.get("bpm", bpm))
		else:
			break
	return bpm

func next_tempo_time_after(time_beats: float) -> float:
	for event in tempo_events:
		var event_time = float(event.get("time", 0.0))
		if event_time > time_beats:
			return event_time
	return -1.0

func _apply_event_to_active_notes(event: Dictionary) -> void:
	var event_type = String(event.get("type", ""))
	if event_type != "note_on" and event_type != "note_off":
		return
	var player: Node = event.get("player")
	if player == null:
		return
	var channel = int(event.get("channel", 0)) % MAX_CHANNELS
	var pitch = int(event.get("pitch", 0))
	if event_type == "note_on":
		var velocity = int(event.get("velocity", DEFAULT_VELOCITY))
		_track_active_note(player, channel, pitch, velocity)
	else:
		_track_active_note(player, channel, pitch, 0)

func _track_active_note(player: Node, channel: int, pitch: int, velocity: int) -> void:
	var player_map: Dictionary = active_notes.get(player, {})
	var channel_map: Dictionary = player_map.get(channel, {})
	if velocity > 0:
		channel_map[pitch] = velocity
	else:
		channel_map.erase(pitch)
	if channel_map.is_empty():
		player_map.erase(channel)
	else:
		player_map[channel] = channel_map
	if player_map.is_empty():
		active_notes.erase(player)
	else:
		active_notes[player] = player_map
