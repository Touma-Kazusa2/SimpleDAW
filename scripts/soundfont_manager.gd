extends Node

class_name SoundfontManager

const MAX_CHANNELS := 16
const MIDI_PLAYER = preload("res://addons/midi/MidiPlayer.gd")

signal bank_load_started(path: String)
signal bank_load_finished(path: String, success: bool)

var project_model: Node = null
var base_player: Node = null
var default_soundfont_path := ""

var _bank_by_path: Dictionary = {}
var _players: Array = []
var _players_by_path: Dictionary = {}
var _player_path: Dictionary = {}
var _route_by_track: Array = []
var _next_player_id := 1
var _bank_load_thread: Thread = null
var _bank_load_path := ""
var _bank_pending_paths: Array = []

func _ready() -> void:
	set_process(true)

func _exit_tree() -> void:
	if _bank_load_thread != null:
		_bank_load_thread.wait_to_finish()
		_bank_load_thread = null

func set_project_model(model: Node) -> void:
	if project_model != null and project_model.has_signal("changed"):
		var callable = Callable(self, "_on_project_changed")
		if project_model.is_connected("changed", callable):
			project_model.disconnect("changed", callable)
	project_model = model
	if project_model != null and project_model.has_signal("changed"):
		project_model.connect("changed", Callable(self, "_on_project_changed"))
	_rebuild_routes()

func register_base_player(player: Node) -> void:
	base_player = player
	if base_player != null and not _players.has(base_player):
		_players.append(base_player)
	_rebuild_routes()

func set_default_soundfont_path(path: String) -> void:
	default_soundfont_path = path
	_rebuild_routes()

func get_bank_for_path(path: String) -> Bank:
	return _get_bank_for_path(path)

func get_bank_for_track(track: Node) -> Bank:
	var path = _resolve_soundfont_path(track)
	return _get_bank_for_path(path)

func resolve_soundfont_path_for_track(track: Node) -> String:
	return _resolve_soundfont_path(track)

func get_route_for_track(track_index: int, _track: Node) -> Dictionary:
	if track_index >= 0 and track_index < _route_by_track.size():
		return _route_by_track[track_index]
	_rebuild_routes()
	if track_index >= 0 and track_index < _route_by_track.size():
		return _route_by_track[track_index]
	return {
		"player": base_player,
		"channel": track_index % MAX_CHANNELS
	}

func _on_project_changed() -> void:
	_rebuild_routes()

func _rebuild_routes() -> void:
	_route_by_track.clear()
	var tracks = project_model.tracks if project_model != null and project_model.has_method("get") else []
	if tracks.is_empty():
		return
	var needed_paths: Array = []
	for track in tracks:
		var path = _resolve_soundfont_path(track)
		if not needed_paths.has(path):
			needed_paths.append(path)
	var available_players: Array = _players.duplicate()
	_players_by_path.clear()
	_player_path.clear()
	var default_path = _resolve_default_path()
	if base_player != null and needed_paths.has(default_path):
		if available_players.has(base_player):
			available_players.erase(base_player)
		_assign_player_to_path(base_player, default_path)
	for path in needed_paths:
		if _players_by_path.has(path):
			continue
		var path_player = _take_available_player(available_players)
		_assign_player_to_path(path_player, path)
	var allocations: Dictionary = {}
	for track_index in range(tracks.size()):
		var track = tracks[track_index]
		var path = _resolve_soundfont_path(track)
		if not _players_by_path.has(path):
			var path_player = _take_available_player(available_players)
			_assign_player_to_path(path_player, path)
		var alloc: Dictionary = allocations.get(path, {})
		if alloc.is_empty():
			alloc = {
				"players": _players_by_path[path],
				"player_index": 0,
				"next_channel": 0
			}
		var players: Array = alloc["players"]
		var player_index = int(alloc["player_index"])
		var next_channel = int(alloc["next_channel"])
		if next_channel >= MAX_CHANNELS:
			player_index += 1
			next_channel = 0
		if player_index >= players.size():
			var extra = _take_available_player(available_players)
			_assign_player_to_path(extra, path)
			players = _players_by_path[path]
			alloc["players"] = players
		var route_player = players[player_index]
		_route_by_track.append({
			"player": route_player,
			"channel": next_channel,
			"soundfont_path": path
		})
		next_channel += 1
		alloc["player_index"] = player_index
		alloc["next_channel"] = next_channel
		allocations[path] = alloc

func _take_available_player(pool: Array) -> Node:
	if pool.is_empty():
		return _create_player()
	var player = pool.pop_front()
	return player if player != null else _create_player()

func _create_player() -> Node:
	var player = MIDI_PLAYER.new()
	player.name = "MidiPlayer_%d" % _next_player_id
	if player.has_method("set"):
		player.set("bus_prefix", "sf%d_" % _next_player_id)
	_next_player_id += 1
	add_child(player)
	if not _players.has(player):
		_players.append(player)
	return player

func _assign_player_to_path(player: Node, path: String) -> void:
	if player == null:
		return
	_player_path[player] = path
	if not _players_by_path.has(path):
		_players_by_path[path] = []
	var list: Array = _players_by_path[path]
	if not list.has(player):
		list.append(player)
	_players_by_path[path] = list
	_apply_soundfont_to_player(player, path)

func _apply_soundfont_to_player(player: Node, path: String) -> void:
	if player == null:
		return
	if path == "":
		if player.has_method("set_shared_bank"):
			player.call("set_shared_bank", null, "")
		elif player.has_method("set_soundfont"):
			player.call("set_soundfont", "")
		return
	var bank = _get_bank_for_path(path)
	if bank == null:
		if player.has_method("set_shared_bank"):
			player.call("set_shared_bank", null, "")
		elif player.has_method("set_soundfont"):
			player.call("set_soundfont", "")
		return
	if player.has_method("set_shared_bank"):
		player.call("set_shared_bank", bank, path)
	elif player.has_method("set_soundfont"):
		player.call("set_soundfont", path)

func _get_bank_for_path(path: String) -> Bank:
	if path == "" or not FileAccess.file_exists(path):
		return null
	if _bank_by_path.has(path):
		return _bank_by_path[path]
	_enqueue_bank_load(path)
	return null

func _process(_delta: float) -> void:
	_poll_bank_load_thread()

func _enqueue_bank_load(path: String) -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	if _bank_by_path.has(path):
		return
	if path == _bank_load_path:
		return
	if _bank_pending_paths.has(path):
		return
	if _bank_load_thread == null:
		_start_bank_load(path)
	else:
		_bank_pending_paths.append(path)

func _start_bank_load(path: String) -> void:
	if path == "":
		return
	_bank_load_path = path
	emit_signal("bank_load_started", path)
	var thread = Thread.new()
	var callable = Callable(self, "_thread_load_bank").bind(path)
	var result = thread.start(callable)
	if result != OK:
		_bank_load_path = ""
		emit_signal("bank_load_finished", path, false)
		return
	_bank_load_thread = thread

func _thread_load_bank(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {"path": path, "bank": null}
	var sf_reader = SoundFont.new()
	var result = sf_reader.read_file(path)
	if result.error != OK:
		return {"path": path, "bank": null}
	var bank = Bank.new()
	bank.read_soundfont(result.data)
	return {"path": path, "bank": bank}

func _poll_bank_load_thread() -> void:
	if _bank_load_thread == null:
		return
	if not _thread_is_finished(_bank_load_thread):
		return
	var result = _bank_load_thread.wait_to_finish()
	_bank_load_thread = null
	var path = _bank_load_path
	_bank_load_path = ""
	var bank: Bank = null
	if result is Dictionary:
		path = String(result.get("path", path))
		bank = result.get("bank")
	if bank != null and path != "":
		_bank_by_path[path] = bank
		_apply_bank_to_path(path)
		emit_signal("bank_load_finished", path, true)
	else:
		emit_signal("bank_load_finished", path, false)
	if not _bank_pending_paths.is_empty():
		var next_path = String(_bank_pending_paths.pop_front())
		_start_bank_load(next_path)

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

func _apply_bank_to_path(path: String) -> void:
	if not _players_by_path.has(path):
		return
	var players: Array = _players_by_path[path]
	for player in players:
		_apply_soundfont_to_player(player, path)

func _resolve_default_path() -> String:
	if _is_path_valid(default_soundfont_path):
		return default_soundfont_path
	return ""

func _resolve_soundfont_path(track: Node) -> String:
	var track_path := ""
	if track != null and track.has_method("get"):
		track_path = str(track.get("soundfont_path"))
	if _is_path_valid(track_path):
		return track_path
	return _resolve_default_path()

func _is_path_valid(path: String) -> bool:
	return path != "" and FileAccess.file_exists(path)
