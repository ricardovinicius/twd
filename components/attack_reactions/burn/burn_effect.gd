class_name BurnEffect
extends RefCounted

## Effect data carried by an AttackData: sets the target on fire, dealing
## tick_damage every tick_interval for duration seconds.

var duration: float = 3.0
var tick_interval: float = 0.5
var tick_damage: float = 4.0


static func find_in(attack: AttackData) -> BurnEffect:
	if attack == null:
		return null

	for effect in attack.effects:
		if effect is BurnEffect:
			return effect

	return null
