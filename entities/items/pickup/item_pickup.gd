extends Area2D

@export var item_definition: ItemDefinition
@export var amount: int = 1

var _player_inside: CharacterBody2D = null


func _ready() -> void:
	PersistentPickup.register(self)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.has_method("collect_item"):
		return

	_player_inside = body


func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_player_inside):
		return

	if event.is_action_pressed("interaction"):
		if _player_inside.collect_item(item_definition, amount):
			SaveGame.mark_collected(self)
			queue_free()
