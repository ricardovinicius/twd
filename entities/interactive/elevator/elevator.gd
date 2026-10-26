class_name Elevator
extends Node2D

## A platform that travels between a bottom stop (this node's origin) and a
## top stop (`travel` above it). Any state change of a connected switch, such
## as an elevator lever, sends it to the other stop. While descending it waits
## if a body is underneath, so nothing gets crushed.

signal departed(to_top: bool)
signal arrived(at_top: bool)

## Offset from the bottom stop to the top stop, in this node's space.
@export var travel: Vector2 = Vector2(0.0, -480.0)
## Travel speed in pixels per second (eased at both ends).
@export_range(10.0, 5000.0, 10.0, "or_greater") var speed: float = 360.0
@export var start_at_top: bool = false
## How far above the top stop the cables are anchored (the shaft ceiling).
@export_range(0.0, 5000.0, 1.0, "or_greater") var cable_anchor_height: float = 480.0
## Switches that call the elevator. Each state change triggers one trip.
@export var switches: Array[SwitchComponent] = []

@export_category("Dependencies")
@export var platform: AnimatableBody2D
@export var crush_guard: Area2D
@export var cables: Array[Line2D] = []
## Floor art drawn on the platform. Its vertical offset blends between the
## two values below so it lines up with the drawn floor at each stop.
@export var floor_visual: Node2D

@export_category("Floor Alignment")
## Landing floors collide 16.5 px below the drawn tile top, so the art sits
## that much above the platform at the top stop.
@export var top_floor_offset: float = -16.5
## Shaft floors collide at the drawn tile top.
@export var bottom_floor_offset: float = 0.0

var _at_top: bool = false
var _moving: bool = false
var _progress: float = 0.0
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO


func _ready() -> void:
	if platform == null or crush_guard == null:
		push_error("Elevator: Platform and CrushGuard must be assigned.")
		set_physics_process(false)
		return

	if travel.is_zero_approx():
		push_error("Elevator: Travel must not be zero.")
		set_physics_process(false)
		return

	for switch in switches:
		if switch == null:
			push_error("Elevator: A switch reference is missing.")
			continue

		if not switch.state_changed.is_connected(_on_switch_state_changed):
			switch.state_changed.connect(_on_switch_state_changed)

	_at_top = start_at_top
	platform.position = _stop_position(_at_top)
	platform.reset_physics_interpolation()
	_update_cables()
	_update_floor_visual()
	_set_cables_visible(false)


func _physics_process(delta: float) -> void:
	if not _moving:
		return

	var descending := _to.y > _from.y

	if descending and _is_blocked_below():
		return

	var duration := maxf(_from.distance_to(_to) / speed, 0.01)
	_progress = minf(_progress + delta / duration, 1.0)

	var eased := (1.0 - cos(PI * _progress)) * 0.5
	platform.position = _from.lerp(_to, eased)
	_update_cables()
	_update_floor_visual()

	if _progress >= 1.0:
		_finish_trip()


func is_moving() -> bool:
	return _moving


func is_at_top() -> bool:
	return _at_top and not _moving


## Starts a trip to the other stop. Ignored while already moving.
func call_elevator() -> bool:
	if _moving or not is_physics_processing():
		return false

	_from = _stop_position(_at_top)
	_to = _stop_position(not _at_top)
	_progress = 0.0
	_moving = true
	_set_switches_locked(true)
	_set_cables_visible(true)
	departed.emit(not _at_top)

	return true


func _finish_trip() -> void:
	_moving = false
	_set_switches_locked(false)
	_at_top = not _at_top
	platform.position = _stop_position(_at_top)
	_update_cables()
	_update_floor_visual()
	_set_cables_visible(false)
	arrived.emit(_at_top)


func _stop_position(top: bool) -> Vector2:
	return travel if top else Vector2.ZERO


## Stretches the cables from the platform to their fixed anchor above.
func _update_cables() -> void:
	var anchor_y := travel.y - cable_anchor_height - platform.position.y

	for cable in cables:
		if cable == null or cable.get_point_count() < 2:
			continue

		cable.set_point_position(1, Vector2(cable.get_point_position(0).x, anchor_y))


func _update_floor_visual() -> void:
	if floor_visual == null:
		return

	var t := clampf(platform.position.dot(travel) / travel.length_squared(), 0.0, 1.0)
	floor_visual.position.y = lerpf(bottom_floor_offset, top_floor_offset, t)


## The platform is drawn with the floor tiles, so at rest it blends into the
## landing. Cables only show while it travels.
func _set_cables_visible(value: bool) -> void:
	for cable in cables:
		if cable != null:
			cable.visible = value


func _is_blocked_below() -> bool:
	for body in crush_guard.get_overlapping_bodies():
		if body is CharacterBody2D or body is RigidBody2D:
			return true

	return false


## Levers cannot be flipped while the elevator travels, so their state never
## suggests a request that will be ignored.
func _set_switches_locked(value: bool) -> void:
	for switch in switches:
		if switch != null:
			switch.locked = value


func _on_switch_state_changed(_active: bool) -> void:
	call_elevator()
