class_name ActionSpell
extends SpellCommand

@onready var effect_query: ShapeCast2D = $EffectQuery


func _execute() -> void:
	if context == null:
		fail("ActionSpell: context is null.")
		return
	
	
	if context.caster == null:
		fail("ActionSpell: context.caster is null.")
		return
	
	effect_query.global_position = context.origin

	var effect_direction := _get_effect_direction()

	if not effect_direction.is_zero_approx():
		effect_query.rotation = effect_direction.angle()
	
	effect_query.force_shapecast_update()

	for receiver in _find_receivers():

		var action := _create_action_for(receiver)

		if action != null:
			receiver.receive_action(action)
	
	await get_tree().create_timer(2.0).timeout  # Wait for 2 seconds before completing the spell.

	complete()

func _find_receivers() -> Array[ActionReceiver]:
	var receivers: Array[ActionReceiver] = []
	var seen: Dictionary = {}

	for i in effect_query.get_collision_count():
		var area := effect_query.get_collider(i)
		var receiver := area as ActionReceiver


		if receiver == null:
			continue

		if _belongs_to_caster(receiver):
			continue

		var receiver_id = receiver.get_instance_id()

		if seen.has(receiver_id):
			continue

		seen[receiver_id] = true
		receivers.append(receiver)
	
	return receivers


func _belongs_to_caster(node: Node) -> bool:
	if context == null or not is_instance_valid(context.caster):
		return false

	return node == context.caster or context.caster.is_ancestor_of(node)


# Direction used to orient the effect query. Subclasses may aim elsewhere,
# such as the player's aim input.
func _get_effect_direction() -> Vector2:
	return context.direction

func _create_action_for(_receiver: ActionReceiver) -> ActionData:
	push_error("ActionSpell: _create_action_for() method must be implemented in subclasses.")
	return null
