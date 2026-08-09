class_name KnockbackComponent
extends Node

signal knockback_started(direction: Vector2, strength: float, duration: float)
signal knockback_finished

@export_range(0.01, 10.0, 0.01, "or_greater")
var default_duration: float = 0.25
@export var body: CharacterBody2D

var _initial_horizontal_velocity: float = 0.0
var _duration: float = 0.0
var _remaining: float = 0.0
var _collision_source: PhysicsBody2D


func _ready() -> void:
	assert(body != null, "KnockbackComponent: CharacterBody2D is not assigned.")


func begin_knockback(
	direction: Vector2,
	strength: float,
	duration: float = -1.0,
	collision_source: PhysicsBody2D = null
) -> bool:
	if is_zero_approx(direction.x) or strength <= 0.0:
		return false

	var applied_duration := duration

	if applied_duration <= 0.0:
		applied_duration = default_duration

	_duration = maxf(applied_duration, 0.01)
	_remaining = _duration
	_initial_horizontal_velocity = signf(direction.x) * strength
	_set_collision_source(collision_source)

	knockback_started.emit(
		Vector2(signf(direction.x), 0.0),
		strength,
		_duration
	)
	return true


func calculate_horizontal_velocity(delta: float) -> float:
	if not is_active():
		return 0.0

	var weight := _remaining / _duration
	var horizontal_velocity := _initial_horizontal_velocity * weight
	_remaining = maxf(_remaining - delta, 0.0)

	if is_zero_approx(_remaining):
		_initial_horizontal_velocity = 0.0
		_clear_collision_source()
		knockback_finished.emit()

	return horizontal_velocity


func is_active() -> bool:
	return _remaining > 0.0


func _set_collision_source(collision_source: PhysicsBody2D) -> void:
	_clear_collision_source()

	if not is_instance_valid(collision_source):
		return

	_collision_source = collision_source
	body.add_collision_exception_with(_collision_source)


func _clear_collision_source() -> void:
	if is_instance_valid(body) and is_instance_valid(_collision_source):
		body.remove_collision_exception_with(_collision_source)

	_collision_source = null
