extends SceneTree

# Scripts that reference autoloads (SaveGame, CoinManager, Events) are loaded at
# runtime from _run, after autoload registration, and are kept untyped here so
# compiling this test does not compile them early.

const TEST_SAVE_PATH := "user://test_savegame.cfg"
const PLAYER_SCENE := "res://entities/player/Player.tscn"
const CHECKPOINT_SCENE := "res://entities/interactive/checkpoint/Checkpoint.tscn"
const SKELETON_SCENE := "res://entities/enemies/basic_skeleton/BasicSkeleton.tscn"
const RESPAWNER_SCRIPT := "res://entities/enemies/respawn/enemy_respawner.gd"
const RING_PATH := "res://entities/items/definitions/regular_ring.tres"

var _checks: int = 0
var _failures: Array[String] = []
var _save_game: Node
var _coin_manager: Node
var _events: Node


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_save_game = root.get_node("SaveGame")
	_coin_manager = root.get_node("CoinManager")
	_events = root.get_node("Events")
	_save_game.save_path = TEST_SAVE_PATH
	_save_game.delete_save()

	await _test_rest_restores_health_and_announces()
	await _test_rest_respawns_enemies()
	await _test_save_and_load_round_trip()
	await _test_missing_save_is_ignored()
	await _test_checkpoint_save_button_rests_and_saves()
	await _test_spell_purchase_survives_death_and_restart()
	await _test_restart_without_save_resets_stardust()

	_save_game.delete_save()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: save system (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_rest_restores_health_and_announces() -> void:
	var player := await _spawn_player()
	var health = player.get_node("Health")
	var rest_count := [0]
	var on_rest := func() -> void: rest_count[0] += 1

	_events.checkpoint_rested.connect(on_rest)
	health.take_damage(40.0)
	_check(health.current < health.maximum, "Fixture: the player must start damaged.")

	player.rest_at_checkpoint(Vector2(300.0, 120.0))

	_check(is_equal_approx(health.current, health.maximum), "Resting must fully restore health.")
	_check(player.has_checkpoint(), "Resting must set the checkpoint.")
	_check(player.get_checkpoint_position() == Vector2(300.0, 120.0), "Resting must store the checkpoint position.")
	_check(rest_count[0] == 1, "Resting must announce checkpoint_rested exactly once.")

	_events.checkpoint_rested.disconnect(on_rest)
	await _free_all([player])


func _test_rest_respawns_enemies() -> void:
	var respawner := Node2D.new()
	respawner.set_script(load(RESPAWNER_SCRIPT))
	respawner.position = Vector2(5000.0, 5000.0)

	var enemy := (load(SKELETON_SCENE) as PackedScene).instantiate() as Node2D
	enemy.position = Vector2(40.0, 0.0)
	respawner.add_child(enemy)
	root.add_child(respawner)

	# EnemyRespawner records placements in _ready, before physics moves anything.
	var placed_position := respawner.position + enemy.position

	await process_frame

	# Simulate the enemy being killed before the player rests.
	enemy.queue_free()
	await process_frame
	_check(respawner.get_child_count() == 0, "Fixture: the killed enemy must be removed.")

	var player := await _spawn_player()
	player.rest_at_checkpoint(Vector2.ZERO)

	# Recreation happens synchronously on the rest signal; check before physics runs.
	_check(respawner.get_child_count() == 1, "Resting must recreate killed enemies.")

	if respawner.get_child_count() == 1:
		var recreated := respawner.get_child(0) as Node2D
		_check(recreated.global_position.is_equal_approx(placed_position), "Recreated enemies must return to their placed position.")

	await _free_all([player, respawner])


func _test_save_and_load_round_trip() -> void:
	var ring := load(RING_PATH)
	var source := await _spawn_player()

	_coin_manager.set_coins(7)
	source.get_spell_registry().register_spell(&"double_jump")
	source.get_inventory().add_item(ring, 2)
	source.get_equipment().equip(1, ring)
	source.rest_at_checkpoint(Vector2(640.0, -80.0))

	_check(_save_game.save_player(source), "Saving a rested player must succeed.")
	_check(_save_game.has_save(), "Saving must create the save file.")
	await _free_all([source])

	_coin_manager.set_coins(0)
	var target := await _spawn_player()
	var health = target.get_node("Health")
	health.take_damage(10.0)

	_check(_save_game.load_into_player(target), "Loading an existing save must succeed.")
	_check(target.global_position == Vector2(640.0, -80.0), "Loading must place the player at the saved checkpoint.")
	_check(target.get_checkpoint_position() == Vector2(640.0, -80.0), "Loading must restore the checkpoint for later deaths.")
	_check(_coin_manager.coins == 7, "Loading must restore Stardust.")
	_check(target.get_spell_registry().has_spell(&"double_jump"), "Loading must restore acquired spells.")
	_check(target.get_spell_registry().has_spell(&"magic_arrow"), "Loading must keep initial spells.")
	_check(target.get_inventory().get_quantity(ring) == 2, "Loading must restore inventory quantities.")
	_check(target.get_equipment().get_item(1) == ring, "Loading must restore equipped items in their slots.")
	_check(target.get_equipment().get_item(0) == null, "Loading must leave empty slots empty.")
	_check(is_equal_approx(health.current, health.maximum), "Loading must start the player at full health.")

	_coin_manager.set_coins(0)
	await _free_all([target])


func _test_missing_save_is_ignored() -> void:
	_save_game.delete_save()
	_check(not _save_game.has_save(), "Deleting the save must remove the file.")

	var player := await _spawn_player()
	var start_position := player.global_position

	_check(not _save_game.load_into_player(player), "Loading without a save must report false.")
	_check(player.global_position == start_position, "Loading without a save must not move the player.")
	_check(not player.has_checkpoint(), "Loading without a save must not set a checkpoint.")

	var unsaved := await _spawn_player()
	_check(not _save_game.save_player(unsaved), "A player without a checkpoint must not be saved.")
	_check(not _save_game.has_save(), "Rejected saves must not create a file.")

	await _free_all([player, unsaved])


func _test_checkpoint_save_button_rests_and_saves() -> void:
	var player := await _spawn_player()
	var health = player.get_node("Health")
	var checkpoint = (load(CHECKPOINT_SCENE) as PackedScene).instantiate()

	checkpoint.position = Vector2(240.0, -180.0)
	root.add_child(checkpoint)
	await process_frame

	health.take_damage(30.0)
	checkpoint.body_entered.emit(player)
	_press_interaction(player.get_interactor())

	var menu := _find_menu()
	_check(menu != null, "The checkpoint menu must open.")

	if menu != null:
		menu.get_node("MenuHolder/SaveButton").pressed.emit()
		await process_frame

		var spawn_position: Vector2 = checkpoint.spawn_point.global_position

		_check(is_equal_approx(health.current, health.maximum), "Saving at a checkpoint must restore health.")
		_check(player.get_checkpoint_position() == spawn_position, "Saving at a checkpoint must set it as the respawn point.")
		_check(_save_game.has_save(), "Saving at a checkpoint must write the save file.")
		_check(not paused, "Saving at a checkpoint must resume gameplay.")

	await _free_all([player, checkpoint])


func _test_spell_purchase_survives_death_and_restart() -> void:
	_save_game.delete_save()
	change_scene_to_file("res://Main.tscn")
	await _frames(3)

	_coin_manager.set_coins(500)
	var player = current_scene.get_node("LevelRoot/Player")
	var menu = _open_level_checkpoint_menu(player)
	_check(menu != null, "The level checkpoint menu must open.")

	if menu == null:
		return

	var spell = player.get_spell_registry().database.get_spell(&"double_jump")
	menu.open_spell_shop()
	menu._on_buy_pressed(spell)
	menu.go_back()
	menu.go_back()
	await process_frame

	_check(player.get_spell_registry().has_spell(&"double_jump"), "Buying must register the spell.")
	_check(_save_game.has_save(), "Buying a spell must save even when leaving with Back.")

	player.get_node("Health").take_damage(99999.0)
	await _frames(3)
	_check(player.get_spell_registry().has_spell(&"double_jump"), "Death must not undo a purchase.")

	var coins_after_purchase: int = _coin_manager.coins
	current_scene.get_node("PauseMenuLayer/PauseMenu")._on_restart_pressed()
	await _frames(3)
	player = current_scene.get_node("LevelRoot/Player")

	_check(player.get_spell_registry().has_spell(&"double_jump"), "Restart must not undo a purchase.")
	_check(_coin_manager.coins == coins_after_purchase, "Restart must keep the Stardust left after a purchase.")

	_save_game.delete_save()
	_coin_manager.set_coins(0)


func _test_restart_without_save_resets_stardust() -> void:
	_save_game.delete_save()
	_coin_manager.set_coins(250)

	current_scene.get_node("PauseMenuLayer/PauseMenu")._on_restart_pressed()
	await _frames(3)

	_check(_coin_manager.coins == 0, "Restart without a save must not keep unsaved Stardust.")

	current_scene.queue_free()
	current_scene = null
	await process_frame


func _open_level_checkpoint_menu(player: Node) -> Node:
	var checkpoint = current_scene.get_node("LevelRoot/Checkpoint")

	checkpoint.body_entered.emit(player)
	checkpoint.try_interact(player)

	return _find_menu()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _spawn_player() -> CharacterBody2D:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as CharacterBody2D

	player.position = Vector2(-1000.0, -1000.0)
	player.set_physics_process(false)
	root.add_child(player)
	await process_frame

	return player


func _free_all(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()

	await process_frame


func _find_menu() -> Node:
	for child in root.get_children():
		if child.has_method(&"open_spell_shop"):
			return child

	return null


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)


func _press_interaction(interactor: Node) -> void:
	var release := InputEventAction.new()
	release.action = &"interaction"
	release.pressed = false
	interactor._input(release)

	var press := InputEventAction.new()
	press.action = &"interaction"
	press.pressed = true
	interactor._unhandled_input(press)
