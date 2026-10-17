extends SceneTree

# Push spell radial burst and Magic Arrow passing through world obstacles.

const PUSH_SPELL_SCENE := "res://spells/action/push/PushSpell.tscn"
const ARROW_SCENE := "res://spells/attack/magic_arrow/MagicArrowProjectile.tscn"
const ACTION_RECEIVER_LAYER := 1 << 3
const ATTACK_RECEIVER_LAYER := 1 << 4
const WORLD_LAYER := 1 << 0

var _checks: int = 0
var _failures: Array[String] = []


class RecordingReaction extends ActionReaction:
	var actions: Array[ActionData] = []

	func supports(action: ActionData) -> bool:
		return action != null and action.type == &"push"

	func react(action: ActionData) -> void:
		actions.append(action)


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_push_hits_every_direction()
	await _test_push_ignores_far_receivers()
	await _test_arrow_passes_through_walls()
	await _test_arrow_still_stops_on_first_enemy()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: spell effects (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_push_hits_every_direction() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)

	var caster := _make_caster(fixture)
	var offsets := {
		"to the right": Vector2(60.0, 0.0),
		"to the left": Vector2(-60.0, 0.0),
		"above": Vector2(0.0, -60.0),
		"below": Vector2(0.0, 60.0),
		"diagonally behind": Vector2(-45.0, 40.0),
	}
	var reactions := {}

	for key in offsets:
		reactions[key] = _make_push_receiver(fixture, caster.global_position + offsets[key])

	await _cast_push(caster, Vector2.RIGHT)

	for key in offsets:
		var reaction: RecordingReaction = reactions[key]
		var expected: Vector2 = (offsets[key] as Vector2).normalized()

		_check(reaction.actions.size() == 1, "Push must reach the receiver placed %s." % key)

		if reaction.actions.size() == 1:
			_check(
				reaction.actions[0].direction.is_equal_approx(expected),
				"Push must send the receiver placed %s away from the caster (got %s)." % [key, reaction.actions[0].direction]
			)

	fixture.queue_free()
	await process_frame


func _test_push_ignores_far_receivers() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)

	var caster := _make_caster(fixture)
	var far := _make_push_receiver(fixture, caster.global_position + Vector2(400.0, 0.0))

	await _cast_push(caster, Vector2.RIGHT)
	_check(far.actions.is_empty(), "Push must not reach receivers outside its radius.")

	fixture.queue_free()
	await process_frame


func _test_arrow_passes_through_walls() -> void:
	var world := Node2D.new()
	root.add_child(world)

	var source := Node2D.new()
	world.add_child(source)

	var wall := StaticBody2D.new()
	wall.position = Vector2(70.0, 0.0)
	wall.collision_layer = WORLD_LAYER
	wall.collision_mask = 0
	wall.add_child(_make_shape(Vector2(10.0, 80.0)))
	world.add_child(wall)

	var target := _make_target(world, Vector2(160.0, 0.0), 25.0)
	var arrow = (load(ARROW_SCENE) as PackedScene).instantiate()
	arrow.debug_collisions = false
	world.add_child(arrow)
	await process_frame

	var arrow_ref: WeakRef = weakref(arrow)
	arrow.launch(Vector2.ZERO, Vector2.RIGHT, _make_attack(source, 10.0), 360.0, 1.0)

	var passed_wall := false

	for i in 90:
		await physics_frame

		if arrow_ref.get_ref() == null:
			break

		if (arrow_ref.get_ref() as Node2D).global_position.x > wall.position.x + 10.0:
			passed_wall = true

	_check(passed_wall, "Magic Arrow must keep flying past a wall.")
	_check(is_equal_approx(target.current, 15.0), "Magic Arrow must hit the enemy behind the wall.")
	_check(arrow_ref.get_ref() == null, "Magic Arrow must still be consumed by the enemy it hits.")

	world.queue_free()
	await process_frame


func _test_arrow_still_stops_on_first_enemy() -> void:
	var world := Node2D.new()
	root.add_child(world)

	var source := Node2D.new()
	world.add_child(source)

	var first := _make_target(world, Vector2(80.0, 0.0), 25.0)
	var second := _make_target(world, Vector2(160.0, 0.0), 25.0)
	var arrow = (load(ARROW_SCENE) as PackedScene).instantiate()
	arrow.debug_collisions = false
	world.add_child(arrow)
	await process_frame

	arrow.launch(Vector2.ZERO, Vector2.RIGHT, _make_attack(source, 10.0), 360.0, 1.0)

	for i in 90:
		await physics_frame

	_check(is_equal_approx(first.current, 15.0), "Magic Arrow must damage the first enemy.")
	_check(is_equal_approx(second.current, 25.0), "Magic Arrow must not pierce enemies.")

	world.queue_free()
	await process_frame


func _make_caster(parent: Node) -> Node2D:
	var caster := Node2D.new()
	caster.position = Vector2(2000.0, 2000.0)
	caster.scale = Vector2(3.0, 3.0)
	parent.add_child(caster)
	return caster


func _cast_push(caster: Node2D, facing: Vector2) -> void:
	var spell = (load(PUSH_SPELL_SCENE) as PackedScene).instantiate()
	caster.add_child(spell)
	await physics_frame
	await physics_frame

	var context := SpellContext.new()
	context.caster = caster
	context.effect_parent = caster
	context.origin = caster.global_position
	context.direction = facing
	spell.execute(context)

	if is_instance_valid(spell):
		spell.cancel()


func _make_push_receiver(parent: Node, at: Vector2) -> RecordingReaction:
	var receiver := ActionReceiver.new()
	receiver.collision_layer = ACTION_RECEIVER_LAYER
	receiver.collision_mask = 0
	receiver.add_child(_make_shape(Vector2(20.0, 20.0)))

	var reaction := RecordingReaction.new()
	receiver.add_child(reaction)
	parent.add_child(receiver)
	receiver.global_position = at

	return reaction


func _make_target(parent: Node, at: Vector2, maximum: float) -> Health:
	var holder := Node2D.new()
	holder.position = at
	parent.add_child(holder)

	var health := Health.new()
	health.maximum = maximum
	holder.add_child(health)

	var receiver := AttackReceiver.new()
	receiver.collision_layer = ATTACK_RECEIVER_LAYER
	receiver.collision_mask = 0
	receiver.add_child(_make_shape(Vector2(18.0, 18.0)))

	var reaction := HealthDamageReaction.new()
	reaction.health = health
	receiver.add_child(reaction)
	holder.add_child(receiver)

	return health


func _make_attack(source: Node2D, damage: float) -> AttackData:
	var attack := AttackData.new()
	attack.attack_type = &"magic_arrow"
	attack.source = source
	attack.damage = damage
	return attack


func _make_shape(size: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	return shape


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
