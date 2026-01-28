extends RefCounted

class_name MidiExporter

const SMF_LIB = preload("res://addons/midi/SMF.gd")

const DEFAULT_TIMEBASE := 480
const DEFAULT_PROGRAM := 0
const DEFAULT_VELOCITY := 100
const BEAT_META_CLOCK := 24
const BEAT_META_32 := 8

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

func export_project_to_bytes(project_model: Node) -> PackedByteArray:
	var smf_data = export_project(project_model)
	if smf_data == null:
		return PackedByteArray()
	var smf = SMF_LIB.new()
	var data = smf.write(smf_data, false, true)
	if data == null:
		return PackedByteArray()
	return data

func export_clip_to_bytes(project_model: Node, track_index: int, clip_index: int) -> PackedByteArray:
	var smf_data = export_clip(project_model, track_index, clip_index)
	if smf_data == null:
		return PackedByteArray()
	var smf = SMF_LIB.new()
	var data = smf.write(smf_data, false, true)
	if data == null:
		return PackedByteArray()
	return data

func export_project(project_model: Node) -> SMF_LIB.SMFData:
	if project_model == null:
		return null
	var timebase = DEFAULT_TIMEBASE
	var tracks: Array[SMF_LIB.MIDITrack] = []
	var transport = project_model.transport
	tracks.append(_build_meta_track(transport, timebase))
	var track_list = project_model.tracks if project_model.has_method("get") else []
	for i in range(track_list.size()):
		var channel = _resolve_channel(i)
		var track = track_list[i]
		var events: Array[SMF_LIB.MIDIEventChunk] = _build_track_events(track, channel, timebase)
		var midi_track = SMF_LIB.MIDITrack.new()
		midi_track.track_number = i + 1
		midi_track.events = events
		tracks.append(midi_track)
	var smf_data: SMF_LIB.SMFData = SMF_LIB.SMFData.new(SMF_LIB.SMFFormat.format_1, tracks.size(), timebase, tracks)
	return smf_data

func export_clip(project_model: Node, track_index: int, clip_index: int) -> SMF_LIB.SMFData:
	if project_model == null:
		return null
	var track = _resolve_track(project_model, track_index)
	if track == null:
		return null
	var clip = _resolve_clip(track, clip_index)
	if clip == null:
		return null
	var timebase = DEFAULT_TIMEBASE
	var tracks: Array[SMF_LIB.MIDITrack] = []
	var transport = project_model.transport
	tracks.append(_build_meta_track(transport, timebase))
	var channel = _resolve_channel(track_index)
	var events: Array[SMF_LIB.MIDIEventChunk] = _build_clip_events(clip, track, channel, timebase)
	var midi_track = SMF_LIB.MIDITrack.new()
	midi_track.track_number = 1
	midi_track.events = events
	tracks.append(midi_track)
	var smf_data: SMF_LIB.SMFData = SMF_LIB.SMFData.new(SMF_LIB.SMFFormat.format_1, tracks.size(), timebase, tracks)
	return smf_data

func _build_meta_track(transport: Node, timebase: int) -> SMF_LIB.MIDITrack:
	var events: Array[SMF_LIB.MIDIEventChunk] = []
	var tempo_events: Array = []
	var signature_events: Array = []
	if transport != null:
		if transport.has_method("get_tempo_events"):
			tempo_events = transport.call("get_tempo_events")
		if transport.has_method("get_time_signature_events"):
			signature_events = transport.call("get_time_signature_events")
	if tempo_events.is_empty():
		tempo_events = [{"time": 0.0, "bpm": 120.0}]
	if signature_events.is_empty():
		signature_events = [{"time": 0.0, "numerator": 4, "denominator": 4}]
	for tempo in tempo_events:
		var bpm = float(tempo.get("bpm", 120.0))
		var mpqn = int(round(60000000.0 / max(1.0, bpm)))
		events.append(_make_system_event(int(round(float(tempo.get("time", 0.0)) * timebase)), {
			"type": SMF_LIB.MIDISystemEventType.set_tempo,
			"bpm": mpqn
		}))
	for signature in signature_events:
		var numerator = int(signature.get("numerator", 4))
		var denominator = int(signature.get("denominator", 4))
		var denom_pow = _denominator_power(denominator)
		events.append(_make_system_event(int(round(float(signature.get("time", 0.0)) * timebase)), {
			"type": SMF_LIB.MIDISystemEventType.beat,
			"numerator": numerator,
			"denominator": denom_pow,
			"clock": BEAT_META_CLOCK,
			"beat32": BEAT_META_32
		}))
	_append_end_of_track(events)
	var meta_track = SMF_LIB.MIDITrack.new()
	meta_track.track_number = 0
	meta_track.events = events
	return meta_track

func _build_track_events(track: Node, channel: int, timebase: int) -> Array[SMF_LIB.MIDIEventChunk]:
	var events: Array[SMF_LIB.MIDIEventChunk] = []
	var label = _track_label(track)
	if label != "":
		events.append(_make_system_event(0, {
			"type": SMF_LIB.MIDISystemEventType.track_name,
			"text": label
		}))
	var program = _track_program(track)
	events.append(SMF_LIB.MIDIEventChunk.new(0, channel, SMF_LIB.MIDIEventProgramChange.new(program)))
	var entries = _collect_track_entries(track)
	for entry in entries:
		var entry_start = float(entry.get("start", 0.0))
		var clip = entry.get("clip")
		if clip == null:
			continue
		var notes: Array = clip.get("notes") if clip.has_method("get") else []
		for note in notes:
			var start_beats = entry_start + float(note.get("start", 0.0))
			var duration_beats = max(0.0, float(note.get("duration", 0.0)))
			var velocity = int(note.get("velocity", DEFAULT_VELOCITY))
			var pitch = int(note.get("pitch", 0))
			var start_ticks = int(round(start_beats * timebase))
			var duration_ticks = max(1, int(round(duration_beats * timebase)))
			var end_ticks = start_ticks + duration_ticks
			events.append(SMF_LIB.MIDIEventChunk.new(start_ticks, channel, SMF_LIB.MIDIEventNoteOn.new(pitch, velocity)))
			events.append(SMF_LIB.MIDIEventChunk.new(end_ticks, channel, SMF_LIB.MIDIEventNoteOff.new(pitch, 0)))
		_append_cc_events(events, clip, entry_start, channel, timebase)
	_append_end_of_track(events)
	return events

func _build_clip_events(clip: Node, track: Node, channel: int, timebase: int) -> Array[SMF_LIB.MIDIEventChunk]:
	var events: Array[SMF_LIB.MIDIEventChunk] = []
	var label = _track_label(track)
	if label == "" and clip != null and clip.has_method("get"):
		label = str(clip.get("clip_name"))
	if label != "":
		events.append(_make_system_event(0, {
			"type": SMF_LIB.MIDISystemEventType.track_name,
			"text": label
		}))
	var program = _track_program(track)
	events.append(SMF_LIB.MIDIEventChunk.new(0, channel, SMF_LIB.MIDIEventProgramChange.new(program)))
	var notes: Array = []
	if clip != null and clip.has_method("get"):
		notes = clip.get("notes")
	for note in notes:
		var start_beats = float(note.get("start", 0.0))
		var duration_beats = max(0.0, float(note.get("duration", 0.0)))
		var velocity = int(note.get("velocity", DEFAULT_VELOCITY))
		var pitch = int(note.get("pitch", 0))
		var start_ticks = int(round(start_beats * timebase))
		var duration_ticks = max(1, int(round(duration_beats * timebase)))
		var end_ticks = start_ticks + duration_ticks
		events.append(SMF_LIB.MIDIEventChunk.new(start_ticks, channel, SMF_LIB.MIDIEventNoteOn.new(pitch, velocity)))
		events.append(SMF_LIB.MIDIEventChunk.new(end_ticks, channel, SMF_LIB.MIDIEventNoteOff.new(pitch, 0)))
	_append_cc_events(events, clip, 0.0, channel, timebase)
	_append_end_of_track(events)
	return events

func _resolve_track(project_model: Node, track_index: int) -> Node:
	if project_model == null:
		return null
	var track_list = project_model.tracks if project_model.has_method("get") else []
	if track_index < 0 or track_index >= track_list.size():
		return null
	return track_list[track_index]

func _resolve_clip(track: Node, clip_index: int) -> Node:
	if track == null:
		return null
	var clips = track.clips if track.has_method("get") else []
	if clip_index < 0 or clip_index >= clips.size():
		return null
	return clips[clip_index]

func _append_cc_events(events: Array, clip: Node, entry_start: float, channel: int, timebase: int) -> void:
	if clip == null:
		return
	if not clip.has_method("get_param_names"):
		return
	var params: Array = clip.call("get_param_names")
	for param in params:
		var param_name = String(param)
		if not param_name.begins_with("CC"):
			continue
		var cc_num = int(param_name.replace("CC", ""))
		var points: Array = []
		if clip.has_method("get_points_for_param"):
			points = clip.call("get_points_for_param", param_name)
		for point in points:
			var time_beats = entry_start + float(point.get("time", 0.0))
			var value = clamp(float(point.get("value", 0.0)), 0.0, 1.0)
			var ticks = int(round(time_beats * timebase))
			var cc_value = int(round(value * 127.0))
			events.append(SMF_LIB.MIDIEventChunk.new(ticks, channel, SMF_LIB.MIDIEventControlChange.new(cc_num, cc_value)))

func _collect_track_entries(track: Node) -> Array:
	var entries: Array = []
	if track == null:
		return entries
	var arrangement = track.get("arrangement") if track.has_method("get") else []
	if arrangement is Array and not arrangement.is_empty():
		for entry in arrangement:
			if entry is Dictionary:
				entries.append(entry)
	if entries.is_empty():
		var clips = track.get("clips") if track.has_method("get") else []
		if clips is Array and clips.size() > 0 and clips[0] != null:
			entries.append({"clip": clips[0], "start": 0.0, "length": float(clips[0].clip_length_beats)})
	return entries

func _track_label(track: Node) -> String:
	if track == null:
		return ""
	return str(track.track_name) if track.has_method("get") else ""

func _track_program(track: Node) -> int:
	var label = _strip_channel_suffix(_track_label(track))
	for i in range(GM_PROGRAM_NAMES.size()):
		if GM_PROGRAM_NAMES[i].to_lower() == label.to_lower():
			return i
	return DEFAULT_PROGRAM

func _strip_channel_suffix(label: String) -> String:
	var text = label.strip_edges()
	var idx = text.find(" Ch ")
	if idx >= 0:
		return text.substr(0, idx).strip_edges()
	return text

func _resolve_channel(track_index: int) -> int:
	return int(track_index % 16)

func _denominator_power(denominator: int) -> int:
	var pow_val = 0
	var value = max(1, denominator)
	while value > 1:
		value >>= 1
		pow_val += 1
	return pow_val

func _make_system_event(time_ticks: int, args: Dictionary) -> SMF_LIB.MIDIEventChunk:
	return SMF_LIB.MIDIEventChunk.new(time_ticks, 0, SMF_LIB.MIDIEventSystemEvent.new(args))

func _append_end_of_track(events: Array[SMF_LIB.MIDIEventChunk]) -> void:
	var time_ticks := 0
	for event in events:
		if event != null and int(event.time) > time_ticks:
			time_ticks = int(event.time)
	events.append(_make_system_event(time_ticks, {"type": SMF_LIB.MIDISystemEventType.end_of_track}))
