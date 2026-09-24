class_name PauseMenu
extends Control

@export var spell_registry: SpellRegistry

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var main_menu_panel: PanelContainer = $PanelContainer
@onready var resume_button: Button = %Resume
@onready var spell_registry_button: Button = %SpellRegistryButton
@onready var spell_registry_window: PanelContainer = %SpellRegistryWindow
@onready var spell_registry_debug_ui: SpellRegistryDebugUI = %SpellRegistryDebugUI
@onready var close_spell_registry_button: Button = %CloseSpellRegistry

@onready var equipment_button: Button = %EquipmentButton
@onready var equipment_window: PanelContainer = %EquipmentWindow
@onready var equipment_content: VBoxContainer = %EquipmentContent
@onready var close_equipment_button: Button = %CloseEquipmentButton
@onready var item_list_window: PanelContainer = %ItemListWindow
@onready var equipment_panel: EquipmentPanel = %EquipmentWindow

@onready var item_list_container: VBoxContainer = %ItemListContainer
@onready var close_item_list_button: Button = %CloseItemListButton

var _is_transitioning: bool = false
var _pending_slot_index: int = -1


func _ready() -> void:
	visible = false
	spell_registry_window.visible = false
	equipment_window.visible = false
	item_list_window.visible = false
	spell_registry_debug_ui.setup(spell_registry)

	equipment_panel.slot_pressed.connect(_on_equipment_slot_pressed)
	close_item_list_button.pressed.connect(close_item_list)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return

	get_viewport().set_input_as_handled()

	if get_tree().paused:
		if item_list_window.visible:
			close_item_list()
			return

		if equipment_window.visible:
			close_equipment_window()
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
	_show_main_menu()
	visible = true

	get_tree().paused = true

	animation_player.play(&"blur")
	resume_button.grab_focus()


func resume_game() -> void:
	_is_transitioning = true
	get_tree().paused = false
	animation_player.play_backwards(&"blur")
	await animation_player.animation_finished
	visible = false
	_is_transitioning = false


func _on_resume_pressed() -> void:
	resume_game()


func _on_spell_registry_pressed() -> void:
	main_menu_panel.visible = false
	spell_registry_window.visible = true
	close_spell_registry_button.grab_focus()


func close_spell_registry_window() -> void:
	spell_registry_window.visible = false
	main_menu_panel.visible = true
	spell_registry_button.grab_focus()


func _on_equipment_pressed() -> void:
	main_menu_panel.visible = false
	equipment_window.visible = true
	equipment_content.visible = true
	item_list_window.visible = false
	close_equipment_button.grab_focus()
	equipment_panel.refresh()


func close_equipment_window() -> void:
	item_list_window.visible = false
	equipment_window.visible = false
	main_menu_panel.visible = true
	equipment_button.grab_focus()


func _on_equipment_slot_pressed(slot_index: int) -> void:
	open_item_list(slot_index)


func open_item_list(slot_index: int) -> void:
	_pending_slot_index = slot_index
	equipment_content.visible = false
	item_list_window.visible = true
	_populate_item_list()
	close_item_list_button.grab_focus()


func close_item_list() -> void:
	item_list_window.visible = false
	equipment_content.visible = true
	_pending_slot_index = -1


func _on_item_selected(item: ItemDefinition) -> void:
	if _pending_slot_index == -1:
		return

	equipment_panel.equipment.equip(_pending_slot_index, item)
	close_item_list()


func _populate_item_list() -> void:
	for child in item_list_container.get_children():
		child.queue_free()

	var items := equipment_panel.inventory.get_items()

	if items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Nenhum item no inventário."
		item_list_container.add_child(empty_label)
		return

	for item: ItemDefinition in items:
		var quantity: int = items[item]
		var item_button := Button.new()
		item_button.text = "%s (x%d)" % [item.display_name, quantity]

		if item.icon:
			item_button.icon = item.icon

		item_button.pressed.connect(_on_item_selected.bind(item))
		item_list_container.add_child(item_button)


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Main_menu/main_menu.tscn")


func _show_main_menu() -> void:
	spell_registry_window.visible = false
	equipment_window.visible = false
	item_list_window.visible = false
	main_menu_panel.visible = true
