extends SceneTree

const MOB_SCENE: PackedScene = preload(
	"res://entities/enemies/Skeletons/basic skeleton/basic_skeleton.tscn"
)

const PHYSICS_SETTLE_FRAMES := 4
const STATE_IDLE := BasicMob.State.IDLE
const STATE_CHASE := BasicMob.State.CHASE
const STATE_ATTACK := BasicMob.State.ATTACK

var _failures: Array[String] = []
var _test_world: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_idle_ignores_ungrouped_bodies()
	await _test_grouped_player_is_acquired_and_chased()
	await _test_leaving_aggro_stops_the_mob()
	await _test_attack_range_and_post_attack_chase()
	await _test_leaving_aggro_during_attack_returns_to_idle()
	await _test_repeated_attacks_respect_recovery()
	await _test_multiple_mobs_operate_independently()

	if _failures.is_empty():
		print("PASS: initial mob behavior (7 tests)")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("FAIL: initial mob behavior (%d failure(s))" % _failures.size())
	quit(1)


func _test_idle_ignores_ungrouped_bodies() -> void:
	_start_test_world()
	var mob := _spawn_mob(Vector2.ZERO)
	var decoy := _spawn_target(Vector2(100.0, 0.0), false, "NotThePlayer")
	var far_player := _spawn_target(Vector2(900.0, 0.0), true, "FarAwayHero")
	await _wait_physics_frames(PHYSICS_SETTLE_FRAMES)

	_expect(mob.state == STATE_IDLE, "mob must begin idle before player aggro")
	_expect(mob.target == null, "mob must ignore bodies outside the player group")
	_expect(mob.animated_sprite.animation == &"idle", "idle mob must show idle animation")
	_expect(is_zero_approx(mob.velocity.x), "idle mob must have no horizontal velocity")
	_expect(decoy != far_player, "test setup must contain distinct target bodies")
	await _finish_test_world()


func _test_grouped_player_is_acquired_and_chased() -> void:
	_start_test_world()
	var mob := _spawn_mob(Vector2.ZERO)
	var nested_container := Node2D.new()
	nested_container.name = "ArbitrarySceneBranch"
	_test_world.add_child(nested_container)
	var player := _make_target(Vector2(400.0, 0.0), true, "RenamedHero")
	nested_container.add_child(player)
	await _wait_physics_frames(PHYSICS_SETTLE_FRAMES)

	_expect(mob.target == player, "mob must acquire the body identified by the player group")
	_expect(mob.state == STATE_CHASE, "entering aggro range must enter CHASE")
	_expect(mob.velocity.x > 0.0, "mob must chase horizontally toward a player on its right")
	_expect(mob.animated_sprite.animation == &"walk", "chasing mob must show walk animation")
	_expect(mob.facing_direction.x > 0.0, "chasing mob must face its movement direction")
	await _finish_test_world()


func _test_leaving_aggro_stops_the_mob() -> void:
	_start_test_world()
	var mob := _spawn_mob(Vector2.ZERO)
	var player := _spawn_target(Vector2(400.0, 0.0), true)
	await _wait_physics_frames(8)
	_expect(mob.state == STATE_CHASE, "test setup must put mob in CHASE")

	player.global_position = mob.global_position + Vector2(1000.0, 0.0)
	await _wait_until(func() -> bool: return mob.state == STATE_IDLE and mob.target == null, 30)
	await _wait_physics_frames(20)
	var stopped_position := mob.global_position.x
	await _wait_physics_frames(5)

	_expect(mob.state == STATE_IDLE, "leaving aggro range must return mob to IDLE")
	_expect(mob.target == null, "leaving aggro range must clear the target")
	_expect(absf(mob.velocity.x) < 0.01, "idle mob must decelerate to a stop")
	_expect(
		absf(mob.global_position.x - stopped_position) < 0.1,
		"mob must remain at its current position after losing aggro"
	)
	await _finish_test_world()


func _test_attack_range_and_post_attack_chase() -> void:
	_start_test_world()
	var mob := _spawn_mob(Vector2.ZERO)
	var player := _spawn_target(Vector2(20.0, 0.0), true)
	var finish_observation := {
		"idle_state": false,
		"idle_animation": false,
	}
	mob.melee_attack.attack_finished.connect(func() -> void:
		finish_observation.idle_state = mob.state == STATE_IDLE
		finish_observation.idle_animation = mob.animated_sprite.animation == &"idle"
	)
	await _wait_until(func() -> bool: return mob.state == STATE_ATTACK, 20)

	_expect(mob.melee_attack.is_attacking(), "entering attack range must begin an attack")
	_expect(mob.animated_sprite.animation == &"attack", "attack state must show attack animation")
	player.global_position = Vector2(400.0, 0.0)
	await _wait_until(func() -> bool: return finish_observation.idle_state, 120)
	await _wait_physics_frames(2)

	_expect(finish_observation.idle_state, "attack completion must transition through IDLE")
	_expect(
		finish_observation.idle_animation,
		"attack completion must immediately restore the idle animation"
	)
	_expect(mob.state == STATE_CHASE, "player outside attack range but in aggro must resume CHASE")
	_expect(mob.velocity.x > 0.0, "mob must resume moving toward the player after attack")
	await _finish_test_world()


func _test_leaving_aggro_during_attack_returns_to_idle() -> void:
	_start_test_world()
	var mob := _spawn_mob(Vector2.ZERO)
	var player := _spawn_target(Vector2(20.0, 0.0), true)
	await _wait_until(func() -> bool: return mob.state == STATE_ATTACK, 20)
	player.global_position = Vector2(1000.0, 0.0)
	await _wait_until(func() -> bool: return not mob.melee_attack.is_attacking(), 120)
	await _wait_physics_frames(3)

	_expect(mob.state == STATE_IDLE, "leaving aggro during attack must end in IDLE")
	_expect(mob.target == null, "leaving aggro during attack must clear the target")
	_expect(mob.animated_sprite.animation == &"idle", "completed attack outside aggro must show idle")
	await _finish_test_world()


func _test_repeated_attacks_respect_recovery() -> void:
	_start_test_world()
	var mob := _spawn_mob(Vector2.ZERO)
	mob.melee_attack.windup_duration = 0.05
	mob.melee_attack.active_duration = 0.05
	mob.melee_attack.recovery_duration = 0.08
	var player := _spawn_target(Vector2(20.0, 0.0), true)
	var attack_start_frames: Array[int] = []
	mob.melee_attack.attack_started.connect(func(_direction: Vector2) -> void:
		attack_start_frames.append(Engine.get_process_frames())
	)
	await _wait_until(func() -> bool: return attack_start_frames.size() >= 3, 120)

	_expect(player.is_in_group(&"player"), "repeated attack target must remain a player")
	_expect(attack_start_frames.size() >= 3, "player remaining in range must allow repeated attacks")
	if attack_start_frames.size() >= 3:
		var first_interval := attack_start_frames[1] - attack_start_frames[0]
		var second_interval := attack_start_frames[2] - attack_start_frames[1]
		_expect(first_interval >= 9, "recovery must prevent an immediate second attack")
		_expect(second_interval >= 9, "recovery must prevent attacks on consecutive frames")
	await _finish_test_world()


func _test_multiple_mobs_operate_independently() -> void:
	_start_test_world()
	var left_mob := _spawn_mob(Vector2(-300.0, 0.0))
	var right_mob := _spawn_mob(Vector2(300.0, 0.0))
	var player := _spawn_target(Vector2.ZERO, true)
	await _wait_physics_frames(8)

	_expect(left_mob.target == player, "left mob must independently acquire player")
	_expect(right_mob.target == player, "right mob must independently acquire player")
	_expect(left_mob.state == STATE_CHASE, "left mob must independently enter CHASE")
	_expect(right_mob.state == STATE_CHASE, "right mob must independently enter CHASE")
	_expect(left_mob.velocity.x > 0.0, "left mob must chase right toward player")
	_expect(right_mob.velocity.x < 0.0, "right mob must chase left toward player")
	_expect(left_mob.facing_direction.x > 0.0, "left mob must face its own chase direction")
	_expect(right_mob.facing_direction.x < 0.0, "right mob must face its own chase direction")
	await _finish_test_world()


func _start_test_world() -> void:
	_test_world = Node2D.new()
	_test_world.name = "InitialMobTestWorld"
	root.add_child(_test_world)


func _finish_test_world() -> void:
	_test_world.queue_free()
	await process_frame
	await physics_frame
	_test_world = null


func _spawn_mob(position: Vector2) -> BasicMob:
	var mob := MOB_SCENE.instantiate() as BasicMob
	mob.position = position
	_test_world.add_child(mob)
	mob.gravity.rise_gravity_multiplier = 0.0
	mob.gravity.fall_gravity_multiplier = 0.0
	return mob


func _spawn_target(
	position: Vector2,
	is_player: bool,
	name_override: String = "TestTarget"
) -> CharacterBody2D:
	var target := _make_target(position, is_player, name_override)
	_test_world.add_child(target)
	return target


func _make_target(
	position: Vector2,
	is_player: bool,
	name_override: String
) -> CharacterBody2D:
	var target := CharacterBody2D.new()
	target.name = name_override
	target.position = position
	target.collision_layer = 4
	target.collision_mask = 0
	if is_player:
		target.add_to_group(&"player")

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	collision.shape = shape
	target.add_child(collision)
	return target


func _wait_physics_frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _wait_until(predicate: Callable, maximum_frames: int) -> void:
	for _index in maximum_frames:
		if predicate.call():
			return
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
