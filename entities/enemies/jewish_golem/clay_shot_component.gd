class_name ClayShotComponent
extends Node2D

## The golem tears a lump of clay from his body and lobs it at the target.
## After the wind-up it throws `shots` ClayBalls from this node's position,
## spread around the target. A ball that lands on the ground asks the
## summoner to raise a clay minion there. Cooldowns belong to the owner.

signal attack_started(target: Node2D)
signal ball_thrown(ball: ClayBall)
signal attack_finished

@export_category("Dependencies")
@export var source: Node2D
@export var ball_scene: PackedScene
## Raises a minion where a ball lands. Empty = balls only splatter.
@export var summoner: ClayMinionSummoner
## Where balls are added. Should be freed with the golem (his Summons node).
@export var projectile_parent: Node

@export_category("Ball")
@export_range(0.0, 1000.0, 1.0, "or_greater") var damage: float = 20.0
@export_range(1.0, 5000.0, 1.0, "or_greater") var horizontal_speed: float = 520.0
@export_range(1.0, 10000.0, 1.0, "or_greater") var ball_gravity: float = 1400.0
@export_range(0.05, 30.0, 0.05, "or_greater") var ball_lifetime: float = 4.0
## Horizontal distance between balls when several are thrown at once.
@export_range(0.0, 1000.0, 1.0, "or_greater") var spread: float = 110.0
@export var target_group: StringName = &"player"

@export_category("Timing")
## The golem holds the clay overhead this long; the throw can be read.
@export_range(0.0, 5.0, 0.01, "or_greater") var windup_duration: float = 0.7
@export_range(0.0, 5.0, 0.01, "or_greater") var recovery_duration: float = 0.45

var shots: int = 1

var _target: Node2D
var _time_left: float = 0.0
var _thrown: bool = false
var _attacking: bool = false
var _configured: bool = false


func _ready() -> void:
	if source == null or ball_scene == null or projectile_parent == null:
		push_error("ClayShotComponent: Source, Ball Scene and Projectile Parent must be assigned.")
		return

	_configured = true


func _physics_process(delta: float) -> void:
	if not _attacking:
		return

	_time_left -= delta

	if _time_left > 0.0:
		return

	if not _thrown:
		_throw_all()
		_thrown = true
		_time_left = recovery_duration
		return

	_finish()


func is_attacking() -> bool:
	return _attacking


## Starts the wind-up. Rejected while attacking or without a valid target.
func begin_attack(target: Node2D) -> bool:
	if not _configured or _attacking or not is_instance_valid(target):
		return false

	_target = target
	_attacking = true
	_thrown = false
	_time_left = windup_duration

	attack_started.emit(target)
	return true


## Stops the attack; balls already thrown keep flying.
func cancel_attack() -> void:
	if not _attacking:
		return

	_finish()


func has_thrown() -> bool:
	return _attacking and _thrown


func _throw_all() -> void:
	if not is_instance_valid(_target):
		return

	var count := maxi(shots, 1)
	var first_offset := -spread * (count - 1) * 0.5

	for index in count:
		var aim := _target.global_position + Vector2(first_offset + spread * index, 0.0)
		_throw(aim)


func _throw(aim: Vector2) -> void:
	var ball := ball_scene.instantiate() as ClayBall

	if ball == null:
		push_error("ClayShotComponent: Ball Scene must create a ClayBall.")
		return

	var attack := AttackData.new()

	attack.attack_type = &"clay_ball"
	attack.source = source
	attack.origin = global_position
	attack.direction = (aim - global_position).normalized()
	attack.damage = damage

	projectile_parent.add_child(ball)
	ball.launch(global_position, aim, attack, horizontal_speed, ball_gravity, ball_lifetime, target_group)

	if summoner != null:
		ball.landed.connect(_on_ball_landed.bind(_target))

	ball_thrown.emit(ball)


func _on_ball_landed(point: Vector2, target: Node2D) -> void:
	if is_instance_valid(summoner):
		summoner.summon_at(point, target)


func _finish() -> void:
	_attacking = false
	_thrown = false
	_target = null

	attack_finished.emit()
