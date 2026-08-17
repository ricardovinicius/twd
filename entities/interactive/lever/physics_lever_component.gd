class_name PhysicsLeverComponent
extends Node

@export_category("Dependencies")
@export var handle: RigidBody2D
@export var pivot: Node2D
@export var switch: SwitchComponent

@export_category("Angles")
@export_range(-180.0, 180.0, 0.5) var inactive_stop_degrees := -35.0
@export_range(-180.0, 180.0, 0.5) var inactive_threshold_degrees := -5.0
@export_range(-180.0, 180.0, 0.5) var active_threshold_degrees := 5.0
@export_range(-180.0, 180.0, 0.5) var active_stop_degrees := 35.0
@export var mirrored := false

@export_category("Resistance")
@export_range(0.0, 100.0, 0.1, "or_greater") var settling_acceleration := 3.0
@export_range(0.0, 100.0, 0.1, "or_greater") var angular_damping := 2.0
@export_range(0.1, 100.0, 0.1, "or_greater") var maximum_angular_speed := 24.0
@export_range(0.0, 10.0, 0.1, "or_greater") var snap_angle_degrees := 1.5
@export_range(0.0, 10.0, 0.05, "or_greater") var snap_angular_speed := 0.25

var _configured := false
var _pending_torque_impulse := 0.0


func _ready() -> void:
	if handle == null or pivot == null or switch == null:
		push_error("PhysicsLeverComponent requires handle, pivot, and switch references.")
		return

	if not _angles_are_valid():
		push_error(
			"PhysicsLeverComponent angles must satisfy inactive stop <= inactive threshold "
			+ "< active threshold <= active stop."
		)
		return

	_apply_initial_pose()
	_configured = true


func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not _configured:
		return

	# Keep the rigid handle anchored even under large impulses. The PinJoint2D provides
	# the physical relationship; this correction prevents solver drift from accumulating.
	state.transform.origin = pivot.global_position
	state.linear_velocity = Vector2.ZERO
	if not is_zero_approx(_pending_torque_impulse):
		state.angular_velocity += _pending_torque_impulse * state.inverse_inertia
		_pending_torque_impulse = 0.0

	var inactive_stop := deg_to_rad(inactive_stop_degrees)
	var active_stop := deg_to_rad(active_stop_degrees)
	var angle := clampf(_get_canonical_angle(state), inactive_stop, active_stop)
	_set_canonical_angle(state, angle)

	if switch.one_shot and switch.active:
		_latch_active(state, active_stop)
		return

	if not switch.active and angle >= deg_to_rad(active_threshold_degrees):
		switch.set_active(true)
	elif switch.active and angle <= deg_to_rad(inactive_threshold_degrees):
		switch.set_active(false)

	var target_angle := active_stop if switch.active else inactive_stop
	var direction := _angle_direction()
	var canonical_velocity := state.angular_velocity * direction
	var distance := target_angle - angle
	var step := state.step

	if not is_zero_approx(distance):
		canonical_velocity += signf(distance) * settling_acceleration * step

	canonical_velocity /= 1.0 + angular_damping * step
	canonical_velocity = clampf(
		canonical_velocity,
		-maximum_angular_speed,
		maximum_angular_speed
	)

	if (
		absf(distance) <= deg_to_rad(snap_angle_degrees)
		and absf(canonical_velocity) <= snap_angular_speed
	):
		_set_canonical_angle(state, target_angle)
		canonical_velocity = 0.0

	if angle <= inactive_stop and canonical_velocity < 0.0:
		canonical_velocity = 0.0
	elif angle >= active_stop and canonical_velocity > 0.0:
		canonical_velocity = 0.0

	state.angular_velocity = canonical_velocity * direction


func queue_torque_impulse(torque_impulse: float) -> void:
	if is_zero_approx(torque_impulse):
		return

	_pending_torque_impulse += torque_impulse
	if handle != null:
		handle.sleeping = false


func _angles_are_valid() -> bool:
	return (
		inactive_stop_degrees <= inactive_threshold_degrees
		and inactive_threshold_degrees < active_threshold_degrees
		and active_threshold_degrees <= active_stop_degrees
	)


func _apply_initial_pose() -> void:
	var target_degrees := active_stop_degrees if switch.active else inactive_stop_degrees
	handle.global_position = pivot.global_position
	handle.global_rotation = pivot.global_rotation + deg_to_rad(target_degrees) * _angle_direction()
	handle.linear_velocity = Vector2.ZERO
	handle.angular_velocity = 0.0
	handle.sleeping = false


func _get_canonical_angle(state: PhysicsDirectBodyState2D) -> float:
	var physical_angle := wrapf(
		state.transform.get_rotation() - pivot.global_rotation,
		-PI,
		PI
	)
	return physical_angle * _angle_direction()


func _set_canonical_angle(state: PhysicsDirectBodyState2D, angle: float) -> void:
	var physical_angle := pivot.global_rotation + angle * _angle_direction()
	state.transform = Transform2D(physical_angle, state.transform.origin)


func _latch_active(state: PhysicsDirectBodyState2D, active_stop: float) -> void:
	_set_canonical_angle(state, active_stop)
	state.transform.origin = pivot.global_position
	state.linear_velocity = Vector2.ZERO
	state.angular_velocity = 0.0


func _angle_direction() -> float:
	return -1.0 if mirrored else 1.0
