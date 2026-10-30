class_name StarGuardReaction
extends AttackReaction

## Damage reaction that the Star Man can close: while guarded, attacks are
## deflected (they still count as received, so projectiles stop) and health
## is untouched.

signal deflected(attack: AttackData)

@export var health: Health

var guarded: bool = false


func _ready() -> void:
	assert(health != null, "StarGuardReaction: Health is not assigned.")


func supports(attack: AttackData) -> bool:
	return attack != null and attack.damage > 0.0 and not health.is_depleted()


func react(attack: AttackData) -> void:
	if guarded:
		deflected.emit(attack)
		return

	health.take_damage(attack.damage)
