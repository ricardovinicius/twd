class_name PushSpell
extends ActionSpell

@export var push_strength: float = 100.0


func _create_action_for(_receiver: ActionReceiver) -> ActionData:
	var action = ActionData.new()

	action.type = &"push"
	action.source = context.caster
	action.origin = context.origin
	action.direction = context.direction.normalized()
	action.strength = push_strength

	return action
