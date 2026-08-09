class_name CharacterBodyPushReaction
extends ActionReaction

@export var knockback: KnockbackComponent
@export_range(0.1, 100.0, 0.1, "or_greater") var resistance: float = 1.0


func _ready() -> void:
	assert(
		knockback != null,
		"CharacterBodyPushReaction: KnockbackComponent is not assigned."
	)


func supports(action: ActionData) -> bool:
	return (
		action != null
		and action.type == &"push"
		and action.strength > 0.0
		and not is_zero_approx(action.direction.x)
	)


func react(action: ActionData) -> void:
	var duration := float(
		action.metadata.get(&"duration", knockback.default_duration)
	)
	knockback.begin_knockback(
		action.direction,
		action.strength / resistance,
		duration,
		action.source as PhysicsBody2D
	)
