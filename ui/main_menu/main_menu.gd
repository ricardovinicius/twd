extends Node2D

const GAME_SCENE := "res://Main.tscn"

@onready var continue_button: Button = $ButtonManager/Continue
@onready var start_button: Button = $ButtonManager/Start
@onready var quit_button: Button = $ButtonManager/Quit


func _ready() -> void:
	if SaveGame.has_save():
		_show_continue()
	else:
		start_button.grab_focus()


func _show_continue() -> void:
	continue_button.show()
	start_button.text = "New Game"

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
	SaveGame.delete_save()
	CoinManager.set_coins(0)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu/Options.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
