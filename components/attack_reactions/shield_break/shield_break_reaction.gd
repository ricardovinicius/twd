class_name ShieldBreakReaction
extends AttackReaction

## Placed under an AttackReceiver: a "break" attack (the Break spell) shatters
## the assigned BreakableShield at once, whatever its strength. Ignored when
## the shield is already broken.

const BREAK_ATTACK_TYPE := &"break"

signal shield_shattered

@export var shield: BreakableShield


func _ready() -> void:
	if shield == null:
		push_error("ShieldBreakReaction: BreakableShield is not assigned.")


func supports(attack: AttackData) -> bool:
	return (
		attack != null
		and attack.attack_type == BREAK_ATTACK_TYPE
		and shield != null
		and not shield.is_broken()
	)


func react(_attack: AttackData) -> void:
	if shield.shatter():
		shield_shattered.emit()
