class_name Bestiary
extends Resource

## Ordered list of monster guide entries.

@export var entries: Array[MonsterEntry] = []


func get_entries() -> Array[MonsterEntry]:
	var valid: Array[MonsterEntry] = []

	for entry in entries:
		if entry != null:
			valid.append(entry)

	return valid
