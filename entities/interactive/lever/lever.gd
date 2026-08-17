class_name Lever
extends Node2D

@export var switch: SwitchComponent
@export var handle: RigidBody2D
@export var pivot_joint: PinJoint2D
@export var physics_component: PhysicsLeverComponent
@export var grip: Polygon2D
@export var inactive_grip_color := Color(0.85, 0.28, 0.2, 1)
@export var active_grip_color := Color(0.28, 0.78, 0.4, 1)


func _ready() -> void:
	if switch == null or handle == null or pivot_joint == null or physics_component == null:
		push_error("Lever requires switch, handle, pivot joint, and physics component references.")
		return

	switch.state_changed.connect(_on_switch_state_changed)
	_apply_state_feedback(switch.active)


func _on_switch_state_changed(active: bool) -> void:
	_apply_state_feedback(active)


func _apply_state_feedback(active: bool) -> void:
	if grip != null:
		grip.color = active_grip_color if active else inactive_grip_color
