class_name ShieldBlockSpawner
extends Node

## Raises breakable clay blocks around the Jewish Golem: the map's diggable
## blocks, broken with the Dig spell, that also catch the player's attacks
## (ClayShieldBlock). Slots that share an x form a column: breaking one block
## breaks the whole column, so one Dig opens the wall. Each slot is an offset
## from the anchor in world pixels; a slot is skipped when something already
## occupies it (a wall, the player, a block that is still standing).
## Blocks live under `container` (the golem's Summons node), so they
## disappear with him, and `clear()` removes them when he is defeated.

signal blocks_raised(blocks: Array[Node2D])

## Blocks whose centers are this close horizontally share a column.
const COLUMN_TOLERANCE := 4.0

@export_category("Dependencies")
@export var block_scene: PackedScene
@export var anchor: CollisionObject2D
@export var container: Node

@export_category("Layout")
## Block centers relative to the anchor, in world pixels (not scaled).
@export var slot_offsets: Array[Vector2] = [
	Vector2(-102.0, 46.5),
	Vector2(102.0, 46.5),
	Vector2(-102.0, -49.5),
	Vector2(102.0, -49.5),
]
## World size of one block, used to check that a slot is free.
@export var block_size: Vector2 = Vector2(96.0, 96.0)
## What makes a slot occupied: world and entities (the player).
@export_flags_2d_physics var blocking_mask: int = 5

var _blocks: Array[Node2D] = []
var _configured: bool = false


func _ready() -> void:
	if block_scene == null or anchor == null or container == null:
		push_error("ShieldBlockSpawner: Block Scene, Anchor and Container must be assigned.")
		return

	_configured = true


func get_alive_count() -> int:
	_prune()
	return _blocks.size()


func get_blocks() -> Array[Node2D]:
	_prune()
	return _blocks.duplicate()


## Fills every free slot with a block. Returns how many were raised.
func raise_blocks() -> int:
	if not _configured or not anchor.is_inside_tree():
		return 0

	var raised: Array[Node2D] = []

	for offset in slot_offsets:
		var center := anchor.global_position + offset

		if not is_slot_free(center):
			continue

		var block := block_scene.instantiate() as Node2D

		if block == null:
			push_error("ShieldBlockSpawner: Block Scene must have a Node2D root.")
			break

		block.position = center
		container.add_child(block)
		block.reset_physics_interpolation()
		_blocks.append(block)
		raised.append(block)
		_watch_block(block)

	if not raised.is_empty():
		blocks_raised.emit(raised)

	return raised.size()


func is_slot_free(center: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	var query := PhysicsShapeQueryParameters2D.new()

	# Slightly smaller than a block so touching neighbours do not count.
	shape.size = block_size - Vector2(6.0, 6.0)
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = blocking_mask
	query.collide_with_areas = false
	query.exclude = [anchor.get_rid()]

	if not anchor.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false

	# Blocks raised this frame are not in the physics space yet.
	for block in get_blocks():
		if block.global_position.distance_to(center) < block_size.x * 0.5:
			return false

	return true


## Breaks every standing block in the same column as `block`.
func break_column(block: Node2D) -> void:
	if not is_instance_valid(block):
		return

	var column_x := block.global_position.x

	for other in get_blocks():
		if other == block or absf(other.global_position.x - column_x) > COLUMN_TOLERANCE:
			continue

		var other_health := other.get_node_or_null("Health") as Health

		if other_health != null and not other_health.is_depleted():
			other_health.take_damage(other_health.current)


func _watch_block(block: Node2D) -> void:
	var health := block.get_node_or_null("Health") as Health

	if health == null:
		push_warning("ShieldBlockSpawner: Block '%s' has no Health; its column will not break together." % block.name)
		return

	health.depleted.connect(break_column.bind(block))


## Removes every block (the golem was defeated or removed).
func clear() -> void:
	_prune()

	for block in _blocks:
		block.queue_free()

	_blocks.clear()


func _prune() -> void:
	for index in range(_blocks.size() - 1, -1, -1):
		if not is_instance_valid(_blocks[index]) or _blocks[index].is_queued_for_deletion():
			_blocks.remove_at(index)
