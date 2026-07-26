class_name GravityComponent
extends Node

@export_category("Gravity")
## Scales the project gravity while the player is moving against gravity.
## A value of 1 uses the project gravity without modification.
@export_range(0.0, 5.0, 0.1, "or_greater") var rise_gravity_multiplier: float = 1.0
## Scales the project gravity at the jump apex and while the player is falling.
## Values above the rise multiplier create a faster, more responsive descent.
@export_range(0.0, 5.0, 0.1, "or_greater") var fall_gravity_multiplier: float = 1.5


func calculate_velocity(
	current_velocity: Vector2,
	base_gravity: Vector2,
	delta: float
) -> Vector2:
	var gravity_multiplier := fall_gravity_multiplier

	if current_velocity.dot(base_gravity) < 0.0:
		gravity_multiplier = rise_gravity_multiplier

	return current_velocity + base_gravity * gravity_multiplier * delta
