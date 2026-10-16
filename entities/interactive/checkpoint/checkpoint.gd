class_name Checkpoint
extends InteractionTarget

@export var spawn_point: Marker2D
@export var menu_scene: PackedScene

var _active_menu: CheckpointMenu


func _ready() -> void:
	super._ready()
	prompt = "Use checkpoint"

	if spawn_point == null or menu_scene == null:
		push_error("Checkpoint: Spawn point and menu scene must be assigned.")
		enabled = false


func can_interact(player: Node2D) -> bool:
	return (
		super.can_interact(player)
		and player.has_method(&"set_checkpoint")
		and not is_instance_valid(_active_menu)
	)


func try_interact(player: Node2D) -> bool:
	if not can_interact(player) or get_tree().paused:
		return false

	var interactor := player.get_interactor() as PlayerInteractor

	if (
		interactor != null
		and is_instance_valid(interactor.dialogue_session)
		and interactor.dialogue_session.is_active()
	):
		return false

	var instance := menu_scene.instantiate()
	var menu := instance as CheckpointMenu

	if menu == null:
		instance.queue_free()
		push_error("Checkpoint: Menu scene must have a CheckpointMenu root.")
		return false

	_active_menu = menu
	get_tree().root.add_child(menu)
	menu.open(player, spawn_point.global_position)

	return true
