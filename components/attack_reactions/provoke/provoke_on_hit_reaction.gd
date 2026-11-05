class_name ProvokeOnHitReaction
extends AttackReaction

## Placed under an enemy's AttackReceiver: when an attack from the target
## group lands (a spell, a projectile...), the attacker is provoked on the
## enemy's detectors, so the enemy reacts to them as if they had been seen,
## even from outside its detection radius.

signal provoked(attacker: Node2D)

## Detectors the enemy uses to find its target (aggro, vision, threat...).
@export var detectors: Array[TargetDetector] = []
## How long the attacker stays detected after a hit; every hit refreshes it.
@export_range(0.1, 60.0, 0.1, "or_greater") var duration: float = 8.0
@export var target_group: StringName = &"player"


func _ready() -> void:
	if detectors.is_empty():
		push_error("ProvokeOnHitReaction: No detectors assigned.")


func supports(attack: AttackData) -> bool:
	return not detectors.is_empty() and find_attacker(attack) != null


func react(attack: AttackData) -> void:
	var attacker := find_attacker(attack)

	if attacker == null:
		return

	for detector in detectors:
		if is_instance_valid(detector):
			detector.provoke(attacker, duration)

	provoked.emit(attacker)


## The attack's source, or its first ancestor, that belongs to target_group.
func find_attacker(attack: AttackData) -> Node2D:
	if attack == null:
		return null

	var current: Node = attack.source

	while is_instance_valid(current):
		if current.is_in_group(target_group) and current is Node2D:
			return current

		current = current.get_parent()

	return null
