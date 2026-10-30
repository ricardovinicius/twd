class_name HealthOrbDropOnDeath
extends Node

## When the carrier's health runs out, lets go of the orb it holds: hides the
## held orb visual and spawns a falling HealthOrb at the hand.

signal dropped(orb: HealthOrb)

@export var health: Health
## Where the orb is held; the dropped orb starts here.
@export var hand: Node2D
@export var orb_scene: PackedScene
## Optional visual of the held orb, hidden when it is dropped.
@export var held_orb: CanvasItem
## Overrides the orb's heal amount when above zero.
@export_range(0.0, 1000.0, 1.0, "or_greater") var heal_amount: float = 0.0
## Where the orb is added. Empty = current scene (or the carrier's parent).
@export var drop_parent: Node


func _ready() -> void:
	if health == null or hand == null or orb_scene == null:
		push_error("HealthOrbDropOnDeath: Health, Hand and Orb Scene must be assigned.")
		return

	health.depleted.connect(_on_health_depleted)


func _on_health_depleted() -> void:
	var parent := _resolve_drop_parent()

	if parent == null:
		push_error("HealthOrbDropOnDeath: No parent available for the dropped orb.")
		return

	var orb := orb_scene.instantiate() as HealthOrb

	if orb == null:
		push_error("HealthOrbDropOnDeath: Orb Scene must create a HealthOrb.")
		return

	var to_parent := Transform2D.IDENTITY

	if parent is CanvasItem:
		to_parent = (parent as CanvasItem).get_global_transform().affine_inverse()

	if heal_amount > 0.0:
		orb.heal_amount = heal_amount

	orb.position = to_parent * hand.global_position

	if held_orb != null:
		held_orb.visible = false

	# Damage can arrive inside a physics callback and the carrier is freed in
	# the same frame, so the deferred add belongs to the parent.
	parent.add_child.call_deferred(orb)
	dropped.emit(orb)


func _resolve_drop_parent() -> Node:
	if is_instance_valid(drop_parent):
		return drop_parent

	var current_scene := get_tree().current_scene

	if current_scene != null:
		return current_scene

	var carrier: Node = owner if owner != null else get_parent()

	return carrier.get_parent()
