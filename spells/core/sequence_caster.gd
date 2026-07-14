# This class is responsible for managing the casting of spells in a sequence. 
# It buffers the input sequences and invokes the appropriate spell effects based on the defined sequence 
# in the SpellDefinition resource.

class_name SequenceCaster
extends Node

signal sequence_changed(new_sequence: Array[StringName])
signal sequence_failed(sequence: Array[StringName], reason: StringName)
signal spell_selected(spell: SpellDefinition)

@export var input_timeout: float = 5.0
@export var max_sequence_length: int = 5

# SpellDefinition resources for the spells that can be cast in sequence.
# TODO: Consider using a more dynamic way to manage available spells, 
# because they could change based on the player's level, class, or other factors.

# TODO: Consider using a better approach to manage the available spells, such as a SpellRegistry or a SpellManager
@export var available_spells: Array[SpellDefinition] = []

@export var caster: CharacterBody2D
@export var spell_origin: Marker2D
@export var effect_parent: Node

@onready var timeout_timer: Timer = $TimeoutTimer
@onready var spell_invoker: SpellInvoker = $"../SpellInvoker" # Maybe I should use a signal to connect 
																# the invoker instead of hardcoding the path?

var current_sequence: Array[StringName] = []

# Maps sequences strings to their corresponding SpellDefinition for quick lookup.
var sequence_to_spell: Dictionary[StringName, SpellDefinition] = {}


func _ready() -> void:
	timeout_timer.one_shot = true
	timeout_timer.timeout.connect(_on_timeout)

	_register_spells()


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
		return  # Ignore other inputs
	
	get_viewport().set_input_as_handled()  # TODO: Mark the input as handled to prevent further processing?


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

	if spell == null:
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


func _register_spells() -> void:
	# Build the sequence_to_spell dictionary for quick lookup of spells based on their sequences.
	sequence_to_spell.clear()

	for spell in available_spells:
		var sequence_key := _convert_sequence_to_key(spell.sequence)
		
		if sequence_to_spell.has(sequence_key):
			push_error("SequenceCaster::_register_spells() - Duplicate sequence found for spells: %s and %s" % [sequence_to_spell[sequence_key].display_name, spell.display_name])
		else:
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
	context.direction = caster.facing_direction.normalized()  # Assuming the character has a facing_direction property
	context.target_position = spell_origin.global_position + context.direction * 1000.0  # Arbitrary distance for targeting

	return context


func _on_timeout() -> void:
	push_warning("SequenceCaster::_on_timeout() - Input sequence timed out.")
	clear_sequence()
