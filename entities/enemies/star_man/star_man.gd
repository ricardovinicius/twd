class_name StarMan
extends CharacterBody2D

## Tough enemy: a man with a star stuck around his neck. He waits until he sees the
## player, screams, then curls into the star and rolls at them like a madman:
## very fast, hopping at random, turning back when he overshoots, bouncing off
## walls. While rolling he cannot be hurt and hits hard. When the roll ends he
## stands still, dizzy, and only then (or while standing before a roll) can
## he be damaged. Then he rolls again while the player is near.

enum State {
	IDLE,
	SCREAM,
	ROLL,
	DIZZY,
}

signal state_changed(state: State)
signal screamed(target: Node2D)

@export_category("Vision")
@export_range(0.0, 4000.0, 1.0, "or_greater") var vision_radius: float = 420.0
## Layers that block sight (walls, floors).
@export_flags_2d_physics var line_of_sight_mask: int = 1
## He forgets the player once they are this far away while he is dizzy.
@export_range(0.0, 10000.0, 1.0, "or_greater") var lose_radius: float = 1000.0

@export_category("Scream")
@export_range(0.0, 5.0, 0.01, "or_greater") var scream_duration: float = 0.9

@export_category("Roll")
@export_range(0.0, 3000.0, 1.0, "or_greater") var roll_speed: float = 620.0
@export_range(0.0, 20000.0, 1.0, "or_greater") var roll_acceleration: float = 2400.0
@export_range(0.1, 20.0, 0.05, "or_greater") var roll_duration: float = 2.4
## Random hops while rolling: upward speed and the time between hops.
@export_range(0.0, 3000.0, 1.0, "or_greater") var hop_speed: float = 420.0
@export var hop_interval: Vector2 = Vector2(0.25, 0.6)
## How far past the player he rolls before turning back, and how many times.
@export_range(0.0, 2000.0, 1.0, "or_greater") var overshoot_distance: float = 180.0
@export_range(0, 10) var max_turns: int = 2
## Spin of the rolling sprite, in radians per pixel travelled.
@export_range(0.0, 1.0, 0.001) var spin_per_pixel: float = 0.025
## Contact damage while rolling and while standing.
@export_range(0.0, 1000.0, 1.0, "or_greater") var roll_contact_damage: float = 20.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var stand_contact_damage: float = 5.0
@export_range(0.0, 5000.0, 1.0, "or_greater") var roll_knockback: float = 700.0
@export_range(0.0, 5000.0, 1.0, "or_greater") var stand_knockback: float = 300.0

@export_category("Dizzy")
## How long he stands still, open to damage, after each roll.
@export_range(0.1, 20.0, 0.05, "or_greater") var dizzy_duration: float = 1.8
@export_range(0.0, 20000.0, 1.0, "or_greater") var brake_deceleration: float = 3000.0

@export_category("Randomness")
## 0 = random every run; any other value repeats the same hops.
@export var rng_seed: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var gravity: GravityComponent = $Gravity
@onready var vision: TargetDetector = $Vision
@onready var vision_shape: CollisionShape2D = $Vision/CollisionShape2D
@onready var guard: StarGuardReaction = $AttackReceiver/StarGuardReaction
@onready var burn: BurnStatusReaction = $AttackReceiver/BurnStatusReaction
@onready var contact_impact: ContactImpactComponent = $ContactImpact
@onready var health: Health = $Health

var _state: State = State.IDLE
var _target: Node2D
var _direction: float = 1.0
var _state_time: float = 0.0
var _hop_time_left: float = 0.0
var _turns_left: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var circle := vision_shape.shape as CircleShape2D

	if circle != null:
		# Each instance sets its own radius without touching the shared resource.
		circle = circle.duplicate()
		circle.radius = vision_radius / maxf(absf(global_scale.x), 0.001)
		vision_shape.shape = circle

	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	health.damaged.connect(_on_damaged)
	guard.deflected.connect(_on_deflected)
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity = gravity.calculate_velocity(velocity, get_gravity(), delta)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	_state_time += delta

	match _state:
		State.IDLE:
			_process_idle()
		State.SCREAM:
			_process_scream()
		State.ROLL:
			_process_roll(delta)
		State.DIZZY:
			_process_dizzy(delta)

	var previous_x := global_position.x

	move_and_slide()

	if _state == State.ROLL:
		_bounce_off_walls()
		sprite.rotation += (global_position.x - previous_x) * spin_per_pixel


func get_state() -> State:
	return _state


func get_target() -> Node2D:
	return _target


func get_roll_direction() -> float:
	return _direction


func is_vulnerable() -> bool:
	return not guard.guarded


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
		and vision.has_target(target)
		and global_position.distance_to(target.global_position) <= vision_radius
		and has_line_of_sight(target.global_position)
	)


func _process_idle() -> void:
	velocity.x = move_toward(velocity.x, 0.0, brake_deceleration * get_physics_process_delta_time())

	var seen := _find_visible_target()

	if seen == null:
		return

	_target = seen
	_face_target()
	_enter_state(State.SCREAM)
	screamed.emit(seen)


func _process_scream() -> void:
	velocity.x = 0.0

	if _state_time >= scream_duration:
		_start_roll()


func _start_roll() -> void:
	if not _has_valid_target():
		_enter_state(State.IDLE)
		return

	_face_target()
	_turns_left = max_turns
	_hop_time_left = _rng.randf_range(hop_interval.x, hop_interval.y)
	_enter_state(State.ROLL)


func _process_roll(delta: float) -> void:
	if _state_time >= roll_duration:
		_enter_state(State.DIZZY)
		return

	if _has_valid_target() and _turns_left > 0:
		var past := (global_position.x - _target.global_position.x) * _direction

		if past > overshoot_distance:
			_direction = -_direction
			_turns_left -= 1

	velocity.x = move_toward(velocity.x, _direction * roll_speed, roll_acceleration * delta)

	_hop_time_left -= delta

	if _hop_time_left <= 0.0 and is_on_floor():
		velocity.y = -hop_speed * _rng.randf_range(0.5, 1.0)
		_hop_time_left = _rng.randf_range(hop_interval.x, hop_interval.y)


func _bounce_off_walls() -> void:
	if not is_on_wall():
		return

	var normal := get_wall_normal()

	if signf(normal.x) == -_direction:
		_direction = signf(normal.x)
		velocity.x = _direction * absf(velocity.x) * 0.6


func _process_dizzy(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, brake_deceleration * delta)

	if _state_time < dizzy_duration:
		return

	if _has_valid_target() and global_position.distance_to(_target.global_position) <= lose_radius:
		_start_roll()
	else:
		_target = null
		_enter_state(State.IDLE)


func _has_valid_target() -> bool:
	return is_instance_valid(_target) and _target.is_inside_tree()


func _face_target() -> void:
	if not _has_valid_target():
		return

	var offset := _target.global_position.x - global_position.x

	if not is_zero_approx(offset):
		_direction = signf(offset)


func _find_visible_target() -> Node2D:
	var closest: Node2D = null
	var closest_distance := INF

	for candidate in vision.get_targets():
		if not can_see(candidate):
			continue

		var candidate_distance := global_position.distance_squared_to(candidate.global_position)

		if candidate_distance < closest_distance:
			closest = candidate
			closest_distance = candidate_distance

	return closest


func _enter_state(new_state: State) -> void:
	var changed := new_state != _state

	_state = new_state
	_state_time = 0.0
	guard.guarded = _state == State.ROLL
	# Rolling smothers any fire and he cannot catch fire while rolling.
	burn.blocked = guard.guarded

	if _state == State.ROLL:
		contact_impact.contact_damage = roll_contact_damage
		contact_impact.knockback_strength = roll_knockback
	else:
		contact_impact.contact_damage = stand_contact_damage
		contact_impact.knockback_strength = stand_knockback
		sprite.rotation = 0.0

	_update_presentation()

	if changed:
		state_changed.emit(_state)


func _update_presentation() -> void:
	sprite.flip_h = _direction < 0.0

	match _state:
		State.IDLE:
			sprite.play(&"idle")
		State.SCREAM:
			sprite.play(&"scream")
		State.ROLL:
			sprite.play(&"roll")
		State.DIZZY:
			sprite.play(&"dizzy")


func _on_damaged(amount: float) -> void:
	if amount <= 0.0 or health.is_depleted():
		return

	sprite.play(&"hit")
	get_tree().create_timer(0.12, false, true).timeout.connect(_on_hit_flash_finished)


func _on_hit_flash_finished() -> void:
	if is_inside_tree() and sprite.animation == &"hit":
		_update_presentation()


func _on_deflected(_attack: AttackData) -> void:
	# Quick flash so the player can tell the hit bounced off.
	var tween := create_tween()

	sprite.modulate = Color(1.6, 1.6, 0.6)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
