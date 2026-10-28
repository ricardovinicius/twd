class_name EyeBolt
extends Area2D

## Projectile spat by the Flying Eye. Flies straight, damages the first
## Attack Receiver that belongs to the target group, and stops on world
## geometry. Other enemies' receivers are ignored, so bolts pass through them.

@export_category("Debug")
@export var debug_collisions: bool = false

var _attack: AttackData
var _direction: Vector2 = Vector2.ZERO
var _speed: float = 0.0
var _remaining_lifetime: float = 0.0
var _target_group: StringName = &"player"
var _launched: bool = false
var _consumed: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func launch(
	origin: Vector2,
	direction: Vector2,
	attack: AttackData,
	speed: float,
	lifetime: float,
	target_group: StringName
) -> void:
	if attack == null or direction.is_zero_approx() or speed <= 0.0 or lifetime <= 0.0:
		push_error("EyeBolt: Launch needs an attack, a direction, and a positive speed and lifetime.")
		queue_free()
		return

	_attack = attack
	_direction = direction.normalized()
	_speed = speed
	_remaining_lifetime = lifetime
	_target_group = target_group

	global_position = origin
	rotation = _direction.angle()
	reset_physics_interpolation()

	_launched = true
	_debug_log("launched origin=%s direction=%s" % [global_position, _direction])


func is_consumed() -> bool:
	return _consumed


func _physics_process(delta: float) -> void:
	if not _launched or _consumed:
		return

	global_position += _direction * _speed * delta
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


# Only world layers are scanned for bodies, so any body here is an obstacle.
# The scene keeps the bolt monitorable: Godot skips area/static-body pairs
# for non-monitorable areas, which would let bolts pass through walls.
func _on_body_entered(body: Node2D) -> void:
	if _consumed or not _launched:
		return

	if is_instance_valid(_attack.source) and body == _attack.source:
		return

	_consume("hit obstacle %s" % body.name)


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

	print("EyeBolt: instance=%d %s" % [get_instance_id(), message])
