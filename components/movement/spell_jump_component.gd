class_name SpellJumpComponent
extends Node

@export var body: CharacterBody2D
@export var jump_velocity: float = -1000.0


func jump() -> bool:
	if body == null:
		push_error("SpellJumpComponent: CharacterBody2D is not assigned.")
		return false

	body.velocity.y = jump_velocity
	return true
