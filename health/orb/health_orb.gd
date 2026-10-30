class_name HealthOrb
extends Area2D

## Health pickup dropped by orb-carrying creatures. It falls to the floor
## first and only releases its health once it has landed. The player collects
## it by touching it, unless their health is already full; then it stays.

signal released
signal collected(target: Node2D, restored: float)

@export_range(0.0, 1000.0, 1.0, "or_greater") var heal_amount: float = 25.0
@export var player_group: StringName = &"player"
@export var fall: PickupFallComponent

@export_category("Presentation")
@export var falling_animation: StringName = &"falling"
@export var released_animation: StringName = &"released"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _released: bool = false
var _collected: bool = false


func _ready() -> void:
	if fall == null:
		# Without a fall component the orb is placed by hand and works at once.
		_release()
		return

	fall.landed.connect(_release)
	sprite.play(falling_animation)

	if fall.is_resting():
		_release()


func _physics_process(_delta: float) -> void:
	if _released and not _collected:
		_try_collect_overlaps()
	elif not _released and fall != null and fall.is_resting():
		# Fell past max_fall_distance (a pit): release where it stopped.
		_release()


func is_released() -> bool:
	return _released


func is_collected() -> bool:
	return _collected


func _release() -> void:
	if _released:
		return

	_released = true
	sprite.play(released_animation)
	released.emit()


func _try_collect_overlaps() -> void:
	for body in get_overlapping_bodies():
		if _try_collect(body):
			return


func _try_collect(body: Node2D) -> bool:
	if not body.is_in_group(player_group) or not body.has_method("heal"):
		return false

	if body.has_method("can_heal") and not body.can_heal():
		return false

	var restored: float = body.heal(heal_amount)

	if restored <= 0.0:
		return false

	_collected = true
	set_deferred(&"monitoring", false)
	collected.emit(body, restored)
	queue_free()
	return true
