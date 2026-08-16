extends SceneTree

const PLAYER_SCENE := preload("res://entities/player/Player.tscn")
const BASIC_MOB_SCENE := preload(
	"res://entities/enemies/basic_skeleton/BasicSkeleton.tscn"
)

const PHYSICS_TIMEOUT_FRAMES := 180

var _failures: Array[String] = []
var _passed: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_player_owns_health_hud()
	await _test_melee_damage_plays_and_completes_hit_animation()
	await _test_contact_payloads_deduplication_and_cooldown()
	await _test_knockback_moves_away_while_gravity_continues()
	await _test_player_falling_on_mob_receives_contact_impact()
	await _test_mob_falling_on_player_delivers_contact_impact()
	await _test_player_death_reloads_current_scene()

	if _failures.is_empty():
		print("PASS: %d player/contact initial-mob checks" % _passed)
		quit(0)
		return

	for failure in _failures:
		push_error(failure)

	print("FAIL: %d failure(s), %d check(s) passed" % [_failures.size(), _passed])
	quit(1)


func _test_player_owns_health_hud() -> void:
	var player := await _spawn_player()
	player.set_physics_process(false)

	var health: Health = player.get_node("Health")
	var hud: PlayerHud = player.get_node("PlayerHudLayer/PlayerHud")
	var health_bar: TextureProgressBar = hud.get_node(
		"HealthMarginContainer/NinePatchRect/HealthBar"
	)

	_check(hud.health == health, "Player HUD must use its owning player's Health component.")
	health.take_damage(25.0)
	_check(is_equal_approx(health_bar.value, 75.0), "Player HUD must reflect Health changes.")
	_check(
		is_equal_approx(health_bar.max_value, health.maximum),
		"Player HUD maximum must match its owning player's maximum health."
	)

	await _free_node(player)


func _test_melee_damage_plays_and_completes_hit_animation() -> void:
	var player := await _spawn_player()
	player.set_physics_process(false)

	var health: Health = player.get_node("Health")
	var receiver: AttackReceiver = player.get_node("AttackReceiver")
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	var attack := AttackData.new()
	attack.attack_type = &"melee"
	attack.source = Node2D.new()
	attack.damage = 10.0

	receiver.receive_attack(attack)
	_check(is_equal_approx(health.current, 90.0), "Melee damage must reduce player health.")
	_check(sprite.animation == &"hit", "Melee damage must start the player's hit animation.")
	_check(sprite.is_playing(), "The player's hit animation must be playing after damage.")

	await create_timer(0.45).timeout
	_check(
		sprite.animation == &"hit" and not sprite.is_playing(),
		"The non-looping hit animation must reach its end."
	)
	_check(
		not bool(player.get("_is_playing_hit_animation")),
		"Player animation state must stop locking movement animations when hit finishes."
	)

	attack.source.free()
	await _free_node(player)


func _test_contact_payloads_deduplication_and_cooldown() -> void:
	var player := await _spawn_player(Vector2(5000.0, 0.0))
	var mob := await _spawn_mob(Vector2.ZERO)
	player.set_physics_process(false)
	mob.set_physics_process(false)

	var health: Health = player.get_node("Health")
	var attack_receiver: AttackReceiver = player.get_node("AttackReceiver")
	var action_receiver: ActionReceiver = player.get_node("ActionReceiver")
	var knockback: KnockbackComponent = player.get_node("Knockback")
	var contact: ContactImpactComponent = mob.get_node("ContactImpact")
	contact.contact_cooldown = 0.05

	var received_attacks: Array[AttackData] = []
	var received_actions: Array[ActionData] = []
	var applied_count := [0]
	attack_receiver.attack_received.connect(
		func(attack: AttackData) -> void: received_attacks.append(attack)
	)
	action_receiver.action_received.connect(
		func(action: ActionData) -> void: received_actions.append(action)
	)
	contact.contact_applied.connect(func(_target: Node2D) -> void: applied_count[0] += 1)

	contact._on_body_entered(player)
	_check(applied_count[0] == 1, "Initial contact must apply exactly one impact.")
	_check(received_attacks.size() == 1, "Contact must deliver one AttackData.")
	_check(received_actions.size() == 1, "Contact must deliver one ActionData.")
	_check(is_equal_approx(health.current, 90.0), "Contact AttackData must damage player health.")
	_check(knockback.is_active(), "Contact ActionData must activate player knockback.")

	if not received_attacks.is_empty():
		var attack := received_attacks[0]
		_check(attack.attack_type == &"contact", "Contact attack type must be 'contact'.")
		_check(attack.source == mob, "Contact AttackData source must be the mob.")
		_check(attack.direction == Vector2.RIGHT, "Contact damage direction must point away from mob.")
		_check(
			is_equal_approx(attack.damage, contact.contact_damage),
			"Contact AttackData must carry the configured damage."
		)

	if not received_actions.is_empty():
		var action := received_actions[0]
		_check(action.type == &"push", "Contact action type must be 'push'.")
		_check(action.source == mob, "Contact ActionData source must be the mob.")
		_check(action.direction == Vector2.RIGHT, "Contact push direction must point away from mob.")
		_check(
			is_equal_approx(action.strength, contact.knockback_strength),
			"Contact ActionData must carry the configured knockback strength."
		)
		_check(
			is_equal_approx(
				float(action.metadata.get(&"duration", -1.0)),
				contact.knockback_duration
			),
			"Contact ActionData must carry the configured knockback duration."
		)

	contact._on_body_entered(player)
	_check(applied_count[0] == 1, "Continuous overlap must not reapply contact impact.")
	_check(is_equal_approx(health.current, 90.0), "Continuous overlap must not repeat damage.")

	contact._on_body_exited(player)
	contact._on_body_entered(player)
	_check(applied_count[0] == 1, "Immediate re-entry must be blocked by contact cooldown.")
	_check(is_equal_approx(health.current, 90.0), "Cooldown-blocked re-entry must not deal damage.")

	contact._on_body_exited(player)
	await create_timer(0.08).timeout
	contact._on_body_entered(player)
	_check(applied_count[0] == 2, "Re-entry after cooldown must apply another impact.")
	_check(is_equal_approx(health.current, 80.0), "Post-cooldown contact must deal damage again.")

	# The contact component owns cooldown references to the player, so stop its
	# processing before releasing the target.
	await _free_node(mob)
	await _free_node(player)


func _test_knockback_moves_away_while_gravity_continues() -> void:
	var player := await _spawn_player(Vector2(200.0, -500.0))
	var mob := await _spawn_mob(Vector2.ZERO)
	mob.set_physics_process(false)
	var contact: ContactImpactComponent = mob.get_node("ContactImpact")
	var knockback: KnockbackComponent = player.get_node("Knockback")

	var initial_position := player.global_position
	contact._on_body_entered(player)
	# Depending on SceneTree callback ordering, the test coroutine can resume
	# before the player's movement callback for the same physics frame.
	await _wait_until(
		func() -> bool:
			return player.velocity.y > 0.0 and player.global_position.y > initial_position.y,
		5
	)

	_check(knockback.is_active(), "Contact must leave knockback active during its configured duration.")
	_check(player.velocity.x > 0.0, "Player to the right of a mob must be knocked right.")
	_check(
		player.global_position.x > initial_position.x,
		"Knockback must move the player horizontally away from the mob."
	)
	_check(player.velocity.y > 0.0, "Gravity must continue increasing downward velocity during knockback.")
	_check(
		player.global_position.y > initial_position.y,
		"An airborne knocked-back player must continue falling."
	)
	_check(
		player.get_collision_exceptions().has(mob),
		"Player knockback must temporarily ignore its collision source."
	)
	_check(
		not mob.get_collision_exceptions().has(player),
		"The current collision exception must remain player-side only."
	)

	var finished := await _wait_until(func() -> bool: return not knockback.is_active())
	_check(finished, "Knockback must finish within its configured duration.")
	_check(
		not player.get_collision_exceptions().has(mob),
		"Player collision with the mob must be restored after knockback."
	)

	await _free_node(mob)
	await _free_node(player)


func _test_player_falling_on_mob_receives_contact_impact() -> void:
	var player := await _spawn_player(Vector2(20.0, -220.0))
	var mob := await _spawn_mob(Vector2.ZERO)
	mob.set_physics_process(false)
	var health: Health = player.get_node("Health")
	var knockback: KnockbackComponent = player.get_node("Knockback")

	var impacted := await _wait_until(func() -> bool: return health.current < health.maximum)
	_check(impacted, "A player falling onto a mob must receive contact damage.")
	_check(knockback.is_active(), "A player falling onto a mob must receive knockback.")
	# The area signal may arrive after the player's movement callback for the
	# current tick. Allow the newly activated knockback one movement tick.
	await physics_frame
	_check(player.velocity.x > 0.0, "Vertical contact must choose an outward horizontal push direction.")

	await _free_node(mob)
	await _free_node(player)


func _test_mob_falling_on_player_delivers_contact_impact() -> void:
	var player := await _spawn_player(Vector2(20.0, 0.0))
	var mob := await _spawn_mob(Vector2(0.0, -220.0))
	player.set_physics_process(false)
	var health: Health = player.get_node("Health")
	var knockback: KnockbackComponent = player.get_node("Knockback")

	var impacted := await _wait_until(func() -> bool: return health.current < health.maximum)
	_check(impacted, "A mob falling onto the player must deliver contact damage.")
	_check(knockback.is_active(), "A mob falling onto the player must deliver knockback.")
	_check(
		player.get_collision_exceptions().has(mob),
		"Vertical mob contact must install the player's temporary source exception."
	)

	await _free_node(mob)
	await _free_node(player)


func _test_player_death_reloads_current_scene() -> void:
	var player := await _spawn_player()
	current_scene = player
	var previous_player_id := player.get_instance_id()
	var health: Health = player.get_node("Health")

	health.take_damage(health.maximum)
	var reloaded := await _wait_until(
		func() -> bool:
			return (
				is_instance_valid(current_scene)
				and current_scene.get_instance_id() != previous_player_id
				and current_scene.scene_file_path == PLAYER_SCENE.resource_path
			)
	)
	_check(reloaded, "Depleting player health must reload the current scene.")

	if is_instance_valid(current_scene):
		var reloaded_health: Health = current_scene.get_node("Health")
		_check(
			is_equal_approx(reloaded_health.current, reloaded_health.maximum),
			"Reloaded player scene must start with full health."
		)
		var reloaded_player := current_scene
		current_scene = null
		await _free_node(reloaded_player)


func _spawn_player(position: Vector2 = Vector2.ZERO) -> CharacterBody2D:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.global_position = position
	root.add_child(player)
	await process_frame
	return player


func _spawn_mob(position: Vector2 = Vector2.ZERO) -> CharacterBody2D:
	var mob := BASIC_MOB_SCENE.instantiate() as CharacterBody2D
	mob.global_position = position
	root.add_child(mob)
	await process_frame
	return mob


func _wait_until(predicate: Callable, maximum_frames: int = PHYSICS_TIMEOUT_FRAMES) -> bool:
	for _frame in maximum_frames:
		if predicate.call():
			return true
		await physics_frame

	return bool(predicate.call())


func _free_node(node: Node) -> void:
	if not is_instance_valid(node):
		return

	node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		return

	_failures.append(message)
