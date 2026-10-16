class_name DialogueLine
extends Resource

@export var speaker_name: String
@export_multiline var text: String


func is_valid() -> bool:
	return not speaker_name.strip_edges().is_empty() and not text.strip_edges().is_empty()
