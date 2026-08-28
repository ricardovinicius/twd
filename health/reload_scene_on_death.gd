class_name ReloadSceneOnDeath
extends Node

@export var health: Health


func _ready() -> void:
	assert(health != null, "ReloadSceneOnDeath: Health is not assigned.")
	health.depleted.connect(_on_health_depleted)


func _on_health_depleted() -> void:
	get_tree().call_deferred(&"reload_current_scene")
