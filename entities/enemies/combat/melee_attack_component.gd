class_name MeleeAttackComponent
extends Node2D

signal attack_started(direction: Vector2)
signal attack_active
signal attack_finished

enum Phase {
	IDLE,
	WINDUP,
	ACTIVE,
	RECOVERY,
}

@export_category("Dependencies")
@export var attack_hitbox: AttackHitbox
@export var visual: Node2D

@export_category("Attack")
@export_range(0.0, 1000.0, 1.0, "or_greater") var damage: float = 10.0
@export_range(0.01, 10.0, 0.01, "or_greater") var windup_duration: float = 0.3
@export_range(0.01, 10.0, 0.01, "or_greater") var active_duration: float = 0.1
@export_range(0.01, 10.0, 0.01, "or_greater") var recovery_duration: float = 0.6

@export_category("Presentation")
@export_range(0.0, 100.0, 0.5, "or_greater") var windup_distance: float = 2.0
@export_range(0.0, 100.0, 0.5, "or_greater") var lunge_distance: float = 6.0

var _phase: Phase = Phase.IDLE
var _phase_elapsed: float = 0.0
var _phase_duration: float = 0.0
var _phase_start_position: Vector2
var _phase_target_position: Vector2
var _rest_position: Vector2
var _source: Node2D
var _direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	assert(attack_hitbox != null, "MeleeAttackComponent: AttackHitbox is not assigned.")
	assert(visual != null, "MeleeAttackComponent: Visual is not assigned.")

	_rest_position = visual.position
	set_process(false)


func begin_attack(source: Node2D, direction: Vector2) -> bool:
	if is_attacking():
		return false

	if not is_instance_valid(source):
		push_error("MeleeAttackComponent: Attack source is invalid.")
		return false

	if direction.is_zero_approx():
		push_error("MeleeAttackComponent: Attack direction cannot be zero.")
		return false

	_source = source
	_direction = Vector2(signf(direction.x), 0.0)
	attack_hitbox.position.x = absf(attack_hitbox.position.x) * _direction.x

	_start_phase(
		Phase.WINDUP,
		windup_duration,
		_rest_position - _direction * windup_distance
	)
	set_process(true)
	attack_started.emit(_direction)
	return true


func is_attacking() -> bool:
	return _phase != Phase.IDLE


func _process(delta: float) -> void:
	_phase_elapsed += delta

	var progress := minf(_phase_elapsed / _phase_duration, 1.0)
	visual.position = _phase_start_position.lerp(
		_phase_target_position,
		ease(progress, -1.5)
	)

	if _phase_elapsed < _phase_duration:
		return

	match _phase:
		Phase.WINDUP:
			_begin_active_phase()
		Phase.ACTIVE:
			_begin_recovery_phase()
		Phase.RECOVERY:
			_complete_attack()


func _begin_active_phase() -> void:
	var attack := AttackData.new()
	attack.attack_type = &"melee"
	attack.source = _source
	attack.origin = attack_hitbox.global_position
	attack.direction = _direction
	attack.damage = damage

	attack_hitbox.activate(attack)
	_start_phase(
		Phase.ACTIVE,
		active_duration,
		_rest_position + _direction * lunge_distance
	)
	attack_active.emit()


func _begin_recovery_phase() -> void:
	attack_hitbox.deactivate()
	_start_phase(Phase.RECOVERY, recovery_duration, _rest_position)


func _complete_attack() -> void:
	visual.position = _rest_position
	_source = null
	_phase = Phase.IDLE
	set_process(false)
	attack_finished.emit()


func _start_phase(
	new_phase: Phase,
	duration: float,
	target_position: Vector2
) -> void:
	_phase = new_phase
	_phase_elapsed = 0.0
	_phase_duration = duration
	_phase_start_position = visual.position
	_phase_target_position = target_position
