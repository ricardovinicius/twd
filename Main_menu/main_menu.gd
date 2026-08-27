extends Node2D


func _ready() -> void:
	$button_manager/Start.grab_focus()


func _on_start_pressed():
	get_tree().change_scene_to_file("res://Main.tscn")


func _on_options_pressed():
	get_tree().change_scene_to_file("res://Main_menu/options.tscn")


func _on_quit_pressed():
	get_tree().quit()
