class_name ClayBall
extends Area2D

## Lump of clay thrown by the Jewish Golem. Flies in an arc under its own
## gravity. Hitting the player damages them and the ball splatters; landing on
## world geometry emits `landed` with a point just outside the surface, where
## the golem's summoner raises a clay minion. Other enemies are ignored.

signal landed(point: Vector2)

@export_category("Debug")
@export var debug_collisions: bool = false

var _attack: AttackData
var _velocity: Vector2 = Vector2.ZERO
var _gravity: float = 0.0
var _remaining_lifetime: float = 0.0
var _target_group: StringName = &"player"
var _launched: bool = false
var _consumed: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


## Throws the ball so that, undisturbed, it passes through `target_point`.
## The flight time follows the horizontal distance, within the given bounds.
func launch(
	origin: Vector2,
	target_point: Vector2,
	attack: AttackData,
	horizontal_speed: float,
	gravity: float,
	lifetime: float,
	target_group: StringName,
	flight_time_bounds: Vector2 = Vector2(0.45, 1.4)
) -> void:
	if attack == null or horizontal_speed <= 0.0 or gravity <= 0.0 or lifetime <= 0.0:
		push_error("ClayBall: Launch needs an attack and a positive speed, gravity, and lifetime.")
		queue_free()
		return

	var offset := target_point - origin
	var flight_time := clampf(absf(offset.x) / horizontal_speed, flight_time_bounds.x, flight_time_bounds.y)

	_attack = attack
	_gravity = gravity
	_velocity = Vector2(
		offset.x / flight_time,
		(offset.y - 0.5 * gravity * flight_time * flight_time) / flight_time
	)
	_remaining_lifetime = lifetime
	_target_group = target_group

	global_position = origin
	reset_physics_interpolation()

	_launched = true
	_debug_log("launched origin=%s velocity=%s" % [global_position, _velocity])


func get_velocity() -> Vector2:
	return _velocity


func is_consumed() -> bool:
	return _consumed


func _physics_process(delta: float) -> void:
	if not _launched or _consumed:
		return

	_velocity.y += _gravity * delta
	global_position += _velocity * delta
	rotation += signf(_velocity.x) * 8.0 * delta
	_remaining_lifetime -= delta

	if _remaining_lifetime <= 0.0:
		_consume("lifetime expired")


func _on_area_entered(area: Area2D) -> void:
	if _consumed or not _launched:
		return

	var receiver := area as AttackReceiver

	if receiver == null or not _belongs_to_target(receiver):
		return

	_debug_log("hit %s" % receiver.get_path())
	receiver.receive_attack(_attack)
	_consume("hit target")


# Only world layers are scanned for bodies, so any body here is ground or a
# wall (including the golem's own clay blocks). Monitorable stays on so
# Godot reports area/static-body pairs (see EyeBolt).
func _on_body_entered(body: Node2D) -> void:
	if _consumed or not _launched:
		return

	if is_instance_valid(_attack.source) and body == _attack.source:
		return

	# Step back along the flight so the point sits outside the surface.
	var landing_point := global_position - _velocity.normalized() * 8.0

	_consume("landed on %s" % body.name)
	landed.emit(landing_point)


func _belongs_to_target(node: Node) -> bool:
	var current := node

	while current != null:
		if current.is_in_group(_target_group):
			return true

		current = current.get_parent()

	return false


func _consume(reason: String) -> void:
	if _consumed:
		return

	_debug_log("consumed: %s" % reason)
	_consumed = true
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	queue_free()


func _debug_log(message: String) -> void:
	if not debug_collisions:
		return

	print("ClayBall: instance=%d %s" % [get_instance_id(), message])
