class_name LeapAttackComponent
extends Node

## Leaping attack: crouches, then jumps across the room past the target,
## leading with a damaging hitbox (the butt pincers). The hitbox hits each
## receiver at most once per leap. While attacking, this component moves the
## body; its owner must not move it.

signal leap_started(direction: float)
signal took_off
signal landed
signal attack_finished

enum Phase {
	IDLE,
	WINDUP,
	AIRBORNE,
	RECOVERY,
}

@export_category("Dependencies")
@export var body: CharacterBody2D
@export var attack_hitbox: AttackHitbox

@export_category("Leap")
@export_range(0.0, 1000.0, 1.0, "or_greater") var damage: float = 20.0
## Crouch before take-off: the warning the player gets.
@export_range(0.0, 5.0, 0.01, "or_greater") var windup_duration: float = 0.9
## Time spent stuck after landing: the window to hit him.
@export_range(0.0, 5.0, 0.01, "or_greater") var recovery_duration: float = 1.2
## Horizontal speed of the leap. The flight lasts distance / leap_speed.
@export_range(1.0, 5000.0, 1.0, "or_greater") var leap_speed: float = 600.0
## Peak height of the leap arc, kept low so the pincers sweep the floor.
@export_range(0.0, 1000.0, 1.0, "or_greater") var leap_height: float = 40.0
## How far past the target he lands.
@export_range(0.0, 2000.0, 1.0, "or_greater") var overshoot: float = 160.0
@export_range(0.0, 5000.0, 1.0, "or_greater") var min_distance: float = 200.0
@export_range(0.0, 5000.0, 1.0, "or_greater") var max_distance: float = 900.0

var _phase: Phase = Phase.IDLE
var _phase_time: float = 0.0
var _direction: float = 1.0
var _distance: float = 0.0
var _source: Node2D
var _left_floor: bool = false
var _flight_gravity: float = 0.0


func _ready() -> void:
	if body == null or attack_hitbox == null:
		push_error("LeapAttackComponent: Body and Attack Hitbox must be assigned.")

	set_physics_process(false)


func is_attacking() -> bool:
	return _phase != Phase.IDLE


func is_airborne() -> bool:
	return _phase == Phase.AIRBORNE


func get_direction() -> float:
	return _direction


## Starts a leap toward target_x. Rejected while attacking or without a
## valid body; a rejection changes no state.
func begin_leap(source: Node2D, target_x: float) -> bool:
	if is_attacking() or body == null or attack_hitbox == null or not is_instance_valid(source):
		return false

	var offset := target_x - body.global_position.x

	_direction = signf(offset) if not is_zero_approx(offset) else 1.0
	_distance = clampf(absf(offset) + overshoot, min_distance, max_distance)
	_source = source
	attack_hitbox.position.x = absf(attack_hitbox.position.x) * _direction
	_start_phase(Phase.WINDUP)
	set_physics_process(true)
	leap_started.emit(_direction)
	return true


func cancel() -> void:
	if not is_attacking():
		return

	attack_hitbox.deactivate()
	_finish()


func _physics_process(delta: float) -> void:
	_phase_time += delta

	match _phase:
		Phase.WINDUP:
			_brake(delta)
			if _phase_time >= windup_duration:
				_take_off()
		Phase.AIRBORNE:
			_fly(delta)
		Phase.RECOVERY:
			_brake(delta)
			if _phase_time >= recovery_duration:
				_finish()


func _take_off() -> void:
	# A parabola of leap_height that covers the distance at leap_speed.
	var flight_time := maxf(_distance / leap_speed, 0.05)
	var jump_speed := 4.0 * leap_height / flight_time
	var attack := AttackData.new()

	attack.attack_type = &"leap"
	attack.source = _source
	attack.origin = attack_hitbox.global_position
	attack.direction = Vector2(_direction, 0.0)
	attack.damage = damage
	attack_hitbox.activate(attack)

	_flight_gravity = 8.0 * leap_height / (flight_time * flight_time)
	body.velocity = Vector2(_direction * leap_speed, -jump_speed)
	_left_floor = false
	_start_phase(Phase.AIRBORNE)
	took_off.emit()


func _fly(delta: float) -> void:
	body.velocity.y += _flight_gravity * delta
	body.move_and_slide()

	if not body.is_on_floor():
		_left_floor = true

	# A wall ends the horizontal flight; he drops where he hit it.
	if body.is_on_wall():
		body.velocity.x = 0.0

	if _left_floor and body.is_on_floor():
		attack_hitbox.deactivate()
		body.velocity.x = 0.0
		_start_phase(Phase.RECOVERY)
		landed.emit()


func _brake(delta: float) -> void:
	body.velocity.x = move_toward(body.velocity.x, 0.0, 4000.0 * delta)

	if not body.is_on_floor():
		body.velocity.y += _gravity() * delta
	elif body.velocity.y > 0.0:
		body.velocity.y = 0.0

	body.move_and_slide()


func _finish() -> void:
	_phase = Phase.IDLE
	_source = null
	set_physics_process(false)
	attack_finished.emit()


func _start_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0


func _gravity() -> float:
	return body.get_gravity().y
