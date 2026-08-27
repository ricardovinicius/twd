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

var _is_transitioning: bool = false


func _ready() -> void:
	visible = false
	spell_registry_window.visible = false
	spell_registry_debug_ui.setup(spell_registry)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return

	get_viewport().set_input_as_handled()
	if get_tree().paused and spell_registry_window.visible:
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


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Main_menu/main_menu.tscn")


func _show_main_menu() -> void:
	spell_registry_window.visible = false
	main_menu_panel.visible = true
