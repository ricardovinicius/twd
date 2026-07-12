extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

const SPEED = 400.0
const JUMP_VELOCITY = -1050.0


func _physics_process(delta: float) -> void:
	# Add animation
	if velocity.x > 1 or velocity.x < -1:
		animated_sprite_2d.animation = "base"
	else:
		animated_sprite_2d.animation = "base"
	
	# Add the gravity.
	if not is_on_floor():
		animated_sprite_2d.animation = "base"
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	if direction == 1.0:
		animated_sprite_2d.flip_h = false
	elif direction == -1.0:
		animated_sprite_2d.flip_h = true
	
