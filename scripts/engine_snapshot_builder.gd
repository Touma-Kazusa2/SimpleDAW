extends RefCounted

class_name EngineSnapshotBuilder

const PLAYBACK_MODE_TRACKS := "tracks"
const PLAYBACK_MODE_CLIP := "clip"
const DEFAULT_BPM := 120.0
const DEFAULT_PROGRAM := 0
const DEFAULT_VELOCITY := 100
const MIN_NOTE_LENGTH_BEATS := 0.0001
const MAX_CHANNELS := 16
const ADSR_PARAMS := ["Attack", "Decay", "Sustain", "Release"]
const ADSR_TIME_MAX := 10.0
const SUSTAIN_MIN_DB := -80.0
const SUSTAIN_MAX_DB := 0.0
const CC_ATTACK_TIME := 73
const CC_DECAY_TIME := 75
const CC_RELEASE_TIME := 72

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

func build_snapshot(
		project_model: Node,
		playback_mode: String,
		playback_track_index: int,
		playback_clip_index: int,
		track_router: Node,
		midi_player: Node
	) -> Dictionary:
	var snapshot := {
		"events": [],
		"note_ranges": [],
		"cc_events": [],
		"adsr_events": [],
		"program_events": [],
		"tempo_events": [],
		"max_event_beats": 0.0,
		"players_in_use": []
	}
	_refresh_tempo_events(project_model, snapshot)
	if project_model == null:
		return snapshot
	if playback_mode == PLAYBACK_MODE_TRACKS:
		_build_tracks_cache(project_model, track_router, midi_player, snapshot)
	else:
		_build_clip_cache(project_model, playback_track_index, playback_clip_index, track_router, midi_player, snapshot)
	snapshot["events"].sort_custom(Callable(self, "_event_sort"))
	snapshot["cc_events"].sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	snapshot["adsr_events"].sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	snapshot["program_events"].sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	return snapshot

func build_snapshot_from_data(
		model_data: Dictionary,
		playback_mode: String,
		playback_track_index: int,
		playback_clip_index: int,
		track_routes: Array,
		default_player: Node
	) -> Dictionary:
	var snapshot := {
		"events": [],
		"note_ranges": [],
		"cc_events": [],
		"adsr_events": [],
		"program_events": [],
		"tempo_events": [],
		"max_event_beats": 0.0,
		"players_in_use": []
	}
	_refresh_tempo_events_from_data(model_data, snapshot)
	if playback_mode == PLAYBACK_MODE_TRACKS:
		_build_tracks_from_data(model_data, track_routes, default_player, snapshot)
	else:
		_build_clip_from_data(model_data, playback_track_index, playback_clip_index, track_routes, default_player, snapshot)
	snapshot["events"].sort_custom(Callable(self, "_event_sort"))
	snapshot["cc_events"].sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	snapshot["adsr_events"].sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	snapshot["program_events"].sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	return snapshot

func _build_tracks_cache(project_model: Node, track_router: Node, midi_player: Node, snapshot: Dictionary) -> void:
	var tracks = project_model.tracks if project_model.has_method("get") else []
	var solo_active = _has_solo_tracks(tracks)
	for track_index in range(tracks.size()):
		var track = tracks[track_index]
		if track == null:
			continue
		if _should_skip_track(track, solo_active):
			continue
		var route = _resolve_route(track_router, track_index, track, midi_player)
		var player = route.get("player", midi_player)
		var channel = int(route.get("channel", _resolve_channel(track_index)))
		_register_player(snapshot, player)
		var program = _track_program(track)
		_add_program_event(snapshot, 0.0, player, channel, program)
		_add_adsr_events(snapshot, track, player, channel)
		var arrangement = track.get("arrangement") if track.has_method("get") else []
		for entry in arrangement:
			if entry is Dictionary:
				var entry_start = float(entry.get("start", 0.0))
				var entry_length = float(entry.get("length", 0.0))
				var clip = entry.get("clip")
				if clip == null:
					continue
				_add_clip_events(snapshot, clip, player, channel, entry_start, entry_length)

func _build_clip_cache(project_model: Node, track_index: int, clip_index: int, track_router: Node, midi_player: Node, snapshot: Dictionary) -> void:
	var track = _resolve_track(project_model, track_index)
	if track == null:
		return
	var clip = _resolve_clip(track, clip_index)
	if clip == null:
		return
	var route = _resolve_route(track_router, track_index, track, midi_player)
	var player = route.get("player", midi_player)
	var channel = int(route.get("channel", _resolve_channel(track_index)))
	_register_player(snapshot, player)
	var program = _track_program(track)
	_add_program_event(snapshot, 0.0, player, channel, program)
	_add_adsr_events(snapshot, track, player, channel)
	var clip_length = float(clip.get("clip_length_beats")) if clip.has_method("get") else 0.0
	_add_clip_events(snapshot, clip, player, channel, 0.0, clip_length)

func _build_tracks_from_data(model_data: Dictionary, track_routes: Array, default_player: Node, snapshot: Dictionary) -> void:
	var tracks: Array = model_data.get("tracks", [])
	var solo_active = _has_solo_tracks_data(tracks)
	for track_index in range(tracks.size()):
		var track_data = tracks[track_index]
		if not (track_data is Dictionary):
			continue
		if _should_skip_track_data(track_data, solo_active):
			continue
		var route = _resolve_route_from_data(track_routes, track_index, default_player)
		var player = route.get("player", default_player)
		var channel = int(route.get("channel", _resolve_channel(track_index)))
		_register_player(snapshot, player)
		var program = _track_program_from_data(track_data)
		_add_program_event(snapshot, 0.0, player, channel, program)
		_add_adsr_events_from_data(snapshot, track_data, player, channel)
		var arrangement: Array = track_data.get("arrangement", [])
		for entry in arrangement:
			if entry is Dictionary:
				var entry_start = float(entry.get("start", 0.0))
				var entry_length = float(entry.get("length", 0.0))
				var clip_data = entry.get("clip")
				if clip_data == null:
					continue
				_add_clip_data_events(snapshot, clip_data, player, channel, entry_start, entry_length)

func _build_clip_from_data(model_data: Dictionary, track_index: int, clip_index: int, track_routes: Array, default_player: Node, snapshot: Dictionary) -> void:
	var track_data = _resolve_track_data(model_data, track_index)
	if track_data.is_empty():
		return
	var clip_data = _resolve_clip_data(track_data, clip_index)
	if clip_data.is_empty():
		return
	var route = _resolve_route_from_data(track_routes, track_index, default_player)
	var player = route.get("player", default_player)
	var channel = int(route.get("channel", _resolve_channel(track_index)))
	_register_player(snapshot, player)
	var program = _track_program_from_data(track_data)
	_add_program_event(snapshot, 0.0, player, channel, program)
	_add_adsr_events_from_data(snapshot, track_data, player, channel)
	var clip_length = float(clip_data.get("clip_length_beats", 0.0))
	_add_clip_data_events(snapshot, clip_data, player, channel, 0.0, clip_length)

func _add_clip_data_events(snapshot: Dictionary, clip_data: Dictionary, player: Node, channel: int, entry_start: float, entry_length: float) -> void:
	if clip_data.is_empty():
		return
	var notes: Array = clip_data.get("notes", [])
	for note in notes:
		if not (note is Dictionary):
			continue
		var start_beats = entry_start + float(note.get("start", 0.0))
		var duration_beats = max(MIN_NOTE_LENGTH_BEATS, float(note.get("duration", 0.0)))
		var end_beats = start_beats + duration_beats
		if entry_length > 0.0:
			var entry_end = entry_start + entry_length
			if start_beats >= entry_end:
				continue
			end_beats = min(end_beats, entry_end)
		if end_beats <= start_beats:
			continue
		var velocity = int(note.get("velocity", DEFAULT_VELOCITY))
		var pitch = int(note.get("pitch", 0))
		snapshot["note_ranges"].append({
			"start": start_beats,
			"end": end_beats,
			"pitch": pitch,
			"velocity": velocity,
			"channel": channel,
			"player": player
		})
		snapshot["events"].append({
			"time": start_beats,
			"type": "note_on",
			"channel": channel,
			"pitch": pitch,
			"velocity": velocity,
			"player": player
		})
		snapshot["events"].append({
			"time": end_beats,
			"type": "note_off",
			"channel": channel,
			"pitch": pitch,
			"velocity": 0,
			"player": player
		})
		snapshot["max_event_beats"] = max(snapshot["max_event_beats"], end_beats)
	_add_cc_events_from_data(snapshot, clip_data, player, channel, entry_start, entry_length)
	if entry_length > 0.0:
		snapshot["max_event_beats"] = max(snapshot["max_event_beats"], entry_start + entry_length)

func _add_cc_events_from_data(snapshot: Dictionary, clip_data: Dictionary, player: Node, channel: int, entry_start: float, entry_length: float) -> void:
	var automation: Dictionary = clip_data.get("automation", {})
	for param in automation.keys():
		var param_name = String(param)
		if not param_name.begins_with("CC"):
			continue
		var cc_num = int(param_name.replace("CC", ""))
		var points: Array = automation.get(param_name, [])
		for point in points:
			if not (point is Dictionary):
				continue
			var time_beats = entry_start + float(point.get("time", 0.0))
			if entry_length > 0.0 and time_beats > entry_start + entry_length:
				continue
			var value = clamp(float(point.get("value", 0.0)), 0.0, 1.0)
			var cc_value = int(round(value * 127.0))
			snapshot["cc_events"].append({
				"time": time_beats,
				"channel": channel,
				"cc": cc_num,
				"value": cc_value,
				"player": player
			})
			snapshot["events"].append({
				"time": time_beats,
				"type": "cc",
				"channel": channel,
				"cc": cc_num,
				"value": cc_value,
				"player": player
			})
			snapshot["max_event_beats"] = max(snapshot["max_event_beats"], time_beats)

func _add_clip_events(snapshot: Dictionary, clip: Node, player: Node, channel: int, entry_start: float, entry_length: float) -> void:
	if clip == null or not clip.has_method("get"):
		return
	var notes: Array = clip.get("notes")
	for note in notes:
		var start_beats = entry_start + float(note.get("start", 0.0))
		var duration_beats = max(MIN_NOTE_LENGTH_BEATS, float(note.get("duration", 0.0)))
		var end_beats = start_beats + duration_beats
		if entry_length > 0.0:
			var entry_end = entry_start + entry_length
			if start_beats >= entry_end:
				continue
			end_beats = min(end_beats, entry_end)
		if end_beats <= start_beats:
			continue
		var velocity = int(note.get("velocity", DEFAULT_VELOCITY))
		var pitch = int(note.get("pitch", 0))
		snapshot["note_ranges"].append({
			"start": start_beats,
			"end": end_beats,
			"pitch": pitch,
			"velocity": velocity,
			"channel": channel,
			"player": player
		})
		snapshot["events"].append({
			"time": start_beats,
			"type": "note_on",
			"channel": channel,
			"pitch": pitch,
			"velocity": velocity,
			"player": player
		})
		snapshot["events"].append({
			"time": end_beats,
			"type": "note_off",
			"channel": channel,
			"pitch": pitch,
			"velocity": 0,
			"player": player
		})
		snapshot["max_event_beats"] = max(snapshot["max_event_beats"], end_beats)
	_add_cc_events(snapshot, clip, player, channel, entry_start, entry_length)
	if entry_length > 0.0:
		snapshot["max_event_beats"] = max(snapshot["max_event_beats"], entry_start + entry_length)

func _add_cc_events(snapshot: Dictionary, clip: Node, player: Node, channel: int, entry_start: float, entry_length: float) -> void:
	if clip == null or not clip.has_method("get_param_names"):
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
			if entry_length > 0.0 and time_beats > entry_start + entry_length:
				continue
			var value = clamp(float(point.get("value", 0.0)), 0.0, 1.0)
			var cc_value = int(round(value * 127.0))
			snapshot["cc_events"].append({
				"time": time_beats,
				"channel": channel,
				"cc": cc_num,
				"value": cc_value,
				"player": player
			})
			snapshot["events"].append({
				"time": time_beats,
				"type": "cc",
				"channel": channel,
				"cc": cc_num,
				"value": cc_value,
				"player": player
			})
			snapshot["max_event_beats"] = max(snapshot["max_event_beats"], time_beats)

func _add_program_event(snapshot: Dictionary, time_beats: float, player: Node, channel: int, program: int) -> void:
	snapshot["program_events"].append({
		"time": time_beats,
		"channel": channel,
		"program": program,
		"player": player
	})
	snapshot["events"].append({
		"time": time_beats,
		"type": "program",
		"channel": channel,
		"program": program,
		"player": player
	})

func _add_adsr_events(snapshot: Dictionary, track: Node, player: Node, channel: int) -> void:
	if track == null:
		return
	if track.has_method("has_adsr_override") and not bool(track.call("has_adsr_override")):
		return
	var defaults: Dictionary = {}
	var automation: Dictionary = {}
	if track.has_method("get_adsr_defaults"):
		defaults = track.call("get_adsr_defaults")
	if track.has_method("get_adsr_automation_data"):
		automation = track.call("get_adsr_automation_data")
	_add_adsr_events_from_values(snapshot, defaults, automation, player, channel)

func _add_adsr_events_from_data(snapshot: Dictionary, track_data: Dictionary, player: Node, channel: int) -> void:
	if track_data.is_empty():
		return
	if track_data.has("adsr_override") and not bool(track_data.get("adsr_override")):
		return
	var defaults: Dictionary = track_data.get("adsr_defaults", {})
	var automation: Dictionary = track_data.get("adsr_automation", {})
	_add_adsr_events_from_values(snapshot, defaults, automation, player, channel)

func _add_adsr_events_from_values(
	snapshot: Dictionary,
	defaults: Dictionary,
	automation: Dictionary,
	player: Node,
	channel: int
) -> void:
	for param in ADSR_PARAMS:
		var default_value = clamp(float(defaults.get(param, 0.0)), 0.0, 1.0)
		_queue_adsr_param_event(snapshot, param, 0.0, default_value, player, channel)
		var points: Array = automation.get(param, [])
		for point in points:
			if not (point is Dictionary):
				continue
			var time_beats = float(point.get("time", 0.0))
			var value = clamp(float(point.get("value", default_value)), 0.0, 1.0)
			_queue_adsr_param_event(snapshot, param, time_beats, value, player, channel)

func _queue_adsr_param_event(
	snapshot: Dictionary,
	param: String,
	time_beats: float,
	value: float,
	player: Node,
	channel: int
) -> void:
	if param == "Sustain":
		var sustain_db = lerp(SUSTAIN_MIN_DB, SUSTAIN_MAX_DB, value)
		_add_adsr_sustain_event(snapshot, time_beats, player, channel, sustain_db)
		return
	var cc_num = _adsr_param_cc(param)
	if cc_num < 0:
		return
	_add_cc_event(snapshot, time_beats, player, channel, cc_num, value)

func _adsr_param_cc(param: String) -> int:
	match param:
		"Attack":
			return CC_ATTACK_TIME
		"Decay":
			return CC_DECAY_TIME
		"Release":
			return CC_RELEASE_TIME
		_:
			return -1

func _add_cc_event(snapshot: Dictionary, time_beats: float, player: Node, channel: int, cc_num: int, value: float) -> void:
	var cc_value = int(round(clamp(value, 0.0, 1.0) * 127.0))
	snapshot["cc_events"].append({
		"time": time_beats,
		"channel": channel,
		"cc": cc_num,
		"value": cc_value,
		"player": player
	})
	snapshot["events"].append({
		"time": time_beats,
		"type": "cc",
		"channel": channel,
		"cc": cc_num,
		"value": cc_value,
		"player": player
	})
	snapshot["max_event_beats"] = max(snapshot["max_event_beats"], time_beats)

func _add_adsr_sustain_event(snapshot: Dictionary, time_beats: float, player: Node, channel: int, sustain_db: float) -> void:
	var clamped_db = clamp(sustain_db, SUSTAIN_MIN_DB, SUSTAIN_MAX_DB)
	snapshot["adsr_events"].append({
		"time": time_beats,
		"channel": channel,
		"value": clamped_db,
		"player": player
	})
	snapshot["events"].append({
		"time": time_beats,
		"type": "adsr_sustain",
		"channel": channel,
		"value": clamped_db,
		"player": player
	})
	snapshot["max_event_beats"] = max(snapshot["max_event_beats"], time_beats)

func _event_sort(a: Dictionary, b: Dictionary) -> bool:
	var time_a = float(a.get("time", 0.0))
	var time_b = float(b.get("time", 0.0))
	if is_equal_approx(time_a, time_b):
		return _event_order(String(a.get("type", ""))) < _event_order(String(b.get("type", "")))
	return time_a < time_b

func _event_order(event_type: String) -> int:
	match event_type:
		"program":
			return 0
		"cc":
			return 1
		"adsr_sustain":
			return 2
		"note_off":
			return 3
		"note_on":
			return 4
		_:
			return 99

func _refresh_tempo_events(project_model: Node, snapshot: Dictionary) -> void:
	snapshot["tempo_events"].clear()
	var transport = project_model.transport if project_model != null and project_model.has_method("get") else null
	var events: Array = []
	if transport != null and transport.has_method("get_tempo_events"):
		events = transport.call("get_tempo_events")
	for event in events:
		if event is Dictionary:
			snapshot["tempo_events"].append({
				"time": float(event.get("time", 0.0)),
				"bpm": float(event.get("bpm", DEFAULT_BPM))
			})
	snapshot["tempo_events"].sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	if snapshot["tempo_events"].is_empty():
		snapshot["tempo_events"].append({"time": 0.0, "bpm": DEFAULT_BPM})

func _refresh_tempo_events_from_data(model_data: Dictionary, snapshot: Dictionary) -> void:
	snapshot["tempo_events"].clear()
	var events: Array = model_data.get("tempo_events", [])
	for event in events:
		if event is Dictionary:
			snapshot["tempo_events"].append({
				"time": float(event.get("time", 0.0)),
				"bpm": float(event.get("bpm", DEFAULT_BPM))
			})
	snapshot["tempo_events"].sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	if snapshot["tempo_events"].is_empty():
		snapshot["tempo_events"].append({"time": 0.0, "bpm": DEFAULT_BPM})

func _resolve_track(project_model: Node, track_index: int) -> Node:
	if project_model == null:
		return null
	var tracks = project_model.tracks if project_model.has_method("get") else []
	if track_index < 0 or track_index >= tracks.size():
		return null
	return tracks[track_index]

func _resolve_track_data(model_data: Dictionary, track_index: int) -> Dictionary:
	var tracks: Array = model_data.get("tracks", [])
	if track_index < 0 or track_index >= tracks.size():
		return {}
	var track_data = tracks[track_index]
	return track_data if track_data is Dictionary else {}

func _has_solo_tracks(tracks: Array) -> bool:
	for track in tracks:
		if track != null and track.has_method("get") and bool(track.get("is_solo")):
			return true
	return false

func _has_solo_tracks_data(tracks: Array) -> bool:
	for track_data in tracks:
		if track_data is Dictionary and bool(track_data.get("is_solo", false)):
			return true
	return false

func _should_skip_track(track: Node, solo_active: bool) -> bool:
	if track == null or not track.has_method("get"):
		return true
	var is_solo = bool(track.get("is_solo"))
	var is_muted = bool(track.get("is_muted"))
	if solo_active:
		return (not is_solo) or is_muted
	return is_muted

func _should_skip_track_data(track_data: Dictionary, solo_active: bool) -> bool:
	if track_data.is_empty():
		return true
	var is_solo = bool(track_data.get("is_solo", false))
	var is_muted = bool(track_data.get("is_muted", false))
	if solo_active:
		return (not is_solo) or is_muted
	return is_muted

func _resolve_clip(track: Node, clip_index: int) -> Node:
	if track == null:
		return null
	var clips = track.clips if track.has_method("get") else []
	if clip_index < 0 or clip_index >= clips.size():
		return null
	return clips[clip_index]

func _resolve_clip_data(track_data: Dictionary, clip_index: int) -> Dictionary:
	var clips: Array = track_data.get("clips", [])
	if clip_index < 0 or clip_index >= clips.size():
		return {}
	var clip_data = clips[clip_index]
	return clip_data if clip_data is Dictionary else {}

func _resolve_route(track_router: Node, track_index: int, track: Node, midi_player: Node) -> Dictionary:
	if track_router != null and track_router.has_method("get_route_for_track"):
		var route = track_router.call("get_route_for_track", track_index, track)
		if route is Dictionary and route.has("channel"):
			if not route.has("player"):
				route["player"] = midi_player
			return route
	return {
		"player": midi_player,
		"channel": _resolve_channel(track_index)
	}

func _resolve_route_from_data(track_routes: Array, track_index: int, default_player: Node) -> Dictionary:
	if track_index >= 0 and track_index < track_routes.size():
		var route = track_routes[track_index]
		if route is Dictionary:
			if not route.has("player"):
				route["player"] = default_player
			return route
	return {
		"player": default_player,
		"channel": _resolve_channel(track_index)
	}

func _register_player(snapshot: Dictionary, player: Node) -> void:
	if player == null:
		return
	var players: Array = snapshot["players_in_use"]
	if not players.has(player):
		players.append(player)
		snapshot["players_in_use"] = players

func _resolve_channel(track_index: int) -> int:
	return int(track_index % MAX_CHANNELS)

func _track_program(track: Node) -> int:
	if track == null:
		return DEFAULT_PROGRAM
	var label = ""
	if track.has_method("get"):
		label = str(track.get("track_name"))
	return _program_from_label(label)

func _track_program_from_data(track_data: Dictionary) -> int:
	if track_data.is_empty():
		return DEFAULT_PROGRAM
	var label = str(track_data.get("track_name", ""))
	return _program_from_label(label)

func _program_from_label(label: String) -> int:
	var text = _strip_channel_suffix(label)
	for i in range(GM_PROGRAM_NAMES.size()):
		if GM_PROGRAM_NAMES[i].to_lower() == text.to_lower():
			return i
	return DEFAULT_PROGRAM

func program_index_from_label(label: String) -> int:
	return _program_from_label(label)

func _strip_channel_suffix(label: String) -> String:
	var text = label.strip_edges()
	var idx = text.find(" Ch ")
	if idx >= 0:
		return text.substr(0, idx).strip_edges()
	return text
