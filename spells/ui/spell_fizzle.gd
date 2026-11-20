class_name SpellFizzle
extends AnimatedSprite2D

## Plays a short sputter-and-smoke animation on the caster whenever a spell
## cannot be cast: unknown or not owned sequence, cooldown, or too many tokens.

@export var sequence_caster: SequenceCaster


func _ready() -> void:
	visible = false
	animation_finished.connect(_on_animation_finished)

	if sequence_caster == null:
		push_error("SpellFizzle: SequenceCaster is not assigned.")
		return

	sequence_caster.sequence_failed.connect(_on_sequence_failed)


func play_fizzle() -> void:
	visible = true
	play(&"fizzle")
	# Restart from the first frame when spells fail in quick succession.
	set_frame_and_progress(0, 0.0)


func _on_sequence_failed(_sequence: Array[StringName], _reason: StringName) -> void:
	play_fizzle()


func _on_animation_finished() -> void:
	visible = false
