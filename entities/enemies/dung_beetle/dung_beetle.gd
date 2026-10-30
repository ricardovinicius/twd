class_name DungBeetle
extends CharacterBody2D

## Harmless beetle that plays with a health orb, tossing it in its hands.
## When the player comes close it drops the orb to the ground and rolls it
## away, fleeing a bit slower than the player runs, so it can be caught with
## effort (walls corner it). Killing it releases the orb.

enum State {
	PLAY,
	FLEE,
}

signal state_changed(state: State)

@export_category("Play")
## Half of the distance it shuffles around its spot while playing.
@export_range(0.0, 500.0, 1.0, "or_greater") var play_distance: float = 16.0
@export_range(0.1, 30.0, 0.1, "or_greater") var play_period: float = 2.4
## Height of the orb toss while playing.
@export_range(0.0, 64.0, 0.5, "or_greater") var toss_height: float = 4.0
@export_range(0.1, 10.0, 0.05, "or_greater") var toss_period: float = 0.8

@export_category("Flee")
## It starts fleeing when the player comes this close.
@export_range(0.0, 2000.0, 1.0, "or_greater") var flee_radius: float = 200.0
## It stops after the player has been farther than this (the detector's
## radius) for calm_delay seconds.
@export_range(0.0, 4000.0, 1.0, "or_greater") var calm_radius: float = 360.0
@export_range(0.0, 10.0, 0.05, "or_greater") var calm_delay: float = 1.0

@export_category("Presentation")
@export var play_animation: StringName = &"play"
@export var roll_animation: StringName = &"roll"
@export var hit_animation: StringName = &"hit"
## Orb position, in the beetle's local space, while held in its hands.
@export var held_orb_position: Vector2 = Vector2(5, -6)
## Orb position, in the beetle's local space, while rolled ahead on the ground.
@export var rolled_orb_position: Vector2 = Vector2(10, 4)
## Orb radius in local pixels, used to spin it as it rolls.
@export_range(0.5, 32.0, 0.5, "or_greater") var orb_radius: float = 4.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var orb_visual: Node2D = $Orb
@onready var horizontal_movement: HorizontalMovementComponent = $HorizontalMovement
@onready var gravity: GravityComponent = $Gravity
@onready var threat_detector: TargetDetector = $ThreatDetector
@onready var threat_shape: CollisionShape2D = $ThreatDetector/CollisionShape2D
@onready var health: Health = $Health

var _state: State = State.PLAY
var _threat: Node2D
var _home_x: float = 0.0
var _home_set: bool = false
var _facing: float = 1.0
var _play_time: float = 0.0
var _toss_time: float = 0.0
var _calm_time: float = 0.0


func _ready() -> void:
	var circle := threat_shape.shape as CircleShape2D

	if circle != null:
		# Each instance sets its own radius without touching the shared resource.
		circle = circle.duplicate()
		circle.radius = calm_radius / maxf(absf(global_scale.x), 0.001)
		threat_shape.shape = circle

	health.damaged.connect(_on_damaged)
	sprite.animation_finished.connect(_on_animation_finished)
	_update_presentation()


func _physics_process(delta: float) -> void:
	# The respawner places the beetle after _ready, so home is read here.
	if not _home_set:
		set_home_x(global_position.x)

	if not is_on_floor():
		velocity = gravity.calculate_velocity(velocity, get_gravity(), delta)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	_update_threat(delta)

	var direction := _flee_direction() if _state == State.FLEE else _play_direction(delta)

	velocity.x = horizontal_movement.calculate_velocity(velocity.x, direction, delta)

	var previous_x := global_position.x

	move_and_slide()
	_update_orb(global_position.x - previous_x, delta)


func get_state() -> State:
	return _state


func get_threat() -> Node2D:
	return _threat


func get_facing() -> float:
	return _facing


func get_home_x() -> float:
	return _home_x


func set_home_x(x: float) -> void:
	_home_x = x
	_home_set = true


func is_cornered() -> bool:
	return _state == State.FLEE and is_on_wall()


func _update_threat(delta: float) -> void:
	var closest: Node2D = null
	var closest_distance := INF

	for candidate in threat_detector.get_targets():
		var distance := global_position.distance_to(candidate.global_position)

		if distance < closest_distance:
			closest = candidate
			closest_distance = distance

	if _state == State.PLAY:
		if closest != null and closest_distance <= flee_radius:
			_threat = closest
			_calm_time = 0.0
			_set_state(State.FLEE)
		return

	if closest != null and closest_distance <= calm_radius:
		_threat = closest
		_calm_time = 0.0
		return

	_calm_time += delta

	if _calm_time >= calm_delay:
		_calm_down()


func _calm_down() -> void:
	_threat = null
	# It starts playing again wherever it ended up.
	set_home_x(global_position.x)
	_play_time = 0.0
	_set_state(State.PLAY)


func _play_direction(delta: float) -> float:
	_play_time = fmod(_play_time + delta, play_period)

	var phase := TAU * _play_time / play_period
	var target_x := _home_x + sin(phase) * play_distance
	var offset := target_x - global_position.x

	if absf(offset) < 2.0:
		return 0.0

	# Shuffles slowly; the movement component's max speed is for fleeing.
	_face(signf(offset))
	return signf(offset) * 0.25


func _flee_direction() -> float:
	if not is_instance_valid(_threat):
		return 0.0

	var away := global_position.x - _threat.global_position.x
	var direction := signf(away) if not is_zero_approx(away) else _facing

	_face(direction)
	return direction


func _face(direction: float) -> void:
	if is_zero_approx(direction):
		return

	_facing = signf(direction)
	sprite.flip_h = _facing < 0.0


func _update_orb(moved_x: float, delta: float) -> void:
	if _state == State.FLEE:
		orb_visual.position = Vector2(rolled_orb_position.x * _facing, rolled_orb_position.y)
		# Rolling without slipping: the angle follows the distance travelled.
		orb_visual.rotation += moved_x / absf(global_scale.x) / orb_radius
		return

	_toss_time = fmod(_toss_time + delta, toss_period)

	var toss := absf(sin(PI * _toss_time / toss_period)) * toss_height

	orb_visual.position = Vector2(held_orb_position.x * _facing, held_orb_position.y - toss)
	orb_visual.rotation = 0.0


func _set_state(new_state: State) -> void:
	if new_state == _state:
		return

	_state = new_state
	_update_presentation()
	state_changed.emit(_state)


func _update_presentation() -> void:
	if sprite.animation == hit_animation and sprite.is_playing():
		return

	sprite.play(roll_animation if _state == State.FLEE else play_animation)


func _on_damaged(amount: float) -> void:
	if amount <= 0.0 or health.is_depleted():
		return

	sprite.play(hit_animation)


func _on_animation_finished() -> void:
	if sprite.animation == hit_animation:
		_update_presentation()
