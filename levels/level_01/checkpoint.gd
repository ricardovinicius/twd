extends Area2D

const CheckpointMenu := preload("res://ui/checkpoint_menu/checkpoint_menu.tscn")

var _player_inside: CharacterBody2D = null


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.has_method("set_checkpoint"):
		return

	_player_inside = body
	print("PLAYER ENTROU NO CHECKPOINT")


func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null
		print("PLAYER SAIU DO CHECKPOINT")


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside == null:
		return

	if event.is_action_pressed("interaction"):
		print("TECLA S PRESSIONADA")

		var checkpoint_position: Vector2 = $Marker2D.global_position
		var menu := CheckpointMenu.instantiate()
		get_tree().root.add_child(menu)
		menu.open(_player_inside, checkpoint_position)
