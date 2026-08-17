class_name SwitchComponent
extends Node

signal state_changed(active: bool)

@export var active := false
@export var one_shot := false


func toggle() -> void:
	if one_shot and active:
		return

	set_active(not active)


func set_active(value: bool) -> void:
	if value == active:
		return

	if one_shot and active and not value:
		return

	active = value
	state_changed.emit(active)
