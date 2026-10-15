class_name JumpDownComponent
extends Node

signal jump_down_started()
signal jump_down_finished()

@export var body: CharacterBody2D
@export var down_action: StringName = &"aim_down"
@export_range(1, 32, 1) var platform_collision_layer: int = 2
@export_range(0.05, 1.0, 0.01, "or_greater") var ignore_duration: float = 0.18
@export_range(0.0, 1000.0, 10.0, "or_greater") var minimum_downward_speed: float = 120.0

var _time_remaining: float = 0.0
var _is_active: bool = false


func _ready() -> void:
	assert(body != null, "JumpDownComponent: body is not assigned.")
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_finish()


func is_requested() -> bool:
	return Input.is_action_pressed(down_action)


func begin(is_on_floor: bool) -> bool:
	if _is_active or not is_on_floor:
		return false

	if not body.get_collision_mask_value(platform_collision_layer):
		return false

	_is_active = true
	_time_remaining = ignore_duration
	body.set_collision_mask_value(platform_collision_layer, false)
	body.velocity.y = maxf(body.velocity.y, minimum_downward_speed)
	set_physics_process(true)
	jump_down_started.emit()
	return true


func is_active() -> bool:
	return _is_active


func cancel() -> void:
	_finish()


func _exit_tree() -> void:
	_restore_platform_collision()


func _finish() -> void:
	if not _is_active:
		return

	_restore_platform_collision()
	_time_remaining = 0.0
	_is_active = false
	set_physics_process(false)
	jump_down_finished.emit()


func _restore_platform_collision() -> void:
	if _is_active and is_instance_valid(body):
		body.set_collision_mask_value(platform_collision_layer, true)
