class_name ProjectileAttackComponent
extends Node2D

## Ranged attack: winds up while tracking the target, then launches one
## EyeBolt from this node's position toward it and waits for the cooldown.
## The launched bolt owns its own movement, hits, and lifetime.

signal attack_started(target: Node2D)
signal projectile_fired(projectile: EyeBolt)
signal attack_finished

@export_category("Dependencies")
@export var source: Node2D
@export var projectile_scene: PackedScene
## Where bolts are added. Empty = current scene (or the source's parent).
@export var projectile_parent: Node

@export_category("Projectile")
@export_range(0.0, 1000.0, 1.0, "or_greater") var damage: float = 10.0
@export_range(1.0, 5000.0, 1.0, "or_greater") var projectile_speed: float = 260.0
@export_range(0.05, 30.0, 0.05, "or_greater") var projectile_lifetime: float = 3.0
@export var target_group: StringName = &"player"

@export_category("Timing")
## The eye charges for this long before firing; the target can still dodge.
@export_range(0.0, 5.0, 0.01, "or_greater") var windup_duration: float = 0.45
@export_range(0.0, 30.0, 0.05, "or_greater") var cooldown: float = 1.6

var _target: Node2D
var _aim_direction: Vector2 = Vector2.RIGHT
var _windup_left: float = 0.0
var _cooldown_left: float = 0.0
var _attacking: bool = false
var _configured: bool = false


func _ready() -> void:
	if source == null or projectile_scene == null:
		push_error("ProjectileAttackComponent: Source and Projectile Scene must be assigned.")
		return

	_configured = true


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if not _attacking:
		return

	_update_aim()
	_windup_left -= delta

	if _windup_left > 0.0:
		return

	_fire()
	_finish_attack()


func can_attack() -> bool:
	return _configured and not _attacking and _cooldown_left <= 0.0


func is_attacking() -> bool:
	return _attacking


func get_cooldown_left() -> float:
	return _cooldown_left


## Starts the wind-up toward the target. Rejected while attacking, cooling
## down, or without a valid target; a rejection changes no state.
func begin_attack(target: Node2D) -> bool:
	if not can_attack() or not is_instance_valid(target):
		return false

	_target = target
	_attacking = true
	_windup_left = windup_duration
	_update_aim()

	attack_started.emit(target)
	return true


## Stops a wind-up without firing or starting the cooldown.
func cancel_attack() -> void:
	if not _attacking:
		return

	_attacking = false
	_target = null
	attack_finished.emit()


func _update_aim() -> void:
	if not is_instance_valid(_target):
		return

	var offset := _target.global_position - global_position

	if not offset.is_zero_approx():
		_aim_direction = offset.normalized()


func _fire() -> void:
	var parent := _resolve_projectile_parent()

	if parent == null:
		push_error("ProjectileAttackComponent: No parent available for the projectile.")
		return

	var projectile := projectile_scene.instantiate() as EyeBolt

	if projectile == null:
		push_error("ProjectileAttackComponent: Projectile Scene must create an EyeBolt.")
		return

	var attack := AttackData.new()

	attack.attack_type = &"eye_bolt"
	attack.source = source
	attack.origin = global_position
	attack.direction = _aim_direction
	attack.damage = damage

	parent.add_child(projectile)
	projectile.launch(
		global_position,
		_aim_direction,
		attack,
		projectile_speed,
		projectile_lifetime,
		target_group
	)

	projectile_fired.emit(projectile)


func _finish_attack() -> void:
	_attacking = false
	_target = null
	_cooldown_left = cooldown

	attack_finished.emit()


func _resolve_projectile_parent() -> Node:
	if is_instance_valid(projectile_parent):
		return projectile_parent

	var current_scene := get_tree().current_scene

	if current_scene != null:
		return current_scene

	# The bolt outlives the eye that fired it, so it never goes under the eye.
	return source.get_parent()
