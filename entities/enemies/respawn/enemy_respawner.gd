class_name EnemyRespawner
extends Node2D

## Recreates its child enemies when the player dies or rests at a checkpoint.

var _enemy_data: Array[Dictionary] = []


func _ready() -> void:
	for child in get_children():
		_register_enemy(child)

	Events.player_died.connect(respawn_all)
	Events.checkpoint_rested.connect(respawn_all)


func _register_enemy(enemy: Node2D) -> void:
	if enemy.scene_file_path.is_empty():
		push_error(
			"EnemyRespawner: '%s' has no scene_file_path. It must be instanced " % enemy.name
			+ "from its own scene (.tscn) so it can be recreated."
		)
		return

	_enemy_data.append({
		"scene": load(enemy.scene_file_path),
		"transform": enemy.global_transform,
		"properties": _exported_values(enemy),
	})


func respawn_all() -> void:
	for child in get_children():
		child.queue_free()

	for data in _enemy_data:
		var instance: Node2D = data["scene"].instantiate()
		var properties: Dictionary = data["properties"]
		for property in properties:
			instance.set(property, properties[property])
		add_child(instance)
		instance.global_transform = data["transform"]


# Valores exportados configurados no level (ex.: tamanho da plataforma).
# Referências a nós/recursos ficam de fora: apontariam para a instância antiga.
func _exported_values(enemy: Node) -> Dictionary:
	var values := {}
	for property in enemy.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or usage & PROPERTY_USAGE_STORAGE == 0:
			continue

		var value: Variant = enemy.get(property["name"])
		if value is Object:
			continue
		if value is Array or value is Dictionary:
			value = value.duplicate(true)

		values[property["name"]] = value
	return values
