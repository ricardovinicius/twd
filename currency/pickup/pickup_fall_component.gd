class_name PickupFallComponent
extends Node

## Pulls a pickup down until it rests on world collision. Pickups are areas,
## so this component moves the body directly and finds the floor with a ray.

signal landed

@export var body: Node2D

@export_category("Fall")
@export_range(0.0, 5000.0, 10.0, "or_greater") var gravity: float = 900.0
@export_range(0.0, 5000.0, 10.0, "or_greater") var max_fall_speed: float = 600.0
## Distance from the body's origin to the bottom of its art. The body rests
## this far above the floor.
@export_range(0.0, 128.0, 0.5, "or_greater") var rest_height: float = 12.0
## Layers the body lands on. Layer 1 is world collision.
@export_flags_2d_physics var floor_mask: int = 1
## Stops falling after this distance without a floor, such as over a pit.
@export_range(0.0, 100000.0, 10.0, "or_greater") var max_fall_distance: float = 4000.0

var _fall_speed: float = 0.0
var _fallen_distance: float = 0.0
var _is_resting: bool = false
var _is_suspended: bool = false


func _ready() -> void:
	if body == null:
		push_error("PickupFallComponent: Body is not assigned.")
		set_physics_process(false)
		return

	_update_processing()


func _physics_process(delta: float) -> void:
	_fall_speed = minf(_fall_speed + gravity * delta, max_fall_speed)
	var step := _fall_speed * delta
	var hit := _find_floor(step)

	if hit.is_empty():
		body.global_position.y += step
		_fallen_distance += step

		if _fallen_distance >= max_fall_distance:
			_stop()
		return

	# A ray that starts inside the floor reports a zero normal; stay in place.
	if hit.normal != Vector2.ZERO:
		body.global_position.y = hit.position.y - rest_height

	_stop()
	landed.emit()


## Pauses falling while something else moves the body, such as attraction.
## Resuming starts a new fall from the current position.
func set_suspended(suspended: bool) -> void:
	if _is_suspended == suspended:
		return

	_is_suspended = suspended
	_fall_speed = 0.0

	if not suspended:
		_is_resting = false
		_fallen_distance = 0.0

	_update_processing()


func is_falling() -> bool:
	return body != null and not _is_resting and not _is_suspended


func is_resting() -> bool:
	return _is_resting


func _find_floor(step: float) -> Dictionary:
	var from := body.global_position
	var to := from + Vector2(0.0, rest_height + step)
	var query := PhysicsRayQueryParameters2D.create(from, to, floor_mask)

	query.hit_from_inside = true
	query.collide_with_areas = false

	return body.get_world_2d().direct_space_state.intersect_ray(query)


func _stop() -> void:
	_is_resting = true
	_fall_speed = 0.0
	_update_processing()


func _update_processing() -> void:
	set_physics_process(is_falling())
