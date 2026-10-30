class_name ScorpionMan
extends CharacterBody2D

## Boss: a crouching man with a big stinger tail where his head should be and
## two pincers on his butt. His attack depends on distance:
## - close: he raises the big tail and slams the stinger into the ground in
##   front of him;
## - far: he turns his back and leaps across the room butt-first, pincers
##   open, landing past the player.
## In between he walks closer. He has a lot of health and is not interrupted
## by damage.

enum State {
	IDLE,
	CHASE,
	ATTACK,
}

enum Attack {
	NONE,
	SLAM,
	LEAP,
}

signal state_changed(state: State)
signal attack_chosen(attack: Attack)

@export var facing_direction: float = -1.0

@export_category("Attacks")
## Horizontal distance within which he slams the big stinger.
@export_range(0.0, 1000.0, 1.0, "or_greater") var slam_range: float = 110.0
## Height difference allowed for the slam.
@export_range(0.0, 1000.0, 1.0, "or_greater") var slam_height: float = 110.0
## He leaps when the player is at least this far away (and the leap is ready).
@export_range(0.0, 5000.0, 1.0, "or_greater") var leap_trigger_distance: float = 240.0
## Time between leaps; while it runs he walks closer instead.
@export_range(0.0, 30.0, 0.05, "or_greater") var leap_cooldown: float = 3.5
## Pause after any attack.
@export_range(0.0, 10.0, 0.05, "or_greater") var attack_cooldown: float = 0.35

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var horizontal_movement: HorizontalMovementComponent = $HorizontalMovement
@onready var gravity: GravityComponent = $Gravity
@onready var aggro_detector: TargetDetector = $AggroDetector
@onready var slam: MeleeAttackComponent = $Slam
@onready var leap: LeapAttackComponent = $Leap
@onready var health: Health = $Health

var _state: State = State.IDLE
var _target: Node2D
var _current_attack: Attack = Attack.NONE
var _cooldown_left: float = 0.0
var _leap_cooldown_left: float = 0.0


func _ready() -> void:
	aggro_detector.target_entered.connect(_on_target_entered)
	slam.attack_active.connect(_on_slam_active)
	slam.attack_finished.connect(_on_attack_finished)
	leap.took_off.connect(_on_leap_took_off)
	leap.landed.connect(_on_leap_landed)
	leap.attack_finished.connect(_on_attack_finished)
	health.damaged.connect(_on_damaged)
	sprite.play(&"walk")


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_leap_cooldown_left = maxf(_leap_cooldown_left - delta, 0.0)

	# The leap moves the body itself.
	if leap.is_attacking():
		return

	if not is_on_floor():
		velocity = gravity.calculate_velocity(velocity, get_gravity(), delta)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	_validate_target()

	var direction := 0.0

	if _state != State.ATTACK:
		direction = _resolve_movement()

	velocity.x = horizontal_movement.calculate_velocity(velocity.x, direction, delta)
	move_and_slide()
	_update_walk_animation()


func get_state() -> State:
	return _state


func get_target() -> Node2D:
	return _target


func get_current_attack() -> Attack:
	return _current_attack


## Which attack fits a target at this offset right now (NONE = walk closer).
func choose_attack(offset: Vector2) -> Attack:
	if _cooldown_left > 0.0:
		return Attack.NONE

	if absf(offset.x) <= slam_range and absf(offset.y) <= slam_height:
		return Attack.SLAM

	if absf(offset.x) >= leap_trigger_distance and _leap_cooldown_left <= 0.0 and is_on_floor():
		return Attack.LEAP

	return Attack.NONE


func _resolve_movement() -> float:
	if not is_instance_valid(_target):
		_set_state(State.IDLE)
		return 0.0

	var offset := _target.global_position - global_position
	var attack := choose_attack(offset)

	if attack != Attack.NONE:
		_start_attack(attack, offset)
		return 0.0

	_set_state(State.CHASE)

	if absf(offset.x) <= slam_range:
		return 0.0

	var direction := signf(offset.x)

	_face(direction)
	return direction


func _start_attack(attack: Attack, offset: Vector2) -> void:
	var toward := signf(offset.x) if not is_zero_approx(offset.x) else facing_direction

	_current_attack = attack
	_set_state(State.ATTACK)
	attack_chosen.emit(attack)

	if attack == Attack.SLAM:
		_face(toward)
		_show_frame(&"slam", 0)
		slam.begin_attack(self, Vector2(toward, 0.0))
		return

	# Turns his back: the butt pincers lead the leap.
	_face(-toward)
	_show_frame(&"leap", 0)
	leap.begin_leap(self, _target.global_position.x)
	_leap_cooldown_left = leap_cooldown


func _validate_target() -> void:
	if is_instance_valid(_target) and _target.is_inside_tree() and aggro_detector.has_target(_target):
		return

	if _state == State.ATTACK:
		return

	_target = null

	var targets := aggro_detector.get_targets()

	if not targets.is_empty():
		_target = targets[0]


func _face(direction: float) -> void:
	if is_zero_approx(direction):
		return

	facing_direction = signf(direction)
	sprite.flip_h = facing_direction < 0.0


func _set_state(new_state: State) -> void:
	if new_state == _state:
		return

	_state = new_state
	state_changed.emit(_state)


func _update_walk_animation() -> void:
	if _state == State.ATTACK:
		return

	if absf(velocity.x) > 1.0:
		sprite.play(&"walk")
	else:
		sprite.pause()


func _on_target_entered(target: Node2D) -> void:
	if not is_instance_valid(_target):
		_target = target


# Attack frames follow the attack phases instead of a timer.
func _show_frame(animation_name: StringName, frame: int) -> void:
	sprite.animation = animation_name
	sprite.pause()
	sprite.frame = frame


func _on_slam_active() -> void:
	_show_frame(&"slam", 1)


func _on_leap_took_off() -> void:
	_show_frame(&"leap", 1)


func _on_leap_landed() -> void:
	_show_frame(&"leap", 0)


func _on_attack_finished() -> void:
	if slam.is_attacking() or leap.is_attacking():
		return

	_current_attack = Attack.NONE
	_cooldown_left = attack_cooldown
	_set_state(State.CHASE if is_instance_valid(_target) else State.IDLE)
	sprite.play(&"walk")


# Damage never interrupts him; it only flashes the sprite.
func _on_damaged(amount: float) -> void:
	if amount <= 0.0 or health.is_depleted():
		return

	var tween := create_tween()

	sprite.modulate = Color(1.0, 0.45, 0.45)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
