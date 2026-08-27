extends CanvasLayer

var _player: Node = null
var _checkpoint_position: Vector2 = Vector2.ZERO


func open(player: Node, checkpoint_position: Vector2) -> void:
	_player = player
	_checkpoint_position = checkpoint_position
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	show()
	$menu_holder/save_btn.grab_focus()


func _on_save_btn_pressed() -> void:
	if is_instance_valid(_player):
		_player.set_checkpoint(_checkpoint_position)
	_close()


func _on_back_btn_pressed() -> void:
	_close()


func _close() -> void:
	get_tree().paused = false
	queue_free()
