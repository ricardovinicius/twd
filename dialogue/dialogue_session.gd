class_name DialogueSession
extends Node

signal started
signal line_changed(line: DialogueLine)
signal ended(reason: StringName)

@export var player: Node2D
@export var health: Health
@export var respawn: Node

var _definition: DialogueDefinition
var _target: InteractionTarget
var _line_index: int = -1
var _connections: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if (
		player == null
		or health == null
		or respawn == null
		or not respawn.has_signal(&"respawning")
	):
		push_error("DialogueSession: Player, Health, and RespawnOnDeath must be assigned.")


func try_start(
	definition: DialogueDefinition,
	participant: Node2D,
	target: InteractionTarget
) -> bool:
	if (
		is_active()
		or get_tree().paused
		or definition == null
		or not definition.is_valid()
	):
		return false

	if (
		participant != player
		or not _player_available()
		or not is_instance_valid(target)
	):
		return false

	if not target.can_interact(player):
		return false

	_definition = definition
	_target = target
	_line_index = 0

	_watch(health.damaged, _on_damaged)
	_watch(health.depleted, _on_player_unavailable)
	_watch(Signal(respawn, &"respawning"), _on_player_unavailable)
	_watch(player.tree_exiting, _on_player_unavailable)
	_watch(target.tree_exiting, _on_target_removed)
	_watch(target.availability_changed, revalidate)

	started.emit()
	if is_active():
		line_changed.emit(get_current_line())

	return true


func advance() -> bool:
	if get_tree().paused or not revalidate():
		return false

	_line_index += 1

	if _line_index >= _definition.lines.size():
		_end(&"completed")
	else:
		line_changed.emit(get_current_line())

	return true


func cancel() -> bool:
	if not is_active() or get_tree().paused:
		return false

	_end(&"cancelled")

	return true


func is_active() -> bool:
	return _definition != null


func get_current_line() -> DialogueLine:
	return _definition.lines[_line_index] if is_active() else null


func revalidate() -> bool:
	if not is_active():
		return false

	if not _player_available():
		_end(&"player_unavailable")
	elif (
		not is_instance_valid(_target)
		or not _target.is_inside_tree()
		or _target.is_queued_for_deletion()
	):
		_end(&"target_unavailable")
	elif not _target.can_interact(player):
		_end(&"out_of_range")

	return is_active()


func _process(_delta: float) -> void:
	if not get_tree().paused:
		revalidate()


func _player_available() -> bool:
	return (
		is_instance_valid(player)
		and player.is_inside_tree()
		and not player.is_queued_for_deletion()
		and is_instance_valid(health)
		and not health.is_depleted()
		and is_instance_valid(respawn)
		and respawn.has_signal(&"respawning")
	)


func _watch(source: Signal, callback: Callable) -> void:
	source.connect(callback)
	_connections.append({"source": source, "callback": callback})


func _end(reason: StringName) -> void:
	if not is_active():
		return

	_definition = null
	_target = null
	_line_index = -1

	for connection in _connections:
		var source: Signal = connection.source
		if is_instance_valid(source.get_object()) and source.is_connected(connection.callback):
			source.disconnect(connection.callback)
	_connections.clear()

	ended.emit(reason)


func _on_damaged(amount: float) -> void:
	if amount > 0.0:
		_end(&"damaged")


func _on_player_unavailable() -> void:
	_end(&"player_unavailable")


func _on_target_removed() -> void:
	_end(&"target_unavailable")


func _exit_tree() -> void:
	_end(&"scene_changed")
