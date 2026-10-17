class_name RespawnOnDeath
extends Node

signal respawning
signal respawned
signal rested

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


func has_checkpoint() -> bool:
	return _has_checkpoint


func get_checkpoint_position() -> Vector2:
	return _checkpoint_position


## Resting sets the checkpoint and fully restores health, then announces the
## rest so other features (e.g. enemy respawning) can react.
func rest_at(position: Vector2) -> void:
	if not is_instance_valid(health):
		return

	set_checkpoint(position)
	health.reset()

	rested.emit()
	Events.checkpoint_rested.emit()


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
