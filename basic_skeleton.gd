class_name BasicMob
extends CharacterBody2D

enum State {
	IDLE,
	CHASE,
	ATTACK,
}

@export var facing_direction: Vector2 = Vector2.LEFT

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var horizontal_movement: HorizontalMovementComponent = $HorizontalMovement
@onready var gravity: GravityComponent = $Gravity
@onready var aggro_detector: TargetDetector = $AggroDetector
@onready var attack_range_detector: TargetDetector = $AttackRangeDetector
@onready var melee_attack: MeleeAttackComponent = $MeleeAttack

var state: State = State.IDLE
var target: Node2D


func _ready() -> void:
	aggro_detector.target_entered.connect(_on_aggro_target_entered)
	aggro_detector.target_exited.connect(_on_aggro_target_exited)
	melee_attack.attack_started.connect(_on_attack_started)
	melee_attack.attack_finished.connect(_on_attack_finished)
	_play_animation(&"idle")


func _physics_process(delta: float) -> void:
	_validate_target()

	if not is_on_floor():
		velocity = gravity.calculate_velocity(velocity, get_gravity(), delta)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if state != State.ATTACK:
		_resolve_non_attack_state()

	var movement_direction := 0.0

	if state == State.CHASE and is_instance_valid(target):
		movement_direction = signf(target.global_position.x - global_position.x)
		if not is_zero_approx(movement_direction):
			facing_direction = Vector2(movement_direction, 0.0)

	velocity.x = horizontal_movement.calculate_velocity(
		velocity.x,
		movement_direction,
		delta
	)

	move_and_slide()
	_update_animation()


func _resolve_non_attack_state() -> void:
	if not is_instance_valid(target):
		state = State.IDLE
		return

	if attack_range_detector.has_target(target):
		_start_attack()
	else:
		state = State.CHASE


func _start_attack() -> void:
	var horizontal_distance := target.global_position.x - global_position.x

	if not is_zero_approx(horizontal_distance):
		facing_direction = Vector2(signf(horizontal_distance), 0.0)

	if melee_attack.begin_attack(self, facing_direction):
		state = State.ATTACK


func _validate_target() -> void:
	if is_instance_valid(target) and aggro_detector.has_target(target):
		return

	target = null

	if state != State.ATTACK:
		state = State.IDLE


func _update_animation() -> void:
	animated_sprite.flip_h = facing_direction.x < 0.0

	if state == State.ATTACK:
		return

	if state == State.CHASE and absf(velocity.x) > 1.0:
		_play_animation(&"walk")
	else:
		_play_animation(&"idle")


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite.animation == animation_name:
		return

	animated_sprite.play(animation_name)


func _on_aggro_target_entered(detected_target: Node2D) -> void:
	if is_instance_valid(target):
		return

	target = detected_target

	if state != State.ATTACK:
		_resolve_non_attack_state()


func _on_aggro_target_exited(detected_target: Node2D) -> void:
	if detected_target != target:
		return

	target = null

	if state != State.ATTACK:
		state = State.IDLE


func _on_attack_started(_direction: Vector2) -> void:
	_play_animation(&"attack")


func _on_attack_finished() -> void:
	state = State.IDLE
	_play_animation(&"idle")
