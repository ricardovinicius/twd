class_name OptionsMenu
extends Control

## Main-menu Options screen: hosts the shared OptionsPanel and returns to the
## main menu. Settings are saved when the screen closes.

const MAIN_MENU_SCENE := "res://ui/main_menu/MainMenu.tscn"

@onready var options_panel: OptionsPanel = %OptionsPanel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(close)
	options_panel.focus_first()


func _exit_tree() -> void:
	Settings.save_settings()


func _unhandled_input(event: InputEvent) -> void:
	if options_panel.is_capturing():
		return

	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
