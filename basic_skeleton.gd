extends CharacterBody2D

@onready var target=$"../player"
var speed: float = 35
var gravity = 15

@export_range(-1,1) var dir: int = 1

func _ready() -> void:
	if dir == 0:
		dir = 1
	$sprite2D.flip_h = false if dir == 1 else true
	
	func _physics_process(delta: float) -> void:
		if dir == 1 and (!$rightray.is_colliding() or $rightwallray.is_collinding()):
			$Sprite2D.flip_h = true
			dir = -1
		if dir == -1 and ($leftray.is_colliding() or $leftwallray.is_colliding()):
			$sprite2D.flip_h = false
			dir = 1
		
		velocity.x = lerp(velocity.x, dir * speed, 10.0*delta)
		velocity.y += gravity
		move_and_slide()
		
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == player_node:
		get_tree () .call_deferred("reload_current_scene")
