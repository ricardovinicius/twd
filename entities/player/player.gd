extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var horizontal_movement: HorizontalMovementComponent = $HorizontalMovement
@onready var coyote_time: CoyoteTimeComponent = $CoyoteTimer
@onready var variable_jump_height: VariableJumpHeightComponent = $VariableJumpHeight
@onready var jump_buffer: JumpBufferComponent = $JumpBufferTimer
@onready var jump_down: JumpDownComponent = $JumpDown
@onready var spell_jump: SpellJumpComponent = $SpellJump
@onready var gravity: GravityComponent = $Gravity
@onready var knockback: KnockbackComponent = $Knockback
@onready var rigid_body_push: CharacterRigidBodyPushComponent = $RigidBodyPush
@onready var health: Health = $Health
@onready var inventory: Inventory = $Inventory

@export var jump_velocity = -1050.0
@export var facing_direction: Vector2 = Vector2.RIGHT

var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_speed: float = 0.0
var _is_playing_hit_animation: bool = false
var _dash_generation: int = 0

# Posição inicial do jogador
var spawn_point: Vector2

# Posição do último checkpoint ativado
var checkpoint_position: Vector2

var has_checkpoint: bool = false


func _ready() -> void:
	# Guarda a posição inicial do Player
	spawn_point = global_position
	checkpoint_position = spawn_point
	has_checkpoint = false

	print("PLAYER _READY")
	print("SPAWN INICIAL: ", spawn_point)

	health.damaged.connect(_on_health_damaged)
	health.depleted.connect(_on_health_depleted)
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()
	var is_being_knocked_back := knockback.is_active()

	if Input.is_action_just_pressed("jump"):
		_handle_jump_input()

	if is_being_knocked_back:
		_cancel_dash()
		_apply_knockback_movement(delta)
	elif not is_dashing:
		_apply_normal_movement(delta)
	else:
		_apply_dash_movement()

	coyote_time.update_floor_state(was_on_floor, is_on_floor())

	if not is_dashing and not is_being_knocked_back:
		_try_jump()


func _apply_normal_movement(delta: float) -> void:
	_update_movement_animation()

	if not is_on_floor():
		velocity = gravity.calculate_velocity(
			velocity,
			get_gravity(),
			delta
		)

	_try_jump()

	var direction := Input.get_axis("left", "right")

	if direction:
		facing_direction = Vector2(direction, 0.0)

	velocity.x = horizontal_movement.calculate_velocity(
		velocity.x,
		direction,
		delta
	)

	_move_and_slide_with_rigid_body_push()

	if direction == 1.0:
		animated_sprite_2d.flip_h = false
	elif direction == -1.0:
		animated_sprite_2d.flip_h = true


func _try_jump() -> void:
	if jump_down.is_active():
		return

	if not jump_buffer.is_jump_buffered():
		return

	if not coyote_time.can_jump(is_on_floor()):
		return

	velocity.y = jump_velocity
	jump_buffer.consume_jump()
	coyote_time.consume_jump()
	_play_animation(&"jump")

	if not Input.is_action_pressed("jump"):
		velocity.y = variable_jump_height.cut_jump(velocity.y)


func _handle_jump_input() -> void:
	if jump_down.is_active():
		return

	if jump_down.is_requested() and jump_down.begin(is_on_floor()):
		jump_buffer.consume_jump()
		coyote_time.consume_jump()
		return

	jump_buffer.buffer_jump()


func _apply_dash_movement() -> void:
	velocity = dash_direction * dash_speed
	velocity.y = 0

	_play_animation(&"jump")
	_move_and_slide_with_rigid_body_push()


func _apply_knockback_movement(delta: float) -> void:
	_play_hit_animation()

	if not is_on_floor():
		velocity = gravity.calculate_velocity(
			velocity,
			get_gravity(),
			delta
		)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	velocity.x = knockback.calculate_horizontal_velocity(delta)
	_move_and_slide_with_rigid_body_push()


func _move_and_slide_with_rigid_body_push() -> void:
	var intended_velocity := velocity
	move_and_slide()
	rigid_body_push.push_slide_collisions(intended_velocity)


func _update_movement_animation() -> void:
	if not is_on_floor() or velocity.y < 0.0:
		_play_animation(&"jump")
	elif absf(velocity.x) > 1.0:
		_play_animation(&"walk")
	else:
		_play_animation(&"idle")


func _play_animation(animation_name: StringName) -> void:
	if _is_playing_hit_animation and animation_name != &"hit":
		return

	if animated_sprite_2d.animation == animation_name:
		return

	animated_sprite_2d.play(animation_name)


func _play_hit_animation(restart: bool = false) -> void:
	if _is_playing_hit_animation and not restart:
		return

	_is_playing_hit_animation = true
	animated_sprite_2d.play(&"hit")
	animated_sprite_2d.set_frame_and_progress(0, 0.0)


func _on_health_damaged(amount: float) -> void:
	if amount <= 0.0:
		return

	_play_hit_animation(true)


func _on_health_depleted() -> void:
	print("PLAYER MORREU")

	Events.player_died.emit()

	spawn_player()


func _on_animation_finished() -> void:
	if animated_sprite_2d.animation == &"hit":
		_is_playing_hit_animation = false


func try_spell_jump() -> bool:
	_cancel_dash()
	jump_down.cancel()

	if not spell_jump.jump():
		return false

	_play_animation(&"jump")
	return true


func begin_dash(direction: Vector2, speed: float, duration: float) -> void:
	if is_dashing:
		push_error("Player is already dashing.")
		return

	_dash_generation += 1
	var generation := _dash_generation
	is_dashing = true

	dash_direction = direction.normalized()

	if dash_direction.is_zero_approx():
		push_error("Dash direction is zero. Defaulting to facing direction.")
		dash_direction = facing_direction.normalized()

	dash_speed = speed

	await get_tree().create_timer(duration).timeout

	if generation != _dash_generation:
		return

	is_dashing = false
	velocity.x = 0


func _cancel_dash() -> void:
	if not is_dashing:
		return

	_dash_generation += 1
	is_dashing = false
	dash_direction = Vector2.ZERO
	dash_speed = 0.0


# ============================================================
# CHECKPOINT
# ============================================================

func collect_item(item: ItemDefinition, amount: int = 1) -> void:
	inventory.add_item(item, amount)
	Events.item_collected.emit(item, inventory.get_quantity(item))

func set_checkpoint(pos: Vector2) -> void:
	checkpoint_position = pos
	has_checkpoint = true

	print("CHECKPOINT SALVO EM: ", checkpoint_position)


func spawn_player() -> void:
	print("RESPAWNANDO...")

	if has_checkpoint:
		print("VOLTANDO PARA CHECKPOINT: ", checkpoint_position)
		global_position = checkpoint_position
	else:
		print("NENHUM CHECKPOINT. VOLTANDO PARA SPAWN INICIAL: ", spawn_point)
		global_position = spawn_point

	velocity = Vector2.ZERO

	health.reset()

	var camera := $Camera2D as Camera2D

	if camera:
		camera.reset_smoothing()

	print("PLAYER AGORA ESTÁ EM: ", global_position)
