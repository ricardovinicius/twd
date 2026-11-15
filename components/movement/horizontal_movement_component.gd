class_name HorizontalMovementComponent
extends Node

@export_category("Horizontal Movement")
@export var max_speed: float = 400.0
@export var acceleration: float = 2000.0
@export var deceleration: float = 2400.0

## Scales the top speed without changing max_speed, which equipment and stats
## own. For example, the map sets it while open so the player walks slowly.
var speed_multiplier: float = 1.0


func calculate_velocity(
	current_velocity: float,
	input_direction: float,
	delta: float
) -> float:
	var clamped_direction := clampf(input_direction, -1.0, 1.0)
	var target_velocity := clamped_direction * max_speed * speed_multiplier
	var movement_rate := acceleration

	if is_zero_approx(clamped_direction) or _is_changing_direction(
		current_velocity,
		clamped_direction
	):
		movement_rate = deceleration

	return move_toward(current_velocity, target_velocity, movement_rate * delta)


func _is_changing_direction(
	current_velocity: float,
	input_direction: float
) -> bool:
	return (
		not is_zero_approx(current_velocity)
		and signf(current_velocity) != signf(input_direction)
	)
