class_name EnemyManager
extends Node2D
 
var _enemy_data: Array[Dictionary] = []
 
 
func _ready() -> void:
	for child in get_children():
		_register_enemy(child)
 
	Events.player_died.connect(respawn_all)
 
 
func _register_enemy(enemy: Node2D) -> void:
	if enemy.scene_file_path.is_empty():
		push_error(
			"EnemyManager: '%s' não tem scene_file_path. Ele precisa ser " % enemy.name
			+ "instanciado a partir de uma cena própria (.tscn) para poder ser recriado."
		)
		return
 
	_enemy_data.append({
		"scene": load(enemy.scene_file_path),
		"transform": enemy.global_transform,
	})
 
 
func respawn_all() -> void:
	for child in get_children():
		child.queue_free()
 
	for data in _enemy_data:
		var instance: Node2D = data["scene"].instantiate()
		add_child(instance)
		instance.global_transform = data["transform"]
