extends Node

## Persists the player's progress to disk when they rest at a checkpoint and
## restores it when the game starts. Gameplay state stays with its owners;
## this autoload only reads and writes it through their public APIs.

signal saved
signal loaded

const SAVE_PATH := "user://savegame.cfg"
const SAVE_VERSION := 1

const SECTION_META := "meta"
const SECTION_PLAYER := "player"

## Overridable so tests can write to an isolated file.
var save_path: String = SAVE_PATH


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func delete_save() -> void:
	if not has_save():
		return

	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	if error != OK:
		push_error("SaveGame: Could not delete '%s' (error %d)." % [save_path, error])


## Writes the player's checkpoint, Stardust, spells, inventory, and equipment.
func save_player(player: Node) -> bool:
	if not _is_saveable_player(player):
		push_error("SaveGame: Player does not expose the save API.")
		return false

	if not player.has_checkpoint():
		push_warning("SaveGame: Player has no checkpoint; nothing was saved.")
		return false

	var file := ConfigFile.new()

	file.set_value(SECTION_META, "version", SAVE_VERSION)
	file.set_value(SECTION_PLAYER, "checkpoint_position", player.get_checkpoint_position())
	file.set_value(SECTION_PLAYER, "stardust", CoinManager.coins)
	file.set_value(SECTION_PLAYER, "spells", _capture_spells(player.get_spell_registry()))
	file.set_value(SECTION_PLAYER, "inventory", _capture_inventory(player.get_inventory()))
	file.set_value(SECTION_PLAYER, "equipment", _capture_equipment(player.get_equipment()))

	var error := file.save(save_path)

	if error != OK:
		push_error("SaveGame: Could not write '%s' (error %d)." % [save_path, error])
		return false

	saved.emit()
	return true


## Restores a saved game into a freshly loaded player and moves them to the
## saved checkpoint. Returns false when there is no valid save.
func load_into_player(player: Node) -> bool:
	if not has_save():
		return false

	if not _is_saveable_player(player):
		push_error("SaveGame: Player does not expose the save API.")
		return false

	var file := ConfigFile.new()
	var error := file.load(save_path)

	if error != OK:
		push_error("SaveGame: Could not read '%s' (error %d)." % [save_path, error])
		return false

	var version: int = file.get_value(SECTION_META, "version", 0)

	if version != SAVE_VERSION:
		push_warning("SaveGame: Ignoring save with unsupported version %d." % version)
		return false

	if not file.has_section_key(SECTION_PLAYER, "checkpoint_position"):
		push_warning("SaveGame: Save has no checkpoint; ignoring it.")
		return false

	CoinManager.set_coins(file.get_value(SECTION_PLAYER, "stardust", 0))
	_restore_spells(player.get_spell_registry(), file.get_value(SECTION_PLAYER, "spells", []))
	_restore_inventory(player.get_inventory(), file.get_value(SECTION_PLAYER, "inventory", {}))
	_restore_equipment(player.get_equipment(), file.get_value(SECTION_PLAYER, "equipment", []))

	player.set_checkpoint(file.get_value(SECTION_PLAYER, "checkpoint_position"))
	player.spawn_player()

	loaded.emit()
	return true


func _is_saveable_player(player: Node) -> bool:
	if not is_instance_valid(player):
		return false

	for method in [
		&"has_checkpoint",
		&"get_checkpoint_position",
		&"set_checkpoint",
		&"spawn_player",
		&"get_spell_registry",
		&"get_inventory",
		&"get_equipment",
	]:
		if not player.has_method(method):
			return false

	return true


func _capture_spells(registry: SpellRegistry) -> Array[String]:
	var spell_ids: Array[String] = []

	if registry == null:
		return spell_ids

	for spell in registry.get_registered_spells():
		spell_ids.append(String(spell.id))

	return spell_ids


func _capture_inventory(inventory: Inventory) -> Dictionary:
	var quantities := {}

	if inventory == null:
		return quantities

	var items := inventory.get_items()

	for item: ItemDefinition in items:
		if item.resource_path.is_empty():
			push_warning("SaveGame: Item '%s' has no resource path and was not saved." % item.id)
			continue

		quantities[item.resource_path] = items[item]

	return quantities


func _capture_equipment(equipment: Equipment) -> Array[String]:
	var slots: Array[String] = []

	if equipment == null:
		return slots

	for slot_index in Equipment.SLOT_COUNT:
		var item := equipment.get_item(slot_index)
		slots.append(item.resource_path if item != null else "")

	return slots


func _restore_spells(registry: SpellRegistry, spell_ids: Array) -> void:
	if registry == null:
		return

	for spell_id in spell_ids:
		if not registry.has_spell(StringName(spell_id)):
			registry.register_spell(StringName(spell_id))


func _restore_inventory(inventory: Inventory, quantities: Dictionary) -> void:
	if inventory == null:
		return

	for item_path in quantities:
		var item := _load_item(item_path)
		var missing := int(quantities[item_path]) - inventory.get_quantity(item) if item != null else 0

		if missing > 0:
			inventory.add_item(item, missing)


func _restore_equipment(equipment: Equipment, slot_paths: Array) -> void:
	if equipment == null:
		return

	for slot_index in mini(slot_paths.size(), Equipment.SLOT_COUNT):
		var item_path: String = slot_paths[slot_index]
		var item := _load_item(item_path) if not item_path.is_empty() else null

		equipment.equip(slot_index, item)


func _load_item(item_path: String) -> ItemDefinition:
	if not ResourceLoader.exists(item_path):
		push_warning("SaveGame: Saved item '%s' no longer exists." % item_path)
		return null

	var item := load(item_path) as ItemDefinition

	if item == null:
		push_warning("SaveGame: Saved resource '%s' is not an item." % item_path)

	return item
