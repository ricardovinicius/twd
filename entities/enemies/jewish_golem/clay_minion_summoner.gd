class_name ClayMinionSummoner
extends Node

## Raises small clay minions (clay versions of the Flying Eye and the
## Homunculus) for the Jewish Golem. Scenes are used in turn. At most
## `max_alive` minions (2) exist at once; further requests are rejected. Minions
## live under `container` (the golem's Summons node), so they disappear with
## him, and `clear()` crumbles them all when he is defeated.

signal minion_summoned(minion: Node2D)

@export_category("Dependencies")
## Minion scenes, used in turn.
@export var minion_scenes: Array[PackedScene] = []
@export var container: Node

@export_category("Summoning")
@export_range(0, 20) var max_alive: int = 2
## Minions appear this far above the requested point, clear of the ground.
@export_range(0.0, 500.0, 1.0, "or_greater") var spawn_lift: float = 36.0

var _minions: Array[Node2D] = []
var _next_scene: int = 0
var _configured: bool = false


func _ready() -> void:
	if container == null or minion_scenes.is_empty():
		push_error("ClayMinionSummoner: Container and at least one Minion Scene must be assigned.")
		return

	_configured = true


func get_alive_count() -> int:
	_prune()
	return _minions.size()


func get_minions() -> Array[Node2D]:
	_prune()
	return _minions.duplicate()


func can_summon(count: int = 1) -> bool:
	return _configured and get_alive_count() + count <= max_alive


## Raises the next minion at `point` and points it at `target`. Returns the
## minion, or null when the cap is reached. Entering the tree is deferred:
## requests often arrive from physics callbacks (a ball landing).
func summon_at(point: Vector2, target: Node2D) -> Node2D:
	if not can_summon():
		return null

	var scene := minion_scenes[_next_scene % minion_scenes.size()]
	var minion := scene.instantiate() as Node2D

	_next_scene += 1

	if minion == null:
		push_error("ClayMinionSummoner: Minion scenes must have a Node2D root.")
		return null

	minion.position = point - Vector2(0.0, spawn_lift)
	_minions.append(minion)
	minion.tree_exited.connect(_on_minion_exited.bind(minion))
	_enter_minion.call_deferred(minion, target)

	return minion


## Crumbles every minion (the golem was defeated or removed).
func clear() -> void:
	_prune()

	for minion in _minions:
		# A minion whose deferred entry has not happened yet is not in the tree.
		if minion.is_inside_tree():
			minion.queue_free()
		else:
			minion.free()

	_minions.clear()


func _enter_minion(minion: Node2D, target: Node2D) -> void:
	if not is_instance_valid(minion) or not is_instance_valid(container):
		return

	container.add_child(minion)
	minion.reset_physics_interpolation()

	# Ground minions (the clay homunculus) are told who to chase; flying ones
	# find the player with their own sight.
	if is_instance_valid(target) and minion.has_method(&"chase"):
		minion.chase(target)

	minion_summoned.emit(minion)


func _on_minion_exited(minion: Node2D) -> void:
	_minions.erase(minion)


func _prune() -> void:
	for index in range(_minions.size() - 1, -1, -1):
		if not is_instance_valid(_minions[index]):
			_minions.remove_at(index)
