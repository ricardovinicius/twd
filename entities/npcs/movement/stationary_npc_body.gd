class_name StationaryNpcBody
extends Node

@export var body: CharacterBody2D
@export var gravity: GravityComponent


func _ready() -> void:
	if body == null or gravity == null:
		push_error("StationaryNpcBody: CharacterBody2D and GravityComponent must be assigned.")
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(body) or not is_instance_valid(gravity):
		return

	body.velocity.x = 0.0

	if not body.is_on_floor():
		body.velocity = gravity.calculate_velocity(body.velocity, body.get_gravity(), delta)
	elif body.velocity.y > 0.0:
		body.velocity.y = 0.0

	body.move_and_slide()
