class_name Homunculus
extends CharacterBody2D

## One half of the Homunculus Couple. Walks on the ground with gravity and
## follows orders from its couple: kiss, stare at the target mid-kiss, chase,
## go home, or wait. Contact damage, health, and drops come from its composed
## components.

enum State {
	KISS,
	STARE,
	CHASE,
	RETURN,
	IDLE,
}

signal state_changed(state: State)

@export_category("Movement")
## How close counts as "arrived" at a spot or under the target.
@export_range(0.0, 50.0, 0.5, "or_greater") var arrive_distance: float = 6.0

@export_category("Presentation")
@export var kiss_animation: StringName = &"kiss"
## Mid-kiss stare toward a target in front (the side it faces).
@export var stare_front_animation: StringName = &"stare_front"
## Mid-kiss stare over the shoulder at a target behind it.
@export var stare_back_animation: StringName = &"stare_back"
@export var idle_animation: StringName = &"alert"
@export var run_animation: StringName = &"run"
@export var hit_animation: StringName = &"hit"
## How long the hit pose stays before the state animation returns.
@export_range(0.0, 2.0, 0.01, "or_greater") var hit_duration: float = 0.2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var horizontal_movement: HorizontalMovementComponent = $HorizontalMovement
@onready var gravity: GravityComponent = $Gravity
@onready var attack_receiver: AttackReceiver = $AttackReceiver
@onready var health: Health = $Health

var _state: State = State.KISS
var _facing: float = 1.0
var _target: Node2D
var _home_x: float = 0.0
var _hit_time_left: float = 0.0


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	_update_presentation()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity = gravity.calculate_velocity(velocity, get_gravity(), delta)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	var direction := _resolve_direction()

	velocity.x = horizontal_movement.calculate_velocity(velocity.x, direction, delta)
	move_and_slide()
	_update_hit_pose(delta)

	if _state == State.STARE:
		_update_presentation()


func get_state() -> State:
	return _state


func get_target() -> Node2D:
	return _target


func get_facing() -> float:
	return _facing


func is_home() -> bool:
	return absf(global_position.x - _home_x) <= arrive_distance


func is_looking_back() -> bool:
	return (
		is_instance_valid(_target)
		and signf(_target.global_position.x - global_position.x) == -_facing
	)


func kiss(facing: float) -> void:
	_target = null
	velocity.x = 0.0
	_face(facing)
	_set_state(State.KISS)


## Keeps kissing in place but turns its eyes to the target.
func stare(target: Node2D) -> void:
	_target = target
	velocity.x = 0.0
	_set_state(State.STARE)
	_update_presentation()


func chase(target: Node2D) -> void:
	_target = target
	_set_state(State.CHASE)


func return_home(home_x: float) -> void:
	_target = null
	_home_x = home_x
	_set_state(State.RETURN)


func wait() -> void:
	_target = null
	_set_state(State.IDLE)


func _resolve_direction() -> float:
	match _state:
		State.CHASE:
			if is_instance_valid(_target):
				return _direction_to_x(_target.global_position.x)
		State.RETURN:
			if is_home():
				# Stop on the spot instead of sliding past it.
				velocity.x = 0.0
				_set_state(State.IDLE)
				return 0.0
			return _direction_to_x(_home_x)

	return 0.0


func _direction_to_x(x: float) -> float:
	var offset := x - global_position.x

	if absf(offset) <= arrive_distance:
		return 0.0

	var direction := signf(offset)

	_face(direction)
	return direction


func _face(direction: float) -> void:
	if is_zero_approx(direction):
		return

	_facing = signf(direction)
	sprite.flip_h = _facing < 0.0


func _set_state(new_state: State) -> void:
	if new_state == _state:
		return

	_state = new_state
	_update_presentation()
	state_changed.emit(_state)


func _update_presentation() -> void:
	if _hit_time_left > 0.0:
		return

	var animation := idle_animation

	match _state:
		State.KISS:
			animation = kiss_animation
		State.STARE:
			animation = stare_back_animation if is_looking_back() else stare_front_animation
		State.CHASE, State.RETURN:
			animation = run_animation

	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)


func _update_hit_pose(delta: float) -> void:
	if _hit_time_left <= 0.0:
		return

	_hit_time_left -= delta

	if _hit_time_left <= 0.0:
		_update_presentation()


func _on_damaged(amount: float) -> void:
	if amount <= 0.0 or health.is_depleted():
		return

	_hit_time_left = hit_duration
	sprite.play(hit_animation)
