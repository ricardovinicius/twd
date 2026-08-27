class_name Select
extends Control


var is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Select"):
		_toggle_map()


func _toggle_map() -> void:
	if is_open:
		close_map()
	else:
		open_map()


func open_map() -> void:
	is_open = true
	visible = true
	
	get_tree().paused = true


func close_map() -> void:
	is_open = false
	visible = false
	
	get_tree().paused = false
