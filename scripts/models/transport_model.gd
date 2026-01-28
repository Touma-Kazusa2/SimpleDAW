extends Node

signal changed

var _tempo: float = 120.0
var _time_signature_numerator: int = 4
var _time_signature_denominator: int = 4
var tempo_events: Array = []
var time_signature_events: Array = []

var tempo: float:
	get:
		return _tempo
	set(value):
		if is_equal_approx(_tempo, value):
			return
		_tempo = value
		emit_signal("changed")

var time_signature_numerator: int:
	get:
		return _time_signature_numerator
	set(value):
		if _time_signature_numerator == value:
			return
		_time_signature_numerator = value
		emit_signal("changed")

var time_signature_denominator: int:
	get:
		return _time_signature_denominator
	set(value):
		if _time_signature_denominator == value:
			return
		_time_signature_denominator = value
		emit_signal("changed")

func get_tempo_events() -> Array:
	return tempo_events

func set_tempo_events(events: Array) -> void:
	tempo_events = _sanitize_tempo_events(events)
	if not tempo_events.is_empty():
		var next_tempo = float(tempo_events[0].get("bpm", _tempo))
		if not is_equal_approx(_tempo, next_tempo):
			_tempo = next_tempo
	emit_signal("changed")

func get_time_signature_events() -> Array:
	return time_signature_events

func set_time_signature_events(events: Array) -> void:
	time_signature_events = _sanitize_time_signature_events(events)
	if not time_signature_events.is_empty():
		var first = time_signature_events[0]
		_time_signature_numerator = int(first.get("numerator", _time_signature_numerator))
		_time_signature_denominator = int(first.get("denominator", _time_signature_denominator))
	emit_signal("changed")

func _sanitize_tempo_events(events: Array) -> Array:
	var sanitized: Array = []
	for event in events:
		if event is Dictionary:
			sanitized.append({
				"time": float(event.get("time", 0.0)),
				"bpm": float(event.get("bpm", _tempo))
			})
	sanitized.sort_custom(func(a, b): return a["time"] < b["time"])
	sanitized = _dedupe_events(sanitized, "bpm")
	if sanitized.is_empty():
		sanitized.append({"time": 0.0, "bpm": _tempo})
	return sanitized

func _sanitize_time_signature_events(events: Array) -> Array:
	var sanitized: Array = []
	for event in events:
		if event is Dictionary:
			var denominator = int(event.get("denominator", _time_signature_denominator))
			if denominator <= 0:
				denominator = _time_signature_denominator
			sanitized.append({
				"time": float(event.get("time", 0.0)),
				"numerator": int(event.get("numerator", _time_signature_numerator)),
				"denominator": denominator
			})
	sanitized.sort_custom(func(a, b): return a["time"] < b["time"])
	sanitized = _dedupe_events(sanitized, "", true)
	if sanitized.is_empty():
		sanitized.append({
			"time": 0.0,
			"numerator": _time_signature_numerator,
			"denominator": _time_signature_denominator
		})
	return sanitized

func _dedupe_events(events: Array, value_key: String, replace_all: bool = false) -> Array:
	if events.is_empty():
		return events
	var deduped: Array = []
	for event in events:
		if deduped.is_empty():
			deduped.append(event)
			continue
		var last = deduped[deduped.size() - 1]
		if is_equal_approx(float(event.get("time", 0.0)), float(last.get("time", 0.0))):
			if replace_all or value_key == "":
				deduped[deduped.size() - 1] = event
			else:
				last[value_key] = event.get(value_key, last.get(value_key))
				deduped[deduped.size() - 1] = last
		else:
			deduped.append(event)
	return deduped
