class_name HomunculusCouple
extends Node2D

## Two homunculi in love, kissing in place. When the player comes into view
## (in range, clear line of sight) they keep kissing but turn their eyes to
## the player, then quickly break apart and run after them. They do not give
## up while they are on the player's screen: only once both have been off
## screen for a moment do they walk back and kiss again. Hurting one skips
## the stare. A lone survivor just waits at its spot.

enum State {
	KISSING,
	STARING,
	CHASING,
	RETURNING,
	ALONE,
}

signal state_changed(state: State)

@export_category("Vision")
@export_range(0.0, 2000.0, 1.0, "or_greater") var vision_radius: float = 260.0
## Layers that block sight (walls, floors).
@export_flags_2d_physics var line_of_sight_mask: int = 1
@export var target_group: StringName = &"player"

@export_category("Chase")
## How long they stare at the player, still kissing, before running.
@export_range(0.0, 5.0, 0.01, "or_greater") var stare_duration: float = 0.6
## They give up after both have been off screen for this long.
@export_range(0.0, 10.0, 0.05, "or_greater") var offscreen_grace: float = 0.75
## Extra pixels around the screen that still count as on screen.
@export_range(0.0, 1000.0, 1.0, "or_greater") var screen_margin: float = 0.0

@onready var left: Homunculus = $Left
@onready var right: Homunculus = $Right
@onready var heart: CanvasItem = $Heart
@onready var vision: TargetDetector = $Vision
@onready var vision_shape: CollisionShape2D = $Vision/CollisionShape2D

var _state: State = State.KISSING
var _target: Node2D
var _home: Vector2
var _left_home_x: float = 0.0
var _right_home_x: float = 0.0
var _homes_set: bool = false
var _stare_time_left: float = 0.0
var _offscreen_time: float = 0.0


func _ready() -> void:
	var circle := vision_shape.shape as CircleShape2D

	if circle != null:
		# Each instance sets its own radius without touching the shared resource.
		circle = circle.duplicate()
		circle.radius = vision_radius
		vision_shape.shape = circle

	left.add_collision_exception_with(right)

	for homunculus in _members():
		homunculus.attack_receiver.attack_received.connect(_on_attack_received)
		homunculus.tree_exited.connect(_on_member_exited)

	left.kiss(1.0)
	right.kiss(-1.0)
	_update_presentation()


func _physics_process(delta: float) -> void:
	# The respawner places the couple after _ready, so homes are read here.
	if not _homes_set:
		_record_homes()

	match _state:
		State.KISSING:
			var seen := _find_visible_target()
			if seen != null:
				_start_staring(seen)
		State.STARING:
			_process_stare(delta)
		State.CHASING:
			_process_chase(delta)
		State.RETURNING, State.ALONE:
			var seen := _find_visible_target()
			if seen != null:
				_start_chase(seen)
			elif _state == State.RETURNING and _everyone_home():
				_settle()


func get_state() -> State:
	return _state


func get_target() -> Node2D:
	return _target


func get_home() -> Vector2:
	return _home


func has_line_of_sight(point: Vector2) -> bool:
	if line_of_sight_mask == 0 or not is_inside_tree():
		return true

	var query := PhysicsRayQueryParameters2D.create(global_position, point, line_of_sight_mask)

	query.collide_with_areas = false
	query.exclude = _member_rids()

	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func can_see(target: Node2D) -> bool:
	# The detector updates on the next physics step, so a teleported target is
	# also checked by distance instead of trusting a stale overlap.
	return (
		is_instance_valid(target)
		and vision.has_target(target)
		and global_position.distance_to(target.global_position) <= vision_radius
		and has_line_of_sight(target.global_position)
	)


## True while the node is inside the visible part of the screen.
func is_on_screen(node: Node2D) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return false

	var viewport := node.get_viewport()
	var visible_area := viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()

	return visible_area.grow(screen_margin).has_point(node.global_position)


func is_any_member_on_screen() -> bool:
	for homunculus in _members():
		if is_on_screen(homunculus):
			return true

	return false


func _start_staring(target: Node2D) -> void:
	_target = target
	_stare_time_left = stare_duration

	for homunculus in _members():
		homunculus.stare(target)

	_set_state(State.STARING)


func _process_stare(delta: float) -> void:
	_stare_time_left -= delta

	if _stare_time_left > 0.0:
		return

	if is_instance_valid(_target):
		_start_chase(_target)
	else:
		_go_home()


func _start_chase(target: Node2D) -> void:
	if not is_instance_valid(target):
		return

	_target = target
	_offscreen_time = 0.0

	for homunculus in _members():
		homunculus.chase(target)

	_set_state(State.CHASING)


func _process_chase(delta: float) -> void:
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		_go_home()
		return

	if is_any_member_on_screen():
		_offscreen_time = 0.0
		return

	_offscreen_time += delta

	if _offscreen_time >= offscreen_grace:
		_go_home()


func _find_visible_target() -> Node2D:
	var closest: Node2D = null
	var closest_distance := INF

	for candidate in vision.get_targets():
		if not can_see(candidate):
			continue

		var candidate_distance := global_position.distance_squared_to(candidate.global_position)

		if candidate_distance < closest_distance:
			closest = candidate
			closest_distance = candidate_distance

	return closest


func _go_home() -> void:
	_target = null

	if is_instance_valid(left):
		left.return_home(_left_home_x)
	if is_instance_valid(right):
		right.return_home(_right_home_x)

	_set_state(State.RETURNING)


func _everyone_home() -> bool:
	for homunculus in _members():
		if not homunculus.is_home() or not homunculus.is_on_floor():
			return false

	return true


func _settle() -> void:
	if _members().size() == 2:
		left.kiss(1.0)
		right.kiss(-1.0)
		_set_state(State.KISSING)
		return

	for homunculus in _members():
		homunculus.wait()

	_set_state(State.ALONE)


func _record_homes() -> void:
	_home = global_position

	if is_instance_valid(left):
		_left_home_x = left.global_position.x
	if is_instance_valid(right):
		_right_home_x = right.global_position.x

	_homes_set = true


func _members() -> Array[Homunculus]:
	var members: Array[Homunculus] = []

	for homunculus in [left, right]:
		if is_instance_valid(homunculus) and homunculus.is_inside_tree():
			members.append(homunculus)

	return members


func _member_rids() -> Array[RID]:
	var rids: Array[RID] = []

	for homunculus in _members():
		rids.append(homunculus.get_rid())

	return rids


func _set_state(new_state: State) -> void:
	if new_state == _state:
		return

	_state = new_state
	_update_presentation()
	state_changed.emit(_state)


func _update_presentation() -> void:
	heart.visible = _state == State.KISSING or _state == State.STARING


# Getting hurt skips the stare: they run at whoever did it right away.
func _on_attack_received(attack: AttackData) -> void:
	if _state == State.CHASING or attack == null:
		return

	var attacker := _find_target_ancestor(attack.source)

	if attacker == null:
		attacker = _find_visible_target()

	_start_chase(attacker)


func _find_target_ancestor(node: Node) -> Node2D:
	var current := node

	while is_instance_valid(current):
		if current.is_in_group(target_group) and current is Node2D:
			return current

		current = current.get_parent()

	return null


func _on_member_exited() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return

	# The pair dies together only when both are gone.
	if _members().is_empty():
		queue_free()
		return

	if _state == State.KISSING or _state == State.STARING:
		_settle()
