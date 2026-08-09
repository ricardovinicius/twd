class_name AimInputComponent
extends Node

@export var left_action: StringName = &"left"
@export var right_action: StringName = &"right"
@export var up_action: StringName = &"aim_up"
@export var down_action: StringName = &"aim_down"


func get_direction(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var direction := Input.get_vector(
		left_action,
		right_action,
		up_action,
		down_action
	)

	if direction.is_zero_approx():
		direction = fallback

	return _to_cardinal_direction(direction)


func _to_cardinal_direction(direction: Vector2) -> Vector2:
	if direction.is_zero_approx():
		return Vector2.ZERO

	if absf(direction.x) >= absf(direction.y):
		return Vector2(signf(direction.x), 0.0)

	return Vector2(0.0, signf(direction.y))
