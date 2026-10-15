class_name TargetDetector
extends Area2D

signal target_entered(target: Node2D)
signal target_exited(target: Node2D)

@export var target_group: StringName = &"player"

var _targets: Dictionary[Node2D, bool] = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func has_target(target: Node2D) -> bool:
	return is_instance_valid(target) and _targets.has(target)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(target_group):
		return

	if _targets.has(body):
		return

	_targets[body] = true
	target_entered.emit(body)


func _on_body_exited(body: Node2D) -> void:
	if not _targets.erase(body):
		return

	target_exited.emit(body)
