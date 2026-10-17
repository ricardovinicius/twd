class_name PauseMenu
extends Control

## Tabbed in-game menu opened with Pause (Esc / Start). Tabs: Inventory,
## Spells, Settings, and Quit, switched with menu_tab_prev / menu_tab_next
## (Q / E, LB / RB) or by clicking. Gameplay state is read and changed only
## through the owning components' public APIs.

signal tab_changed(index: int)

enum Tab { INVENTORY, SPELLS, SETTINGS, QUIT }

const MAIN_MENU_SCENE := "res://ui/main_menu/MainMenu.tscn"
const POSITIVE_COLOR := Color(0.35, 0.72, 1.0)
const NEGATIVE_COLOR := Color(1.0, 0.38, 0.38)
const NEUTRAL_COLOR := Color(1.0, 1.0, 1.0)
const DIM_COLOR := Color(1.0, 1.0, 1.0, 0.45)
const ELEMENTS: Array[String] = ["arc", "san", "col", "fle", "mel"]

@export var spell_registry: SpellRegistry
@export var equipment: Equipment
@export var stats: PlayerStats
@export var health: Health
@export var inventory: Inventory
@export var bestiary: Bestiary

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var tab_buttons: Array[Button] = [%InventoryTab, %SpellsTab, %SettingsTab, %QuitTab]
@onready var pages: Array[Control] = [%InventoryPage, %SpellsPage, %SettingsPage, %QuitPage]

@onready var artifact_slots: Array[Button] = [%ArtifactSlot0, %ArtifactSlot1, %ArtifactSlot2]
@onready var channeler_slot: Button = %ChannelerSlot
@onready var stats_grid: GridContainer = %StatsGrid
@onready var chains_button: Button = %ChainsButton
@onready var general_items_button: Button = %GeneralItemsButton
@onready var monster_guide_button: Button = %MonsterGuideButton

@onready var overlay: PanelContainer = %InventoryOverlay
@onready var overlay_title: Label = %OverlayTitle
@onready var overlay_list: VBoxContainer = %OverlayList
@onready var overlay_detail: VBoxContainer = %OverlayDetail
@onready var overlay_back_button: Button = %OverlayBackButton

@onready var spell_list: VBoxContainer = %SpellList
@onready var spell_icon: TextureRect = %SpellIcon
@onready var spell_name_label: Label = %SpellNameLabel
@onready var spell_status_label: Label = %SpellStatusLabel
@onready var spell_keys_label: Label = %SpellKeysLabel
@onready var spell_cooldown_label: Label = %SpellCooldownLabel
@onready var spell_effect_label: Label = %SpellEffectLabel
@onready var spell_registry_button: Button = %SpellRegistryButton
@onready var spell_registry_window: PanelContainer = %SpellRegistryWindow
@onready var spell_registry_debug_ui: SpellRegistryDebugUI = %SpellRegistryDebugUI
@onready var close_spell_registry_button: Button = %CloseSpellRegistry

@onready var options_panel: OptionsPanel = %OptionsPanel

@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_game_button: Button = %QuitGameButton

var current_tab: int = Tab.INVENTORY

var _is_transitioning: bool = false
var _pending_slot_index: int = -1
var _spell_buttons: Dictionary[StringName, Button] = {}
var _stat_value_labels: Dictionary[String, Label] = {}


func _ready() -> void:
	visible = false
	overlay.visible = false
	spell_registry_window.visible = false
	spell_registry_button.visible = OS.is_debug_build()

	for i in tab_buttons.size():
		tab_buttons[i].pressed.connect(select_tab.bind(i))

	for i in artifact_slots.size():
		artifact_slots[i].pressed.connect(open_item_picker.bind(i))

	chains_button.pressed.connect(open_chains)
	general_items_button.pressed.connect(open_general_items)
	monster_guide_button.pressed.connect(open_monster_guide)
	overlay_back_button.pressed.connect(close_overlay)

	spell_registry_button.pressed.connect(_on_spell_registry_pressed)
	close_spell_registry_button.pressed.connect(close_spell_registry_window)

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_quit_pressed)
	quit_game_button.pressed.connect(_on_quit_game_pressed)

	_build_stat_rows()
	spell_registry_debug_ui.setup(spell_registry)
	_show_tab(current_tab)


func setup(
	player_registry: SpellRegistry,
	player_equipment: Equipment,
	player_stats: PlayerStats,
	player_health: Health,
	player_inventory: Inventory
) -> void:
	spell_registry = player_registry
	equipment = player_equipment
	stats = player_stats
	health = player_health
	inventory = player_inventory
	spell_registry_debug_ui.setup(spell_registry)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_on_pause_pressed()
		return

	if not visible or _is_transitioning or overlay.visible or spell_registry_window.visible:
		return

	if event.is_action_pressed(&"menu_tab_prev"):
		get_viewport().set_input_as_handled()
		select_tab(wrapi(current_tab - 1, 0, pages.size()))
	elif event.is_action_pressed(&"menu_tab_next"):
		get_viewport().set_input_as_handled()
		select_tab(wrapi(current_tab + 1, 0, pages.size()))


func _on_pause_pressed() -> void:
	if get_tree().paused and visible:
		if overlay.visible:
			close_overlay()
			return

		if spell_registry_window.visible:
			close_spell_registry_window()
			return

	_toggle_pause()


func _toggle_pause() -> void:
	if _is_transitioning:
		return

	if get_tree().paused:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	visible = true
	get_tree().paused = true

	overlay.visible = false
	spell_registry_window.visible = false
	select_tab(Tab.INVENTORY)
	animation_player.play(&"blur")


func resume_game() -> void:
	_is_transitioning = true
	Settings.save_settings()
	get_tree().paused = false
	animation_player.play_backwards(&"blur")
	await animation_player.animation_finished
	visible = false
	_is_transitioning = false


func select_tab(index: int) -> void:
	if index < 0 or index >= pages.size():
		return

	if options_panel.is_capturing():
		options_panel.cancel_capture()

	overlay.visible = false
	spell_registry_window.visible = false
	current_tab = index
	_show_tab(index)
	_refresh_tab(index)
	_focus_tab(index)
	tab_changed.emit(index)


func _show_tab(index: int) -> void:
	for i in pages.size():
		pages[i].visible = i == index
		tab_buttons[i].set_pressed_no_signal(i == index)


func _refresh_tab(index: int) -> void:
	match index:
		Tab.INVENTORY:
			refresh_inventory()
		Tab.SPELLS:
			refresh_spells()
		Tab.SETTINGS:
			options_panel.refresh()


func _focus_tab(index: int) -> void:
	match index:
		Tab.INVENTORY:
			artifact_slots[0].grab_focus()
		Tab.SPELLS:
			_focus_first_spell()
		Tab.SETTINGS:
			options_panel.focus_first()
		Tab.QUIT:
			resume_button.grab_focus()


# Inventory -----------------------------------------------------------------


func refresh_inventory() -> void:
	if not _has_inventory_dependencies():
		return

	if not equipment.equipment_changed.is_connected(_on_equipment_changed):
		equipment.equipment_changed.connect(_on_equipment_changed)

	for i in artifact_slots.size():
		var item := equipment.get_item(i)
		var slot := artifact_slots[i]

		slot.text = item.display_name if item != null else "Vazio"
		slot.icon = item.icon if item != null else null

	channeler_slot.text = "Vazio"
	_refresh_stats()


func get_stat_text(stat: String) -> String:
	var label := _stat_value_labels.get(stat) as Label
	return label.text if label != null else ""


func _build_stat_rows() -> void:
	var rows: Array[Array] = [
		["hp", "HP"],
		["shield", "ESCUDO"],
		["insight", "INSIGHT"],
	]

	for element in ELEMENTS:
		rows.append(["dam_" + element, "Dam. " + element.to_upper()])

	for element in ELEMENTS:
		rows.append(["res_" + element, "Res. " + element.to_upper()])

	rows.append(["weight", "PESO"])
	rows.append(["move_speed", "MOVESPEED"])

	for row in rows:
		var name_label := Label.new()
		name_label.text = row[1]
		name_label.custom_minimum_size = Vector2(150.0, 0.0)
		stats_grid.add_child(name_label)

		var value_label := Label.new()
		value_label.text = ":"
		stats_grid.add_child(value_label)

		_stat_value_labels[row[0]] = value_label


func _refresh_stats() -> void:
	var totals := equipment.get_total_bonus()

	_set_stat("hp", "%d/%d" % [roundi(health.current), roundi(health.maximum)], NEUTRAL_COLOR)
	_set_stat("shield", "%d/%d" % [roundi(health.shield_current), roundi(health.shield_maximum)], NEUTRAL_COLOR)
	_set_stat("insight", str(stats.base_insight + totals.insight), NEUTRAL_COLOR)

	for element in ELEMENTS:
		# Elemental damage bonuses do not exist yet; shown as +0 placeholders.
		_set_signed_stat("dam_" + element, 0.0)

		var resistance: float = stats.get("base_resistance_" + element) + totals["resistance_" + element]
		_set_signed_stat("res_" + element, resistance)

	_set_stat("weight", _format_number(equipment.get_final_weight()), NEUTRAL_COLOR)
	_set_signed_stat("move_speed", totals.move_speed)


func _set_signed_stat(stat: String, value: float) -> void:
	var color := NEUTRAL_COLOR

	if value > 0.0:
		color = POSITIVE_COLOR
	elif value < 0.0:
		color = NEGATIVE_COLOR

	var prefix := "+" if value >= 0.0 else ""
	_set_stat(stat, prefix + _format_number(value), color)


func _set_stat(stat: String, text: String, color: Color) -> void:
	var label := _stat_value_labels.get(stat) as Label

	if label == null:
		return

	label.text = text
	label.add_theme_color_override(&"font_color", color)


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))

	return String.num(value, 2)


func _has_inventory_dependencies() -> bool:
	return equipment != null and stats != null and health != null and inventory != null


func _on_equipment_changed(_slot_index: int, _item: ItemDefinition) -> void:
	if visible and current_tab == Tab.INVENTORY:
		refresh_inventory()


## Opens the list of inventory items to equip in an artifact slot.
func open_item_picker(slot_index: int) -> void:
	if not _has_inventory_dependencies():
		return

	_pending_slot_index = slot_index
	_open_overlay("Artefato %d" % (slot_index + 1))

	var items := inventory.get_items()

	for item: ItemDefinition in items:
		var button := _add_overlay_button("%s  x%d" % [item.display_name, items[item]], item.icon)
		button.pressed.connect(_on_item_selected.bind(item))

	if equipment.get_item(slot_index) != null:
		var remove_button := _add_overlay_button("Remover artefato", null)
		remove_button.pressed.connect(_on_item_selected.bind(null))

	if items.is_empty():
		_add_overlay_text("Nenhum item no inventário.")

	_focus_overlay()


func _on_item_selected(item: ItemDefinition) -> void:
	if _pending_slot_index == -1 or equipment == null:
		return

	var slot_index := _pending_slot_index

	equipment.equip(slot_index, item)
	close_overlay()
	refresh_inventory()
	artifact_slots[slot_index].grab_focus()


func open_chains() -> void:
	_open_overlay("Correntes")
	_add_overlay_text("Nenhuma corrente encontrada ainda.")
	_focus_overlay()


func open_general_items() -> void:
	_open_overlay("Itens gerais")

	var items := inventory.get_items() if inventory != null else {}

	for item: ItemDefinition in items:
		var row := _add_overlay_button("%s  x%d" % [item.display_name, items[item]], item.icon)
		row.focus_mode = Control.FOCUS_ALL

	if items.is_empty():
		_add_overlay_text("Nenhum item coletado.")

	_focus_overlay()


func open_monster_guide() -> void:
	_open_overlay("Guia dos monstros")

	var entries: Array[MonsterEntry] = bestiary.get_entries() if bestiary != null else []

	for entry in entries:
		var button := _add_overlay_button(entry.display_name, entry.portrait)
		button.focus_entered.connect(_show_monster.bind(entry))
		button.pressed.connect(_show_monster.bind(entry))

	if entries.is_empty():
		_add_overlay_text("Nenhum monstro registrado.")
	else:
		_show_monster(entries[0])

	_focus_overlay()


func _show_monster(entry: MonsterEntry) -> void:
	_clear(overlay_detail)
	overlay_detail.visible = true

	var portrait := _make_portrait(entry.portrait, entry.placeholder_color, Vector2(128.0, 128.0))
	overlay_detail.add_child(portrait)

	var name_label := Label.new()
	name_label.text = entry.display_name
	name_label.add_theme_font_size_override(&"font_size", 26)
	overlay_detail.add_child(name_label)

	for line in [
		"Vida: %d" % roundi(entry.max_health),
		"Dano: %d" % roundi(entry.damage),
		"Stardust: %d" % entry.stardust_drop,
		"Fraqueza: %s" % (entry.weakness if not entry.weakness.is_empty() else "?"),
	]:
		var stat_label := Label.new()
		stat_label.text = line
		overlay_detail.add_child(stat_label)

	var description := Label.new()
	description.text = entry.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(420.0, 0.0)
	overlay_detail.add_child(description)


func close_overlay() -> void:
	var was_item_picker := _pending_slot_index != -1
	var slot_index := _pending_slot_index

	overlay.visible = false
	_pending_slot_index = -1

	if was_item_picker:
		artifact_slots[slot_index].grab_focus()
	else:
		artifact_slots[0].grab_focus()


func _open_overlay(title: String) -> void:
	overlay_title.text = title
	_clear(overlay_list)
	_clear(overlay_detail)
	overlay_detail.visible = false
	overlay.visible = true


func _add_overlay_button(text: String, icon: Texture2D) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(320.0, 40.0)

	if icon != null:
		button.icon = icon
		button.expand_icon = true
		button.add_theme_constant_override(&"icon_max_width", 28)

	overlay_list.add_child(button)
	return button


func _add_overlay_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", DIM_COLOR)
	overlay_list.add_child(label)


func _focus_overlay() -> void:
	for child in overlay_list.get_children():
		if child is Button:
			(child as Button).grab_focus()
			return

	overlay_back_button.grab_focus()


# Spells --------------------------------------------------------------------


func refresh_spells() -> void:
	_clear(spell_list)
	_spell_buttons.clear()

	var spells := _get_all_spells()

	for spell in spells:
		var owned := spell_registry != null and spell_registry.has_spell(spell.id)
		var button := Button.new()

		button.text = spell.display_name if owned else "%s  (bloqueada)" % spell.display_name
		button.icon = spell.icon
		button.expand_icon = true
		button.add_theme_constant_override(&"icon_max_width", 28)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(300.0, 44.0)

		if not owned:
			button.add_theme_color_override(&"font_color", DIM_COLOR)

		button.focus_entered.connect(show_spell.bind(spell))
		button.pressed.connect(show_spell.bind(spell))
		spell_list.add_child(button)
		_spell_buttons[spell.id] = button

	if spells.is_empty():
		var empty := Label.new()
		empty.text = "Nenhuma magia."
		spell_list.add_child(empty)
		_clear_spell_detail()
	else:
		show_spell(spells[0])


## Fills the detail panel: symbol, name, keys, effect, and cooldown.
func show_spell(spell: SpellDefinition) -> void:
	if spell == null:
		_clear_spell_detail()
		return

	var owned := spell_registry != null and spell_registry.has_spell(spell.id)

	spell_icon.texture = spell.icon
	spell_name_label.text = spell.display_name
	spell_status_label.text = "Aprendida" if owned else "Bloqueada: compre em uma bonfire"
	spell_status_label.add_theme_color_override(&"font_color", POSITIVE_COLOR if owned else DIM_COLOR)
	spell_keys_label.text = "Botões:  %s" % Settings.format_sequence(spell.sequence)
	spell_cooldown_label.text = (
		"Cooldown:  %s s" % _format_number(spell.cooldown)
		if spell.cooldown > 0.0
		else "Cooldown:  nenhum"
	)
	spell_effect_label.text = spell.description if not spell.description.is_empty() else "Sem descrição."


func get_spell_button(spell_id: StringName) -> Button:
	return _spell_buttons.get(spell_id) as Button


func _get_all_spells() -> Array[SpellDefinition]:
	if spell_registry == null or spell_registry.database == null:
		return []

	return spell_registry.database.get_spells()


func _clear_spell_detail() -> void:
	spell_icon.texture = null
	spell_name_label.text = ""
	spell_status_label.text = ""
	spell_keys_label.text = ""
	spell_cooldown_label.text = ""
	spell_effect_label.text = ""


func _focus_first_spell() -> void:
	for child in spell_list.get_children():
		if child is Button:
			(child as Button).grab_focus()
			return


func _on_spell_registry_pressed() -> void:
	spell_registry_window.visible = true
	close_spell_registry_button.grab_focus()


func close_spell_registry_window() -> void:
	spell_registry_window.visible = false
	refresh_spells()
	spell_registry_button.grab_focus()


# Quit ----------------------------------------------------------------------


func _on_resume_pressed() -> void:
	resume_game()


func _on_restart_pressed() -> void:
	Settings.save_settings()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	Settings.save_settings()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit_game_pressed() -> void:
	Settings.save_settings()
	get_tree().quit()


# Helpers -------------------------------------------------------------------


func _make_portrait(texture: Texture2D, placeholder: Color, portrait_size: Vector2) -> Control:
	if texture != null:
		var texture_rect := TextureRect.new()
		texture_rect.texture = texture
		texture_rect.custom_minimum_size = portrait_size
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		return texture_rect

	var swatch := ColorRect.new()
	swatch.color = placeholder
	swatch.custom_minimum_size = portrait_size * 0.6
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return swatch


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
