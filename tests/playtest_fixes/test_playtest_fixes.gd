extends SceneTree

## Regressions found while playtesting the whole game.

const MAIN_SCENE_PATH := "res://Main.tscn"
const PLAYER_SCENE_PATH := "res://entities/player/Player.tscn"
const RESPAWNER_SCRIPT_PATH := "res://entities/enemies/respawn/enemy_respawner.gd"
const STAR_SCENE_PATH := "res://entities/enemies/star_man/StarMan.tscn"
const SCORPION_SCENE_PATH := "res://entities/enemies/scorpion_man/ScorpionMan.tscn"
const SKELETON_SCENE_PATH := "res://entities/enemies/basic_skeleton/BasicSkeleton.tscn"
const EYE_SCENE_PATH := "res://entities/enemies/flying_eye/FlyingEye.tscn"
const ENEMY_CLASSES := [
	"BasicMob", "PlatformCrawler", "FlyingEye", "HomunculusCouple", "LifeMoth",
	"DungBeetle", "StarMan", "ScorpionMan",
]

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_enemy_health_has_no_invulnerability()
	await _test_player_invulnerability_window()
	await _test_killed_enemies_come_back()
	_test_every_main_enemy_respawns()
	await _test_flying_eye_crosses_the_line_of_fire()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: playtest fixes (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_enemy_health_has_no_invulnerability() -> void:
	var health := Health.new()

	health.maximum = 100.0
	root.add_child(health)
	await physics_frame

	health.take_damage(10.0)
	health.take_damage(10.0)

	_check(is_equal_approx(health.current, 80.0), "Without a window, back-to-back hits must all land.")
	health.free()


func _test_player_invulnerability_window() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as CharacterBody2D

	player.set_physics_process(false)
	root.add_child(player)
	await physics_frame

	var health: Health = player.get_node("Health")

	_check(health.invulnerability_duration > 0.0, "The player must have a short invulnerability window.")
	_check(is_equal_approx(health.take_damage(20.0), 20.0), "The first hit must land.")
	_check(health.is_invulnerable(), "A hit must start the invulnerability window.")
	_check(is_zero_approx(health.take_damage(20.0)), "A second hit inside the window must be ignored.")
	_check(is_equal_approx(health.current, health.maximum - 20.0), "Only the first of two simultaneous hits must count.")

	for _index in ceili(health.invulnerability_duration * 60.0) + 2:
		await physics_frame

	_check(not health.is_invulnerable(), "The window must end.")
	_check(is_equal_approx(health.take_damage(20.0), 20.0), "Hits must land again after the window.")

	health.reset()
	_check(not health.is_invulnerable(), "Respawning (reset) must clear the window.")

	player.queue_free()
	await process_frame


func _test_killed_enemies_come_back() -> void:
	var world := Node2D.new()
	var respawner := Node2D.new()

	respawner.set_script(load(RESPAWNER_SCRIPT_PATH))

	for path in [STAR_SCENE_PATH, SCORPION_SCENE_PATH, SKELETON_SCENE_PATH]:
		var enemy := (load(path) as PackedScene).instantiate() as Node2D

		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		respawner.add_child(enemy)

	world.add_child(respawner)
	root.add_child(world)
	await process_frame

	for type in [StarMan, ScorpionMan, BasicMob]:
		_first_of(respawner, type).get_node("Health").take_damage(9999.0)

	await process_frame
	respawner.respawn_all()
	await process_frame

	for type in [StarMan, ScorpionMan, BasicMob]:
		var enemy := _first_of(respawner, type)

		_check(enemy != null, "Every killed enemy, the Star Man and Scorpion Man included, must come back on respawn.")
		if enemy != null:
			var health: Health = enemy.get_node("Health")

			_check(is_equal_approx(health.current, health.maximum), "Respawned enemies must come back at full health.")

	world.queue_free()
	await process_frame


func _test_every_main_enemy_respawns() -> void:
	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	var enemy_count := 0

	for node in main.find_children("*", "", true, false):
		var script: Script = node.get_script()

		if script == null or not (script.get_global_name() in ENEMY_CLASSES):
			continue

		enemy_count += 1
		_check(
			node.get_parent().get_script() == load(RESPAWNER_SCRIPT_PATH),
			"'%s' must be placed under an EnemyRespawner so it comes back after death." % node.name
		)

	_check(enemy_count >= 15, "The demo must contain all placed enemies.")
	main.free()


func _test_flying_eye_crosses_the_line_of_fire() -> void:
	var eye := (load(EYE_SCENE_PATH) as PackedScene).instantiate() as FlyingEye
	var target := Node2D.new()
	var lowest_height := INF

	root.add_child(target)
	root.add_child(eye)
	eye.set_physics_process(false)
	await process_frame

	for step in 60:
		eye._engage_time = eye.engage_sway_period * step / 60.0
		var point := eye._engage_point(target)

		lowest_height = minf(lowest_height, target.global_position.y - point.y)

	_check(lowest_height <= 20.0, "While shooting, the eye must dip to the player's height now and then.")

	eye.queue_free()
	target.queue_free()
	await process_frame


func _first_of(parent: Node, type: Variant) -> Node:
	for child in parent.get_children():
		if is_instance_of(child, type) and not child.is_queued_for_deletion():
			return child

	return null


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
