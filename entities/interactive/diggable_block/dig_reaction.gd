class_name DigReaction
extends ActionReaction

## Health that dig actions consume. The owning block decides what happens when
## it is depleted, usually through DestroyOnDeath.
@export var health: Health


func _ready() -> void:
	if health == null:
		push_error("DigReaction: Health is not assigned.")


func supports(action: ActionData) -> bool:
	return (
		action != null
		and action.type == &"dig"
		and action.strength > 0.0
		and health != null
		and not health.is_depleted()
	)


func react(action: ActionData) -> void:
	health.take_damage(action.strength)
