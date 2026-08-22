# This class is responsible for managing the casting of spells in a sequence.
# It buffers input sequences and invokes the corresponding registered spell.
# in the SpellDefinition resource.

class_name SequenceCaster
extends Node

signal sequence_changed(new_sequence: Array[StringName])
signal sequence_failed(sequence: Array[StringName], reason: StringName)
signal spell_selected(spell: SpellDefinition)

@export var input_timeout: float = 5.0
@export var max_sequence_length: int = 5

@export var registry: SpellRegistry

@export var caster: CharacterBody2D
@export var spell_origin: Marker2D
@export var effect_parent: Node
@export var projectile_aim: Node

@onready var timeout_timer: Timer = $TimeoutTimer
@onready var spell_invoker: SpellInvoker = $"../SpellInvoker"

var current_sequence: Array[StringName] = []

# Maps sequences strings to their corresponding SpellDefinition for quick lookup.
var sequence_to_spell: Dictionary[StringName, SpellDefinition] = {}


func _ready() -> void:
	timeout_timer.one_shot = true
	timeout_timer.timeout.connect(_on_timeout)
	spell_invoker.spell_rejected.connect(_on_spell_rejected)

	if registry == null:
		push_error("SequenceCaster: SpellRegistry is not assigned.")
		return

	registry.spell_registered.connect(_on_spell_registered)
	registry.spell_unregistered.connect(_on_spell_unregistered)
	_rebuild_spell_lookup()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cast_attack_token"):
		_add_token_to_sequence("attack")
	elif event.is_action_pressed("cast_interaction_token"):
		_add_token_to_sequence("interaction")
	elif event.is_action_pressed("cast_move_token"):
		_add_token_to_sequence("move")
	elif event.is_action_pressed("cast_confirm_token"):
		confirm_sequence()
	else:
		return

	get_viewport().set_input_as_handled()


func clear_sequence() -> void:
	current_sequence.clear()
	timeout_timer.stop()
	sequence_changed.emit(current_sequence)


func confirm_sequence() -> void:
	if current_sequence.is_empty():
		push_warning("SequenceCaster::confirm_sequence() - No sequence to confirm.")
		return

	# Duplicate the current sequence to avoid mutation during processing.
	var entered_sequence := current_sequence.duplicate()

	# Look up the spell based on the entered sequence.
	var sequence_key := _convert_sequence_to_key(entered_sequence)
	var spell := sequence_to_spell.get(sequence_key, null) as SpellDefinition

	if spell == null or registry == null or not registry.has_spell(spell.id):
		push_warning("SequenceCaster::confirm_sequence() - No spell found for the entered sequence: %s" % entered_sequence)
		sequence_failed.emit(entered_sequence, "no_matching_spell")
		clear_sequence()
		return

	var context := _create_spell_context()

	# Emit the spell_selected signal and invoke the spell using the SpellInvoker.
	spell_selected.emit(spell)
	spell_invoker.cast(spell, context)

	clear_sequence()  # Clear the sequence after casting the spell.


func get_timeout_ratio() -> float:
	if timeout_timer.is_stopped():
		return 0.0

	if input_timeout <= 0.0:
		return 0.0

	return timeout_timer.time_left / input_timeout


func _rebuild_spell_lookup() -> void:
	# Build the sequence_to_spell dictionary for quick lookup of spells based on their sequences.
	sequence_to_spell.clear()

	if registry == null:
		return

	for spell in registry.get_registered_spells():
		_add_spell_mapping(spell)


func _add_spell_mapping(spell: SpellDefinition) -> void:
	if spell == null:
		return

	var sequence_key := _convert_sequence_to_key(spell.sequence)
	if sequence_to_spell.has(sequence_key):
		var existing_spell := sequence_to_spell[sequence_key]
		push_error(
			"SequenceCaster: Duplicate sequence found for spells '%s' and '%s'." % [
				existing_spell.display_name,
				spell.display_name,
			]
		)
		return

	sequence_to_spell[sequence_key] = spell


func _convert_sequence_to_key(sequence: Array[StringName]) -> StringName:
	# Convert the sequence array to a string key for dictionary lookup.
	var parts := PackedStringArray()

	for token in sequence:
		parts.append(String(token))

	return StringName("+".join(parts))


func _add_token_to_sequence(token: StringName) -> void:
	if current_sequence.size() >= max_sequence_length:
		push_warning("SequenceCaster::_add_token_to_sequence() - Maximum sequence length exceeded.")
		sequence_failed.emit(current_sequence, "max_length_exceeded")
		clear_sequence()
		return

	current_sequence.append(token)

	# Reset the timeout timer whenever a new token is added.
	timeout_timer.start(input_timeout)

	sequence_changed.emit(current_sequence)


func _create_spell_context() -> SpellContext:
	var context := SpellContext.new()

	context.caster = caster
	context.effect_parent = effect_parent
	context.origin = spell_origin.global_position
	context.direction = caster.facing_direction.normalized()
	context.aim_direction = context.direction
	if projectile_aim != null:
		context.aim_direction = projectile_aim.get_direction(context.direction)
	context.target_position = spell_origin.global_position + context.direction * 1000.0  # Arbitrary distance for targeting

	return context


func _on_timeout() -> void:
	push_warning("SequenceCaster::_on_timeout() - Input sequence timed out.")
	clear_sequence()


func _on_spell_rejected(_spell: SpellDefinition, reason: StringName) -> void:
	sequence_failed.emit(current_sequence.duplicate(), reason)


func _on_spell_registered(spell: SpellDefinition) -> void:
	_add_spell_mapping(spell)


func _on_spell_unregistered(spell: SpellDefinition) -> void:
	if spell == null:
		return

	var sequence_key := _convert_sequence_to_key(spell.sequence)
	var mapped_spell := sequence_to_spell.get(sequence_key) as SpellDefinition
	if mapped_spell != null and mapped_spell.id == spell.id:
		sequence_to_spell.erase(sequence_key)
