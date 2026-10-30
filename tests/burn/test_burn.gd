extends SceneTree

const DATABASE_PATH := "res://spells/spell_database.tres"
const SHOP_PATH := "res://spells/shop/spell_shop.tres"
const PLAYER_SCENE_PATH := "res://entities/player/Player.tscn"
const DUMMY_SCENE_PATH := "res://entities/dummy/Dummy.tscn"
const STAR_SCENE_PATH := "res://entities/enemies/star_man/StarMan.tscn"
const ENEMY_SCENES := [
	"res://entities/enemies/basic_skeleton/BasicSkeleton.tscn",
	"res://entities/enemies/platform_crawler/PlatformCrawler.tscn",
	"res://entities/dummy/Dummy.tscn",
	"res://entities/enemies/flying_eye/FlyingEye.tscn",
	"res://entities/enemies/homunculus_couple/Homunculus.tscn",
	"res://entities/enemies/life_moth/LifeMoth.tscn",
	"res://entities/enemies/dung_beetle/DungBeetle.tscn",
	"res://entities/enemies/star_man/StarMan.tscn",
	"res://entities/enemies/scorpion_man/ScorpionMan.tscn",
]

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_definition()
	await _test_every_enemy_can_burn()
	await _test_fireball_damages_and_ignites()
	await _test_burn_ticks_then_goes_out()
	await _test_reignite_refreshes_without_stacking()
	await _test_plain_attacks_do_not_ignite()
	await _test_star_man_rolling_puts_fire_out()
	await _test_player_casts_burn_with_j_j()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: burn (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_definition() -> void:
	var database := load(DATABASE_PATH) as SpellDatabase
	var burn := database.get_spell(&"burn")

	_check(burn != null, "The spell database must catalogue Burn.")
	if burn == null:
		return

	var expected: Array[StringName] = [&"attack", &"attack"]

	_check(burn.sequence == expected, "Burn must be cast with J + J.")
	_check(burn.icon != null and burn.cooldown > 0.0, "Burn must have an icon and a cooldown.")

	var command := burn.command_scene.instantiate()

	_check(command is BurnSpell, "Burn must run a BurnSpell command.")
	command.free()
	_check(database.get_spells().size() == database.spells.size(), "Burn's sequence must not clash with another spell.")
	_check((load(SHOP_PATH) as SpellShop).is_for_sale(burn), "Like other two-token spells, Burn is sold in the shop.")


func _test_every_enemy_can_burn() -> void:
	for path in ENEMY_SCENES:
		var enemy: Node = (load(path) as PackedScene).instantiate()

		root.add_child(enemy)
		var reactions := enemy.find_children("*", "BurnStatusReaction", true, false)

		_check(reactions.size() == 1, "%s must have one BurnStatusReaction." % path)
		if reactions.size() == 1:
			var reaction: BurnStatusReaction = reactions[0]

			_check(reaction.get_parent() is AttackReceiver, "%s: the burn reaction must sit under the AttackReceiver." % path)
			_check(reaction.health != null and reaction.visual != null, "%s: the burn reaction must be wired." % path)

		enemy.queue_free()
		await process_frame


func _test_fireball_damages_and_ignites() -> void:
	var world := Node2D.new()
	var dummy := _spawn_dummy(world, Vector2(200.0, 0.0))
	var spell := _create_command()
	var caster := Node2D.new()
	var context := SpellContext.new()

	root.add_child(world)
	world.add_child(caster)
	await _await_physics_frames(2)

	var health: Health = dummy.get_node("Health")
	var burn := _burn_of(dummy)

	context.caster = caster
	context.effect_parent = world
	context.origin = Vector2.ZERO
	context.direction = Vector2.RIGHT
	context.aim_direction = Vector2.RIGHT
	world.add_child(spell)
	spell.execute(context)

	var fireballs := world.find_children("*", "MagicArrowProjectile", true, false)

	_check(fireballs.size() == 1, "Casting must launch one fireball.")
	if fireballs.size() == 1:
		_check(fireballs[0].scene_file_path.ends_with("FireballProjectile.tscn"), "The projectile must be the fireball.")

	await _await_until(func() -> bool: return burn.is_burning(), 30)

	_check(is_equal_approx(health.maximum - health.current, 15.0), "The fireball must deal 15 fire damage on hit.")
	_check(burn.is_burning(), "The fireball must set the enemy on fire.")
	_check(dummy.get_node("AnimatedSprite2D").has_node("BurnFlames"), "A burning enemy must show flames.")

	world.queue_free()
	await process_frame


func _test_burn_ticks_then_goes_out() -> void:
	var world := Node2D.new()

	root.add_child(world)

	var dummy := _spawn_dummy(world, Vector2.ZERO)
	await process_frame

	var health: Health = dummy.get_node("Health")
	var burn := _burn_of(dummy)
	var ticks: Array[float] = []
	var sprite: CanvasItem = dummy.get_node("AnimatedSprite2D")

	burn.burn_ticked.connect(func(damage: float) -> void: ticks.append(damage))
	burn.ignite(_effect(3.0, 0.5, 4.0))

	await _await_physics_frames(60)
	_check(sprite.self_modulate != Color.WHITE, "A burning enemy must flicker.")

	await _await_physics_frames(140)

	_check(ticks.size() == 6, "A 3 s burn ticking every 0.5 s must tick six times.")
	_check(is_equal_approx(health.maximum - health.current, 24.0), "Burn ticks must hurt the enemy's health.")
	_check(not burn.is_burning(), "The burn must go out after its duration.")
	_check(not sprite.has_node("BurnFlames"), "The flames must disappear when the burn ends.")
	_check(sprite.self_modulate == Color.WHITE, "The flicker must stop when the burn ends.")

	world.queue_free()
	await process_frame


func _test_reignite_refreshes_without_stacking() -> void:
	var world := Node2D.new()

	root.add_child(world)

	var dummy := _spawn_dummy(world, Vector2.ZERO)
	await process_frame

	var burn := _burn_of(dummy)
	var ticks: Array[float] = []

	burn.burn_ticked.connect(func(damage: float) -> void: ticks.append(damage))
	burn.ignite(_effect(1.0, 0.5, 4.0))
	await _await_physics_frames(45)
	burn.ignite(_effect(1.0, 0.5, 4.0))

	_check(burn.get_time_left() > 0.95, "A new burn must refresh the duration.")

	await _await_physics_frames(45)
	_check(ticks.size() == 2, "Re-igniting must not add a second burn ticking in parallel.")

	world.queue_free()
	await process_frame


func _test_plain_attacks_do_not_ignite() -> void:
	var world := Node2D.new()

	root.add_child(world)

	var dummy := _spawn_dummy(world, Vector2.ZERO)
	await process_frame

	var attack := AttackData.new()

	attack.damage = 10.0
	(dummy.get_node("AttackReceiver") as AttackReceiver).receive_attack(attack)

	_check(not _burn_of(dummy).is_burning(), "Attacks without a burn effect must not set enemies on fire.")
	_check(attack.damage_type == &"physical", "Attacks default to physical damage.")

	world.queue_free()
	await process_frame


func _test_star_man_rolling_puts_fire_out() -> void:
	var world := Node2D.new()
	var star := (load(STAR_SCENE_PATH) as PackedScene).instantiate() as StarMan

	root.add_child(world)
	world.add_child(star)
	await process_frame

	var burn := _burn_of(star)

	burn.ignite(_effect(3.0, 0.5, 4.0))
	_check(burn.is_burning(), "A standing Star Man can catch fire.")

	star._enter_state(StarMan.State.ROLL)
	_check(not burn.is_burning(), "Rolling must put his fire out.")

	burn.ignite(_effect(3.0, 0.5, 4.0))
	_check(not burn.is_burning(), "He must not catch fire while rolling.")

	star._enter_state(StarMan.State.DIZZY)
	burn.ignite(_effect(3.0, 0.5, 4.0))
	_check(burn.is_burning(), "Dizzy, he can burn again.")

	world.queue_free()
	await process_frame


func _test_player_casts_burn_with_j_j() -> void:
	var world := Node2D.new()
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as CharacterBody2D

	root.add_child(world)
	player.set_physics_process(false)
	world.add_child(player)
	await process_frame

	var registry: SpellRegistry = player.get_node("SpellRegistry")
	var caster: SequenceCaster = player.get_node("SequenceCaster")
	var cast: Array[SpellDefinition] = []

	caster.spell_selected.connect(func(spell: SpellDefinition) -> void: cast.append(spell))
	caster._add_token_to_sequence(&"attack")
	caster._add_token_to_sequence(&"attack")
	caster.confirm_sequence()
	_check(cast.is_empty(), "Burn must be bought (registered) before J + J casts it.")

	registry.register_spell(&"burn")
	caster._add_token_to_sequence(&"attack")
	caster._add_token_to_sequence(&"attack")
	caster.confirm_sequence()

	_check(cast.size() == 1 and cast[0].id == &"burn", "J + J and confirm must cast Burn.")

	await process_frame
	_check(
		not world.find_children("*", "MagicArrowProjectile", true, false).is_empty()
		or not root.find_children("FireballProjectile*", "", true, false).is_empty(),
		"Casting Burn must launch a fireball."
	)

	world.queue_free()
	await process_frame


func _create_command() -> BurnSpell:
	var database := load(DATABASE_PATH) as SpellDatabase

	return database.get_spell(&"burn").command_scene.instantiate() as BurnSpell


func _effect(duration: float, interval: float, damage: float) -> BurnEffect:
	var effect := BurnEffect.new()

	effect.duration = duration
	effect.tick_interval = interval
	effect.tick_damage = damage
	return effect


func _spawn_dummy(parent: Node, at: Vector2) -> Node2D:
	var dummy := (load(DUMMY_SCENE_PATH) as PackedScene).instantiate() as Node2D

	dummy.set_physics_process(false)
	dummy.position = at
	parent.add_child(dummy)
	return dummy


func _burn_of(node: Node) -> BurnStatusReaction:
	return node.find_children("*", "BurnStatusReaction", true, false)[0]


func _await_until(condition: Callable, max_frames: int) -> void:
	for _index in max_frames:
		if condition.call():
			return
		await physics_frame


func _await_physics_frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
