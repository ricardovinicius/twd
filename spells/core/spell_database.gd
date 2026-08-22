class_name SpellDatabase
extends Resource

@export var spells: Array[SpellDefinition] = []:
	set(value):
		spells = value
		_lookup_dirty = true

var _spells_by_id: Dictionary[StringName, SpellDefinition] = {}
var _valid_spells: Array[SpellDefinition] = []
var _lookup_dirty: bool = true


func get_spell(spell_id: StringName) -> SpellDefinition:
	_ensure_lookup()
	return _spells_by_id.get(spell_id) as SpellDefinition


func has_spell(spell_id: StringName) -> bool:
	_ensure_lookup()
	return _spells_by_id.has(spell_id)


func get_spells() -> Array[SpellDefinition]:
	_ensure_lookup()
	return _valid_spells.duplicate()


func rebuild() -> void:
	_lookup_dirty = true
	_ensure_lookup()


func _ensure_lookup() -> void:
	if not _lookup_dirty:
		return

	_lookup_dirty = false
	_spells_by_id.clear()
	_valid_spells.clear()

	var spells_by_sequence: Dictionary[StringName, SpellDefinition] = {}
	for spell in spells:
		if not _is_valid_definition(spell):
			continue

		if _spells_by_id.has(spell.id):
			var existing_id_spell := _spells_by_id[spell.id]
			push_error(
				"SpellDatabase: Duplicate spell ID '%s' for '%s' and '%s'." % [
					spell.id,
					existing_id_spell.display_name,
					spell.display_name,
				]
			)
			continue

		var sequence_key := _sequence_to_key(spell.sequence)
		if spells_by_sequence.has(sequence_key):
			var existing_sequence_spell := spells_by_sequence[sequence_key]
			push_error(
				"SpellDatabase: Duplicate sequence for '%s' and '%s'." % [
					existing_sequence_spell.display_name,
					spell.display_name,
				]
			)
			continue

		_spells_by_id[spell.id] = spell
		spells_by_sequence[sequence_key] = spell
		_valid_spells.append(spell)


func _is_valid_definition(spell: SpellDefinition) -> bool:
	if spell == null:
		push_error("SpellDatabase: Null spell definitions are not allowed.")
		return false

	if spell.id.is_empty():
		push_error("SpellDatabase: Spell '%s' has an empty ID." % spell.display_name)
		return false

	if spell.sequence.is_empty():
		push_error("SpellDatabase: Spell '%s' has an empty sequence." % spell.display_name)
		return false

	return true


func _sequence_to_key(sequence: Array[StringName]) -> StringName:
	var parts := PackedStringArray()
	for token in sequence:
		parts.append(String(token))

	return StringName("+".join(parts))
