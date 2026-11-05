class_name ShieldAbsorbReaction
extends AttackReaction

## Lets the golem's clay blocks catch attacks aimed at him. Player projectiles
## stop on the first Attack Receiver they touch, so a receiver with this
## reaction on a block absorbs arrows and fireballs without effect. The block
## itself is only broken by digging.

signal attack_absorbed(attack: AttackData)


func supports(attack: AttackData) -> bool:
	return attack != null


func react(attack: AttackData) -> void:
	attack_absorbed.emit(attack)
