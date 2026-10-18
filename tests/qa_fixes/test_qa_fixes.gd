extends SceneTree

# Regression checks for the QA round: pickup farming, duplicate equipment,
# levers behind the caster, New Game confirmation, menu key conflicts, the
# restart label, and the shaft B corridor.

const TEST_SAVE_PATH := "user://test_qa_save.cfg"
const RING_PATH := "res://entities/items/definitions/regular_ring.tres"

var _checks: int = 0
var _failures: Array[String] = []
var _save_game: Node
var _coins: Node
var _settings: Node


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_save_game = root.get_node("SaveGame")
	_coins = root.get_node("CoinManager")
	_settings = root.get_node("Settings")
	_save_game.save_path = TEST_SAVE_PATH
	_save_game.delete_save()

	await _test_saved_pickups_stay_collected()
	await _test_equipment_limited_to_owned()
	await _test_levers_ignore_pushes_behind()
	await _test_new_game_confirmation()
	_test_menu_key_conflicts()
	await _test_restart_label()

	_save_game.delete_save()
	_settings.reset_to_defaults()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: QA fixes (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_saved_pickups_stay_collected() -> void:
	await _open_game()

	var coins := current_scene.get_node("Coin")
	var first: Node = coins.get_child(0)
	var first_name := first.name
	var player = _player()

	first._on_body_entered(player)
	await _frames(40)
	_check(_coins.coins == 1, "Collecting a coin must add Stardust.")

	# Not saved yet: a restart brings the coin back and drops the Stardust.
	await _restart()
	_check(current_scene.get_node("Coin").has_node(NodePath(first_name)), "An unsaved pickup must come back on restart.")
	_check(_coins.coins == 0, "Unsaved Stardust must be lost on restart.")

	first = current_scene.get_node("Coin").get_node(NodePath(first_name))
	first._on_body_entered(_player())
	await _frames(40)
	await _rest_at_checkpoint()

	await _restart()
	_check(not current_scene.get_node("Coin").has_node(NodePath(first_name)), "A saved pickup must stay collected after restart.")
	_check(_coins.coins == 1, "Saved Stardust must be kept without being farmable.")
	_check(current_scene.get_node("Coin").get_child_count() == 2, "Other pickups must remain.")

	_save_game.delete_save()


func _test_equipment_limited_to_owned() -> void:
	await _open_game()

	var player = _player()
	var ring = load(RING_PATH)
	var equipment = player.get_equipment()

	player.get_inventory().add_item(ring, 1)
	_check(equipment.equip(0, ring), "An owned item must be equippable.")
	_check(not equipment.equip(1, ring), "One copy must not fill a second slot.")
	_check(equipment.get_item(1) == null, "The second slot must stay empty.")

	var menu = current_scene.get_node("PauseMenuLayer/PauseMenu")
	menu.pause_game()
	menu.open_item_picker(1)
	_check(_overlay_has_button(menu, "Ring") == false, "The picker must hide items already equipped elsewhere.")
	menu.close_overlay()

	player.get_inventory().add_item(ring, 1)
	_check(equipment.equip(1, ring), "A second copy must fill a second slot.")
	_check(not equipment.equip(2, ring), "Two copies must not fill a third slot.")
	paused = false


func _test_levers_ignore_pushes_behind() -> void:
	await _open_game()

	var player = _player()
	var lever = current_scene.get_node("LevelRoot/Lever3")
	var switch = lever.get_node("SwitchComponent")

	await _place(player, lever.global_position + Vector2(-70, -50))
	await _cast_push(player, Vector2.RIGHT)
	_check(switch.active, "A push toward a lever in front must still activate it.")

	await _place(player, lever.global_position + Vector2(70, -50))
	await _cast_push(player, Vector2.RIGHT)
	_check(switch.active, "A push while facing away must not flip a door lever behind the caster.")

	await _cast_push(player, Vector2.LEFT)
	_check(not switch.active, "Facing the lever, a push must still deactivate it.")


func _test_new_game_confirmation() -> void:
	await _open_game()
	await _rest_at_checkpoint()
	_check(_save_game.has_save(), "Fixture: a save must exist.")

	change_scene_to_file("res://ui/main_menu/MainMenu.tscn")
	await _wait_for_scene("MainMenu")

	var menu = current_scene
	menu._on_start_pressed()
	await _frames(2)
	_check(menu.is_confirming_new_game(), "New Game must ask for confirmation when a save exists.")
	_check(_save_game.has_save(), "Asking must not delete the save.")

	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	menu._unhandled_input(cancel)
	_check(not menu.is_confirming_new_game() and _save_game.has_save(), "Cancel must keep the save.")

	menu._on_start_pressed()
	menu.confirm_new_game_button.pressed.emit()
	await _wait_for_scene("Main")
	_check(not _save_game.has_save(), "Confirming must delete the save.")
	_check(current_scene != null and current_scene.name == "Main", "Confirming must start the game.")


func _test_menu_key_conflicts() -> void:
	_settings.reset_to_defaults()

	_check(not _settings.set_binding(&"pause", KEY_E), "Pause must not take E, which switches menu tabs.")
	_check(_settings.get_binding(&"pause") == KEY_ESCAPE, "A rejected binding must leave the old key.")
	_check(not _settings.get_binding_conflict(&"pause", KEY_Q).is_empty(), "Q must be reported as a conflict for Pause.")
	_check(not _settings.set_binding(&"left", KEY_Q), "Movement must not take a menu tab key.")
	_check(_settings.set_binding(&"jump", KEY_E), "Actions not used in menus may take a tab key.")
	_check(not _settings.set_binding(&"jump", KEY_A), "A swap that gives Left the E key must be rejected.")
	_check(_settings.get_binding(&"jump") == KEY_E, "A rejected swap must leave both keys in place.")

	_settings.reset_to_defaults()


func _test_restart_label() -> void:
	_save_game.delete_save()
	await _open_game()

	var menu = current_scene.get_node("PauseMenuLayer/PauseMenu")
	menu.pause_game()
	_check(menu.restart_button.text == "Restart from the beginning", "Without a save, restart must say it starts over.")
	paused = false
	menu.visible = false

	await _rest_at_checkpoint()
	menu.pause_game()
	_check(menu.restart_button.text == "Restart from last checkpoint", "With a save, restart must name the checkpoint.")
	paused = false
	_save_game.delete_save()


func _test_shaft_b_corridor() -> void:
	await _open_game()

	var level := current_scene.get_node("LevelRoot")
	var elevator = level.get_node("ElevatorB")
	var player = _player()
	elevator.speed = 3000.0

	_check(elevator.is_at_top(), "ElevatorB must start at the corridor, keeping it walkable.")

	# Walk the whole corridor gap from the right side to the left side.
	await _place(player, level.position + Vector2(-860, 958))
	Input.action_press(&"left")

	for i in 90:
		await physics_frame

	Input.action_release(&"left")
	await _frames(10)
	var x: float = player.global_position.x - level.position.x
	var y: float = player.global_position.y - level.position.y
	_check(x < -1296.0 and y < 1010.0, "The player must walk across shaft B on the platform (at %.0f, %.0f)." % [x, y])

	# Send it down from the left, then call it back from the right side.
	await _cast_push(player, Vector2.LEFT)
	await _wait_trip(elevator)
	_check(not elevator.is_at_top(), "The left lever must send the elevator down.")

	await _place(player, level.position + Vector2(-840, 958))
	await _cast_push(player, Vector2.LEFT)
	await _wait_trip(elevator)
	_check(elevator.is_at_top(), "The right-side lever must call the elevator back up.")


func _test_elevator_landings_walkable() -> void:
	await _open_game()

	var level := current_scene.get_node("LevelRoot")
	var player = _player()
	var elevator_a = level.get_node("ElevatorA")
	var elevator_b = level.get_node("ElevatorB")
	elevator_a.speed = 3000.0

	await _walk(player, level.position + Vector2(1760, 5340), &"right", 40)
	_check(_level_x(player) > 1900.0 and player.is_on_floor(), "The player must walk into shaft A from its bottom landing.")

	await _walk(player, level.position + Vector2(1990, 5320), &"left", 50)
	_check(_level_x(player) < 1872.0, "The player must walk out of shaft A onto its bottom landing.")

	elevator_b.start_at_top = false
	elevator_b._ready()
	await _walk(player, level.position + Vector2(-820, 3180), &"left", 40)
	_check(_level_x(player) < -940.0 and player.is_on_floor(), "The player must walk into shaft B from its bottom landing.")

	await _walk(player, level.position + Vector2(-1000, 3160), &"right", 50)
	_check(_level_x(player) > -912.0, "The player must walk out of shaft B onto its bottom landing.")

	await _place(player, level.position + Vector2(1990, 5320))
	elevator_a.call_elevator()
	await _wait_trip(elevator_a)
	_check(absf(player.global_position.y - level.position.y - 3280.0) < 6.0, "A player standing in shaft A must ride up to the top landing.")

	await _walk(player, player.global_position, &"left", 20)
	_check(_level_x(player) < 1872.0 and player.is_on_floor(), "The player must walk off at shaft A's top landing.")

	# Shaft C: corridor crossing on the platform, then the bottom landing.
	var elevator_c = level.get_node("ElevatorC")
	elevator_c.speed = 3000.0
	level.get_node("EnemyRespawner/BasicMob5").queue_free()

	await _walk(player, level.position + Vector2(2560, 1744), &"right", 80)
	_check(_level_x(player) > 3024.0 and player.is_on_floor(), "The player must walk across shaft C on the platform.")

	elevator_c.start_at_top = false
	elevator_c._ready()
	await _walk(player, level.position + Vector2(2540, 2704), &"right", 48)
	_check(_level_x(player) > 2670.0 and player.is_on_floor(), "The player must walk into shaft C from its bottom landing.")

	await _walk(player, level.position + Vector2(2760, 2686), &"left", 50)
	_check(_level_x(player) < 2640.0, "The player must walk out of shaft C onto its bottom landing.")

	await _place(player, level.position + Vector2(2560, 2704))
	await _cast_push(player, Vector2.RIGHT)
	await _wait_trip(elevator_c)
	_check(elevator_c.is_at_top(), "The bottom lever must send elevator C up.")


func _walk(player: CharacterBody2D, start: Vector2, action: StringName, frames: int) -> void:
	await _place(player, start)
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(10)


func _level_x(player: Node2D) -> float:
	return player.global_position.x - current_scene.get_node("LevelRoot").position.x


func _open_game() -> void:
	paused = false
	change_scene_to_file("res://Main.tscn")
	await _wait_for_scene("Main")


func _restart() -> void:
	var previous := current_scene
	current_scene.get_node("PauseMenuLayer/PauseMenu")._on_restart_pressed()
	await _wait_for_scene("Main", previous)


## Scene changes apply at the end of a process frame; physics frames can run
## several times in between after a heavy load, so wait on process frames.
func _wait_for_scene(scene_name: String, previous: Node = null) -> void:
	for i in 120:
		await process_frame

		if (
			current_scene != null
			and current_scene != previous
			and current_scene.name == scene_name
			and current_scene.is_node_ready()
		):
			break

	await _frames(5)


func _rest_at_checkpoint() -> void:
	var player = _player()
	var checkpoint = current_scene.get_node("LevelRoot/Checkpoint")
	checkpoint.body_entered.emit(player)
	checkpoint.try_interact(player)

	for child in root.get_children():
		if child.has_method(&"open_spell_shop"):
			child._on_save_btn_pressed()

	await _frames(2)
	checkpoint.body_exited.emit(player)


func _player() -> CharacterBody2D:
	return current_scene.get_node("LevelRoot/Player")


func _place(player: CharacterBody2D, at: Vector2) -> void:
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	await _frames(20)


func _cast_push(player: Node, facing: Vector2) -> void:
	var spell = load("res://spells/action/push/PushSpell.tscn").instantiate()
	player.add_child(spell)
	await _frames(2)

	var context := SpellContext.new()
	context.caster = player
	context.effect_parent = player
	context.origin = player.get_node("SpellOrigin").global_position
	context.direction = facing
	spell.execute(context)
	await _frames(100)


func _wait_trip(elevator: Node) -> void:
	for i in 30:
		if elevator.is_moving():
			break

		await physics_frame

	for i in 900:
		if not elevator.is_moving():
			break

		await physics_frame

	await _frames(10)


func _overlay_has_button(menu: Node, text: String) -> bool:
	for child in menu.overlay_list.get_children():
		if child is Button and (child as Button).text.contains(text):
			return true

	return false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
