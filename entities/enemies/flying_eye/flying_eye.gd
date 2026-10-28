class_name FlyingEye
extends CharacterBody2D

## Winged eyeball that drifts back and forth around where it was placed.
## When it sees the player (in range, with a clear line of sight) it hovers
## at a distance above them and spits bolts through its pupil.

enum State {
	PATROL,
	ENGAGE,
}

signal state_changed(state: State)

@export_category("Patrol")
## Half of the horizontal distance flown around the placement point.
@export_range(0.0, 2000.0, 1.0, "or_greater") var patrol_distance: float = 96.0
@export_range(0.1, 30.0, 0.1, "or_greater") var patrol_period: float = 4.0

@export_category("Engage")
## Horizontal distance kept from the target while shooting.
@export_range(0.0, 2000.0, 1.0, "or_greater") var keep_distance: float = 200.0
## Height kept above the target while shooting.
@export_range(-1000.0, 1000.0, 1.0) var hover_height: float = 120.0
## Layers that block sight (walls, floors).
@export_flags_2d_physics var line_of_sight_mask: int = 1

@export_category("Presentation")
@export var fly_animation: StringName = &"fly"
@export var shoot_animation: StringName = &"shoot"
@export var hit_animation: StringName = &"hit"

@onready var flight: HoverFlightComponent = $Flight
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var aggro_detector: TargetDetector = $AggroDetector
@onready var ranged_attack: ProjectileAttackComponent = $RangedAttack
@onready var health: Health = $Health

var _state: State = State.PATROL
var _target: Node2D
var _home: Vector2
var _home_set: bool = false
var _patrol_time: float = 0.0


func _ready() -> void:
	ranged_attack.attack_started.connect(_on_attack_started)
	ranged_attack.attack_finished.connect(_on_attack_finished)
	health.damaged.connect(_on_damaged)
	sprite.animation_finished.connect(_on_animation_finished)
	_play(fly_animation)


func _physics_process(delta: float) -> void:
	# The respawner places the eye after _ready, so home is read here.
	if not _home_set:
		set_home(global_position)

	_target = _find_visible_target()
	_set_state(State.ENGAGE if _target != null else State.PATROL)

	if _state == State.ENGAGE:
		flight.fly_toward(_engage_point(_target), delta)
		ranged_attack.begin_attack(_target)
	else:
		_patrol_time = fmod(_patrol_time + delta, patrol_period)
		flight.fly_toward(_patrol_point(), delta)


func get_state() -> State:
	return _state


func get_target() -> Node2D:
	return _target


func get_home() -> Vector2:
	return _home


func set_home(point: Vector2) -> void:
	_home = point
	_home_set = true


func has_line_of_sight(point: Vector2) -> bool:
	if line_of_sight_mask == 0 or not is_inside_tree():
		return true

	var query := PhysicsRayQueryParameters2D.create(global_position, point, line_of_sight_mask)

	query.collide_with_areas = false
	query.exclude = [get_rid()]

	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func can_see(target: Node2D) -> bool:
	return (
		is_instance_valid(target)
		and aggro_detector.has_target(target)
		and has_line_of_sight(target.global_position)
	)


func _find_visible_target() -> Node2D:
	var closest: Node2D = null
	var closest_distance := INF

	for candidate in aggro_detector.get_targets():
		if not can_see(candidate):
			continue

		var candidate_distance := global_position.distance_squared_to(candidate.global_position)

		if candidate_distance < closest_distance:
			closest = candidate
			closest_distance = candidate_distance

	return closest


func _patrol_point() -> Vector2:
	var phase := TAU * _patrol_time / patrol_period

	return _home + Vector2(sin(phase) * patrol_distance, 0.0)


# Stays on the side it is already on, so it never crosses over the target.
func _engage_point(target: Node2D) -> Vector2:
	var side := signf(global_position.x - target.global_position.x)

	if is_zero_approx(side):
		side = 1.0

	return target.global_position + Vector2(side * keep_distance, -hover_height)


func _set_state(new_state: State) -> void:
	if new_state == _state:
		return

	_state = new_state

	if _state == State.PATROL:
		# Resume the patrol from where the eye is instead of snapping back.
		ranged_attack.cancel_attack()
		_patrol_time = _patrol_time_nearest(global_position.x)

	state_changed.emit(_state)


func _patrol_time_nearest(x: float) -> float:
	if is_zero_approx(patrol_distance):
		return 0.0

	var ratio := clampf((x - _home.x) / patrol_distance, -1.0, 1.0)

	return fposmod(asin(ratio) / TAU * patrol_period, patrol_period)


func _play(animation_name: StringName) -> void:
	if sprite.animation == animation_name and sprite.is_playing():
		return

	sprite.play(animation_name)


func _on_attack_started(_attack_target: Node2D) -> void:
	if sprite.animation == hit_animation and sprite.is_playing():
		return

	_play(shoot_animation)


func _on_attack_finished() -> void:
	if sprite.animation == shoot_animation:
		_play(fly_animation)


func _on_damaged(amount: float) -> void:
	if amount <= 0.0 or health.is_depleted():
		return

	sprite.play(hit_animation)
	sprite.set_frame_and_progress(0, 0.0)


func _on_animation_finished() -> void:
	if sprite.animation == hit_animation or sprite.animation == shoot_animation:
		_play(shoot_animation if ranged_attack.is_attacking() else fly_animation)
