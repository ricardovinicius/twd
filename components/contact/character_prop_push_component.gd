class_name CharacterPropPushComponent
extends Node

## Empurra objetos leves (props, como os potes de alquimia) que o personagem
## atravessa. Os props ficam numa camada que o personagem não colide, então eles
## nunca bloqueiam o movimento: só são chutados para a frente.

signal prop_pushed(body: RigidBody2D, impulse: Vector2)

@export var character: CharacterBody2D
@export var shape: CollisionShape2D
@export_flags_2d_physics var prop_mask: int = 32
@export var pushable_group: StringName = &"character_pushable"
## Velocidade final do prop em relação à do personagem. Acima de 1 o prop
## se adianta um pouco, como se fosse chutado.
@export_range(0.0, 2.0, 0.05) var velocity_transfer: float = 1.1
## Fração da diferença de velocidade aplicada por frame de contato.
@export_range(0.0, 1.0, 0.05) var push_responsiveness: float = 0.3
@export var max_results: int = 8

var _query := PhysicsShapeQueryParameters2D.new()


func push_overlapping_props() -> void:
	if character == null or shape == null or shape.shape == null:
		push_warning("CharacterPropPushComponent: character or shape is not assigned.")
		return

	_query.shape = shape.shape
	_query.transform = shape.global_transform
	_query.collision_mask = prop_mask
	_query.collide_with_areas = false
	_query.collide_with_bodies = true

	var space_state := character.get_world_2d().direct_space_state
	for result in space_state.intersect_shape(_query, max_results):
		var prop := result.collider as RigidBody2D
		if prop == null or not prop.is_in_group(pushable_group):
			continue

		var side := signf(prop.global_position.x - character.global_position.x)
		var approach_speed := character.velocity.x * side
		if side == 0.0 or approach_speed <= 0.0:
			continue

		var target_velocity_x := side * approach_speed * velocity_transfer
		var missing_velocity_x := target_velocity_x - prop.linear_velocity.x
		if missing_velocity_x * side <= 0.0:
			continue

		var impulse := Vector2(missing_velocity_x * push_responsiveness * prop.mass, 0.0)
		prop.apply_central_impulse(impulse)
		prop_pushed.emit(prop, impulse)
