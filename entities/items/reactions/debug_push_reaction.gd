class_name DebugPushReaction
extends ActionReaction

## Optional trace of push actions received by this object (docs/LOGGING.md).
@export_category("Debug")
@export var debug_pushes: bool = false


func supports(action: ActionData) -> bool:
	return debug_pushes and action.type == &"push"


func react(action: ActionData) -> void:
	print(
		"DebugPushReaction: direction=%s strength=%.1f source=%s"
		% [action.direction, action.strength, action.source]
	)
