extends SceneTree

const PLAYER_SCENE := "res://entities/player/Player.tscn"
const DASH_SCENE := "res://spells/dash/DashScene.tscn"
const TICK := 1.0 / 60.0
const DASH_SPEED := 500.0
const DASH_DURATION := 0.3
const WALK_SPEED := 400.0
## Largest per-tick change in horizontal speed allowed around a dash. The old
## dash dropped 500 -> 0 in one tick when it ended.
const MAX_SPEED_STEP := 120.0

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_component_profile_from_standstill()
	_test_component_profile_from_walking()
	_test_component_never_slows_a_faster_body()
	_test_component_cancel_and_rejection()
	await _test_player_dash_hands_off_speed()
	await _test_player_dash_returns_when_finished()
	await _test_player_dash_cancelled_by_knockback()
	await _test_dash_spell_scene_is_unchanged()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: dash (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_component_profile_from_standstill() -> void:
	var dash := DashMovementComponent.new()
	var finished_count := [0]
	dash.dash_finished.connect(func() -> void: finished_count[0] += 1)

	_check(
		dash.begin(Vector2.RIGHT, DASH_SPEED, DASH_DURATION, Vector2.ZERO, WALK_SPEED),
		"A valid dash must begin."
	)
	var speeds := _run_dash(dash)

	_check(speeds.size() == roundi(DASH_DURATION / TICK), "A dash must last its duration in physics ticks.")
	_check(speeds[0] > 0.0, "A dash must move on its first tick.")
	_check(speeds.max() >= DASH_SPEED - 0.01, "A dash must reach its dash speed.")
	_check(
		is_equal_approx(speeds[speeds.size() - 1], WALK_SPEED),
		"A dash must end at the hand-off speed, not at zero."
	)
	_check(not dash.is_active(), "A dash must finish after its duration.")
	_check(finished_count[0] == 1, "A dash must report finishing exactly once.")
	_check(dash.calculate_velocity(TICK) == Vector2.ZERO, "A finished dash must not move the body.")

	dash.free()


func _test_component_profile_from_walking() -> void:
	var dash := DashMovementComponent.new()
	dash.begin(
		Vector2.RIGHT,
		DASH_SPEED,
		DASH_DURATION,
		Vector2(WALK_SPEED, 0.0),
		WALK_SPEED
	)
	var speeds := _run_dash(dash)

	_check(
		speeds.min() >= WALK_SPEED - 0.01,
		"Dashing while walking must never drop below walking speed."
	)
	_check(
		_largest_step(WALK_SPEED, speeds) <= MAX_SPEED_STEP,
		"Entering and leaving a dash from walking speed must be smooth (largest step %.1f)."
		% _largest_step(WALK_SPEED, speeds)
	)

	dash.free()


func _test_component_never_slows_a_faster_body() -> void:
	var dash := DashMovementComponent.new()
	var entry_speed := 700.0
	dash.begin(Vector2.LEFT, DASH_SPEED, DASH_DURATION, Vector2(-entry_speed, 0.0), WALK_SPEED)
	var first_velocity := dash.calculate_velocity(TICK)

	_check(first_velocity.x < 0.0, "A dash must move in its direction.")
	_check(
		absf(first_velocity.x) >= entry_speed - 0.01,
		"A dash must not brake a body that already moves faster than the dash."
	)

	dash.cancel()
	dash.free()


func _test_component_cancel_and_rejection() -> void:
	var dash := DashMovementComponent.new()
	var finished_count := [0]
	dash.dash_finished.connect(func() -> void: finished_count[0] += 1)

	dash.begin(Vector2.RIGHT, DASH_SPEED, DASH_DURATION, Vector2.ZERO, WALK_SPEED)
	_check(
		not dash.begin(Vector2.LEFT, DASH_SPEED, DASH_DURATION, Vector2.ZERO, WALK_SPEED),
		"A second dash must be rejected while one is active."
	)
	_check(dash.get_direction() == Vector2.RIGHT, "A rejected dash must not change the active one.")

	dash.cancel()
	dash.cancel()
	_check(not dash.is_active(), "Cancelling must end the dash.")
	_check(finished_count[0] == 1, "Cancelling must report finishing once, even when repeated.")

	dash.free()


func _test_player_dash_hands_off_speed() -> void:
	var player := await _spawn_player()
	player.velocity = Vector2(WALK_SPEED, 0.0)
	player.begin_dash(Vector2.RIGHT, DASH_SPEED, DASH_DURATION)

	var speeds: Array[float] = []
	var dash_ticks := 0
	while player.is_dashing and dash_ticks < 60:
		await physics_frame
		dash_ticks += 1
		speeds.append(player.velocity.x)

	# A few ticks of normal movement after the dash, with no input held.
	for tick in 6:
		await physics_frame
		speeds.append(player.velocity.x)

	_check(not player.is_dashing, "The player's dash must end.")
	_check(
		_largest_step(WALK_SPEED, speeds) <= MAX_SPEED_STEP,
		"The player's speed must change smoothly through the dash (largest step %.1f)."
		% _largest_step(WALK_SPEED, speeds)
	)
	_check(
		speeds[speeds.size() - 1] > 0.0,
		"The player must keep some momentum right after a dash instead of stopping dead."
	)
	_check(
		speeds[speeds.size() - 1] < WALK_SPEED,
		"Without input, normal movement must slow the player after the dash."
	)

	await _free_node(player)


func _test_player_dash_returns_when_finished() -> void:
	var player := await _spawn_player()
	var ticks := [0]
	var count_tick := func() -> void: ticks[0] += 1
	physics_frame.connect(count_tick)

	await player.begin_dash(Vector2.RIGHT, DASH_SPEED, 0.1)
	physics_frame.disconnect(count_tick)

	_check(not player.is_dashing, "begin_dash must return after the dash ends.")
	_check(
		ticks[0] >= roundi(0.1 / TICK),
		"begin_dash must wait for the dash's physics ticks before returning (%d ticks)." % ticks[0]
	)

	await _free_node(player)


func _test_player_dash_cancelled_by_knockback() -> void:
	var player := await _spawn_player()
	var knockback: KnockbackComponent = player.get_node("Knockback")
	var returned := [false]
	var dash_call := func() -> void:
		await player.begin_dash(Vector2.RIGHT, DASH_SPEED, 5.0)
		returned[0] = true

	dash_call.call()
	await physics_frame
	knockback.begin_knockback(Vector2.LEFT, 300.0, 0.2)
	await physics_frame
	await physics_frame

	_check(not player.is_dashing, "Knockback must cancel an active dash.")
	_check(returned[0], "An interrupted dash must still return to its caller.")

	await _free_node(player)


func _test_dash_spell_scene_is_unchanged() -> void:
	var spell := (load(DASH_SCENE) as PackedScene).instantiate() as DashSpell
	_check(is_equal_approx(spell.duration, DASH_DURATION), "The Dash spell must keep its 0.3 s duration.")
	_check(spell.move_speed_multiplier > 1.0, "The Dash spell must stay faster than walking.")
	spell.free()


func _run_dash(dash: DashMovementComponent) -> Array[float]:
	var speeds: Array[float] = []
	var guard := 0
	while dash.is_active() and guard < 600:
		speeds.append(dash.calculate_velocity(TICK).length())
		guard += 1
	return speeds


func _largest_step(start: float, speeds: Array[float]) -> float:
	var largest := 0.0
	var previous := start
	for speed in speeds:
		largest = maxf(largest, absf(speed - previous))
		previous = speed
	return largest


func _spawn_player() -> CharacterBody2D:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as CharacterBody2D
	player.position = Vector2(0.0, -5000.0)
	root.add_child(player)
	await process_frame
	return player


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
