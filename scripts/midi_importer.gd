extends RefCounted

class_name MidiImporter

const PROJECT_MODEL = preload("res://scripts/models/project_model.gd")
const CLIP_MODEL = preload("res://scripts/models/clip_model.gd")
const SMF_LIB = preload("res://addons/midi/SMF.gd")

const DEFAULT_CLIP_NAME := "Clip 1"
const MIN_CLIP_BEATS := 1.0

const GM_PROGRAM_NAMES := [
	"Acoustic Grand Piano",
	"Bright Acoustic Piano",
	"Electric Grand Piano",
	"Honky-tonk Piano",
	"Electric Piano 1",
	"Electric Piano 2",
	"Harpsichord",
	"Clavinet",
	"Celesta",
	"Glockenspiel",
	"Music Box",
	"Vibraphone",
	"Marimba",
	"Xylophone",
	"Tubular Bells",
	"Dulcimer",
	"Drawbar Organ",
	"Percussive Organ",
	"Rock Organ",
	"Church Organ",
	"Reed Organ",
	"Accordion",
	"Harmonica",
	"Tango Accordion",
	"Acoustic Guitar (nylon)",
	"Acoustic Guitar (steel)",
	"Electric Guitar (jazz)",
	"Electric Guitar (clean)",
	"Electric Guitar (muted)",
	"Overdriven Guitar",
	"Distortion Guitar",
	"Guitar harmonics",
	"Acoustic Bass",
	"Electric Bass (finger)",
	"Electric Bass (pick)",
	"Fretless Bass",
	"Slap Bass 1",
	"Slap Bass 2",
	"Synth Bass 1",
	"Synth Bass 2",
	"Violin",
	"Viola",
	"Cello",
	"Contrabass",
	"Tremolo Strings",
	"Pizzicato Strings",
	"Orchestral Harp",
	"Timpani",
	"String Ensemble 1",
	"String Ensemble 2",
	"Synth Strings 1",
	"Synth Strings 2",
	"Choir Aahs",
	"Voice Oohs",
	"Synth Voice",
	"Orchestra Hit",
	"Trumpet",
	"Trombone",
	"Tuba",
	"Muted Trumpet",
	"French Horn",
	"Brass Section",
	"Synth Brass 1",
	"Synth Brass 2",
	"Soprano Sax",
	"Alto Sax",
	"Tenor Sax",
	"Baritone Sax",
	"Oboe",
	"English Horn",
	"Bassoon",
	"Clarinet",
	"Piccolo",
	"Flute",
	"Recorder",
	"Pan Flute",
	"Blown Bottle",
	"Shakuhachi",
	"Whistle",
	"Ocarina",
	"Lead 1 (square)",
	"Lead 2 (sawtooth)",
	"Lead 3 (calliope)",
	"Lead 4 (chiff)",
	"Lead 5 (charang)",
	"Lead 6 (voice)",
	"Lead 7 (fifths)",
	"Lead 8 (bass + lead)",
	"Pad 1 (new age)",
	"Pad 2 (warm)",
	"Pad 3 (polysynth)",
	"Pad 4 (choir)",
	"Pad 5 (bowed)",
	"Pad 6 (metallic)",
	"Pad 7 (halo)",
	"Pad 8 (sweep)",
	"FX 1 (rain)",
	"FX 2 (soundtrack)",
	"FX 3 (crystal)",
	"FX 4 (atmosphere)",
	"FX 5 (brightness)",
	"FX 6 (goblins)",
	"FX 7 (echoes)",
	"FX 8 (sci-fi)",
	"Sitar",
	"Banjo",
	"Shamisen",
	"Koto",
	"Kalimba",
	"Bagpipe",
	"Fiddle",
	"Shanai",
	"Tinkle Bell",
	"Agogo",
	"Steel Drums",
	"Woodblock",
	"Taiko Drum",
	"Melodic Tom",
	"Synth Drum",
	"Reverse Cymbal",
	"Guitar Fret Noise",
	"Breath Noise",
	"Seashore",
	"Bird Tweet",
	"Telephone Ring",
	"Helicopter",
	"Applause",
	"Gunshot"
]

func import_project(path: String) -> Node:
	var data = import_project_data(path)
	return build_project_from_data(data)

func import_project_data(path: String) -> Dictionary:
	var smf_reader = SMF_LIB.new()
	var result = smf_reader.read_file(path)
	if result.error != OK or result.data == null:
		return {}
	var smf_data: SMF_LIB.SMFData = result.data
	var tempo_events = _collect_tempo_events(smf_data)
	var signature_events = _collect_time_signature_events(smf_data)
	var track_entries = _build_track_entries(smf_data)
	var filtered_entries: Array = []
	for entry in track_entries:
		var notes = entry.get("notes", [])
		if notes is Array and not notes.is_empty():
			filtered_entries.append(entry)
	return {
		"tempo_events": tempo_events,
		"signature_events": signature_events,
		"entries": filtered_entries
	}

func build_project_from_data(data: Dictionary) -> Node:
	if data.is_empty():
		return null
	var project = PROJECT_MODEL.new()
	var tempo_events: Array = data.get("tempo_events", [])
	var signature_events: Array = data.get("signature_events", [])
	_apply_transport_events(project.transport, tempo_events, signature_events)
	var build_entries: Array = prepare_build_entries(data)
	if build_entries.is_empty():
		project.create_track("Track 1")
		return project
	for item in build_entries:
		var entry = item.get("entry", {})
		var label = String(item.get("label", "Track"))
		var track = project.create_track(label)
		var clip = _build_clip_for_entry(track, entry)
		if track != null and track.has_method("add_clip"):
			track.call("add_clip", clip, 0.0, float(clip.clip_length_beats))
	return project

func prepare_build_entries(data: Dictionary) -> Array:
	var entries: Array = data.get("entries", [])
	var build_entries: Array = []
	var used_names: Dictionary = {}
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var label = _resolve_track_label(entry)
		label = _ensure_unique_label(label, used_names)
		build_entries.append({
			"label": label,
			"entry": entry
		})
	return build_entries

func _apply_transport_map(transport: Node, smf_data: SMF_LIB.SMFData) -> void:
	if transport == null:
		return
	var tempo_events = _collect_tempo_events(smf_data)
	var signature_events = _collect_time_signature_events(smf_data)
	_apply_transport_events(transport, tempo_events, signature_events)

func _apply_transport_events(transport: Node, tempo_events: Array, signature_events: Array) -> void:
	if transport == null:
		return
	if transport.has_method("set_tempo_events"):
		transport.call("set_tempo_events", tempo_events)
	if transport.has_method("set_time_signature_events"):
		transport.call("set_time_signature_events", signature_events)

func _collect_tempo_events(smf_data: SMF_LIB.SMFData) -> Array:
	var timebase = _resolve_timebase(smf_data)
	var events: Array = []
	for track in smf_data.tracks:
		for event_chunk in track.events:
			var event = event_chunk.event
			if event == null:
				continue
			if event.type != SMF_LIB.MIDIEventType.system_event:
				continue
			var args = event.args
			if args == null:
				continue
			if int(args.get("type", -1)) == SMF_LIB.MIDISystemEventType.set_tempo:
				var mpqn = float(args.get("bpm", 0))
				if mpqn <= 0.0:
					continue
				var bpm = 60000000.0 / mpqn
				var time_beats = float(event_chunk.time) / timebase
				events.append({"time": time_beats, "bpm": bpm})
	events.sort_custom(func(a, b): return a["time"] < b["time"])
	return _dedupe_events(events, {"time": 0.0, "bpm": 120.0})

func _collect_time_signature_events(smf_data: SMF_LIB.SMFData) -> Array:
	var timebase = _resolve_timebase(smf_data)
	var events: Array = []
	for track in smf_data.tracks:
		for event_chunk in track.events:
			var event = event_chunk.event
			if event == null:
				continue
			if event.type != SMF_LIB.MIDIEventType.system_event:
				continue
			var args = event.args
			if args == null:
				continue
			if int(args.get("type", -1)) == SMF_LIB.MIDISystemEventType.beat:
				var numerator = int(args.get("numerator", 4))
				var denominator_power = int(args.get("denominator", 2))
				var denominator = int(pow(2.0, float(denominator_power)))
				if denominator <= 0:
					denominator = 4
				var time_beats = float(event_chunk.time) / timebase
				events.append({
					"time": time_beats,
					"numerator": numerator,
					"denominator": denominator
				})
	events.sort_custom(func(a, b): return a["time"] < b["time"])
	return _dedupe_events(events, {"time": 0.0, "numerator": 4, "denominator": 4})

func _build_track_entries(smf_data: SMF_LIB.SMFData) -> Array:
	var entries: Array = []
	var timebase = _resolve_timebase(smf_data)
	for track_index in range(smf_data.tracks.size()):
		var track = smf_data.tracks[track_index]
		var per_track = _parse_track(track, track_index, timebase)
		for entry in per_track:
			entries.append(entry)
	return entries

func _parse_track(track: SMF_LIB.MIDITrack, track_index: int, timebase: float) -> Array:
	var track_name := ""
	var instrument_name_default := ""
	var instrument_name_by_channel: Dictionary = {}
	var program_by_channel: Dictionary = {}
	var channel_data: Dictionary = {}
	var active_notes: Dictionary = {}
	var channel_prefix := -1
	var track_end_ticks := 0

	for event_chunk in track.events:
		var ticks = int(event_chunk.time)
		if ticks > track_end_ticks:
			track_end_ticks = ticks
		var event = event_chunk.event
		if event == null:
			continue
		match event.type:
			SMF_LIB.MIDIEventType.note_on:
				var channel = int(event_chunk.channel_number)
				_ensure_channel(channel_data, active_notes, channel)
				var pitch = int(event.note)
				var velocity = int(event.velocity)
				var pitch_notes: Array = active_notes[channel].get(pitch, [])
				pitch_notes.append({"start": ticks, "velocity": velocity})
				active_notes[channel][pitch] = pitch_notes
			SMF_LIB.MIDIEventType.note_off:
				var channel = int(event_chunk.channel_number)
				_ensure_channel(channel_data, active_notes, channel)
				var pitch = int(event.note)
				var pitch_notes: Array = active_notes[channel].get(pitch, [])
				if pitch_notes.is_empty():
					continue
				var note_info = pitch_notes.pop_at(0)
				active_notes[channel][pitch] = pitch_notes
				var duration_ticks = max(1, ticks - int(note_info.get("start", ticks)))
				var end_ticks = int(note_info.get("start", ticks)) + duration_ticks
				channel_data[channel]["notes"].append({
					"pitch": pitch,
					"start": int(note_info.get("start", ticks)),
					"duration": duration_ticks,
					"velocity": int(note_info.get("velocity", 100))
				})
				channel_data[channel]["max_end_ticks"] = max(int(channel_data[channel]["max_end_ticks"]), end_ticks)
			SMF_LIB.MIDIEventType.control_change:
				var channel = int(event_chunk.channel_number)
				_ensure_channel(channel_data, active_notes, channel)
				channel_data[channel]["cc"].append({
					"number": int(event.number),
					"value": int(event.value),
					"time": ticks
				})
				channel_data[channel]["max_end_ticks"] = max(int(channel_data[channel]["max_end_ticks"]), ticks)
			SMF_LIB.MIDIEventType.program_change:
				var channel = int(event_chunk.channel_number)
				program_by_channel[channel] = int(event.number)
			SMF_LIB.MIDIEventType.system_event:
				var args = event.args
				if args == null:
					continue
				match int(args.get("type", -1)):
					SMF_LIB.MIDISystemEventType.midi_channel_prefix:
						channel_prefix = int(args.get("channel", -1))
					SMF_LIB.MIDISystemEventType.track_name:
						track_name = String(args.get("text", track_name))
					SMF_LIB.MIDISystemEventType.instrument_name:
						if channel_prefix >= 0:
							instrument_name_by_channel[channel_prefix] = String(args.get("text", ""))
						else:
							instrument_name_default = String(args.get("text", ""))
					_:
						pass
			_:
				pass

	_close_active_notes(channel_data, active_notes, track_end_ticks)

	var used_channels: Array = []
	for channel in channel_data.keys():
		used_channels.append(int(channel))
	for channel in program_by_channel.keys():
		if not used_channels.has(int(channel)):
			used_channels.append(int(channel))
	for channel in instrument_name_by_channel.keys():
		if not used_channels.has(int(channel)):
			used_channels.append(int(channel))
	used_channels.sort()

	var channel_count = used_channels.size()
	var entries: Array = []
	for channel in used_channels:
		var entry = channel_data.get(channel, {"notes": [], "cc": [], "max_end_ticks": 0})
		var notes: Array = []
		var max_end_beats = 0.0
		for note in entry.get("notes", []):
			var start_beats = float(note.get("start", 0)) / timebase
			var duration_beats = float(note.get("duration", 1)) / timebase
			duration_beats = max(duration_beats, 1.0 / timebase)
			notes.append({
				"pitch": int(note.get("pitch", 0)),
				"start": start_beats,
				"duration": duration_beats,
				"velocity": int(note.get("velocity", 100))
			})
			max_end_beats = max(max_end_beats, start_beats + duration_beats)
		notes.sort_custom(func(a, b): return a["start"] < b["start"])

		var cc_events: Array = []
		for cc in entry.get("cc", []):
			var time_beats = float(cc.get("time", 0)) / timebase
			cc_events.append({
				"number": int(cc.get("number", 0)),
				"value": int(cc.get("value", 0)),
				"time": time_beats
			})
			max_end_beats = max(max_end_beats, time_beats)
		cc_events.sort_custom(func(a, b): return a["time"] < b["time"])

		var instrument_name = String(instrument_name_by_channel.get(channel, instrument_name_default))
		entries.append({
			"track_index": track_index,
			"channel": channel,
			"channel_count": channel_count,
			"track_name": track_name,
			"instrument_name": instrument_name,
			"program": int(program_by_channel.get(channel, -1)),
			"notes": notes,
			"cc": cc_events,
			"max_end_beats": max_end_beats
		})
	return entries

func _close_active_notes(channel_data: Dictionary, active_notes: Dictionary, end_ticks: int) -> void:
	for channel in active_notes.keys():
		_ensure_channel(channel_data, active_notes, int(channel))
		var pitch_map: Dictionary = active_notes[channel]
		for pitch in pitch_map.keys():
			var pitch_notes: Array = pitch_map[pitch]
			for note_info in pitch_notes:
				var start_ticks = int(note_info.get("start", end_ticks))
				var duration_ticks = max(1, end_ticks - start_ticks)
				var end_note_ticks = start_ticks + duration_ticks
				channel_data[channel]["notes"].append({
					"pitch": int(pitch),
					"start": start_ticks,
					"duration": duration_ticks,
					"velocity": int(note_info.get("velocity", 100))
				})
				channel_data[channel]["max_end_ticks"] = max(int(channel_data[channel]["max_end_ticks"]), end_note_ticks)
		pitch_map.clear()

func _ensure_channel(channel_data: Dictionary, active_notes: Dictionary, channel: int) -> void:
	if not channel_data.has(channel):
		channel_data[channel] = {"notes": [], "cc": [], "max_end_ticks": 0}
	if not active_notes.has(channel):
		active_notes[channel] = {}

func _resolve_track_label(entry: Dictionary) -> String:
	var label = String(entry.get("instrument_name", ""))
	if label == "":
		label = _program_name(int(entry.get("program", -1)))
	if label == "":
		label = String(entry.get("track_name", ""))
	if label == "":
		label = "Track %d" % (int(entry.get("track_index", 0)) + 1)
	var channel_count = int(entry.get("channel_count", 1))
	if channel_count > 1:
		label = "%s Ch %d" % [label, int(entry.get("channel", 0)) + 1]
	return label

func _program_name(program: int) -> String:
	if program < 0 or program >= GM_PROGRAM_NAMES.size():
		return ""
	return GM_PROGRAM_NAMES[program]

func _ensure_unique_label(label: String, used_names: Dictionary) -> String:
	if not used_names.has(label):
		used_names[label] = 1
		return label
	var count = int(used_names[label]) + 1
	used_names[label] = count
	return "%s %d" % [label, count]

func _build_clip_for_entry(track: Node, entry: Dictionary) -> Node:
	var clip = CLIP_MODEL.new()
	var clip_index = track.clips.size() if track != null else 0
	var track_id = track.id if track != null else "track"
	clip.id = "clip_%s_%d" % [str(track_id), clip_index + 1]
	clip.clip_name = DEFAULT_CLIP_NAME
	clip.clip_start_beats = 0.0
	clip.begin_bulk_update()
	for note in entry.get("notes", []):
		var note_index = clip.notes.size()
		clip.add_note(
			int(note.get("pitch", 0)),
			float(note.get("start", 0.0)),
			float(note.get("duration", 0.0)),
			0
		)
		clip.update_velocity(note_index, int(note.get("velocity", 100)))
	for cc in entry.get("cc", []):
		var param = "CC%d" % int(cc.get("number", 0))
		var value = clamp(float(cc.get("value", 0)) / 127.0, 0.0, 1.0)
		clip.set_point_for_param(param, float(cc.get("time", 0.0)), value, 0.0)
	clip.clip_length_beats = max(MIN_CLIP_BEATS, float(entry.get("max_end_beats", 0.0)))
	clip.end_bulk_update()
	return clip

func _resolve_timebase(smf_data: SMF_LIB.SMFData) -> float:
	var timebase = float(smf_data.timebase)
	if timebase <= 0.0:
		timebase = 480.0
	return timebase

func _dedupe_events(events: Array, fallback: Dictionary) -> Array:
	var deduped: Array = []
	for event in events:
		if deduped.is_empty():
			deduped.append(event)
			continue
		var last = deduped[deduped.size() - 1]
		if is_equal_approx(float(event.get("time", 0.0)), float(last.get("time", 0.0))):
			deduped[deduped.size() - 1] = event
		else:
			deduped.append(event)
	if deduped.is_empty():
		deduped.append(fallback)
	return deduped
