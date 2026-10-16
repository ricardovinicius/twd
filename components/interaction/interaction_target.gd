class_name InteractionTarget
extends Area2D

signal availability_changed

@export var prompt: String = "Talk"
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return

		enabled = value

		availability_changed.emit()

var request_handler: Callable
var _players: Array[Node2D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func can_interact(player: Node2D) -> bool:
	return (
		enabled
		and is_inside_tree()
		and not is_queued_for_deletion()
		and is_instance_valid(player)
		and not player.is_queued_for_deletion()
		and player.is_in_group(&"player")
		and player in _players
	)


func try_interact(player: Node2D) -> bool:
	if (
		not can_interact(player)
		or get_tree().paused
		or not request_handler.is_valid()
	):
		return false

	return request_handler.call(player)


func get_prompt() -> String:
	return prompt


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player") or not body.has_method(&"get_interactor"):
		return

	var interactor := body.get_interactor() as PlayerInteractor

	if interactor == null or body in _players:
		return

	_players.append(body)
	interactor.register_target(self)

	availability_changed.emit()


func _on_body_exited(body: Node2D) -> void:
	_players.erase(body)

	if is_instance_valid(body) and body.has_method(&"get_interactor"):
		var interactor := body.get_interactor() as PlayerInteractor

		if is_instance_valid(interactor):
			interactor.unregister_target(self)

	availability_changed.emit()
