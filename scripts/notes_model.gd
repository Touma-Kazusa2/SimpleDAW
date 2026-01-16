extends Node

signal changed

var notes: Array = []

const DEFAULT_VELOCITY := 100

func add_note(pitch: int, start_beats: float, duration_beats: float, track_id: int = 0) -> void:
    notes.append({
        "pitch": pitch,
        "start": start_beats,
        "duration": duration_beats,
        "velocity": DEFAULT_VELOCITY,
        "track_id": track_id,
        "track_tint": Color(1.0, 1.0, 1.0),
        "track_mix": 0.0
    })
    emit_signal("changed")

func update_note(index: int, pitch: int, start_beats: float, duration_beats: float) -> void:
    if index < 0 or index >= notes.size():
        return
    notes[index]["pitch"] = pitch
    notes[index]["start"] = start_beats
    notes[index]["duration"] = duration_beats
    emit_signal("changed")

func update_velocity(index: int, velocity: int) -> void:
    if index < 0 or index >= notes.size():
        return
    notes[index]["velocity"] = clamp(velocity, 0, 127)
    emit_signal("changed")

func delete_note(index: int) -> void:
    if index < 0 or index >= notes.size():
        return
    notes.remove_at(index)
    emit_signal("changed")
