class_name ContactImpactComponent
extends Node2D

signal contact_applied(target: Node2D)

@export_category("Dependencies")
@export var source: Node2D
@export var contact_area: Area2D

@export_category("Contact Effects")
@export_range(0.0, 1000.0, 1.0, "or_greater")
var contact_damage: float = 10.0
@export_range(0.0, 5000.0, 10.0, "or_greater")
var knockback_strength: float = 450.0
@export_range(0.01, 10.0, 0.01, "or_greater")
var knockback_duration: float = 0.25
@export_range(0.0, 10.0, 0.05, "or_greater")
var contact_cooldown: float = 0.5
@export var target_group: StringName = &"player"

var _overlapping_targets: Dictionary = {}
var _cooldowns: Dictionary = {}


func _ready() -> void:
	assert(source != null, "ContactImpactComponent: Source is not assigned.")
	assert(contact_area != null, "ContactImpactComponent: ContactArea is not assigned.")

	contact_area.body_entered.connect(_on_body_entered)
	contact_area.body_exited.connect(_on_body_exited)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	var expired_targets: Array[Node2D] = []

	for target: Node2D in _cooldowns:
		if not is_instance_valid(target):
			expired_targets.append(target)
			continue

		var remaining: float = _cooldowns[target] - delta

		if remaining <= 0.0:
			expired_targets.append(target)
		else:
			_cooldowns[target] = remaining

	for target in expired_targets:
		_cooldowns.erase(target)

	if _cooldowns.is_empty():
		set_physics_process(false)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(target_group):
		return

	if _overlapping_targets.has(body):
		return

	_overlapping_targets[body] = true

	if _cooldowns.has(body):
		return

	_apply_contact(body)

	if contact_cooldown > 0.0:
		_cooldowns[body] = contact_cooldown
		set_physics_process(true)


func _on_body_exited(body: Node2D) -> void:
	_overlapping_targets.erase(body)


func _apply_contact(target: Node2D) -> void:
	var direction := _direction_to_target(target)
	var attack_receiver := _find_attack_receiver(target)
	var action_receiver := _find_action_receiver(target)

	if attack_receiver != null and contact_damage > 0.0:
		var attack := AttackData.new()
		attack.attack_type = &"contact"
		attack.source = source
		attack.origin = contact_area.global_position
		attack.direction = direction
		attack.damage = contact_damage
		attack_receiver.receive_attack(attack)

	if action_receiver != null and knockback_strength > 0.0:
		var action := ActionData.new()
		action.type = &"push"
		action.source = source
		action.origin = contact_area.global_position
		action.direction = direction
		action.strength = knockback_strength
		action.metadata[&"duration"] = knockback_duration
		action_receiver.receive_action(action)

	contact_applied.emit(target)


func _direction_to_target(target: Node2D) -> Vector2:
	var horizontal_distance := target.global_position.x - source.global_position.x

	if is_zero_approx(horizontal_distance):
		return Vector2.RIGHT

	return Vector2(signf(horizontal_distance), 0.0)


func _find_attack_receiver(node: Node) -> AttackReceiver:
	var receiver := node as AttackReceiver

	if receiver != null:
		return receiver

	for child in node.get_children():
		receiver = _find_attack_receiver(child)
		if receiver != null:
			return receiver

	return null


func _find_action_receiver(node: Node) -> ActionReceiver:
	var receiver := node as ActionReceiver

	if receiver != null:
		return receiver

	for child in node.get_children():
		receiver = _find_action_receiver(child)
		if receiver != null:
			return receiver

	return null
