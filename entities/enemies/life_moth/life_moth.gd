class_name LifeMoth
extends CharacterBody2D

## Harmless moth that carries a health orb in its hands. It flutters back and
## forth around its spot and flies away when the player gets too close. It
## flies a bit slower than the player runs, so it can be caught with effort.
## Killing it makes it drop the orb (see HealthOrbDropOnDeath).

enum State {
	PATROL,
	FLEE,
}

signal state_changed(state: State)

@export_category("Patrol")
## Half of the horizontal distance fluttered around its spot.
@export_range(0.0, 2000.0, 1.0, "or_greater") var patrol_distance: float = 80.0
@export_range(0.1, 30.0, 0.1, "or_greater") var patrol_period: float = 3.5
@export_range(0.0, 1000.0, 1.0, "or_greater") var patrol_speed: float = 160.0

@export_category("Flee")
## It starts fleeing when the player comes this close.
@export_range(0.0, 2000.0, 1.0, "or_greater") var flee_radius: float = 200.0
## It calms down once the player is farther than this (the detector's radius).
@export_range(0.0, 4000.0, 1.0, "or_greater") var calm_radius: float = 320.0
## Slower than the player (400) so a determined chase catches it.
@export_range(0.0, 2000.0, 1.0, "or_greater") var flee_speed: float = 340.0
## Upward lean while fleeing, as a fraction of the flee direction.
@export_range(0.0, 2.0, 0.05) var flee_lift: float = 0.35
## It will not fly higher or lower than this from its spot.
@export_range(0.0, 2000.0, 1.0, "or_greater") var max_height_offset: float = 120.0

@export_category("Flight")
@export_range(0.0, 10000.0, 1.0, "or_greater") var acceleration: float = 1200.0
## Up-and-down flutter added on top of the flight.
@export_range(0.0, 500.0, 1.0, "or_greater") var flutter_speed: float = 60.0
@export_range(0.05, 5.0, 0.05, "or_greater") var flutter_period: float = 0.5

@export_category("Presentation")
@export var fly_animation: StringName = &"fly"
@export var hit_animation: StringName = &"hit"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var threat_detector: TargetDetector = $ThreatDetector
@onready var threat_shape: CollisionShape2D = $ThreatDetector/CollisionShape2D
@onready var health: Health = $Health

var _state: State = State.PATROL
var _threat: Node2D
var _home: Vector2
var _home_set: bool = false
var _patrol_time: float = 0.0
var _flutter_time: float = 0.0


func _ready() -> void:
	var circle := threat_shape.shape as CircleShape2D

	if circle != null:
		# Each instance sets its own radius without touching the shared resource.
		circle = circle.duplicate()
		circle.radius = calm_radius / maxf(absf(global_scale.x), 0.001)
		threat_shape.shape = circle

	health.damaged.connect(_on_damaged)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play(fly_animation)


func _physics_process(delta: float) -> void:
	# The respawner places the moth after _ready, so home is read here.
	if not _home_set:
		set_home(global_position)

	_update_threat()
	_flutter_time = fmod(_flutter_time + delta, flutter_period)

	var desired := _flee_velocity() if _state == State.FLEE else _patrol_velocity(delta)

	desired.y += sin(TAU * _flutter_time / flutter_period) * flutter_speed
	velocity = velocity.move_toward(desired, acceleration * delta)
	move_and_slide()

	if not is_zero_approx(velocity.x):
		sprite.flip_h = velocity.x < 0.0


func get_state() -> State:
	return _state


func get_threat() -> Node2D:
	return _threat


func get_home() -> Vector2:
	return _home


func set_home(point: Vector2) -> void:
	_home = point
	_home_set = true


func _update_threat() -> void:
	var closest: Node2D = null
	var closest_distance := INF

	for candidate in threat_detector.get_targets():
		var distance := global_position.distance_to(candidate.global_position)

		if distance < closest_distance:
			closest = candidate
			closest_distance = distance

	if _state == State.PATROL and closest != null and closest_distance <= flee_radius:
		_threat = closest
		_set_state(State.FLEE)
	elif _state == State.FLEE and (closest == null or closest_distance > calm_radius):
		_calm_down()


func _calm_down() -> void:
	_threat = null
	# It settles where it ended up, keeping its original height band.
	_home.x = global_position.x
	_patrol_time = 0.0
	_set_state(State.PATROL)


func _patrol_velocity(delta: float) -> Vector2:
	_patrol_time = fmod(_patrol_time + delta, patrol_period)

	var phase := TAU * _patrol_time / patrol_period
	var target := _home + Vector2(sin(phase) * patrol_distance, 0.0)
	var offset := target - global_position
	var distance := offset.length()

	if distance < 1.0:
		return Vector2.ZERO

	# Eases in over the last 24 px so it does not overshoot the path.
	return offset / distance * patrol_speed * clampf(distance / 24.0, 0.0, 1.0)


func _flee_velocity() -> Vector2:
	if not is_instance_valid(_threat):
		return Vector2.ZERO

	var away := global_position - _threat.global_position

	if away.is_zero_approx():
		away = Vector2.RIGHT

	var direction := Vector2(signf(away.x) if not is_zero_approx(away.x) else 1.0, -flee_lift)
	var height := global_position.y - _home.y

	# Stay inside the height band around the spot.
	if height <= -max_height_offset:
		direction.y = maxf(direction.y, 0.0)
	elif height >= max_height_offset:
		direction.y = minf(direction.y, 0.0)

	return direction.normalized() * flee_speed


func _set_state(new_state: State) -> void:
	if new_state == _state:
		return

	_state = new_state
	state_changed.emit(_state)


func _on_damaged(amount: float) -> void:
	if amount <= 0.0 or health.is_depleted():
		return

	sprite.play(hit_animation)


func _on_animation_finished() -> void:
	if sprite.animation == hit_animation:
		sprite.play(fly_animation)
