class_name DebugPushReaction
extends ActionReaction


func supports(action: ActionData) -> bool:
	return action.type == &"push"


func react(action: ActionData) -> void:
	push_warning(
		"DebugPushReaction: Received push action - direction=%s, strength=%f, source=%s" 
		% [action.direction, action.strength, action.source]
	)