class_name MagicArrowProjectile
extends Area2D

var _attack: AttackData
var _direction: Vector2 = Vector2.ZERO
var _speed: float = 0.0
var _remaining_lifetime: float = 0.0

# Flags
var _launched := false
var _consumed := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func launch(
	origin: Vector2,
	direction: Vector2,
	attack: AttackData,
	speed: float,
	lifetime: float
) -> void:
	if attack == null:
		push_error("MagicArrowProjectile: Cannot launch with a null attack.")
		queue_free()
		return
	
	if direction.is_zero_approx():
		push_error("MagicArrowProjectile: Cannot launch with a zero direction.")
		queue_free()
		return

	if speed <= 0.0:
		push_error("MagicArrowProjectile: Cannot launch with a non-positive speed.")
		queue_free()
		return
	
	if lifetime <= 0.0:
		push_error("MagicArrowProjectile: Cannot launch with a non-positive lifetime.")
		queue_free()
		return

	_attack = attack
	_direction = direction.normalized()
	_speed = speed
	_remaining_lifetime = lifetime

	global_position = origin
	rotation = _direction.angle()

	_launched = true


func _physics_process(delta: float) -> void:
	if not _launched or _consumed:
		return

	# Move the projectile
	var displacement = _direction * _speed * delta
	global_position += displacement

	# Update lifetime
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		_consume()


func _on_area_entered(area: Area2D) -> void:
	if _consumed:
		return
	
	var attack_receiver = area as AttackReceiver

	if attack_receiver == null:
		return
	
	if _belongs_to_caster(attack_receiver):
		return
	
	attack_receiver.receive_attack(_attack)
	_consume()


func _on_body_entered(body: Node) -> void:
	if _consumed:
		return

	if _belongs_to_caster(body):
		return
	
	_consume()


func _belongs_to_caster(node: Node) -> bool:
	if _attack == null:
		return false
	
	var caster := _attack.source
	
	if not is_instance_valid(caster):
		return false
	
	return (
		node == _attack.source 
		or caster.is_ancestor_of(node)
	)


func _consume() -> void:
	if _consumed:
		return
	
	_consumed = true
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	queue_free()
