extends Node2D


func _ready() -> void:
	$ButtonManager/Start.grab_focus()


func _on_start_pressed():
	get_tree().change_scene_to_file("res://Main.tscn")


func _on_options_pressed():
	get_tree().change_scene_to_file("res://ui/main_menu/Options.tscn")


func _on_quit_pressed():
	get_tree().quit()
