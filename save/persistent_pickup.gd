class_name PersistentPickup
extends RefCounted

## Shared rules for pickups placed in a level (coins, items) whose collection
## is remembered by the save. Pickups spawned at runtime, such as enemy
## Stardust drops, have no scene owner and are never persistent.

const GROUP := &"persistent_pickups"


static func register(pickup: Node) -> void:
	if is_persistent(pickup):
		pickup.add_to_group(GROUP)


static func is_persistent(pickup: Node) -> bool:
	return pickup.owner != null and pickup.is_inside_tree()


## Stable id: the pickup's path relative to the running scene.
static func get_id(pickup: Node) -> String:
	var scene := pickup.get_tree().current_scene

	if scene == null or not scene.is_ancestor_of(pickup):
		return String(pickup.get_path())

	return String(scene.get_path_to(pickup))
