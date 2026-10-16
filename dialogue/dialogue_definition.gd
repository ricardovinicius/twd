class_name DialogueDefinition
extends Resource

@export var lines: Array[DialogueLine] = []


func is_valid() -> bool:
	if lines.is_empty():
		return false

	for line in lines:
		if line == null or not line.is_valid():
			return false

	return true
