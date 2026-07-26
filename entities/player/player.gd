extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var horizontal_movement: HorizontalMovementComponent = $HorizontalMovement
@onready var coyote_time: CoyoteTimeComponent = $CoyoteTimer
@onready var variable_jump_height: VariableJumpHeightComponent = $VariableJumpHeight

@export var jump_velocity = -1050.0
@export var Jump_buffer_Time: float = .1
@export var facing_direction: Vector2 = Vector2.RIGHT

var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_speed: float = 0.0
var jump_buffer:bool = false


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()

	if not is_dashing:
		_apply_normal_movement(delta)
	else:
		_apply_dash_movement()

	coyote_time.update_floor_state(was_on_floor, is_on_floor())
	

func _apply_normal_movement(delta: float) -> void:
	_update_movement_animation()

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and coyote_time.can_jump(is_on_floor()):
		velocity.y = jump_velocity
		coyote_time.consume_jump()
		_play_animation(&"jump")


	# Cut the remaining upward velocity when jump is released early.
	if Input.is_action_just_released("jump"):
		velocity.y = variable_jump_height.cut_jump(velocity.y)

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("left", "right")
	if direction:
		facing_direction = Vector2(direction, 0.0)

	velocity.x = horizontal_movement.calculate_velocity(
		velocity.x,
		direction,
		delta
	)

	move_and_slide()
	
	if direction == 1.0:
		animated_sprite_2d.flip_h = false
	elif direction == -1.0:
		animated_sprite_2d.flip_h = true


func _apply_dash_movement() -> void:
	# During dash, we don't apply gravity or normal movement.
	velocity = dash_direction * dash_speed
	velocity.y = 0  # Ensure no vertical movement during dash

	_play_animation(&"jump")
	move_and_slide()


func _update_movement_animation() -> void:
	if not is_on_floor():
		_play_animation(&"jump")
	elif absf(velocity.x) > 1.0:
		_play_animation(&"walk")
	else:
		_play_animation(&"idle")


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite_2d.animation == animation_name:
		return

	animated_sprite_2d.play(animation_name)


func begin_dash(direction: Vector2, speed: float, duration: float) -> void:
	if is_dashing:
		push_error("Player is already dashing.")
		return
	
	is_dashing = true

	dash_direction = direction.normalized()

	if dash_direction.is_zero_approx():
		push_error("Dash direction is zero. Defaulting to facing direction.")
		dash_direction = facing_direction.normalized()
	
	dash_speed = speed

	await get_tree().create_timer(duration).timeout

	is_dashing = false
	velocity.x = 0  # Stop horizontal movement after dash
