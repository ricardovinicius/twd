class_name BreakSpell
extends MagicArrowSpell

## Fires a shard like Magic Arrow. It deals no damage: it carries a "break"
## attack that shatters the BreakableShield of the first enemy it hits (through
## that enemy's ShieldBreakReaction), leaving its health open to attacks.


func _create_attack_data(projectile_direction: Vector2) -> AttackData:
	var attack := super._create_attack_data(projectile_direction)

	attack.attack_type = ShieldBreakReaction.BREAK_ATTACK_TYPE
	attack.damage = 0.0

	return attack
