class_name PushSpell
extends ActionSpell

## Pushes every receiver around the caster away from the caster: a radial
## burst rather than a forward cone. The effect area is EffectQuery's circle,
## centred on the cast origin.

@export var push_strength: float = 200.0


func _create_action_for(receiver: ActionReceiver) -> ActionData:
	var action := ActionData.new()

	action.type = &"push"
	action.source = context.caster
	action.origin = context.origin
	action.direction = _get_push_direction(receiver)
	action.facing = context.direction.normalized()
	action.strength = push_strength

	return action


## Direction from the cast origin to the receiver. A receiver exactly at the
## origin falls back to the caster's facing direction.
func _get_push_direction(receiver: ActionReceiver) -> Vector2:
	var away := receiver.global_position - context.origin

	if away.is_zero_approx():
		return context.direction.normalized()

	return away.normalized()
