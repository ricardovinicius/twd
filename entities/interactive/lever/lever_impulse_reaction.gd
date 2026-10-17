class_name LeverImpulseReaction
extends ActionReaction

const PUSH_ACTION := &"push"

@export var handle: RigidBody2D
@export var physics_component: PhysicsLeverComponent
@export_range(0.0, 10.0, 0.01, "or_greater") var impulse_multiplier := 4.0
@export var application_offset := Vector2(0, -36)
## When true, every push flips the lever toward its other state, whatever
## side it comes from. Used by levers the player must reach from two sides,
## such as elevator levers. Default levers keep direction-dependent pushes.
@export var toggle_on_any_push := false


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

	if toggle_on_any_push:
		torque_impulse = _toggle_torque(lever_arm, impulse)
	if is_zero_approx(torque_impulse):
		return

	physics_component.queue_torque_impulse(torque_impulse)


## Full-strength torque toward the state the lever is not in.
func _toggle_torque(lever_arm: Vector2, impulse: Vector2) -> float:
	var magnitude := lever_arm.length() * impulse.length()
	var toward_active := 1.0 if not physics_component.switch.active else -1.0

	return magnitude * toward_active * physics_component.get_angle_direction()
