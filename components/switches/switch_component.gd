class_name SwitchComponent
extends Node

signal state_changed(active: bool)

@export var active := false
@export var one_shot := false

## While locked, requests to change state are ignored (e.g. an elevator lever
## during a trip). Physical levers then settle back to the current state.
var locked := false


func toggle() -> void:
	if one_shot and active:
		return

	set_active(not active)


func set_active(value: bool) -> void:
	if locked or value == active:
		return

	if one_shot and active and not value:
		return

	active = value
	state_changed.emit(active)
