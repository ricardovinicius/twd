class_name SpellInvoker
extends Node

signal spell_started(spell: SpellDefinition, command: SpellCommand)
signal spell_finished()
signal spell_failed(spell: SpellDefinition, command: SpellCommand, reason: StringName)
signal spell_rejected(spell: SpellDefinition, reason: StringName)

@export var cooldowns: SpellCooldowns


func cast(spell: SpellDefinition, context: SpellContext) -> SpellCommand:
	# Guard clauses
	# ==========================
	if spell == null:
		push_error("SpellInvoker::cast() - spell is null.")
		return null

	if spell.command_scene == null:
		push_error("SpellInvoker::cast() - spell.command_scene is null.")
		return null

	if context == null:
		push_error("SpellInvoker::cast() - context is null.")
		return null

	if spell.cooldown > 0.0 and cooldowns == null:
		push_error("SpellInvoker::cast() - cooldowns is not assigned.")
		spell_rejected.emit(spell, &"missing_cooldown_component")
		return null

	if cooldowns != null and not cooldowns.is_ready(spell):
		spell_rejected.emit(spell, &"cooldown_active")
		return null

	var instance := spell.command_scene.instantiate()
	var command := instance as SpellCommand

	if command == null:
		instance.queue_free()
		push_error("SpellInvoker::cast() - spell.command_scene is not a SpellCommand.")
		return null

	# End Guard clauses
	# ==========================

	# Add the command instance to the scene tree, either under the effect_parent or this node
	var parent := context.effect_parent if context.effect_parent != null else self

	parent.add_child(instance)

	# Connect signals to handle command completion and failure
	command.finished.connect(_on_command_finished.bind(), CONNECT_ONE_SHOT)
	command.failed.connect(_on_command_failed.bind(spell), CONNECT_ONE_SHOT)

	# A cast enters cooldown as soon as it is accepted, preventing another cast
	# while an asynchronous command is still executing.
	if cooldowns != null:
		cooldowns.start(spell)

	# Emit the spell_started signal and execute the command
	spell_started.emit(spell, command)
	command.execute(context)

	return command


func _on_command_finished() -> void:
	spell_finished.emit()

func _on_command_failed(spell: SpellDefinition, command: SpellCommand, reason: StringName) -> void:
	spell_failed.emit(spell, command, reason)
