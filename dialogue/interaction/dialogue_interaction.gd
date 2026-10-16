class_name DialogueInteraction
extends Node

@export var conversation: DialogueDefinition
@export var session: DialogueSession
@export var target: InteractionTarget


func _ready() -> void:
	# An enclosing composition root may supply the session after children are ready.
	if session != null:
		setup(session)


func setup(dialogue_session: DialogueSession) -> void:
	_unbind()
	session = dialogue_session

	if (
		not is_instance_valid(target)
		or conversation == null
		or not conversation.is_valid()
	):
		push_error("DialogueInteraction: A valid conversation and InteractionTarget must be assigned.")
		return

	if not is_instance_valid(session):
		push_error("DialogueInteraction: DialogueSession must be assigned.")
		return

	target.request_handler = try_interact


func try_interact(player: Node2D) -> bool:
	if (
		not is_inside_tree()
		or not is_instance_valid(session)
		or not session.is_inside_tree()
	):
		return false

	if not is_instance_valid(target) or not target.can_interact(player):
		return false

	return session.try_start(conversation, player, target)


func _unbind() -> void:
	if is_instance_valid(target) and target.request_handler == try_interact:
		target.request_handler = Callable()


func _exit_tree() -> void:
	_unbind()
