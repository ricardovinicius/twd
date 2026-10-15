extends SceneTree

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_checkpoint_menu_and_respawn()
	_test_level_checkpoint_placement()
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	if _failures.is_empty():
		print("PASS: checkpoint (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_checkpoint_menu_and_respawn() -> void:
	var player_scene: PackedScene = load("res://entities/player/Player.tscn")
	var checkpoint_scene: PackedScene = load("res://entities/interactive/checkpoint/Checkpoint.tscn")
	var player := player_scene.instantiate() as CharacterBody2D
	player.position = Vector2(-1000.0, -1000.0)
	player.set_physics_process(false)
	root.add_child(player)
	var initial_position := player.global_position
	var checkpoint := checkpoint_scene.instantiate() as Checkpoint
	checkpoint.position = Vector2(240.0, -180.0)
	root.add_child(checkpoint)
	await process_frame

	var interaction := InputEventAction.new()
	interaction.action = &"interaction"
	interaction.pressed = true
	checkpoint.body_entered.emit(player)
	checkpoint._unhandled_input(interaction)
	var menu := _find_menu()
	_check(menu != null, "An eligible player must be able to open the checkpoint menu.")
	if menu == null:
		player.queue_free()
		checkpoint.queue_free()
		await process_frame
		return
	_check(paused, "Opening the checkpoint menu must pause gameplay.")
	var save_button := menu.get_node("MenuHolder/SaveButton") as Button
	_check(save_button.has_focus(), "The checkpoint Save button must receive focus.")
	checkpoint._unhandled_input(interaction)
	_check(_menu_count() == 1, "Repeated interaction must not create another checkpoint menu.")
	menu.get_node("MenuHolder/BackButton").pressed.emit()
	await process_frame
	_check(not paused, "Back must resume gameplay.")
	_check(_find_menu() == null, "Closing a checkpoint menu must free it.")
	player.position = Vector2.ZERO
	player.spawn_player()
	_check(player.global_position == initial_position, "Back must leave the spawn position unchanged.")

	checkpoint._unhandled_input(interaction)
	menu = _find_menu()
	_check(menu != null, "A closed checkpoint menu must be reopenable.")
	if menu != null:
		menu.get_node("MenuHolder/SaveButton").pressed.emit()
		await process_frame
		_check(not paused, "Saving a checkpoint must resume gameplay.")
		player.position = Vector2.ZERO
		player.spawn_player()
		_check(player.global_position == checkpoint.spawn_point.global_position, "Save must use the checkpoint's world-space spawn point.")

	checkpoint.body_exited.emit(player)
	checkpoint._unhandled_input(interaction)
	_check(_find_menu() == null, "Leaving the checkpoint must disable interaction.")
	player.queue_free()
	checkpoint.queue_free()
	await process_frame


func _test_level_checkpoint_placement() -> void:
	var scene: PackedScene = load("res://levels/level_01/Level01.tscn")
	var level := scene.instantiate()
	var checkpoint := level.get_node("Checkpoint") as Checkpoint
	_check(checkpoint != null, "The level must instantiate the reusable checkpoint feature.")
	if checkpoint != null:
		_check(checkpoint.position == Vector2(95.0, 3187.0), "Extracting the checkpoint must preserve its level placement.")
		var shape := checkpoint.get_node("CollisionShape2D") as CollisionShape2D
		_check(shape.position == Vector2(-0.5, 0.0), "The checkpoint shape must retain its local offset.")
	level.free()


func _find_menu() -> CheckpointMenu:
	for child in root.get_children():
		if child is CheckpointMenu:
			return child
	return null


func _menu_count() -> int:
	var count := 0
	for child in root.get_children():
		if child is CheckpointMenu:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
