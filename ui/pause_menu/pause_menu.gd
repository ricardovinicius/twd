class_name PauseMenu
extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var resume_button: Button = $PanelContainer/VBoxContainer/Resume

var _is_transitioning: bool = false


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return

	get_viewport().set_input_as_handled()
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


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()
