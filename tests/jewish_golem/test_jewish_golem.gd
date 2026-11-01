extends SceneTree

const GOLEM_SCENE_PATH := "res://entities/enemies/jewish_golem/JewishGolem.tscn"
const SCORPION_SCENE_PATH := "res://entities/enemies/scorpion_man/ScorpionMan.tscn"
const PLAYER_SCENE_PATH := "res://entities/player/Player.tscn"
const CLAY_EYE_SCENE_PATH := "res://entities/enemies/jewish_golem/minions/ClayFlyingEye.tscn"
const CLAY_HOMUNCULUS_SCENE_PATH := "res://entities/enemies/jewish_golem/minions/ClayHomunculus.tscn"
const MAGIC_ARROW_SCENE_PATH := "res://spells/attack/magic_arrow/MagicArrowProjectile.tscn"
const FIREBALL_SCENE_PATH := "res://spells/attack/burn/FireballProjectile.tscn"
const RESPAWNER_SCRIPT_PATH := "res://entities/enemies/respawn/enemy_respawner.gd"
const BESTIARY_PATH := "res://entities/enemies/bestiary/bestiary.tres"
const FLOOR_Y := 48.0
const FAR_AWAY := Vector2(20000.0, 0.0)

var _checks: int = 0
var _failures: Array[String] = []
var _boss_counter: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	SaveGame.save_path = "user://test_jewish_golem_save.cfg"
	SaveGame.delete_save()

	await _test_composition()
	await _test_attack_choice()
	await _test_sleeps_until_the_player_comes()
	await _test_slam_hits_close_player()
	await _test_clay_ball_becomes_a_minion()
	await _test_clay_ball_hits_the_player()
	await _test_minions_are_clay_versions()
	await _test_summon_raises_minions_with_a_cap()
	await _test_minions_sometimes_drop_health()
	await _test_minions_never_stay_on_the_players_head()
	await _test_shield_raises_breakable_blocks()
	await _test_shield_blocks_stop_attacks()
	await _test_damage_does_not_interrupt_and_enrages()
	await _test_defeat_releases_the_rune_and_kneels()
	await _test_defeat_is_remembered()
	await _test_respawner_restores_golem()
	_test_save_game_boss_records()
	_test_bestiary_entry()

	SaveGame.delete_save()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: jewish golem (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_composition() -> void:
	var world := _spawn_world()
	var golem := _spawn_golem(world, Vector2.ZERO)
	var scorpion := (load(SCORPION_SCENE_PATH) as PackedScene).instantiate() as ScorpionMan

	world.add_child(scorpion)
	scorpion.position = FAR_AWAY
	await _await_physics_frames(20)

	var frames := golem.sprite.sprite_frames
	var expected := {&"idle": 2, &"walk": 4, &"slam": 3, &"throw": 2, &"summon": 2, &"shield": 2, &"defeat": 3}

	for animation in expected:
		_check(frames.has_animation(animation), "The golem must have a '%s' animation." % animation)
		_check(
			frames.get_frame_count(animation) == expected[animation],
			"The '%s' animation must have %d frames." % [animation, expected[animation]]
		)
	_check(frames.get_frame_texture(&"idle", 0).get_size() == Vector2(64.0, 64.0), "Golem frames must be 64x64.")
	_check(golem.is_on_floor(), "He must stand on the floor.")

	var player_scene := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	var player_shape := (player_scene.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var player_height: float = player_shape.size.y * (player_scene as Node2D).scale.y
	var golem_shape := (golem.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var golem_height := golem_shape.size.y * golem.scale.y
	var golem_visual_height := 52.0 * golem.scale.y

	player_scene.free()
	_check(golem_height > player_height * 1.3, "His body must be much taller than the player's.")
	_check(
		golem_visual_height >= player_height * 1.7 and golem_visual_height <= player_height * 2.4,
		"He must look almost twice the player's height."
	)
	_check(golem.horizontal_movement.max_speed <= 80.0, "He must move slowly.")
	_check(
		golem.health.maximum >= scorpion.health.maximum * 2.0,
		"As a boss he must be much tougher than the tough enemies."
	)
	_check(golem.get_state() == JewishGolem.State.DORMANT, "Without a player he must wait.")

	await _free_node(world)


func _test_attack_choice() -> void:
	var world := _spawn_world()
	var golem := _spawn_golem(world, Vector2.ZERO)
	await _await_physics_frames(5)

	_clear_cooldowns(golem)
	_check(golem.choose_attack(Vector2(100.0, 0.0)) == JewishGolem.Attack.SLAM, "Up close he must slam.")
	_check(
		golem.choose_attack(Vector2(500.0, 0.0)) == JewishGolem.Attack.SUMMON,
		"Far away, with the summon ready, he must raise minions."
	)

	golem._summon_cooldown_left = 5.0
	_check(
		golem.choose_attack(Vector2(500.0, 0.0)) == JewishGolem.Attack.CLAY_SHOT,
		"Otherwise he must throw clay."
	)

	golem._clay_shot_cooldown_left = 5.0
	_check(golem.choose_attack(Vector2(500.0, 0.0)) == JewishGolem.Attack.NONE, "With nothing ready he must walk.")
	_check(
		not golem._can_shield(),
		"At full health he must not hide behind blocks yet."
	)

	golem.health.take_damage(golem.health.maximum * 0.2)
	_check(golem.choose_attack(Vector2(500.0, 0.0)) == JewishGolem.Attack.SHIELD, "Once hurt he must raise his blocks.")
	_check(
		golem.choose_attack(Vector2(100.0, 0.0)) == JewishGolem.Attack.SLAM,
		"A player right next to him still gets the slam first."
	)

	golem._cooldown_left = 0.5
	_check(golem.choose_attack(Vector2(100.0, 0.0)) == JewishGolem.Attack.NONE, "He must pause between attacks.")

	await _free_node(world)


func _test_sleeps_until_the_player_comes() -> void:
	var world := _spawn_world()
	var golem := _spawn_golem(world, Vector2.ZERO)
	var player := _spawn_player(world, FAR_AWAY)
	await _await_physics_frames(30)

	_check(golem.get_state() == JewishGolem.State.DORMANT, "Far from the player he must stay still.")
	_check(is_zero_approx(golem.velocity.x), "Dormant, he must not move.")

	_clear_cooldowns(golem)
	golem._summon_cooldown_left = 30.0
	golem._clay_shot_cooldown_left = 30.0
	player.global_position = Vector2(-500.0, 0.0)
	await _await_physics_frames(40)

	_check(golem.get_target() == player, "The player coming near must wake him.")
	_check(golem.get_state() == JewishGolem.State.CHASE, "Awake, he must walk to the player.")
	_check(golem.velocity.x < 0.0, "He must walk toward the player.")
	_check(absf(golem.velocity.x) <= golem.horizontal_movement.max_speed + 0.1, "He must walk slowly.")

	await _free_node(world)


func _test_slam_hits_close_player() -> void:
	var world := _spawn_world()
	var golem := _spawn_golem(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(110.0, 0.0))
	var health: Health = player.get_node("Health")

	await _await_until(func() -> bool: return golem.get_state() == JewishGolem.State.ATTACK, 60)

	_check(golem.get_current_attack() == JewishGolem.Attack.SLAM, "A close player must get the slam.")
	_check(golem.facing_direction > 0.0, "He must face the player.")
	_check(golem.sprite.animation == &"slam" and golem.sprite.frame == 0, "The wind-up must raise his fists.")
	_check(is_equal_approx(health.current, health.maximum), "The slam must wind up before it hits.")

	await _await_until(func() -> bool: return golem.sprite.frame == 1, 90)
	_check(golem.sprite.frame == 1, "The strike must show his fists hitting the ground.")

	await _await_until(func() -> bool: return golem.get_state() != JewishGolem.State.ATTACK, 150)
	_check(is_equal_approx(health.maximum - health.current, golem.slam.damage), "The slam must hit once.")

	await _free_node(world)


func _test_clay_ball_becomes_a_minion() -> void:
	var world := _spawn_world()
	var golem := _spawn_golem(world, Vector2.ZERO)
	var marker := Node2D.new()
	var summoned: Array[Node2D] = []

	world.add_child(marker)
	marker.global_position = Vector2(400.0, FLOOR_Y - 4.0)
	golem.summoner.minion_summoned.connect(func(minion: Node2D) -> void: summoned.append(minion))
	await _await_physics_frames(5)

	_check(golem.clay_shot.begin_attack(marker), "The clay shot must start toward a target.")
	_check(not golem.clay_shot.begin_attack(marker), "A second throw must be rejected while winding up.")

	await _await_until(func() -> bool: return _count_children_of_type(golem.get_node("Summons"), "ClayBall") > 0, 90)
	_check(_count_children_of_type(golem.get_node("Summons"), "ClayBall") == 1, "One ball must be thrown.")

	await _await_until(func() -> bool: return not summoned.is_empty(), 180)
	_check(summoned.size() == 1, "The ball landing must raise one minion.")

	if not summoned.is_empty():
		var minion := summoned[0]
		_check(minion is Homunculus, "The first minion must be a clay homunculus.")
		_check(absf(minion.global_position.x - marker.global_position.x) < 60.0, "The minion must rise where the ball landed.")
		_check(minion.get_parent() == golem.get_node("Summons"), "Minions must belong to the golem.")

	_check(_count_children_of_type(golem.get_node("Summons"), "ClayBall") == 0, "The ball must be gone after landing.")

	await _free_node(world)


func _test_clay_ball_hits_the_player() -> void:
	var world := _spawn_world()
	var golem := _spawn_golem(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(380.0, 0.0))
	var health: Health = player.get_node("Health")
	var summoned: Array[Node2D] = []

	golem.summoner.minion_summoned.connect(func(minion: Node2D) -> void: summoned.append(minion))
	await _await_physics_frames(5)

	golem.clay_shot.begin_attack(player)
	await _await_until(func() -> bool: return health.current < health.maximum, 200)

	_check(is_equal_approx(health.maximum - health.current, golem.clay_shot.damage), "A ball hitting the player must hurt once.")

	await _await_physics_frames(10)
	_check(summoned.is_empty(), "A ball that hits the player must splatter instead of becoming a minion.")

	await _free_node(world)


func _test_minions_are_clay_versions() -> void:
	var eye := (load(CLAY_EYE_SCENE_PATH) as PackedScene).instantiate()
	var homunculus := (load(CLAY_HOMUNCULUS_SCENE_PATH) as PackedScene).instantiate()

	_check(eye is FlyingEye, "The clay eye must be a Flying Eye.")
	_check(homunculus is Homunculus, "The clay homunculus must be a Homunculus.")

	for minion in [eye, homunculus]:
		var sprite := minion.get_node("AnimatedSprite2D") as AnimatedSprite2D
		var material := sprite.material as ShaderMaterial
		var drop := minion.get_node("StardustDropOnDeath") as StardustDropOnDeath

		_check(material != null and material.shader != null, "%s must be drawn as clay." % minion.name)
		_check(drop.pickup_count == 0, "%s must not drop Stardust." % minion.name)
		_check((minion.get_node("Health") as Health).maximum < 30.0, "%s must be weaker than the original." % minion.name)

	eye.free()
	homunculus.free()


func _test_minions_sometimes_drop_health() -> void:
	for path in [CLAY_EYE_SCENE_PATH, CLAY_HOMUNCULUS_SCENE_PATH]:
		var scene := load(path) as PackedScene
		var probe := scene.instantiate()
		var orb_drop := probe.get_node_or_null("HealthOrbDropOnDeath") as HealthOrbDropOnDeath

		_check(orb_drop != null, "%s must be able to drop a health orb." % probe.name)
		if orb_drop != null:
			_check(
				orb_drop.drop_chance > 0.0 and orb_drop.drop_chance < 1.0,
				"%s must drop health only sometimes." % probe.name
			)
		probe.free()

		for chance in [1.0, 0.0]:
			var world := _spawn_world()
			var minion := scene.instantiate() as Node2D

			(minion.get_node("HealthOrbDropOnDeath") as HealthOrbDropOnDeath).drop_chance = chance
			minion.position = Vector2(0.0, -40.0)
			world.add_child(minion)
			await _await_physics_frames(2)

			(minion.get_node("Health") as Health).take_damage(1000.0)
			await process_frame
			await process_frame

			var orbs := _count_children_of_type(world, "HealthOrb") + _count_children_of_type(root, "HealthOrb")

			if chance == 1.0:
				_check(orbs == 1, "A lucky kill must drop one health orb.")
			else:
				_check(orbs == 0, "An unlucky kill must drop nothing.")

			await _free_node(world)
			for child in root.get_children():
				if child is HealthOrb:
					child.queue_free()
			await process_frame


func _test_minions_never_stay_on_the_players_head() -> void:
	var original_path := "res://entities/enemies/homunculus_couple/Homunculus.tscn"

	for path in [CLAY_HOMUNCULUS_SCENE_PATH, original_path]:
		var world := _spawn_world()
		var player := _spawn_player(world, Vector2(0.0, FLOOR_Y - 30.0))
		var homunculus := (load(path) as PackedScene).instantiate() as Homunculus

		# Dropped right above the player's head, as a landing ball can do.
		homunculus.position = Vector2(2.0, FLOOR_Y - 140.0)
		world.add_child(homunculus)
		await _await_physics_frames(2)

		homunculus.chase(player)

		var stuck_frames := 0

		for _index in 80:
			await physics_frame
			if homunculus.is_on_floor() and homunculus.global_position.y < player.global_position.y - 20.0:
				stuck_frames += 1

		var feet_on_floor := homunculus.global_position.y > player.global_position.y

		_check(stuck_frames < 30, "%s must not stay on the player's head." % homunculus.name)
		_check(feet_on_floor and homunculus.is_on_floor(), "%s must end up back on the ground." % homunculus.name)

		await _free_node(world)


func _test_summon_raises_minions_with_a_cap() -> void:
	var world := _spawn_world()
	var golem := _spawn_golem(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(-520.0, 0.0))

	golem.facing_direction = -1.0
	await _await_physics_frames(2)

	_clear_cooldowns(golem)
	golem._clay_shot_cooldown_left = 30.0
	await _await_until(func() -> bool: return golem.get_current_attack() == JewishGolem.Attack.SUMMON, 60)

	_check(golem.get_current_attack() == JewishGolem.Attack.SUMMON, "With the summon ready he must raise minions.")
	_check(golem.sprite.animation == &"summon", "Summoning must show its own pose.")
	_check(golem.summoner.get_alive_count() == 0, "Minions must rise after the wind-up.")

	await _await_until(func() -> bool: return golem.summoner.get_alive_count() > 0, 120)
	await _await_physics_frames(2)

	var minions := golem.summoner.get_minions()

	_check(minions.size() == 1, "A summon must raise a single minion.")
	_check(golem.summoner.max_alive == 2, "At most two minions may be on screen at once.")

	if minions.size() == 1 and minions[0] is Homunculus:
		var homunculus := minions[0] as Homunculus
		_check(homunculus.get_state() == Homunculus.State.CHASE, "The clay homunculus must chase the player.")
		_check(homunculus.get_target() == player, "It must chase the golem's target.")
	else:
		_check(false, "The first summoned minion must be a clay homunculus.")

	var second := golem.summoner.summon_at(Vector2(0.0, 0.0), player)
	await _await_physics_frames(2)

	_check(second is FlyingEye, "Minions must alternate between homunculus and eye.")
	_check(golem.summoner.get_alive_count() == 2, "Minions can be raised up to the cap.")
	_check(golem.summoner.summon_at(Vector2.ZERO, player) == null, "Beyond two on screen no minion must rise.")
	_check(not golem.summoner.can_summon(), "The summon attack must wait while two minions live.")

	golem._cooldown_left = 0.0
	golem._summon_cooldown_left = 0.0
	_check(
		golem.choose_attack(Vector2(-520.0, 0.0)) != JewishGolem.Attack.SUMMON,
		"With two minions alive he must throw clay or build walls instead."
	)

	var marker := Node2D.new()
	var landed_minions: Array[Node2D] = []

	world.add_child(marker)
	marker.global_position = Vector2(400.0, FLOOR_Y - 4.0)
	golem.summoner.minion_summoned.connect(func(minion: Node2D) -> void: landed_minions.append(minion))
	golem.clay_shot.begin_attack(marker)
	await _await_physics_frames(50)
	await _await_until(func() -> bool: return _count_children_of_type(golem.get_node("Summons"), "ClayBall") == 0, 120)
	await _await_physics_frames(3)

	_check(landed_minions.is_empty(), "With two minions alive a landing ball must only splatter.")
	_check(golem.summoner.get_alive_count() == 2, "There must still be only two minions.")

	for minion in golem.summoner.get_minions():
		(minion.get_node("Health") as Health).take_damage(1000.0)
	await _await_physics_frames(3)

	_check(golem.summoner.can_summon(), "Killing his minions must let him raise more.")

	await _free_node(world)


func _test_shield_raises_breakable_blocks() -> void:
	var world := _spawn_world()
	var golem := _spawn_golem(world, Vector2.ZERO)
	await _await_physics_frames(10)

	var raised := golem.shield_spawner.raise_blocks()
	var blocks := golem.shield_spawner.get_blocks()

	_check(raised == 4, "He must raise four blocks around himself.")
	_check(
		blocks.all(func(block: Node2D) -> bool: return block.get_node_or_null("ActionReceiver/DigReaction") is DigReaction),
		"The blocks must break with Dig, like the map's breakable blocks."
	)

	var left := blocks.filter(func(block: Node2D) -> bool: return block.global_position.x < golem.global_position.x)
	_check(left.size() == 2, "Blocks must guard both of his sides.")

	await _await_physics_frames(2)
	_check(golem.shield_spawner.raise_blocks() == 0, "Standing blocks must not be raised again.")

	var dig := ActionData.new()

	dig.type = &"dig"
	dig.strength = 1.0

	var dug_x := blocks[0].global_position.x

	(blocks[0].get_node("ActionReceiver") as ActionReceiver).receive_action(dig)
	await process_frame
	await process_frame

	var remaining := golem.shield_spawner.get_blocks()

	_check(remaining.size() == 2, "One dig must break both blocks of that column.")
	_check(
		remaining.all(func(block: Node2D) -> bool: return absf(block.global_position.x - dug_x) > 10.0),
		"Only the dug column must break; the other side stays standing."
	)

	golem.shield_spawner.clear()
	await process_frame

	var player := _spawn_player(world, golem.global_position + golem.shield_spawner.slot_offsets[1])
	await _await_physics_frames(3)

	_check(golem.shield_spawner.raise_blocks() == 3, "A block must not appear where the player stands.")
	_check(player.is_inside_tree(), "The player must not be trapped or removed.")

	await _free_node(world)


func _test_shield_blocks_stop_attacks() -> void:
	var cases := [
		[MAGIC_ARROW_SCENE_PATH, "magic arrow"],
		[FIREBALL_SCENE_PATH, "fireball"],
	]

	for case in cases:
		var world := _spawn_world()
		var golem := _spawn_golem(world, Vector2.ZERO)
		var player := _spawn_player(world, Vector2(-500.0, -1000.0))
		await _await_physics_frames(10)

		golem.shield_spawner.raise_blocks()
		await _await_physics_frames(3)

		var health_before := golem.health.current
		var chest_height := golem.global_position.y + 10.0

		_fire_projectile(world, case[0], player, Vector2(-300.0, chest_height), Vector2.RIGHT)
		await _await_physics_frames(35)

		_check(
			is_equal_approx(golem.health.current, health_before),
			"A %s fired at the wall must not hurt the golem." % case[1]
		)
		_check(golem.shield_spawner.get_alive_count() == 4, "Attacks must not break the blocks; only Dig does.")

		var dig := ActionData.new()

		dig.type = &"dig"
		dig.strength = 1.0

		for block in golem.shield_spawner.get_blocks():
			if block.global_position.x < golem.global_position.x:
				(block.get_node("ActionReceiver") as ActionReceiver).receive_action(dig)
				break
		await _await_physics_frames(3)

		_fire_projectile(world, case[0], player, Vector2(-300.0, chest_height), Vector2.RIGHT)
		await _await_until(func() -> bool: return golem.health.current < health_before, 35)

		_check(golem.health.current < health_before, "With that wall dug open, the %s must hit him." % case[1])

		await _free_node(world)


func _fire_projectile(world: Node, scene_path: String, caster: Node2D, origin: Vector2, direction: Vector2) -> void:
	var projectile := (load(scene_path) as PackedScene).instantiate() as MagicArrowProjectile
	var attack := AttackData.new()

	attack.source = caster
	attack.origin = origin
	attack.direction = direction
	attack.damage = 25.0
	world.add_child(projectile)
	projectile.launch(origin, direction, attack, 900.0, 2.0)


func _test_damage_does_not_interrupt_and_enrages() -> void:
	var world := _spawn_world()
	var golem := _spawn_golem(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(110.0, 0.0))
	var health: Health = player.get_node("Health")
	var enraged: Array[bool] = []

	golem.enraged.connect(func() -> void: enraged.append(true))
	await _await_until(func() -> bool: return golem.get_state() == JewishGolem.State.ATTACK, 60)

	var attack := AttackData.new()

	attack.source = player
	attack.damage = 25.0
	golem.attack_receiver.receive_attack(attack)

	_check(is_equal_approx(golem.health.current, golem.health.maximum - 25.0), "He must take damage.")
	_check(golem.get_state() == JewishGolem.State.ATTACK, "Damage must not interrupt his attack.")
	_check(enraged.is_empty(), "A small hit must not enrage him.")

	await _await_until(func() -> bool: return golem.get_state() != JewishGolem.State.ATTACK, 150)
	_check(health.current < health.maximum, "The attack must still land after he is hit.")

	golem.health.take_damage(golem.health.maximum * 0.5)
	_check(golem.is_enraged() and enraged.size() == 1, "Below half health he must become enraged once.")

	golem._clay_shot_cooldown_left = 0.0
	golem._summon_cooldown_left = 30.0
	golem._shield_cooldown_left = 30.0
	golem._cooldown_left = 0.0
	player.global_position = Vector2(500.0, 0.0)
	await _await_until(func() -> bool: return golem.get_current_attack() == JewishGolem.Attack.CLAY_SHOT, 60)

	_check(golem.clay_shot.shots == golem.enraged_shots, "Enraged, he must throw more clay at once.")
	_check(
		golem._clay_shot_cooldown_left < golem.clay_shot_cooldown,
		"Enraged, his attacks must come back sooner."
	)

	await _free_node(world)


func _test_defeat_releases_the_rune_and_kneels() -> void:
	var world := _spawn_world()
	var golem := _spawn_golem(world, Vector2.ZERO)
	var player := _spawn_player(world, Vector2(-500.0, 0.0))
	var defeated: Array[bool] = []

	golem.defeated.connect(func() -> void: defeated.append(true))
	await _await_physics_frames(5)

	golem.summoner.summon_at(Vector2(-200.0, 0.0), player)
	golem.shield_spawner.raise_blocks()
	await _await_physics_frames(2)

	var rune_start := golem.rune.global_position

	golem.health.take_damage(golem.health.maximum)
	await process_frame
	await process_frame

	_check(golem.is_defeated(), "Depleted health must defeat him.")
	_check(is_instance_valid(golem) and golem.is_inside_tree(), "He must stay in the room, not vanish.")
	_check(golem.rune.visible, "The rune must leave his chest.")
	_check(golem.sprite.animation == &"defeat", "He must show the defeat pose.")
	_check(SaveGame.is_boss_defeated(golem.boss_id), "His defeat must be recorded for the save.")
	_check(_count_children_of_type(world, "CoinPickup") == 10, "He must drop ten Stardust pickups.")

	await _await_physics_frames(3)
	_check(golem.summoner.get_alive_count() == 0, "His minions must crumble.")
	_check(_count_children_of_type(world, "HealthOrb") == 0, "Crumbled minions must not drop health.")
	_check(golem.shield_spawner.get_alive_count() == 0, "His blocks must crumble.")

	await _await_physics_frames(40)
	_check(golem.rune.global_position.y < rune_start.y - 10.0, "The rune must float up out of his chest.")

	await _await_until(func() -> bool: return not defeated.is_empty(), 180)
	_check(defeated.size() == 1, "The defeat must finish once.")
	_check(not golem.rune.visible, "The rune must be gone at the end.")
	_check(golem.sprite.animation == &"defeat" and golem.sprite.frame == 2, "He must end asleep on his knees.")

	var health_before := golem.health.current
	var attack := AttackData.new()

	attack.damage = 50.0
	golem.attack_receiver.receive_attack(attack)
	_check(is_equal_approx(golem.health.current, health_before), "A sleeping golem must ignore attacks.")
	_check(not golem.contact_area.monitoring, "A sleeping golem must not hurt on contact.")

	player.global_position = Vector2(80.0, 0.0)
	await _await_physics_frames(30)
	_check(golem.get_state() == JewishGolem.State.DEFEATED, "He must not wake up again.")
	_check(is_zero_approx(golem.velocity.x), "He must not move again.")

	await _free_node(world)


func _test_defeat_is_remembered() -> void:
	var world := _spawn_world()
	var boss_id := _unique_boss_id()

	SaveGame.mark_boss_defeated(boss_id)

	var golem := _spawn_golem(world, Vector2.ZERO, boss_id)
	var player := _spawn_player(world, Vector2(100.0, 0.0))
	var health: Health = player.get_node("Health")
	await _await_physics_frames(60)

	_check(golem.is_defeated(), "A golem already defeated in this game must appear asleep.")
	_check(golem.sprite.animation == &"defeat" and golem.sprite.frame == 2, "He must already be on his knees.")
	_check(not golem.rune.visible, "The rune must already be gone.")
	_check(is_equal_approx(health.current, health.maximum), "He must not attack.")
	_check(_count_children_of_type(world, "CoinPickup") == 0, "He must not drop Stardust again.")

	await _free_node(world)


func _test_respawner_restores_golem() -> void:
	var world := _spawn_world()
	var respawner := Node2D.new()
	var golem := (load(GOLEM_SCENE_PATH) as PackedScene).instantiate() as JewishGolem
	var boss_id := _unique_boss_id()

	respawner.set_script(load(RESPAWNER_SCRIPT_PATH))
	golem.boss_id = boss_id
	golem.position = Vector2(320.0, 0.0)
	respawner.add_child(golem)
	world.add_child(respawner)
	await _await_physics_frames(5)

	golem.shield_spawner.raise_blocks()
	golem.health.take_damage(100.0)
	respawner.respawn_all()
	await _await_physics_frames(3)

	var respawned := _find_golem(respawner, golem)

	_check(respawned != null, "The respawner must recreate the golem while he is undefeated.")
	if respawned != null:
		_check(respawned.boss_id == boss_id, "Respawn must keep his boss id.")
		_check(is_equal_approx(respawned.health.current, respawned.health.maximum), "He must come back at full health.")
		_check(respawned.shield_spawner.get_alive_count() == 0, "His old blocks must go with him.")
		_check(not respawned.is_defeated(), "An undefeated golem must come back awake.")

		respawned.health.take_damage(respawned.health.maximum)
		await _await_physics_frames(2)
		respawner.respawn_all()
		await _await_physics_frames(3)

		var after_defeat := _find_golem(respawner, respawned)

		_check(after_defeat != null and after_defeat.is_defeated(), "After his defeat he must come back asleep.")

	await _free_node(world)


func _test_save_game_boss_records() -> void:
	var boss_id := _unique_boss_id()

	_check(not SaveGame.is_boss_defeated(boss_id), "An unknown boss must not count as defeated.")

	SaveGame.mark_boss_defeated(boss_id)
	_check(SaveGame.is_boss_defeated(boss_id), "A marked boss must count as defeated.")

	SaveGame.apply_world_state(self)
	_check(not SaveGame.is_boss_defeated(boss_id), "Starting a new session must forget unsaved defeats.")

	SaveGame.mark_boss_defeated(boss_id)
	SaveGame.delete_save()
	_check(not SaveGame.is_boss_defeated(boss_id), "Deleting the save must forget defeats.")


func _test_bestiary_entry() -> void:
	var found := false

	for entry in load(BESTIARY_PATH).entries:
		if entry.id == &"jewish_golem":
			found = true
			_check(entry.portrait != null, "The golem's guide entry must have a portrait.")
			_check(entry.max_health >= 700.0, "The guide must show his boss health.")

	_check(found, "The monster guide must list the golem.")


func _clear_cooldowns(golem: JewishGolem) -> void:
	golem._cooldown_left = 0.0
	golem._clay_shot_cooldown_left = 0.0
	golem._summon_cooldown_left = 0.0
	golem._shield_cooldown_left = 0.0


func _unique_boss_id() -> StringName:
	_boss_counter += 1
	return StringName("test_golem_%d" % _boss_counter)


func _find_golem(parent: Node, previous: Variant) -> JewishGolem:
	for child in parent.get_children():
		if child is JewishGolem and child != previous and not child.is_queued_for_deletion():
			return child

	return null


func _count_children_of_type(parent: Node, type_name: String) -> int:
	var count := 0

	for child in parent.get_children():
		if child.is_queued_for_deletion():
			continue

		var script := child.get_script() as Script

		if script != null and script.get_global_name() == type_name:
			count += 1

	return count


func _spawn_world() -> Node2D:
	var world := Node2D.new()

	root.add_child(world)
	_spawn_block(world, Vector2(0.0, FLOOR_Y + 20.0), Vector2(40000.0, 40.0))
	return world


func _spawn_block(parent: Node, center: Vector2, size: Vector2) -> StaticBody2D:
	var block := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()

	block.collision_layer = 1
	block.collision_mask = 0
	rectangle.size = size
	shape.shape = rectangle
	block.add_child(shape)
	block.position = center
	parent.add_child(block)
	return block


func _spawn_golem(parent: Node, at: Vector2, boss_id: StringName = &"") -> JewishGolem:
	var golem := (load(GOLEM_SCENE_PATH) as PackedScene).instantiate() as JewishGolem

	golem.boss_id = boss_id if not boss_id.is_empty() else _unique_boss_id()
	golem.position = at
	parent.add_child(golem)
	return golem


func _spawn_player(parent: Node, at: Vector2) -> CharacterBody2D:
	var player := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	var health := Health.new()
	var receiver := AttackReceiver.new()
	var receiver_shape := CollisionShape2D.new()
	var reaction := HealthDamageReaction.new()

	player.collision_layer = 4
	player.collision_mask = 0
	player.add_to_group(&"player")
	rectangle.size = Vector2(30.0, 60.0)
	shape.shape = rectangle
	player.add_child(shape)
	health.name = "Health"
	health.maximum = 1000.0
	player.add_child(health)
	receiver.collision_layer = 16
	receiver.collision_mask = 0
	receiver_shape.shape = rectangle
	receiver.add_child(receiver_shape)
	reaction.health = health
	receiver.add_child(reaction)
	player.add_child(receiver)
	player.position = at
	parent.add_child(player)
	return player


func _await_until(condition: Callable, max_frames: int) -> void:
	for _index in max_frames:
		if condition.call():
			return
		await physics_frame


func _await_physics_frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()

	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
