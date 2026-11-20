extends SceneTree

# BreakableShield on its own and through Health: breaking it within the
# window, refilling when the window runs out, regenerating after a quiet
# period, and Health only taking damage once it is broken.

const SHIELD_MAXIMUM := 40.0
const BREAK_WINDOW := 0.3
const REGEN_DELAY := 0.4

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_intact_shield_protects_health()
	await _test_burst_breaks_shield_and_overflow_hurts()
	await _test_window_expiry_refills_shield()
	await _test_broken_shield_lets_damage_through()
	await _test_regenerates_after_quiet_period()
	await _test_hits_while_broken_delay_regeneration()
	await _test_health_reset_restores_shield()
	await _test_health_without_shield_is_unchanged()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: breakable shield (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_intact_shield_protects_health() -> void:
	var setup := await _spawn()
	var health: Health = setup[0]
	var shield: BreakableShield = setup[1]
	var hits := [0.0]
	shield.hit.connect(func(absorbed: float) -> void: hits[0] += absorbed)

	health.take_damage(25.0)

	_check(is_equal_approx(health.current, 100.0), "An intact shield must keep damage off Health.")
	_check(is_equal_approx(shield.current, 15.0), "The shield must lose what it absorbed.")
	_check(is_equal_approx(hits[0], 25.0), "The shield must report the absorbed damage.")
	_check(not shield.is_broken(), "Less than the maximum must not break the shield.")

	await _free(health)


func _test_burst_breaks_shield_and_overflow_hurts() -> void:
	var setup := await _spawn()
	var health: Health = setup[0]
	var shield: BreakableShield = setup[1]
	var broken := [0]
	shield.broken.connect(func() -> void: broken[0] += 1)

	health.take_damage(25.0)
	health.take_damage(25.0)

	_check(shield.is_broken(), "Dealing the maximum within the window must break the shield.")
	_check(broken[0] == 1, "Breaking must emit broken once.")
	_check(is_equal_approx(health.current, 90.0), "Damage beyond the shield must reach Health.")

	await _free(health)


func _test_window_expiry_refills_shield() -> void:
	var setup := await _spawn()
	var health: Health = setup[0]
	var shield: BreakableShield = setup[1]

	health.take_damage(25.0)
	await create_timer(BREAK_WINDOW + 0.15).timeout

	_check(is_equal_approx(shield.current, SHIELD_MAXIMUM), "The shield must refill when the window runs out.")

	health.take_damage(25.0)

	_check(not shield.is_broken(), "Damage from an expired window must not count toward breaking.")
	_check(is_equal_approx(health.current, 100.0), "Health must stay untouched.")

	await _free(health)


func _test_broken_shield_lets_damage_through() -> void:
	var setup := await _spawn()
	var health: Health = setup[0]
	var shield: BreakableShield = setup[1]

	health.take_damage(SHIELD_MAXIMUM)
	health.take_damage(10.0)

	_check(shield.is_broken(), "The exact maximum must break the shield.")
	_check(is_equal_approx(health.current, 90.0), "A broken shield must let hits reach Health directly.")

	await _free(health)


func _test_regenerates_after_quiet_period() -> void:
	var setup := await _spawn()
	var health: Health = setup[0]
	var shield: BreakableShield = setup[1]
	var restored := [0]
	shield.restored.connect(func() -> void: restored[0] += 1)

	health.take_damage(SHIELD_MAXIMUM)
	await create_timer(REGEN_DELAY * 0.5).timeout

	_check(shield.is_broken(), "The shield must stay broken before the regen delay.")

	await create_timer(REGEN_DELAY * 0.5 + 0.15).timeout

	_check(not shield.is_broken(), "The shield must regenerate after the delay without hits.")
	_check(is_equal_approx(shield.current, SHIELD_MAXIMUM), "It must come back at full strength.")
	_check(restored[0] == 1, "Regenerating must emit restored once.")

	await _free(health)


func _test_hits_while_broken_delay_regeneration() -> void:
	var setup := await _spawn()
	var health: Health = setup[0]
	var shield: BreakableShield = setup[1]

	health.take_damage(SHIELD_MAXIMUM)

	for i in 3:
		await create_timer(REGEN_DELAY * 0.6).timeout
		health.take_damage(1.0)

	_check(shield.is_broken(), "Hits while broken must keep delaying the regeneration.")

	await create_timer(REGEN_DELAY + 0.15).timeout

	_check(not shield.is_broken(), "Once the hits stop, the shield must regenerate.")

	await _free(health)


func _test_health_reset_restores_shield() -> void:
	var setup := await _spawn()
	var health: Health = setup[0]
	var shield: BreakableShield = setup[1]

	health.take_damage(SHIELD_MAXIMUM + 30.0)
	health.reset()

	_check(not shield.is_broken(), "Health.reset() must restore the shield.")
	_check(is_equal_approx(shield.current, SHIELD_MAXIMUM), "The restored shield must be full.")
	_check(is_equal_approx(health.current, 100.0), "Health.reset() must still restore health.")

	await _free(health)


func _test_health_without_shield_is_unchanged() -> void:
	var health := Health.new()
	health.maximum = 100.0
	root.add_child(health)
	await process_frame

	health.take_damage(25.0)

	_check(is_equal_approx(health.current, 75.0), "Health without a breakable shield must take damage directly.")

	await _free(health)


func _spawn() -> Array:
	var health := Health.new()
	var shield := BreakableShield.new()

	health.maximum = 100.0
	shield.maximum = SHIELD_MAXIMUM
	shield.break_window = BREAK_WINDOW
	shield.regen_delay = REGEN_DELAY
	health.breakable_shield = shield
	health.add_child(shield)
	root.add_child(health)
	await process_frame

	return [health, shield]


func _free(node: Node) -> void:
	node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
