extends Control


var is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Select"):
		get_viewport().set_input_as_handled()

		if is_open:
			close_select()
		else:
			open_select()


func open_select() -> void:
	is_open = true
	visible = true


func close_select() -> void:
	is_open = false
	visible = false


func _on_button_pressed() -> void:
	close_select()
