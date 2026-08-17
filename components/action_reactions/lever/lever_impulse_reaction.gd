class_name LeverImpulseReaction
extends ActionReaction

const PUSH_ACTION := &"push"

@export var handle: RigidBody2D
@export var physics_component: PhysicsLeverComponent
@export_range(0.0, 10.0, 0.01, "or_greater") var impulse_multiplier := 4.0
@export var application_offset := Vector2(0, -36)


func supports(action: ActionData) -> bool:
	return action != null and action.type == PUSH_ACTION


func react(action: ActionData) -> void:
	if not supports(action):
		return

	if handle == null:
		push_error("LeverImpulseReaction requires a RigidBody2D handle reference.")
		return
	if physics_component == null:
		push_error("LeverImpulseReaction requires a PhysicsLeverComponent reference.")
		return

	var direction := action.direction.normalized()
	if direction.is_zero_approx() or action.strength <= 0.0:
		return

	var impulse := direction * action.strength * impulse_multiplier
	var lever_arm := application_offset.rotated(handle.global_rotation)
	var torque_impulse := lever_arm.cross(impulse)
	if is_zero_approx(torque_impulse):
		return

	physics_component.queue_torque_impulse(torque_impulse)
