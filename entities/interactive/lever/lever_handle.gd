class_name LeverHandle
extends RigidBody2D

@export var physics_component: PhysicsLeverComponent


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if physics_component != null:
		physics_component.integrate_forces(state)
