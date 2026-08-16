class_name CooldownUI
extends Control

const COOLDOWN_ENTRY_SCENE: PackedScene = preload("res://spells/ui/CooldownEntry.tscn")

@onready var cooldown_container: HBoxContainer = %CooldownContainer

var cooldowns: SpellCooldowns
var _entries: Dictionary[StringName, CooldownEntry] = {}


func _ready() -> void:
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	if cooldowns == null:
		return

	for spell_id in _entries.keys():
		var remaining := cooldowns.get_remaining(spell_id)
		var entry := _entries.get(spell_id) as CooldownEntry

		# get_remaining() may finish the cooldown and synchronously remove its entry.
		if entry != null:
			entry.set_remaining(remaining)


func setup(spell_cooldowns: SpellCooldowns) -> void:
	if cooldowns == spell_cooldowns:
		return

	_disconnect_cooldowns()
	_clear_entries()
	cooldowns = spell_cooldowns

	if cooldowns == null:
		push_warning("CooldownUI: SpellCooldowns is not assigned.")
		return

	cooldowns.cooldown_started.connect(_on_cooldown_started)
	cooldowns.cooldown_finished.connect(_on_cooldown_finished)


func get_entry(spell_id: StringName) -> CooldownEntry:
	return _entries.get(spell_id) as CooldownEntry


func _exit_tree() -> void:
	_disconnect_cooldowns()


func _on_cooldown_started(spell: SpellDefinition, duration: float) -> void:
	if spell == null or duration <= 0.0:
		return

	var existing_entry := get_entry(spell.id)
	if existing_entry != null:
		existing_entry.setup(spell, duration)
		return

	var entry := COOLDOWN_ENTRY_SCENE.instantiate() as CooldownEntry
	if entry == null:
		push_error("CooldownUI: CooldownEntry scene root has an unexpected type.")
		return

	cooldown_container.add_child(entry)
	entry.setup(spell, duration)
	_entries[spell.id] = entry
	visible = true
	set_process(true)


func _on_cooldown_finished(spell_id: StringName) -> void:
	var entry := get_entry(spell_id)
	if entry == null:
		return

	_entries.erase(spell_id)
	entry.queue_free()

	if _entries.is_empty():
		visible = false
		set_process(false)


func _disconnect_cooldowns() -> void:
	if cooldowns == null:
		return

	if cooldowns.cooldown_started.is_connected(_on_cooldown_started):
		cooldowns.cooldown_started.disconnect(_on_cooldown_started)
	if cooldowns.cooldown_finished.is_connected(_on_cooldown_finished):
		cooldowns.cooldown_finished.disconnect(_on_cooldown_finished)

	cooldowns = null


func _clear_entries() -> void:
	for entry in _entries.values():
		entry.queue_free()

	_entries.clear()
	visible = false
	set_process(false)
