extends SceneTree

## Enemies hit by the player from outside their detection radius must react
## to the attacker (provoke on hit).

const FLOOR_Y := 48.0
const FAR := 1400.0
const SCENES := {
	"skeleton": "res://entities/enemies/basic_skeleton/BasicSkeleton.tscn",
	"crawler": "res://entities/enemies/platform_crawler/PlatformCrawler.tscn",
	"eye": "res://entities/enemies/flying_eye/FlyingEye.tscn",
	"moth": "res://entities/enemies/life_moth/LifeMoth.tscn",
	"beetle": "res://entities/enemies/dung_beetle/DungBeetle.tscn",
	"star": "res://entities/enemies/star_man/StarMan.tscn",
	"scorpion": "res://entities/enemies/scorpion_man/ScorpionMan.tscn",
	"couple": "res://entities/enemies/homunculus_couple/HomunculusCouple.tscn",
}
const ARROW_SPELL_PATH := "res://spells/attack/magic_arrow/MagicArrowSpell.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_detector_provocation()
	await _test_only_player_attacks_provoke()
	_test_every_enemy_is_wired()
	await _test_skeleton_chases_far_attacker()
	await _test_skeleton_calms_down_after_provocation()
	await _test_scorpion_chases_far_attacker()
	await _test_star_man_screams_at_far_attacker()
	await _test_flying_eye_engages_far_attacker()
	await _test_crawler_charges_when_hit_from_behind()
	await _test_moth_and_beetle_flee_far_attacker()
	await _test_couple_wakes_when_hit()
	await _test_magic_arrow_provokes_end_to_end()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: provoke on hit (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_detector_provocation() -> void:
	var world := _spawn_world()
	var detector := TargetDetector.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	var entered: Array[Node2D] = []
	var exited: Array[Node2D] = []

	circle.radius = 50.0
	shape.shape = circle
	detector.collision_mask = 4
	detector.add_child(shape)
	world.add_child(detector)

	var player := _spawn_player(world, Vector2(FAR, 0.0))

	detector.target_entered.connect(func(target: Node2D) -> void: entered.append(target))
	detector.target_exited.connect(func(target: Node2D) -> void: exited.append(target))
	await _frames(3)

	_check(not detector.has_target(player), "The fixture player must start out of range.")

	detector.provoke(player, 0.5)
	_check(detector.has_target(player) and detector.is_provoked(player), "A provoked target must count as detected.")
	_check(detector.get_targets().size() == 1 and detector.get_targets()[0] == player, "A provoked target must be listed once.")
	_check(entered.size() == 1 and entered[0] == player, "Provoking must announce the target once.")

	await _frames(20)
	detector.provoke(player, 0.5)
	await _frames(20)
	_check(detector.has_target(player), "Provoking again must refresh the time.")
	_check(entered.size() == 1, "Refreshing must not announce the target again.")

	await _frames(15)
	_check(not detector.has_target(player), "The provocation must end after its duration.")
	_check(exited.size() == 1 and exited[0] == player, "The end of a provocation must announce the exit.")

	# A target that walks out while provoked stays detected until the end.
	player.global_position = Vector2.ZERO
	await _frames(3)
	detector.provoke(player, 0.3)
	player.global_position = Vector2(FAR, 0.0)
	await _frames(3)
	_check(detector.has_target(player), "Leaving the area while provoked must keep the target.")
	_check(exited.size() == 1, "Leaving while provoked must not announce an exit yet.")
	await _frames(25)
	_check(not detector.has_target(player) and exited.size() == 2, "The exit must come when the provocation ends.")

	await _free(world)


func _test_only_player_attacks_provoke() -> void:
	var world := _spawn_world()
	var skeleton := _spawn(world, "skeleton", Vector2.ZERO)
	var stranger := Node2D.new()

	world.add_child(stranger)
	await _frames(3)
	_hit(skeleton, stranger)

	var detector: TargetDetector = skeleton.get_node("AggroDetector")

	_check(detector.get_targets().is_empty(), "Attacks from outside the player group must not provoke.")

	await _free(world)


func _test_every_enemy_is_wired() -> void:
	for key in SCENES:
		if key == "couple":
			continue

		var enemy: Node = (load(SCENES[key]) as PackedScene).instantiate()
		var reactions := enemy.find_children("*", "ProvokeOnHitReaction", true, false)

		_check(reactions.size() == 1, "%s must have a ProvokeOnHitReaction." % key)
		enemy.free()


func _test_skeleton_chases_far_attacker() -> void:
	var world := _spawn_world()
	var skeleton := _spawn(world, "skeleton", Vector2.ZERO) as BasicMob
	var player := _spawn_player(world, Vector2(FAR, 0.0))
	await _frames(10)

	_check(skeleton.target == null, "The fixture skeleton must not see the far player.")

	_hit(skeleton, player)
	await _frames(20)

	_check(skeleton.target == player, "A hit from afar must make the skeleton target the attacker.")
	_check(skeleton.state == BasicMob.State.CHASE, "The provoked skeleton must chase.")
	_check(skeleton.velocity.x > 0.0, "It must walk toward the attacker.")

	await _free(world)


func _test_skeleton_calms_down_after_provocation() -> void:
	var world := _spawn_world()
	var skeleton := _spawn(world, "skeleton", Vector2.ZERO) as BasicMob
	var player := _spawn_player(world, Vector2(FAR * 3.0, 0.0))
	var provoke: ProvokeOnHitReaction = skeleton.find_children("*", "ProvokeOnHitReaction", true, false)[0]

	provoke.duration = 0.3
	await _frames(5)
	_hit(skeleton, player)
	await _frames(5)
	_check(skeleton.state == BasicMob.State.CHASE, "The fixture skeleton must start chasing.")

	await _frames(25)
	_check(skeleton.target == null and skeleton.state == BasicMob.State.IDLE, "Out of range, it must give up when the provocation ends.")

	await _free(world)


func _test_scorpion_chases_far_attacker() -> void:
	var world := _spawn_world()
	var scorpion := _spawn(world, "scorpion", Vector2.ZERO) as ScorpionMan
	var player := _spawn_player(world, Vector2(FAR, 0.0))
	await _frames(10)

	_hit(scorpion, player)
	await _frames(10)

	_check(scorpion.get_target() == player, "A hit from afar must make the Scorpion Man target the attacker.")
	_check(scorpion.get_state() != ScorpionMan.State.IDLE, "The provoked Scorpion Man must act.")

	await _free(world)


func _test_star_man_screams_at_far_attacker() -> void:
	var world := _spawn_world()
	var star := _spawn(world, "star", Vector2.ZERO) as StarMan
	var player := _spawn_player(world, Vector2(FAR, 0.0))

	_spawn_block(world, Vector2(300.0, -40.0), Vector2(20.0, 100.0))
	await _frames(10)
	_check(star.get_state() == StarMan.State.IDLE, "The fixture Star Man must not see the far player.")

	_hit(star, player)
	await _frames(3)

	_check(star.get_state() == StarMan.State.SCREAM, "A hit from afar, even behind a wall, must make him scream.")
	_check(star.get_target() == player, "He must target the attacker.")

	await _free(world)


func _test_flying_eye_engages_far_attacker() -> void:
	var world := _spawn_world()
	var eye := _spawn(world, "eye", Vector2(0.0, -200.0)) as FlyingEye
	var player := _spawn_player(world, Vector2(FAR, 0.0))
	await _frames(10)

	_hit(eye, player)
	await _frames(3)

	_check(eye.get_state() == FlyingEye.State.ENGAGE, "A hit from afar must make the eye engage.")
	_check(eye.get_target() == player, "The eye must target the attacker.")

	await _free(world)


func _test_crawler_charges_when_hit_from_behind() -> void:
	var world := _spawn_world()
	var crawler := _spawn(world, "crawler", Vector2(0.0, -200.0)) as PlatformCrawler
	var player := _spawn_player(world, Vector2(-FAR, 0.0))
	await _frames(10)

	_check(crawler.get_state() == PlatformCrawler.State.PATROL, "The fixture crawler must be patrolling.")

	_hit(crawler, player)
	await _frames(3)

	_check(crawler.get_state() == PlatformCrawler.State.CHARGE, "A hit from afar or from behind must make the crawler charge.")

	await _free(world)


func _test_moth_and_beetle_flee_far_attacker() -> void:
	var world := _spawn_world()
	var moth := _spawn(world, "moth", Vector2(0.0, -150.0)) as LifeMoth
	var beetle := _spawn(world, "beetle", Vector2(600.0, 0.0)) as DungBeetle
	var player := _spawn_player(world, Vector2(-FAR, 0.0))
	await _frames(10)

	_hit(moth, player)
	_hit(beetle, player)
	await _frames(5)

	_check(moth.get_state() == LifeMoth.State.FLEE, "A moth hit from afar must flee.")
	_check(beetle.get_state() == DungBeetle.State.FLEE, "A beetle hit from afar must flee.")

	await _free(world)


func _test_couple_wakes_when_hit() -> void:
	var world := _spawn_world()
	var couple := _spawn(world, "couple", Vector2(0.0, 24.0)) as HomunculusCouple
	var player := _spawn_player(world, Vector2(FAR, 0.0))
	await _frames(10)

	_hit(couple.right, player)
	await _frames(2)

	_check(couple.get_state() == HomunculusCouple.State.CHASING, "Homunculi hit from afar must chase the attacker.")

	await _free(world)


func _test_magic_arrow_provokes_end_to_end() -> void:
	var world := _spawn_world()
	var scorpion := _spawn(world, "scorpion", Vector2(0.0, 0.0)) as ScorpionMan
	var player := _spawn_player(world, Vector2(-450.0, 0.0))
	var spell := (load(ARROW_SPELL_PATH) as PackedScene).instantiate() as MagicArrowSpell
	var context := SpellContext.new()
	var detector: TargetDetector = scorpion.get_node("AggroDetector")

	(detector.get_node("CollisionShape2D") as CollisionShape2D).shape = CircleShape2D.new()
	(detector.get_node("CollisionShape2D") as CollisionShape2D).shape.radius = 10.0
	await _frames(5)
	_check(scorpion.get_target() == null, "The fixture Scorpion Man must not detect the player.")

	context.caster = player
	context.effect_parent = world
	context.origin = player.global_position
	context.direction = Vector2.RIGHT
	context.aim_direction = Vector2.RIGHT
	world.add_child(spell)
	spell.execute(context)

	await _frames(40)
	_check(scorpion.health.current < scorpion.health.maximum, "The arrow must hit.")
	_check(scorpion.get_target() == player, "A real Magic Arrow from afar must provoke the enemy.")

	await _free(world)


func _hit(enemy: Node, attacker: Node) -> void:
	var receivers := enemy.find_children("*", "AttackReceiver", true, false)
	var attack := AttackData.new()

	if enemy is AttackReceiver:
		receivers = [enemy]
	elif enemy.has_node("AttackReceiver"):
		receivers = [enemy.get_node("AttackReceiver")]

	attack.source = attacker
	attack.damage = 1.0
	(receivers[0] as AttackReceiver).receive_attack(attack)


func _spawn(parent: Node, key: String, at: Vector2) -> Node2D:
	var enemy := (load(SCENES[key]) as PackedScene).instantiate() as Node2D

	enemy.position = at
	parent.add_child(enemy)
	return enemy


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


func _spawn_player(parent: Node, at: Vector2) -> CharacterBody2D:
	var player := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()

	player.collision_layer = 4
	player.collision_mask = 0
	player.add_to_group(&"player")
	rectangle.size = Vector2(30.0, 60.0)
	shape.shape = rectangle
	player.add_child(shape)
	player.position = at
	parent.add_child(player)
	return player


func _frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _free(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()

	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
