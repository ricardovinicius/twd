class_name SpellRegistry
extends Node

signal spell_registered(spell: SpellDefinition)
signal spell_unregistered(spell: SpellDefinition)

@export var database: SpellDatabase
@export var initial_spell_ids: Array[StringName] = []

var _registered_spell_ids: Array[StringName] = []
var _registered_spell_lookup: Dictionary[StringName, bool] = {}


func _ready() -> void:
	if database == null:
		push_error("SpellRegistry: SpellDatabase is not assigned.")
		return

	for spell_id in initial_spell_ids:
		_register_spell(spell_id, false)


func register_spell(spell_id: StringName) -> bool:
	return _register_spell(spell_id, true)


func unregister_spell(spell_id: StringName) -> bool:
	if not _registered_spell_lookup.has(spell_id):
		return false

	var spell := database.get_spell(spell_id) if database != null else null
	_registered_spell_lookup.erase(spell_id)
	_registered_spell_ids.erase(spell_id)

	if spell != null:
		spell_unregistered.emit(spell)

	return true


func has_spell(spell_id: StringName) -> bool:
	return _registered_spell_lookup.has(spell_id)


func get_spell(spell_id: StringName) -> SpellDefinition:
	if not has_spell(spell_id) or database == null:
		return null

	return database.get_spell(spell_id)


func get_registered_spells() -> Array[SpellDefinition]:
	var registered_spells: Array[SpellDefinition] = []
	if database == null:
		return registered_spells

	for spell_id in _registered_spell_ids:
		var spell := database.get_spell(spell_id)
		if spell != null:
			registered_spells.append(spell)

	return registered_spells


func _register_spell(spell_id: StringName, emit_change: bool) -> bool:
	if _registered_spell_lookup.has(spell_id):
		return false

	if spell_id.is_empty():
		push_warning("SpellRegistry: Cannot register an empty spell ID.")
		return false

	if database == null:
		push_warning("SpellRegistry: Cannot register '%s' without a SpellDatabase." % spell_id)
		return false

	var spell := database.get_spell(spell_id)
	if spell == null:
		push_warning("SpellRegistry: Spell ID '%s' is not in the database." % spell_id)
		return false

	_registered_spell_lookup[spell_id] = true
	_registered_spell_ids.append(spell_id)
	if emit_change:
		spell_registered.emit(spell)

	return true
