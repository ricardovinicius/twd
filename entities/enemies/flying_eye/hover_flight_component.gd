class_name HoverFlightComponent
extends Node

## Flies a CharacterBody2D toward a point without gravity, easing in as it
## arrives. World collision still stops the body through move_and_slide().

@export var body: CharacterBody2D

@export_category("Flight")
@export_range(0.0, 2000.0, 1.0, "or_greater") var max_speed: float = 140.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var acceleration: float = 420.0
## Distance at which the body starts slowing down before reaching the point.
@export_range(1.0, 1000.0, 1.0, "or_greater") var arrive_radius: float = 48.0


func _ready() -> void:
	if body == null:
		push_error("HoverFlightComponent: Body is not assigned.")


func fly_toward(point: Vector2, delta: float) -> void:
	if body == null:
		return

	var desired_velocity := desired_velocity_toward(point)

	body.velocity = body.velocity.move_toward(desired_velocity, acceleration * delta)
	body.move_and_slide()


func desired_velocity_toward(point: Vector2) -> Vector2:
	var offset := point - body.global_position
	var distance := offset.length()

	if distance < 0.5:
		return Vector2.ZERO

	var speed := max_speed * clampf(distance / arrive_radius, 0.0, 1.0)

	return offset / distance * speed
