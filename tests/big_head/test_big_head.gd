extends SceneTree

const BIG_HEAD_SCENE_PATH := "res://entities/enemies/big_head/BigHead.tscn"
const RESPAWNER_SCRIPT_PATH := "res://entities/enemies/respawn/enemy_respawner.gd"
const BESTIARY_PATH := "res://entities/enemies/bestiary/bestiary.tres"
const TILE_SIZE := 48.0
const ENTITIES_LAYER := 1 << 2
const ATTACK_RECEIVER_LAYER := 1 << 4

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_composition()
	await _test_sleeps_until_hit()
	await _test_falls_asleep_again()
	await _test_death_clears_passage()
	await _test_respawner_restores_it()
	_test_bestiary_entry()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: big head (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_composition() -> void:
	var world := _spawn_world()
	var head := _spawn_head(world, Vector2.ZERO)
	await process_frame

	var shape := (head.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var world_size := shape.size * head.scale

	_check(is_equal_approx(world_size.y, TILE_SIZE * 2.0), "Big Head must be two blocks tall.")
	_check(head.collision_layer & ENTITIES_LAYER != 0, "Big Head must block the player (Entities layer).")
	_check(head.collision_layer & 1 == 0, "Big Head must not be world geometry, so projectiles reach its receiver.")
	_check(
		(head.get_node("AttackReceiver") as Area2D).collision_layer == ATTACK_RECEIVER_LAYER,
		"Big Head must receive attacks."
	)
	_check(head.find_children("*", "ContactImpactComponent").is_empty(), "Big Head must be harmless to touch.")
	_check(head.health.breakable_shield == head.shield, "Big Head's health must be guarded by its breakable shield.")
	_check(
		head.find_children("*", "ShieldBreakReaction").size() == 1,
		"Big Head's shield must be breakable by the Break spell."
	)
	_check(is_equal_approx(head.shield.regen_delay, 4.0), "The shield must come back after 4 seconds without hits.")

	await _free_node(world)


func _test_sleeps_until_hit() -> void:
	var world := _spawn_world()
	var head := _spawn_head(world, Vector2.ZERO)
	await process_frame

	_check(head.is_asleep(), "Big Head must start asleep.")
	_check(head.sprite.animation == &"sleep", "A sleeping Big Head must show closed eyes.")
	_check(not head.alert.visible, "The alert must start hidden.")

	_hit(head, 10.0)

	_check(not head.is_asleep(), "A hit must wake Big Head up.")
	_check(head.sprite.animation == &"awake", "An awake Big Head must show open eyes.")
	_check(head.alert.visible, "A hit must show the startled alert.")
	_check(is_equal_approx(head.health.current, head.health.maximum), "A hit on the intact shield must not hurt its health.")
	_check(is_equal_approx(head.shield.current, head.shield.maximum - 10.0), "The shield must take the hit.")

	await _free_node(world)


func _test_falls_asleep_again() -> void:
	var world := _spawn_world()
	var head := _spawn_head(world, Vector2.ZERO)
	head.sleep_delay = 0.3
	head.alert_duration = 0.1
	await process_frame

	_hit(head, 1.0)
	await create_timer(0.2).timeout

	_check(not head.alert.visible, "The alert must hide after its duration.")
	_check(not head.is_asleep(), "Big Head must still be awake before the sleep delay.")

	await create_timer(0.3).timeout

	_check(head.is_asleep(), "Big Head must fall asleep again after the sleep delay.")
	_check(head.sprite.animation == &"sleep", "Falling asleep must close its eyes.")

	await _free_node(world)


func _test_death_clears_passage() -> void:
	var world := _spawn_world()
	var head := _spawn_head(world, Vector2.ZERO)
	await process_frame

	_defeat(head)
	await process_frame
	await process_frame

	_check(not is_instance_valid(head), "Defeating Big Head must remove it and clear the passage.")
	_check(_count_coins(world) == 2, "Big Head must drop two Stardust pickups.")

	await _free_node(world)


func _test_respawner_restores_it() -> void:
	var world := _spawn_world()
	var respawner: Node2D = (load(RESPAWNER_SCRIPT_PATH) as GDScript).new()
	world.add_child(respawner)
	# The respawner registers its children on ready; this one was added empty.
	var head := _spawn_head(respawner, Vector2(200.0, -48.0))
	respawner._register_enemy(head)
	await process_frame

	_defeat(head)
	await process_frame
	respawner.respawn_all()
	await process_frame

	var heads := respawner.get_children().filter(func(child: Node) -> bool: return child is BigHead)

	_check(heads.size() == 1, "The respawner must bring Big Head back.")
	if heads.size() == 1:
		_check((heads[0] as Node2D).global_position.distance_to(Vector2(200.0, -48.0)) < 1.0, "Respawn must keep the placement.")
		_check(heads[0].is_asleep(), "A respawned Big Head must be asleep.")

	await _free_node(world)


func _test_bestiary_entry() -> void:
	var found := false

	for entry in load(BESTIARY_PATH).entries:
		if entry.id == &"big_head":
			found = true
			_check(entry.damage == 0.0, "Big Head's guide entry must say it is harmless.")

	_check(found, "The monster guide must list Big Head.")


func _defeat(head: BigHead) -> void:
	_hit(head, head.shield.maximum)
	_hit(head, head.health.maximum)


func _hit(head: BigHead, damage: float) -> void:
	var attack := AttackData.new()
	attack.attack_type = &"magic_arrow"
	attack.source = null
	attack.damage = damage
	(head.get_node("AttackReceiver") as AttackReceiver).receive_attack(attack)


func _count_coins(parent: Node) -> int:
	return parent.find_children("*", "CoinPickup", true, false).size()


func _spawn_world() -> Node2D:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	return world


func _spawn_head(parent: Node, at: Vector2) -> BigHead:
	var head := (load(BIG_HEAD_SCENE_PATH) as PackedScene).instantiate() as BigHead
	parent.add_child(head)
	head.global_position = at
	return head


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()

	current_scene = null
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
