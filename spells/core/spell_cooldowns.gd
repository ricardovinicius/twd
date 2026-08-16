class_name SpellCooldowns
extends Node

signal cooldown_started(spell: SpellDefinition, duration: float)
signal cooldown_finished(spell_id: StringName)

var _ends_at_msec: Dictionary[StringName, int] = {}


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()

	for spell_id in _ends_at_msec.keys():
		if now >= _ends_at_msec[spell_id]:
			_ends_at_msec.erase(spell_id)
			cooldown_finished.emit(spell_id)

	if _ends_at_msec.is_empty():
		set_process(false)


func is_ready(spell: SpellDefinition) -> bool:
	return spell != null and get_remaining(spell.id) <= 0.0


func start(spell: SpellDefinition) -> void:
	if spell == null or spell.cooldown <= 0.0:
		return

	_ends_at_msec[spell.id] = Time.get_ticks_msec() + ceili(spell.cooldown * 1000.0)
	set_process(true)
	cooldown_started.emit(spell, spell.cooldown)


func get_remaining(spell_id: StringName) -> float:
	if not _ends_at_msec.has(spell_id):
		return 0.0

	var remaining_msec: int = _ends_at_msec[spell_id] - Time.get_ticks_msec()

	if remaining_msec <= 0:
		_ends_at_msec.erase(spell_id)
		cooldown_finished.emit(spell_id)

		if _ends_at_msec.is_empty():
			set_process(false)

		return 0.0

	return remaining_msec / 1000.0
