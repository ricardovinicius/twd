class_name AttackHitbox
extends Area2D

signal attack_landed(receiver: AttackReceiver)

var _active: bool = false
var _attack: AttackData
var _hit_receivers: Dictionary[AttackReceiver, bool] = {}


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func activate(attack: AttackData) -> void:
	if attack == null:
		push_error("AttackHitbox: Cannot activate with null AttackData.")
		return

	_attack = attack
	_hit_receivers.clear()
	_active = true

	# Existing overlaps do not emit area_entered again when a new swing begins.
	# Defer the query so the physics server has an up-to-date overlap list.
	call_deferred(&"_damage_current_overlaps")


func deactivate() -> void:
	_active = false
	_attack = null
	_hit_receivers.clear()


func _damage_current_overlaps() -> void:
	if not _active:
		return

	for area in get_overlapping_areas():
		_try_damage(area)


func _on_area_entered(area: Area2D) -> void:
	if _active:
		_try_damage(area)


func _try_damage(area: Area2D) -> void:
	var receiver := area as AttackReceiver

	if receiver == null or _hit_receivers.has(receiver):
		return

	if _belongs_to_source(receiver):
		return

	_hit_receivers[receiver] = true
	receiver.receive_attack(_attack)
	attack_landed.emit(receiver)


func _belongs_to_source(node: Node) -> bool:
	if _attack == null or not is_instance_valid(_attack.source):
		return false

	return node == _attack.source or _attack.source.is_ancestor_of(node)
