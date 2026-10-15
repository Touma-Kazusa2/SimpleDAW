extends Node

class_name PlaybackEngine

signal playhead_changed(time_beats: float)
signal finished

const PLAYBACK_MODE_TRACKS := "tracks"
const PLAYBACK_MODE_CLIP := "clip"

const ENGINE_CORE = preload("res://scripts/engine_core.gd")
const SNAPSHOT_BUILDER = preload("res://scripts/engine_snapshot_builder.gd")
const MIDI_SINK = preload("res://scripts/midi_player_sink.gd")

var project_model: Node = null
var midi_player: Node = null
var track_router: Node = null

var playback_mode := PLAYBACK_MODE_CLIP
var playback_track_index := 0
var playback_clip_index := 0

var playhead_beats := 0.0
var is_playing := false

var _core: EngineCore = ENGINE_CORE.new()
var _builder: EngineSnapshotBuilder = SNAPSHOT_BUILDER.new()
var _sink: MidiPlayerSink = MIDI_SINK.new()
var _players_in_use: Array = []
var _pending_rebuild := false
var _snapshot_ready := false
var _snapshot_thread: Thread = null
var _snapshot_building := false
var _snapshot_request_id := 0
var _snapshot_build_id := 0
var _snapshot_applied_id := 0

func _ready() -> void:
	set_process(true)

func setup(model: Node, player: Node, router: Node = null) -> void:
	set_project_model(model)
	set_midi_player(player)
	if router != null:
		set_track_router(router)

func set_project_model(model: Node) -> void:
	if project_model != null and project_model.has_signal("changed"):
		var callable = Callable(self, "_on_project_changed")
		if project_model.is_connected("changed", callable):
			project_model.disconnect("changed", callable)
	project_model = model
	if project_model != null and project_model.has_signal("changed"):
		project_model.connect("changed", Callable(self, "_on_project_changed"))
	_mark_snapshot_dirty()

func set_midi_player(player: Node) -> void:
	midi_player = player
	if _sink != null and _sink.has_method("set_player"):
		_sink.set_player(player)
	_mark_snapshot_dirty()

func set_track_router(router: Node) -> void:
	track_router = router
	_mark_snapshot_dirty()

func set_playback_target(mode: String, track_index: int, clip_index: int) -> void:
	playback_mode = mode if mode != "" else PLAYBACK_MODE_CLIP
	playback_track_index = track_index
	playback_clip_index = clip_index
	_mark_snapshot_dirty()

func play(from_beats: float = 0.0) -> void:
	playhead_beats = max(0.0, from_beats)
	_ensure_snapshot_ready()
	_core.reset_cursor(playhead_beats)
	_send_all_notes_off()
	var events: Array = []
	events.append_array(_core.build_chase_controls(playhead_beats))
	events.append_array(_core.build_chase_notes(playhead_beats, {}))
	events.append_array(_core.dispatch_events(playhead_beats - 0.000001, playhead_beats))
	_sink.emit_events(events)
	is_playing = true
	emit_signal("playhead_changed", playhead_beats)

func pause() -> void:
	if not is_playing:
		return
	is_playing = false
	_send_all_notes_off()

func resume() -> void:
	if is_playing:
		return
	_ensure_snapshot_ready()
	_core.reset_cursor(playhead_beats)
	_send_all_notes_off()
	var events: Array = []
	events.append_array(_core.build_chase_controls(playhead_beats))
	events.append_array(_core.build_chase_notes(playhead_beats, {}))
	events.append_array(_core.dispatch_events(playhead_beats - 0.000001, playhead_beats))
	_sink.emit_events(events)
	is_playing = true

func stop() -> void:
	is_playing = false
	_send_all_notes_off()
	playhead_beats = 0.0
	emit_signal("playhead_changed", playhead_beats)

func seek(to_beats: float) -> void:
	playhead_beats = max(0.0, to_beats)
	_ensure_snapshot_ready()
	_core.reset_cursor(playhead_beats)
	_send_all_notes_off()
	var events: Array = []
	events.append_array(_core.build_chase_controls(playhead_beats))
	events.append_array(_core.build_chase_notes(playhead_beats, {}))
	events.append_array(_core.dispatch_events(playhead_beats - 0.000001, playhead_beats))
	_sink.emit_events(events)
	emit_signal("playhead_changed", playhead_beats)

func get_playhead_beats() -> float:
	return playhead_beats

func get_is_playing() -> bool:
	return is_playing

func _process(delta: float) -> void:
	_poll_snapshot_thread()
	if _pending_rebuild and not _snapshot_building:
		_start_snapshot_build()
	if not is_playing:
		return
	var prev = playhead_beats
	playhead_beats = _core.advance_beats(prev, delta)
	var step_events = _core.dispatch_events(prev, playhead_beats)
	_sink.emit_events(step_events)
	emit_signal("playhead_changed", playhead_beats)
	if _core.is_finished(playhead_beats):
		is_playing = false
		emit_signal("finished")

func _on_project_changed() -> void:
	_mark_snapshot_dirty()

func _exit_tree() -> void:
	_finish_snapshot_thread()

func _mark_snapshot_dirty() -> void:
	_snapshot_request_id += 1
	_pending_rebuild = true

func _ensure_snapshot_ready() -> void:
	_poll_snapshot_thread()
	if _snapshot_ready and not _pending_rebuild:
		return
	_build_snapshot_sync(false)

func _build_snapshot_sync(reconcile: bool) -> void:
	var model_data = _capture_model_data()
	var track_routes = _capture_track_routes()
	var snapshot = _builder.build_snapshot_from_data(
		model_data,
		playback_mode,
		playback_track_index,
		playback_clip_index,
		track_routes,
		midi_player
	)
	_apply_snapshot(snapshot, reconcile)
	_snapshot_applied_id = _snapshot_request_id
	_pending_rebuild = false

func _start_snapshot_build() -> void:
	if _snapshot_building:
		return
	_snapshot_build_id = _snapshot_request_id
	var model_data = _capture_model_data()
	var track_routes = _capture_track_routes()
	var callable = Callable(self, "_thread_build_snapshot").bind(
		_snapshot_build_id,
		model_data,
		track_routes,
		playback_mode,
		playback_track_index,
		playback_clip_index,
		midi_player
	)
	var thread = Thread.new()
	var result = thread.start(callable)
	if result != OK:
		_snapshot_thread = null
		_snapshot_building = false
		_build_snapshot_sync(true)
		return
	_snapshot_thread = thread
	_snapshot_building = true

func _thread_build_snapshot(
		build_id: int,
		model_data: Dictionary,
		track_routes: Array,
		target_mode: String,
		track_index: int,
		clip_index: int,
		default_player: Node
	) -> Dictionary:
	var builder: EngineSnapshotBuilder = SNAPSHOT_BUILDER.new()
	var snapshot = builder.build_snapshot_from_data(
		model_data,
		target_mode,
		track_index,
		clip_index,
		track_routes,
		default_player
	)
	return {
		"build_id": build_id,
		"snapshot": snapshot
	}

func _poll_snapshot_thread() -> void:
	if _snapshot_thread == null:
		return
	if not _thread_is_finished(_snapshot_thread):
		return
	var result = _snapshot_thread.wait_to_finish()
	_snapshot_thread = null
	_snapshot_building = false
	if result is Dictionary:
		var build_id = int(result.get("build_id", -1))
		var snapshot = result.get("snapshot", {})
		if build_id == _snapshot_request_id and build_id > _snapshot_applied_id:
			_apply_snapshot(snapshot, is_playing)
			_snapshot_applied_id = build_id
			_pending_rebuild = false

func _thread_is_finished(thread: Thread) -> bool:
	if thread == null:
		return true
	if thread.has_method("is_alive"):
		return not thread.call("is_alive")
	if thread.has_method("is_started"):
		return not thread.call("is_started")
	if thread.has_method("is_active"):
		return not thread.call("is_active")
	return true

func _finish_snapshot_thread() -> void:
	if _snapshot_thread == null:
		return
	_snapshot_thread.wait_to_finish()
	_snapshot_thread = null
	_snapshot_building = false

func _apply_snapshot(snapshot: Dictionary, reconcile: bool) -> void:
	if snapshot.is_empty():
		_core.set_snapshot({})
		_players_in_use = []
		_snapshot_ready = true
		return
	var prev_active: Dictionary = {}
	var do_reconcile = reconcile and is_playing
	if do_reconcile:
		prev_active = _core.duplicate_active_notes()
	_core.set_snapshot(snapshot)
	_players_in_use = snapshot.get("players_in_use", [])
	_snapshot_ready = true
	if do_reconcile:
		_core.reset_cursor(playhead_beats)
		var events: Array = []
		events.append_array(_core.reconcile_active_notes(playhead_beats, prev_active))
		events.append_array(_core.build_chase_controls(playhead_beats))
		events.append_array(_core.dispatch_events(playhead_beats - 0.000001, playhead_beats))
		_sink.emit_events(events)

func _capture_model_data() -> Dictionary:
	var data := {
		"tempo_events": [],
		"tracks": []
	}
	if project_model == null:
		return data
	var transport = project_model.transport if project_model.has_method("get") else null
	if transport != null and transport.has_method("get_tempo_events"):
		var tempo_events: Array = transport.call("get_tempo_events")
		for event in tempo_events:
			if event is Dictionary:
				data["tempo_events"].append({
					"time": float(event.get("time", 0.0)),
					"bpm": float(event.get("bpm", 120.0))
				})
	var tracks = project_model.tracks if project_model.has_method("get") else []
	for track_index in range(tracks.size()):
		var track = tracks[track_index]
		if track == null:
			continue
		var track_data := {
			"track_index": track_index,
			"track_name": "",
			"clips": [],
			"arrangement": []
		}
		if track.has_method("get"):
			track_data["track_name"] = str(track.get("track_name"))
			track_data["is_muted"] = bool(track.get("is_muted"))
			track_data["is_solo"] = bool(track.get("is_solo"))
			track_data["program_index"] = int(track.get("program_index"))
			track_data["program_bank"] = int(track.get("program_bank"))
		if track.has_method("has_adsr_override"):
			track_data["adsr_override"] = bool(track.call("has_adsr_override"))
		if track.has_method("get_adsr_defaults"):
			track_data["adsr_defaults"] = track.call("get_adsr_defaults")
		if track.has_method("get_adsr_automation_data"):
			track_data["adsr_automation"] = track.call("get_adsr_automation_data")
		var clip_cache: Dictionary = {}
		var clips = track.clips if track.has_method("get") else []
		for clip_index in range(clips.size()):
			var clip = clips[clip_index]
			var clip_data = _capture_clip_data(clip)
			clip_cache[clip] = clip_data
			track_data["clips"].append(clip_data)
		var arrangement = track.arrangement if track.has_method("get") else []
		for entry in arrangement:
			if entry is Dictionary:
				var clip = entry.get("clip")
				if clip == null:
					continue
				var clip_data = clip_cache.get(clip, _capture_clip_data(clip))
				clip_cache[clip] = clip_data
				track_data["arrangement"].append({
					"start": float(entry.get("start", 0.0)),
					"length": float(entry.get("length", 0.0)),
					"clip": clip_data
				})
		data["tracks"].append(track_data)
	return data

func _capture_clip_data(clip: Node) -> Dictionary:
	var clip_data := {
		"clip_length_beats": 0.0,
		"notes": [],
		"automation": {}
	}
	if clip == null or not clip.has_method("get"):
		return clip_data
	clip_data["clip_length_beats"] = float(clip.get("clip_length_beats"))
	var notes = clip.get("notes")
	if notes is Array:
		for note in notes:
			if note is Dictionary:
				clip_data["notes"].append({
					"start": float(note.get("start", 0.0)),
					"duration": float(note.get("duration", 0.0)),
					"pitch": int(note.get("pitch", 0)),
					"velocity": int(note.get("velocity", 100))
				})
	var params: Array = []
	if clip.has_method("get_param_names"):
		params = clip.call("get_param_names")
	for param in params:
		var param_name = String(param)
		var points: Array = []
		if clip.has_method("get_points_for_param"):
			points = clip.call("get_points_for_param", param_name)
		var copied_points: Array = []
		if points is Array:
			for point in points:
				if point is Dictionary:
					copied_points.append({
						"time": float(point.get("time", 0.0)),
						"value": float(point.get("value", 0.0))
					})
		clip_data["automation"][param_name] = copied_points
	return clip_data

func _capture_track_routes() -> Array:
	var routes: Array = []
	var tracks = project_model.tracks if project_model != null and project_model.has_method("get") else []
	for track_index in range(tracks.size()):
		var track = tracks[track_index]
		var route: Dictionary = {}
		if track_router != null and track_router.has_method("get_route_for_track"):
			var resolved = track_router.call("get_route_for_track", track_index, track)
			if resolved is Dictionary:
				route = resolved
		if not route.has("player"):
			route["player"] = midi_player
		if not route.has("channel"):
			route["channel"] = track_index % 16
		routes.append(route)
	return routes

func _send_all_notes_off() -> void:
	_sink.send_all_notes_off(_players_in_use)
	_core.reset_active_notes()
