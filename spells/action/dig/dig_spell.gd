class_name DigSpell
extends ActionSpell

## Damage applied to each diggable target. Diggable blocks with one point of
## health break with a single cast.
@export_range(0.0, 100.0, 1.0, "or_greater") var dig_strength: float = 1.0


func _get_effect_direction() -> Vector2:
	if not context.aim_direction.is_zero_approx():
		return context.aim_direction.normalized()

	return context.direction.normalized()


func _create_action_for(_receiver: ActionReceiver) -> ActionData:
	if context == null:
		return null

	var action := ActionData.new()

	action.type = &"dig"
	action.source = context.caster
	action.origin = context.origin
	action.direction = _get_effect_direction()
	action.strength = dig_strength

	return action
