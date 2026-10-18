class_name Lever
extends Node2D

@export var switch: SwitchComponent
@export var handle: RigidBody2D
@export var pivot_joint: PinJoint2D
@export var physics_component: PhysicsLeverComponent
@export var grip: Polygon2D
@export var inactive_grip_color := Color(0.85, 0.28, 0.2, 1)
@export var active_grip_color := Color(0.28, 0.78, 0.4, 1)
## Every push flips the lever, whichever side it comes from (see
## LeverImpulseReaction.toggle_on_any_push).
@export var toggle_on_any_push := false
@export var impulse_reaction: LeverImpulseReaction
## When false, characters walk through the lever (it becomes a background
## switch). Pushes still reach it through its ActionReceiver.
@export var blocks_movement := true
@export var base: StaticBody2D


func _ready() -> void:
	if switch == null or handle == null or pivot_joint == null or physics_component == null:
		push_error("Lever requires switch, handle, pivot joint, and physics component references.")
		return

	switch.state_changed.connect(_on_switch_state_changed)
	_apply_state_feedback(switch.active)

	if not blocks_movement:
		_make_pass_through()

	if impulse_reaction != null:
		impulse_reaction.toggle_on_any_push = toggle_on_any_push
	elif toggle_on_any_push:
		push_error("Lever: toggle_on_any_push requires an impulse reaction reference.")


func _on_switch_state_changed(active: bool) -> void:
	_apply_state_feedback(active)


func _apply_state_feedback(active: bool) -> void:
	if grip != null:
		grip.color = active_grip_color if active else inactive_grip_color


func _make_pass_through() -> void:
	if base != null:
		base.collision_layer = 0

	handle.collision_layer = 0
	handle.collision_mask = 0
	z_index = -1
