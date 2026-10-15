extends Node3D

@export var camera_2d: Camera2D
@export var camera_3d: Camera3D

@export var world_scale := 0.001

var camera_3d_initial_position: Vector3
var camera_2d_initial_position: Vector2

func _ready() -> void:
	if camera_2d == null or camera_3d == null:
		push_warning("3D camera follow: Assign both cameras to enable movement tracking.")
		set_process(false)
		return

	camera_3d_initial_position = camera_3d.position
	camera_2d_initial_position = camera_2d.global_position

func _process(_delta: float) -> void:
	if not is_instance_valid(camera_2d) or not is_instance_valid(camera_3d):
		set_process(false)
		return

	var movement = camera_2d.global_position - camera_2d_initial_position

	camera_3d.position.x = camera_3d_initial_position.x + movement.x * world_scale
	camera_3d.position.z = camera_3d_initial_position.z + movement.y * world_scale
