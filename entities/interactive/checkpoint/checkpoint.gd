class_name Checkpoint
extends Area2D

@export var spawn_point: Marker2D
@export var menu_scene: PackedScene

var _player_inside: CharacterBody2D
var _active_menu: CheckpointMenu


func _ready() -> void:
	if spawn_point == null or menu_scene == null:
		push_error("Checkpoint: Spawn point and menu scene must be assigned.")
		set_process_unhandled_input(false)
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group(&"player") and body.has_method(&"set_checkpoint"):
		_player_inside = body


func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interaction") or not is_instance_valid(_player_inside):
		return
	if is_instance_valid(_active_menu):
		return

	var instance := menu_scene.instantiate()
	var menu := instance as CheckpointMenu
	if menu == null:
		instance.queue_free()
		push_error("Checkpoint: Menu scene must have a CheckpointMenu root.")
		return

	_active_menu = menu
	get_tree().root.add_child(menu)
	menu.open(_player_inside, spawn_point.global_position)
	get_viewport().set_input_as_handled()
