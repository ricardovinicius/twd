class_name CharacterRigidBodyPushComponent
extends Node

signal body_pushed(body: RigidBody2D, impulse: Vector2)

@export var character: CharacterBody2D
@export var pushable_group: StringName = &"character_pushable"
@export_range(0.0, 2.0, 0.05) var impulse_factor: float = 0.75
@export_range(0.0, 1000.0, 1.0) var maximum_impulse: float = 150.0


func push_slide_collisions(intended_velocity: Vector2) -> void:
	if character == null:
		push_warning("CharacterRigidBodyPushComponent: character is null.")
		return

	var pushed_bodies: Array[RigidBody2D] = []

	for collision_index in character.get_slide_collision_count():
		var collision := character.get_slide_collision(collision_index)
		var rigid_body := collision.get_collider() as RigidBody2D
		if rigid_body == null or rigid_body in pushed_bodies:
			continue
		if not rigid_body.is_in_group(pushable_group):
			continue

		var push_direction := -collision.get_normal()
		var impact_speed := (
			intended_velocity.dot(push_direction)
			- rigid_body.linear_velocity.dot(push_direction)
		)
		if impact_speed <= 0.0:
			continue

		var impulse_magnitude := minf(
			impact_speed * rigid_body.mass * impulse_factor,
			maximum_impulse
		)
		var impulse := push_direction * impulse_magnitude
		var application_offset := collision.get_position() - rigid_body.global_position
		rigid_body.apply_impulse(impulse, application_offset)
		pushed_bodies.append(rigid_body)
		body_pushed.emit(rigid_body, impulse)
