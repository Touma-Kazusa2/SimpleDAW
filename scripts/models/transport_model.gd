extends Node

signal changed

var _tempo: float = 120.0
var _time_signature_numerator: int = 4
var _time_signature_denominator: int = 4

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
