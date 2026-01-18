extends Node

signal changed

const TRANSPORT_MODEL = preload("res://scripts/models/transport_model.gd")
const TRACK_MODEL = preload("res://scripts/models/track_model.gd")

var transport: Node = null
var tracks: Array = []
var _next_id: int = 1

func _init() -> void:
	transport = TRANSPORT_MODEL.new()
	transport.connect("changed", Callable(self, "_on_child_changed"))

func create_track(track_label: String = "Track") -> Node:
	var track = TRACK_MODEL.new()
	track.id = _make_id("track")
	track.track_name = track_label
	track.connect("changed", Callable(self, "_on_child_changed"))
	tracks.append(track)
	emit_signal("changed")
	return track

func _make_id(prefix: String) -> String:
	var next_id = _next_id
	_next_id += 1
	return "%s_%d" % [prefix, next_id]

func _on_child_changed() -> void:
	emit_signal("changed")
