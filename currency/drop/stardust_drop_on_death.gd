class_name StardustDropOnDeath
extends Node

## Ao esgotar a vida do source, solta pickup_count pickups de Stardust
## com amount_per_pickup cada, espalhados na horizontal em volta dele.

signal dropped(pickups: Array[Node2D])

@export var health: Health
@export var source: Node2D
@export var pickup_scene: PackedScene
## Onde os pickups são adicionados. Vazio = cena atual (ou o pai da raiz do source).
@export var drop_parent: Node
@export_range(1, 20) var pickup_count: int = 2
@export_range(1, 1000) var amount_per_pickup: int = 10
@export var pickup_spacing: float = 28.0
@export var spawn_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	if health == null or source == null or pickup_scene == null:
		push_error("StardustDropOnDeath: Health, Source and Pickup Scene must be assigned.")
		return

	health.depleted.connect(_on_health_depleted)


func _on_health_depleted() -> void:
	var parent := _resolve_drop_parent()
	if parent == null:
		push_error("StardustDropOnDeath: No parent available for the dropped pickups.")
		return

	var origin := source.global_position + spawn_offset
	# Posição local calculada agora, enquanto o pai está na árvore.
	var to_parent := Transform2D.IDENTITY
	if parent is CanvasItem:
		to_parent = (parent as CanvasItem).get_global_transform().affine_inverse()

	var pickups: Array[Node2D] = []
	var first_offset := -pickup_spacing * (pickup_count - 1) * 0.5

	for index in pickup_count:
		var instance := pickup_scene.instantiate()
		var pickup := instance as CoinPickup
		if pickup == null:
			instance.free()
			push_error("StardustDropOnDeath: Pickup Scene must create a CoinPickup.")
			break

		pickup.amount = amount_per_pickup
		pickup.position = to_parent * (origin + Vector2(first_offset + pickup_spacing * index, 0.0))
		# O dano pode chegar dentro de um callback de física, e o source é liberado
		# no mesmo frame: a adição adiada fica no pai, não neste componente.
		parent.add_child.call_deferred(pickup)
		pickups.append(pickup)

	if not pickups.is_empty():
		dropped.emit(pickups)


func _resolve_drop_parent() -> Node:
	if is_instance_valid(drop_parent):
		return drop_parent

	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene

	# O source pode ser um filho do inimigo (ex.: Body); usa o pai da raiz dele,
	# que continua existindo depois que o inimigo é liberado.
	var scene_root: Node = source.owner if source.owner != null else source
	return scene_root.get_parent()
