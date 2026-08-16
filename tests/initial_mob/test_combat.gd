extends SceneTree

const ATTACK_DATA_SCRIPT = preload("res://spells/attack/core/attack_data.gd")
const ATTACK_HITBOX_SCRIPT = preload("res://components/attack_reactions/attack_hitbox.gd")
const ATTACK_RECEIVER_SCRIPT = preload("res://components/attack_reactions/attack_receiver.gd")
const HEALTH_DAMAGE_REACTION_SCRIPT = preload(
	"res://components/attack_reactions/health/health_damage_reaction.gd"
)
const HEALTH_SCRIPT = preload("res://health/health.gd")
const MELEE_ATTACK_SCRIPT = preload("res://components/attack_reactions/melee_attack_component.gd")
const AIM_INPUT_SCRIPT = preload("res://components/input/aim_input_component.gd")
const SKELETON_SCENE = preload(
	"res://entities/enemies/basic_skeleton/BasicSkeleton.tscn"
)
const MAGIC_ARROW_SCENE = preload(
	"res://spells/attack/magic_arrow/MagicArrowProjectile.tscn"
)
const MAGIC_ARROW_SPELL_SCENE = preload(
	"res://spells/attack/magic_arrow/MagicArrowSpell.tscn"
)

const ATTACK_RECEIVER_LAYER := 1 << 4
const WORLD_LAYER := 1 << 0

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await process_frame

	await _test_attack_reaction_pipeline()
	_test_analog_projectile_aim()
	await _test_melee_timing_single_hit_miss_and_recovery()
	await _test_magic_arrow_hits_mob_receiver()
	await _test_mob_health_and_death()
	await _test_projectile_world_collision()
	await _test_projectile_lifetime()

	if _failures.is_empty():
		print("PASS: initial mob combat (%d checks)" % _checks)
		quit(0)
		return

	for failure in _failures:
		push_error("FAIL: %s" % failure)
	print("FAIL: initial mob combat (%d failures, %d checks)" % [_failures.size(), _checks])
	quit(1)


func _test_analog_projectile_aim() -> void:
	var aim_input := AIM_INPUT_SCRIPT.new()
	Input.action_press(&"right", 0.8)
	Input.action_press(&"aim_up", 0.6)

	var analog_direction: Vector2 = aim_input.get_direction()
	_check_equal(
		analog_direction,
		Vector2.RIGHT,
		"analog aim snaps a diagonal toward its dominant horizontal axis"
	)

	Input.action_release(&"right")
	Input.action_release(&"aim_up")
	Input.action_press(&"right", 0.6)
	Input.action_press(&"aim_up", 0.8)
	_check_equal(
		aim_input.get_direction(),
		Vector2.UP,
		"analog aim snaps a diagonal toward its dominant vertical axis"
	)
	Input.action_release(&"right")
	Input.action_release(&"aim_up")

	_check_equal(
		aim_input.get_direction(Vector2.LEFT),
		Vector2.LEFT,
		"neutral analog aim falls back to facing direction"
	)
	aim_input.free()

	var spell := MAGIC_ARROW_SPELL_SCENE.instantiate()
	var context := SpellContext.new()
	context.direction = Vector2.LEFT
	context.aim_direction = Vector2.UP
	spell.context = context
	_check_equal(
		spell._get_projectile_direction(),
		Vector2.UP,
		"Magic Arrow uses analog aim instead of player facing"
	)
	spell.free()


func _test_attack_reaction_pipeline() -> void:
	var fixture := _make_damage_receiver_fixture(40.0)
	root.add_child(fixture.root)
	await process_frame

	var source := Node2D.new()
	fixture.root.add_child(source)
	var attack := _make_attack(source, 7.0, &"melee")
	var received_attacks: Array[AttackData] = []
	fixture.receiver.attack_received.connect(
		func(received: AttackData) -> void: received_attacks.append(received)
	)

	fixture.receiver.receive_attack(attack)

	_check_equal(fixture.health.current, 33.0, "AttackReceiver routes damage to Health")
	_check_equal(received_attacks.size(), 1, "handled attack emits attack_received once")
	if not received_attacks.is_empty():
		_check_true(
			received_attacks[0] == attack,
			"attack pipeline preserves the original AttackData instance"
		)

	await _free_fixture(fixture.root)


func _test_melee_timing_single_hit_miss_and_recovery() -> void:
	var world := Node2D.new()
	world.name = "MeleeTimingFixture"
	root.add_child(world)

	var source := Node2D.new()
	source.name = "MobSource"
	world.add_child(source)

	var visual := Node2D.new()
	visual.name = "Visual"
	source.add_child(visual)

	var hitbox := ATTACK_HITBOX_SCRIPT.new()
	hitbox.name = "AttackHitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = ATTACK_RECEIVER_LAYER
	hitbox.monitorable = false
	hitbox.add_child(_make_collision_shape(Vector2(24.0, 24.0)))

	var melee := MELEE_ATTACK_SCRIPT.new()
	melee.name = "MeleeAttack"
	melee.damage = 10.0
	melee.windup_duration = 0.05
	melee.active_duration = 0.04
	melee.recovery_duration = 0.06
	melee.windup_distance = 0.0
	melee.lunge_distance = 0.0
	melee.attack_hitbox = hitbox
	melee.visual = visual
	melee.add_child(hitbox)
	source.add_child(melee)

	var target := _make_damage_receiver_fixture(50.0)
	target.root.name = "MeleeTarget"
	world.add_child(target.root)
	await _wait_physics_frames(2)

	_check_true(melee.begin_attack(source, Vector2.RIGHT), "first melee attack can begin")
	# Advance phases explicitly so assertions are independent of host frame rate.
	melee.set_process(false)
	melee._process(melee.windup_duration - 0.001)
	await process_frame
	_check_equal(target.health.current, 50.0, "melee cannot damage during windup")

	melee._process(0.002)
	await process_frame
	_check_equal(target.health.current, 40.0, "melee damages during its active moment")

	# Re-evaluating an active overlap must not damage the same receiver again.
	hitbox._damage_current_overlaps()
	hitbox._damage_current_overlaps()
	_check_equal(target.health.current, 40.0, "one swing damages a receiver at most once")
	_check_false(melee.begin_attack(source, Vector2.RIGHT), "active attack blocks another attack")

	melee._process(melee.active_duration + 0.001)
	_check_false(melee.begin_attack(source, Vector2.RIGHT), "recovery blocks another attack")
	melee._process(melee.recovery_duration + 0.001)
	_check_false(melee.is_attacking(), "melee becomes ready after recovery")

	# Begin another committed swing, then leave before its active moment.
	_check_true(melee.begin_attack(source, Vector2.RIGHT), "attack can restart after recovery")
	melee.set_process(false)
	target.root.global_position = Vector2(200.0, 0.0)
	await _wait_physics_frames(2)
	melee._process(melee.windup_duration + 0.001)
	await process_frame
	_check_equal(target.health.current, 40.0, "leaving the hitbox before active timing misses")

	await _free_fixture(world)


func _test_magic_arrow_hits_mob_receiver() -> void:
	var world := Node2D.new()
	world.name = "MagicArrowMobFixture"
	root.add_child(world)

	var source := Node2D.new()
	source.name = "ArrowCaster"
	world.add_child(source)

	var mob := SKELETON_SCENE.instantiate()
	mob.name = "ProjectileTargetMob"
	mob.position = Vector2(120.0, 0.0)
	world.add_child(mob)
	await process_frame
	# Keep the target fixed while retaining active physics monitoring on its receiver.
	mob.set_physics_process(false)

	var health: Health = mob.get_node("Health")
	var projectile := MAGIC_ARROW_SCENE.instantiate()
	projectile.name = "ReceiverTestArrow"
	projectile.debug_collisions = false
	world.add_child(projectile)
	await process_frame
	projectile.launch(Vector2.ZERO, Vector2.RIGHT, _make_attack(source, 10.0, &"magic_arrow"), 360.0, 1.0)
	var projectile_ref: WeakRef = weakref(projectile)

	await _wait_until(func() -> bool: return health.current < health.maximum, 90)
	_check_equal(health.current, 40.0, "Magic Arrow damages the mob through AttackReceiver")
	_check_equal(
		projectile.collision_mask & 4,
		0,
		"Magic Arrow does not treat the mob entity layer as a world body"
	)
	await _wait_until(func() -> bool: return projectile_ref.get_ref() == null, 10)
	_check_true(projectile_ref.get_ref() == null, "Magic Arrow is consumed after receiver hit")

	await _free_fixture(world)


func _test_mob_health_and_death() -> void:
	var world := Node2D.new()
	world.name = "MobDeathFixture"
	root.add_child(world)

	var source := Node2D.new()
	world.add_child(source)
	var mob := SKELETON_SCENE.instantiate()
	world.add_child(mob)
	await process_frame
	mob.set_physics_process(false)

	var health: Health = mob.get_node("Health")
	var receiver: AttackReceiver = mob.get_node("AttackReceiver")
	_check_equal(health.maximum, 50.0, "mob scene exposes configured maximum health")
	_check_equal(health.current, 50.0, "mob health starts full")

	receiver.receive_attack(_make_attack(source, 10.0, &"magic_arrow"))
	_check_equal(health.current, 40.0, "mob receiver applies non-lethal damage")
	receiver.receive_attack(_make_attack(source, 40.0, &"magic_arrow"))
	_check_true(mob.is_queued_for_deletion(), "depleted mob queues itself for deletion")
	await process_frame
	_check_false(is_instance_valid(mob), "depleted mob is removed from the scene")

	await _free_fixture(world)


func _test_projectile_world_collision() -> void:
	var world := Node2D.new()
	world.name = "ProjectileWorldCollisionFixture"
	root.add_child(world)

	var source := Node2D.new()
	world.add_child(source)
	var target := _make_damage_receiver_fixture(25.0)
	target.root.position = Vector2(140.0, 0.0)
	world.add_child(target.root)

	var wall := StaticBody2D.new()
	wall.name = "WorldObstacle"
	wall.position = Vector2(70.0, 0.0)
	wall.collision_layer = WORLD_LAYER
	wall.collision_mask = 0
	wall.add_child(_make_collision_shape(Vector2(10.0, 80.0)))
	world.add_child(wall)

	var projectile := MAGIC_ARROW_SCENE.instantiate()
	projectile.debug_collisions = false
	world.add_child(projectile)
	await process_frame
	projectile.launch(Vector2.ZERO, Vector2.RIGHT, _make_attack(source, 10.0, &"magic_arrow"), 360.0, 1.0)
	var projectile_ref: WeakRef = weakref(projectile)

	await _wait_until(func() -> bool: return projectile_ref.get_ref() == null, 90)
	_check_true(projectile_ref.get_ref() == null, "Magic Arrow is consumed by world collision")
	_check_equal(target.health.current, 25.0, "world collision prevents damage to a receiver behind it")

	await _free_fixture(world)


func _test_projectile_lifetime() -> void:
	var world := Node2D.new()
	world.name = "ProjectileLifetimeFixture"
	root.add_child(world)
	var source := Node2D.new()
	world.add_child(source)

	var projectile := MAGIC_ARROW_SCENE.instantiate()
	projectile.debug_collisions = false
	world.add_child(projectile)
	await process_frame
	projectile.launch(Vector2.ZERO, Vector2.RIGHT, _make_attack(source, 1.0, &"magic_arrow"), 30.0, 0.03)
	var projectile_ref: WeakRef = weakref(projectile)

	await _wait_until(func() -> bool: return projectile_ref.get_ref() == null, 12)
	_check_true(projectile_ref.get_ref() == null, "Magic Arrow is removed when its lifetime expires")

	await _free_fixture(world)


func _make_damage_receiver_fixture(maximum_health: float) -> Dictionary:
	var fixture_root := Node2D.new()

	var health := HEALTH_SCRIPT.new()
	health.name = "Health"
	health.maximum = maximum_health
	fixture_root.add_child(health)

	var receiver := ATTACK_RECEIVER_SCRIPT.new()
	receiver.name = "AttackReceiver"
	receiver.collision_layer = ATTACK_RECEIVER_LAYER
	receiver.collision_mask = 0
	receiver.add_child(_make_collision_shape(Vector2(18.0, 18.0)))

	var reaction := HEALTH_DAMAGE_REACTION_SCRIPT.new()
	reaction.name = "HealthDamageReaction"
	reaction.health = health
	receiver.add_child(reaction)
	fixture_root.add_child(receiver)

	return {
		"root": fixture_root,
		"health": health,
		"receiver": receiver,
	}


func _make_collision_shape(size: Vector2) -> CollisionShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = shape
	return collision_shape


func _make_attack(source: Node2D, damage: float, attack_type: StringName) -> AttackData:
	var attack := ATTACK_DATA_SCRIPT.new()
	attack.source = source
	attack.origin = source.global_position
	attack.direction = Vector2.RIGHT
	attack.attack_type = attack_type
	attack.damage = damage
	return attack


func _wait_physics_frames(frame_count: int) -> void:
	for _frame in frame_count:
		await physics_frame


func _wait_until(predicate: Callable, maximum_physics_frames: int) -> void:
	for _frame in maximum_physics_frames:
		if predicate.call():
			return
		await physics_frame
	await process_frame


func _free_fixture(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame


func _check_true(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures.append(message)


func _check_false(value: bool, message: String) -> void:
	_check_true(not value, message)


func _check_equal(actual: Variant, expected: Variant, message: String) -> void:
	_checks += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
