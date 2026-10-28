class_name CompanionFollowComponent
extends Node

## Moves a companion toward a spot beside its target with frame-rate
## independent smoothing. The companion has no collision, so it passes through
## level geometry on its way.

signal snapped_to_target

@export var body: Node2D
@export var target: Node2D

@export_category("Follow")
## Resting spot relative to the target while the target moves right. The
## horizontal offset mirrors when the target moves left, keeping the companion
## behind it.
@export var follow_offset: Vector2 = Vector2(-72.0, -90.0)
## How quickly the companion closes the distance. Higher = tighter.
@export_range(0.1, 30.0, 0.1, "or_greater") var follow_speed: float = 4.0
## Speed cap, so long trips glide instead of jumping.
@export_range(0.0, 10000.0, 10.0, "or_greater") var max_speed: float = 1400.0
## Horizontal target speed needed to switch to the other side.
@export_range(0.0, 1000.0, 1.0, "or_greater") var turn_speed_threshold: float = 20.0
## Beyond this distance, such as after a respawn, the companion jumps to its spot.
@export_range(0.0, 100000.0, 10.0, "or_greater") var snap_distance: float = 1500.0

var _side: float = 1.0
var _last_target_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	if body == null or target == null:
		push_error("CompanionFollowComponent: Body and Target must be assigned.")
		set_physics_process(false)
		return

	_last_target_position = target.global_position
	snap_to_target()


func _physics_process(delta: float) -> void:
	# A removed target leaves the companion where it is.
	if not is_instance_valid(target):
		return

	_update_side(delta)

	var to_destination := get_destination() - body.global_position

	if to_destination.length() > snap_distance:
		snap_to_target()
		return

	var smoothed_step := to_destination * (1.0 - exp(-follow_speed * delta))
	body.global_position += smoothed_step.limit_length(max_speed * delta)


## Where the companion is heading: the follow offset beside the target.
func get_destination() -> Vector2:
	var offset := Vector2(follow_offset.x * _side, follow_offset.y)
	return target.global_position + offset


## Places the companion at its destination without interpolating the jump.
func snap_to_target() -> void:
	if not is_instance_valid(target):
		return

	body.global_position = get_destination()
	body.reset_physics_interpolation()
	snapped_to_target.emit()


func _update_side(delta: float) -> void:
	var target_position := target.global_position
	var horizontal_speed := (target_position.x - _last_target_position.x) / delta
	_last_target_position = target_position

	if absf(horizontal_speed) > turn_speed_threshold:
		_side = signf(horizontal_speed)
