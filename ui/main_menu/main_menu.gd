extends Node2D

const GAME_SCENE := "res://Main.tscn"

@onready var continue_button: Button = $ButtonManager/Continue
@onready var start_button: Button = $ButtonManager/Start
@onready var quit_button: Button = $ButtonManager/Quit
@onready var confirm_new_game: Control = $ConfirmLayer/ConfirmNewGame
@onready var cancel_new_game_button: Button = $ConfirmLayer/ConfirmNewGame/Center/Panel/Content/Buttons/CancelNewGame
@onready var confirm_new_game_button: Button = $ConfirmLayer/ConfirmNewGame/Center/Panel/Content/Buttons/ConfirmNewGameButton


func _ready() -> void:
	cancel_new_game_button.pressed.connect(close_new_game_confirmation)
	confirm_new_game_button.pressed.connect(start_new_game)

	if SaveGame.has_save():
		_show_continue()
	else:
		start_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not confirm_new_game.visible:
		return

	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close_new_game_confirmation()


func is_confirming_new_game() -> bool:
	return confirm_new_game.visible


## Starts over: deletes the save and resets Stardust before loading the game.
func start_new_game() -> void:
	SaveGame.delete_save()
	CoinManager.set_coins(0)
	get_tree().change_scene_to_file(GAME_SCENE)


func close_new_game_confirmation() -> void:
	confirm_new_game.hide()
	start_button.grab_focus()


func _show_continue() -> void:
	continue_button.show()

	# Wrap keyboard/controller focus through Continue while it is visible.
	continue_button.focus_neighbor_top = continue_button.get_path_to(quit_button)
	continue_button.focus_neighbor_bottom = continue_button.get_path_to(start_button)
	start_button.focus_neighbor_top = start_button.get_path_to(continue_button)
	quit_button.focus_neighbor_bottom = quit_button.get_path_to(continue_button)

	continue_button.grab_focus()


func _on_continue_pressed() -> void:
	# Main loads the save on startup.
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_start_pressed() -> void:
	# Never wipe a save without asking.
	if SaveGame.has_save():
		confirm_new_game.show()
		cancel_new_game_button.grab_focus()
		return

	start_new_game()


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu/Options.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
