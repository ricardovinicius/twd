class_name RespawnOnDeath
extends Node

signal respawning
signal respawned

@export var body: CharacterBody2D
@export var health: Health

var _spawn_position: Vector2
var _checkpoint_position: Vector2
var _has_checkpoint: bool = false


func _ready() -> void:
	if body == null or health == null:
		push_error("RespawnOnDeath: Body and Health must be assigned.")
		return
	_spawn_position = body.global_position
	health.depleted.connect(_on_health_depleted)


func set_checkpoint(position: Vector2) -> void:
	_checkpoint_position = position
	_has_checkpoint = true


func respawn() -> void:
	if not is_instance_valid(body) or not is_instance_valid(health):
		return
	respawning.emit()
	body.global_position = _checkpoint_position if _has_checkpoint else _spawn_position
	body.velocity = Vector2.ZERO
	health.reset()
	respawned.emit()


func _on_health_depleted() -> void:
	Events.player_died.emit()
	# Damage may arrive inside a physics callback. Restore collision state afterward.
	call_deferred(&"respawn")
