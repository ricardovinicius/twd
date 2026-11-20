extends SceneTree

const DATABASE_PATH := "res://spells/spell_database.tres"
const SHOP_PATH := "res://spells/shop/spell_shop.tres"
const BREAK_SPELL_PATH := "res://spells/attack/break/BreakSpell.tscn"
const BIG_HEAD_PATH := "res://entities/enemies/big_head/BigHead.tscn"
const DUMMY_PATH := "res://entities/dummy/Dummy.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_definition()
	await _test_reaction_shatters_shield()
	await _test_reaction_ignores_other_attacks()
	await _test_cast_shatters_big_head_shield()
	await _test_enemy_without_shield_ignores_it()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: break spell (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_definition() -> void:
	var database := load(DATABASE_PATH) as SpellDatabase
	var spell := database.get_spell(&"break")

	_check(spell != null, "The spell database must catalogue Break.")
	if spell == null:
		return

	var expected: Array[StringName] = [&"attack", &"move"]

	_check(spell.sequence == expected, "Break must be cast with J + L.")
	_check(spell.icon != null and spell.cooldown > 0.0, "Break must have an icon and a cooldown.")
	_check(database.get_spells().size() == database.spells.size(), "Break's sequence must not clash with another spell.")
	_check((load(SHOP_PATH) as SpellShop).is_for_sale(spell), "Like other two-token spells, Break is sold in the shop.")

	var command := spell.command_scene.instantiate()

	_check(command is BreakSpell, "Break must run a BreakSpell command.")
	command.free()


func _test_reaction_shatters_shield() -> void:
	var shield := BreakableShield.new()
	var reaction := ShieldBreakReaction.new()
	reaction.shield = shield
	root.add_child(shield)
	root.add_child(reaction)
	await process_frame

	var attack := _make_break_attack()

	_check(reaction.supports(attack), "A break attack must be supported while the shield is up.")
	reaction.react(attack)
	_check(shield.is_broken(), "A break attack must shatter the shield at once.")
	_check(not reaction.supports(attack), "A broken shield must ignore further break attacks.")

	shield.queue_free()
	reaction.queue_free()
	await process_frame


func _test_reaction_ignores_other_attacks() -> void:
	var shield := BreakableShield.new()
	var reaction := ShieldBreakReaction.new()
	reaction.shield = shield
	root.add_child(shield)
	root.add_child(reaction)
	await process_frame

	var attack := AttackData.new()
	attack.attack_type = &"magic_arrow"
	attack.damage = 25.0

	_check(not reaction.supports(attack), "Other attacks must not shatter the shield.")

	shield.queue_free()
	reaction.queue_free()
	await process_frame


func _test_cast_shatters_big_head_shield() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var head := (load(BIG_HEAD_PATH) as PackedScene).instantiate() as BigHead
	world.add_child(head)
	head.global_position = Vector2(200.0, 0.0)
	await process_frame

	_cast_break(world, Vector2.ZERO, Vector2.RIGHT)

	for i in 60:
		await physics_frame
		if head.shield.is_broken():
			break

	_check(head.shield.is_broken(), "A Break shard must shatter Big Head's shield.")
	_check(is_equal_approx(head.health.current, head.health.maximum), "Break must not damage health.")
	_check(not head.is_asleep(), "Shattering its shield must wake Big Head up.")

	world.queue_free()
	await process_frame


func _test_enemy_without_shield_ignores_it() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var dummy := (load(DUMMY_PATH) as PackedScene).instantiate() as Node2D
	world.add_child(dummy)
	dummy.global_position = Vector2(200.0, 0.0)
	await process_frame

	var health := dummy.find_children("*", "Health", true, false)[0] as Health
	var before := health.current

	_cast_break(world, Vector2.ZERO, Vector2.RIGHT)

	for i in 60:
		await physics_frame

	_check(is_equal_approx(health.current, before), "Break must not hurt an enemy without a shield.")

	world.queue_free()
	await process_frame


func _cast_break(world: Node2D, origin: Vector2, direction: Vector2) -> void:
	var caster := Node2D.new()
	world.add_child(caster)

	var context := SpellContext.new()
	context.caster = caster
	context.effect_parent = world
	context.origin = origin
	context.direction = direction
	context.aim_direction = direction

	var command := (load(BREAK_SPELL_PATH) as PackedScene).instantiate() as SpellCommand
	world.add_child(command)
	command.execute(context)


func _make_break_attack() -> AttackData:
	var attack := AttackData.new()
	attack.attack_type = ShieldBreakReaction.BREAK_ATTACK_TYPE
	return attack


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
