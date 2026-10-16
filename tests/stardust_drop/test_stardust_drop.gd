extends SceneTree

var _checks: int = 0
var _failures: Array[String] = []
var _coin_manager: Node


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_coin_manager = root.get_node("CoinManager")
	_test_add_coins()
	await _test_skeleton_drops_two_pickups()
	await _test_pickups_ignore_non_player_bodies()
	await _test_collecting_both_pickups_adds_twenty()
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	if _failures.is_empty():
		print("PASS: stardust drop (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_add_coins() -> void:
	var emissions: Array = []
	var on_changed := func(total) -> void: emissions.append(total)
	_coin_manager.coins_changed.connect(on_changed)
	var before: int = _coin_manager.coins

	_coin_manager.add_coins(0)
	_coin_manager.add_coins(-5)
	_check(_coin_manager.coins == before, "Non-positive amounts must not change the total.")
	_check(emissions.is_empty(), "Non-positive amounts must not emit coins_changed.")

	_coin_manager.add_coins(3)
	_check(_coin_manager.coins == before + 3, "add_coins must add the given amount.")
	_check(emissions == [before + 3], "add_coins must emit once with the new total.")

	_coin_manager.add_coin()
	_check(_coin_manager.coins == before + 4, "add_coin must still add one.")
	_coin_manager.coins_changed.disconnect(on_changed)


func _test_skeleton_drops_two_pickups() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var skeleton := _spawn_skeleton(world)
	await process_frame

	var death_position := skeleton.global_position
	var health: Health = skeleton.get_node("Health")
	health.take_damage(health.maximum)
	await process_frame
	await process_frame

	var pickups := _pickups_in(world)
	_check(not is_instance_valid(skeleton), "The skeleton must still be destroyed on death.")
	_check(pickups.size() == 2, "A dead skeleton must drop exactly two Stardust pickups.")
	var total := 0
	for pickup in pickups:
		total += pickup.amount
		_check(pickup.amount == 10, "Each dropped pickup must be worth 10 Stardust.")
		_check(pickup.is_inside_tree(), "Dropped pickups must stay in the world after the skeleton is freed.")
		_check(
			pickup.global_position.distance_to(death_position) <= 20.0,
			"Dropped pickups must appear around the skeleton's death position."
		)
	_check(total == 20, "A skeleton drop must total 20 Stardust.")
	if pickups.size() == 2:
		_check(
			not is_equal_approx(pickups[0].global_position.x, pickups[1].global_position.x),
			"The two pickups must be spread apart horizontally."
		)

	await _free_node(world)


func _test_pickups_ignore_non_player_bodies() -> void:
	var pickup := _spawn_pickup()
	var enemy := CharacterBody2D.new()
	root.add_child(enemy)
	var floor_body := StaticBody2D.new()
	root.add_child(floor_body)
	await process_frame
	var before: int = _coin_manager.coins

	pickup._on_attraction_area_body_entered(enemy)
	_check(pickup.player == null, "A non-player body must not attract a pickup.")
	pickup._on_body_entered(floor_body)
	pickup._on_body_entered(enemy)
	_check(not pickup.collected, "Floor and enemies must not collect a pickup.")
	_check(_coin_manager.coins == before, "A pickup touched by non-players must not add Stardust.")

	await _free_node(enemy)
	await _free_node(floor_body)
	await _free_node(pickup)


func _test_collecting_both_pickups_adds_twenty() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var skeleton := _spawn_skeleton(world)
	var player := CharacterBody2D.new()
	player.add_to_group(&"player")
	root.add_child(player)
	await process_frame

	var health: Health = skeleton.get_node("Health")
	health.take_damage(health.maximum)
	await process_frame
	await process_frame

	var before: int = _coin_manager.coins
	var pickups := _pickups_in(world)
	for pickup in pickups:
		pickup._on_attraction_area_body_entered(player)
		_check(pickup.player == player, "The player must attract a dropped pickup.")
		pickup._on_body_entered(player)
		pickup._on_body_entered(player)
	_check(_coin_manager.coins == before + 20, "Collecting both drops must add 20 Stardust exactly once.")

	await create_timer(1.0).timeout
	for pickup in pickups:
		_check(not is_instance_valid(pickup), "Collected pickups must free themselves.")

	await _free_node(player)
	await _free_node(world)


func _spawn_skeleton(parent: Node) -> Node2D:
	var scene: PackedScene = load("res://entities/enemies/basic_skeleton/BasicSkeleton.tscn")
	var skeleton := scene.instantiate() as Node2D
	skeleton.position = Vector2(300.0, 200.0)
	skeleton.set_physics_process(false)
	parent.add_child(skeleton)
	return skeleton


func _spawn_pickup() -> CoinPickup:
	var scene: PackedScene = load("res://currency/pickup/CoinPickup.tscn")
	var pickup := scene.instantiate() as CoinPickup
	pickup.position = Vector2(-2000.0, -2000.0)
	root.add_child(pickup)
	return pickup


func _pickups_in(parent: Node) -> Array[CoinPickup]:
	var pickups: Array[CoinPickup] = []
	for child in parent.get_children():
		if child is CoinPickup:
			pickups.append(child)
	return pickups


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
