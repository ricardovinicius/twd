class_name BurnSpell
extends MagicArrowSpell

## Fires a fireball like Magic Arrow. It deals fire damage and sets the enemy
## it hits on fire (a BurnEffect handled by the target's BurnStatusReaction).

@export_category("Burn")
@export_range(0.0, 60.0, 0.05, "or_greater") var burn_duration: float = 3.0
@export_range(0.05, 10.0, 0.05, "or_greater") var burn_tick_interval: float = 0.5
@export_range(0.0, 1000.0, 1.0, "or_greater") var burn_tick_damage: float = 4.0


func _create_attack_data(projectile_direction: Vector2) -> AttackData:
	var attack := super._create_attack_data(projectile_direction)
	var burn := BurnEffect.new()

	burn.duration = burn_duration
	burn.tick_interval = burn_tick_interval
	burn.tick_damage = burn_tick_damage

	attack.attack_type = &"burn"
	attack.damage_type = &"fire"
	attack.effects.append(burn)

	return attack
