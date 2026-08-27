extends Node3D

@export var camera_2d: Camera2D
@export var camera_3d: Camera3D

@export var world_scale := 0.001

var camera_3d_initial_position: Vector3
var camera_2d_initial_position: Vector2

func _ready():
	camera_3d_initial_position = camera_3d.position
	camera_2d_initial_position = camera_2d.global_position

func _process(_delta):
	var movement = camera_2d.global_position - camera_2d_initial_position

	camera_3d.position.x = camera_3d_initial_position.x + movement.x * world_scale
	camera_3d.position.z = camera_3d_initial_position.z + movement.y * world_scale
