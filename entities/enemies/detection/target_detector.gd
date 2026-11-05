class_name TargetDetector
extends Area2D

signal target_entered(target: Node2D)
signal target_exited(target: Node2D)

@export var target_group: StringName = &"player"

var _targets: Dictionary[Node2D, bool] = {}
## Targets that count as detected for a while even outside the area, such as
## whoever just hit the owner (see ProvokeOnHitReaction). Value: seconds left.
var _provoked: Dictionary[Node2D, float] = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)


func has_target(target: Node2D) -> bool:
	return is_instance_valid(target) and (_targets.has(target) or _provoked.has(target))


func get_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for target in _targets:
		if is_instance_valid(target):
			targets.append(target)
	for target in _provoked:
		if is_instance_valid(target) and not _targets.has(target):
			targets.append(target)
	return targets


## Makes target count as detected for duration seconds wherever it is, as
## if it were inside the area. Provoking again refreshes the time.
func provoke(target: Node2D, duration: float) -> void:
	if not is_instance_valid(target) or duration <= 0.0:
		return

	var already_detected := has_target(target)

	_provoked[target] = maxf(_provoked.get(target, 0.0), duration)
	set_physics_process(true)

	if not already_detected:
		target_entered.emit(target)


func is_provoked(target: Node2D) -> bool:
	return is_instance_valid(target) and _provoked.has(target)


func _physics_process(delta: float) -> void:
	for target in _provoked.keys():
		if not is_instance_valid(target):
			_provoked.erase(target)
			continue

		_provoked[target] -= delta

		if _provoked[target] > 0.0:
			continue

		_provoked.erase(target)

		if not _targets.has(target):
			target_exited.emit(target)

	if _provoked.is_empty():
		set_physics_process(false)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(target_group):
		return

	if _targets.has(body):
		return

	var already_detected := _provoked.has(body)

	_targets[body] = true

	if not already_detected:
		target_entered.emit(body)


func _on_body_exited(body: Node2D) -> void:
	if not _targets.erase(body):
		return

	# Still provoked: it stays detected until the provocation ends.
	if _provoked.has(body):
		return

	target_exited.emit(body)
