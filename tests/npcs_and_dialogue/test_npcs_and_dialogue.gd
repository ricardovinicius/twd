extends SceneTree

class TestPlayer extends CharacterBody2D:
	var interactor: PlayerInteractor


	func get_interactor() -> PlayerInteractor:
		return interactor


var _checks: int = 0
var _failures: Array[String] = []
var _ends: Array[StringName] = []
var _events: Array[StringName] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_lifecycle()
	await _test_selection_and_input()
	await _test_interruptions()
	await _test_reconnection_and_player_removal()
	await _test_dialogue_interaction_composition()
	await _test_npc_body_collision()
	await _test_npc_one_way_platform()
	await _test_main_integration()
	_test_bindings()

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: NPCs and dialogue (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _definition() -> DialogueDefinition:
	var definition := DialogueDefinition.new()

	for message in ["Hello, traveller.", "Stay safe in these halls."]:
		var line := DialogueLine.new()

		line.speaker_name = "Guide"
		line.text = message

		definition.lines.append(line)

	return definition


func _fixture() -> Dictionary:
	var world := Node2D.new()

	world.position = Vector2(-10000, -10000)

	var player := TestPlayer.new()
	player.add_to_group(&"player")
	player.collision_layer = 4
	player.collision_mask = 0

	var body_shape := CollisionShape2D.new()
	body_shape.shape = CircleShape2D.new()
	body_shape.shape.radius = 5.0
	player.add_child(body_shape)
	world.add_child(player)

	var health := Health.new()
	player.add_child(health)

	var respawn := Node.new()
	respawn.add_user_signal("respawning")
	player.add_child(respawn)

	var session := DialogueSession.new()
	session.player = player
	session.health = health
	session.respawn = respawn
	world.add_child(session)

	var interactor := PlayerInteractor.new()
	interactor.player = player
	interactor.health = health
	interactor.dialogue_session = session
	player.interactor = interactor
	player.add_child(interactor)

	var target := InteractionTarget.new()
	target.collision_layer = 0
	target.collision_mask = 4

	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 100.0
	target.add_child(shape)
	world.add_child(target)

	var definition := _definition()

	target.request_handler = func(participant: Node2D) -> bool:
		return session.try_start(definition, participant, target)

	root.add_child(world)

	return {
		"world": world,
		"player": player,
		"health": health,
		"respawn": respawn,
		"session": session,
		"interactor": interactor,
		"target": target,
		"definition": definition,
	}


func _settle() -> void:
	for frame in range(5):
		await physics_frame

	await process_frame


func _free_fixture(fixture: Dictionary) -> void:
	fixture.world.queue_free()
	await process_frame


func _press(interactor: PlayerInteractor, action: StringName = &"interaction") -> void:
	var release := InputEventAction.new()
	release.action = action
	interactor._input(release)

	var press := InputEventAction.new()
	press.action = action
	press.pressed = true

	interactor._input(press)
	interactor._unhandled_input(press)


func _test_lifecycle() -> void:
	var fixture := _fixture()

	await _settle()

	var session: DialogueSession = fixture.session

	_events.clear()
	_ends.clear()

	session.started.connect(func() -> void: _events.append(&"started"))
	session.line_changed.connect(func(_line: DialogueLine) -> void: _events.append(&"line"))
	session.ended.connect(func(reason: StringName) -> void: _ends.append(reason))

	_check(fixture.target.can_interact(fixture.player), "Physics overlap must register an eligible player.")
	_check(session.try_start(fixture.definition, fixture.player, fixture.target), "A valid start must succeed.")
	_check(not paused, "Dialogue must not pause gameplay.")
	_check(_events == [&"started", &"line"], "Start must publish started before the first line.")
	_check(
		session.get_current_line() == fixture.definition.lines[0],
		"Start must expose the first authored line."
	)
	_check(
		not session.try_start(fixture.definition, fixture.player, fixture.target),
		"A repeated start must reject."
	)
	_check(_events.size() == 2, "Rejected start must emit no changes.")

	_check(session.advance(), "Advance must accept an active conversation.")
	_check(session.get_current_line() == fixture.definition.lines[1], "Advance must expose the next line.")

	_check(session.advance() and not session.is_active(), "Final advance must complete.")
	_check(
		session.get_current_line() == null and _ends == [&"completed"],
		"Completion must clear state and terminate once."
	)

	_check(not session.advance() and not session.cancel(), "Inactive transitions must reject.")
	_check(_ends.size() == 1, "Inactive transitions must not emit termination again.")
	_check(
		fixture.health.damaged.get_connections().is_empty(),
		"Termination must disconnect health subscriptions."
	)

	_check(
		session.try_start(fixture.definition, fixture.player, fixture.target),
		"Completed dialogue must restart."
	)
	_check(session.get_current_line() == fixture.definition.lines[0], "Restart must begin at line one.")

	_check(session.cancel() and _ends.back() == &"cancelled", "Cancel must end the conversation.")

	var invalid := DialogueDefinition.new()

	_check(not session.try_start(invalid, fixture.player, fixture.target), "Empty definitions must reject.")

	invalid.lines.assign([fixture.definition.lines[0], null])

	_check(
		not session.try_start(invalid, fixture.player, fixture.target),
		"A malformed later line must reject before starting."
	)

	var blank := DialogueLine.new()
	blank.speaker_name = " "
	blank.text = "Text"
	invalid.lines.assign([blank])

	_check(not session.try_start(invalid, fixture.player, fixture.target), "Blank speakers must reject.")

	blank.speaker_name = "Guide"
	blank.text = "\n "

	_check(not session.try_start(invalid, fixture.player, fixture.target), "Blank text must reject.")
	_check(not session.try_start(null, fixture.player, fixture.target), "Missing definitions must reject.")

	var other := DialogueSession.new()
	other.player = fixture.player
	other.health = fixture.health
	other.respawn = fixture.respawn
	fixture.world.add_child(other)
	session.try_start(fixture.definition, fixture.player, fixture.target)
	other.try_start(fixture.definition, fixture.player, fixture.target)
	session.advance()

	_check(
		other.get_current_line() == fixture.definition.lines[0],
		"Shared definitions must not share runtime progress."
	)
	_check(
		fixture.definition.lines.size() == 2 and fixture.definition.lines[0].text == "Hello, traveller.",
		"Sessions must leave shared configuration unchanged."
	)

	other.cancel()
	session.cancel()

	await _free_fixture(fixture)


func _test_selection_and_input() -> void:
	var fixture := _fixture()

	await _settle()

	var interactor: PlayerInteractor = fixture.interactor
	var target: InteractionTarget = fixture.target

	_check(interactor.get_selected_target() == target, "A nearby target must be selected.")
	_check(
		interactor.get_prompt().contains("S") and interactor.get_prompt().contains("Talk"),
		"Prompt must reflect target and configured binding."
	)

	var second := InteractionTarget.new()
	second.position = Vector2(30, 0)
	second.prompt = "Other"
	fixture.world.add_child(second)
	second._on_body_entered(fixture.player)

	_check(interactor.get_selected_target() == target, "Nearest target must win.")

	fixture.player.position.x = 25

	_check(interactor.get_selected_target() == second, "Selection must update as the player moves.")

	fixture.player.position.x = 15

	_check(interactor.get_selected_target() == second, "Equal distances must retain the current selection.")

	second.enabled = false

	_check(interactor.get_selected_target() == target, "Unavailable targets must be skipped.")

	second.enabled = true

	_check(interactor.get_selected_target() == target, "Equal distances must not switch an eligible selection.")

	_press(interactor)

	_check(
		fixture.session.is_active() and fixture.session.get_current_line() == fixture.definition.lines[0],
		"Opening press must not also advance."
	)
	_check(interactor.get_prompt().is_empty(), "Nearby prompt must hide while talking.")

	var repeated := InputEventAction.new()
	repeated.action = &"interaction"
	repeated.pressed = true
	interactor._unhandled_input(repeated)

	_check(
		fixture.session.get_current_line() == fixture.definition.lines[0],
		"Repeated held input must not advance."
	)

	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_E
	echo.pressed = true
	echo.echo = true
	interactor._unhandled_input(echo)

	_check(fixture.session.get_current_line() == fixture.definition.lines[0], "Key echo must not advance.")

	var calls := [0]
	second.request_handler = func(_player: Node2D) -> bool:
		calls[0] += 1

		return true
	_press(interactor)

	_check(
		fixture.session.get_current_line() == fixture.definition.lines[1] and calls[0] == 0,
		"Active dialogue must receive input before other targets."
	)

	_press(interactor, &"dialogue_cancel")

	_check(not fixture.session.is_active(), "Dedicated cancel input must terminate dialogue.")

	second.queue_free()
	await process_frame

	_check(interactor.get_selected_target() == target, "Removed targets must be cleared safely.")

	target._on_body_exited(fixture.player)

	_check(
		interactor.get_selected_target() == null and interactor.get_prompt().is_empty(),
		"Leaving all targets must clear selection and prompt."
	)

	_press(interactor)

	_check(not fixture.session.is_active(), "Input with no eligible target must do nothing.")

	await _free_fixture(fixture)


func _test_interruptions() -> void:
	var fixture := _fixture()

	await _settle()

	var session: DialogueSession = fixture.session
	_ends.clear()

	session.ended.connect(func(reason: StringName) -> void: _ends.append(reason))
	session.try_start(fixture.definition, fixture.player, fixture.target)
	fixture.health.take_damage(0)

	_check(session.is_active(), "Zero damage must not interrupt.")

	fixture.health.set_shield_maximum(20)
	fixture.health.reset()
	fixture.health.take_damage(5)

	_check(session.is_active(), "Shield-only absorption must not interrupt.")

	fixture.health.take_damage(20)

	_check(not session.is_active() and _ends.back() == &"damaged", "Health damage must interrupt immediately.")

	session.try_start(fixture.definition, fixture.player, fixture.target)
	fixture.respawn.emit_signal("respawning")

	_check(not session.is_active() and _ends.back() == &"player_unavailable", "Respawn must interrupt.")

	session.try_start(fixture.definition, fixture.player, fixture.target)
	fixture.health.take_damage(1000)

	_check(not session.is_active() and _ends.size() == 3, "Damage plus depletion must terminate only once.")
	_check(
		not session.try_start(fixture.definition, fixture.player, fixture.target),
		"A dead player cannot start a conversation."
	)

	fixture.health.reset()
	session.try_start(fixture.definition, fixture.player, fixture.target)
	fixture.player.position = Vector2(1000, 0)

	await _settle()

	_check(
		not session.is_active() and _ends.back() == &"out_of_range",
		"Leaving the physics overlap must interrupt."
	)

	fixture.player.position = Vector2.ZERO

	await _settle()
	session.try_start(fixture.definition, fixture.player, fixture.target)
	paused = true


	_check(not session.advance() and not session.cancel(), "Paused transitions must reject.")

	_press(fixture.interactor)

	_check(
		session.get_current_line() == fixture.definition.lines[0],
		"Dialogue input during pause must preserve progress."
	)

	fixture.target.queue_free()
	await process_frame

	_check(
		not session.is_active() and paused,
		"Target removal during pause must end dialogue without resuming the world."
	)

	paused = false

	await _free_fixture(fixture)


func _test_reconnection_and_player_removal() -> void:
	var fixture := _fixture()

	await _settle()

	var session: DialogueSession = fixture.session
	var old_target: InteractionTarget = fixture.target
	session.try_start(fixture.definition, fixture.player, old_target)
	session.cancel()

	var next_target := InteractionTarget.new()
	fixture.world.add_child(next_target)
	next_target._on_body_entered(fixture.player)

	_check(
		session.try_start(fixture.definition, fixture.player, next_target),
		"A new NPC must be able to start the next conversation."
	)

	old_target._on_body_exited(fixture.player)
	old_target.queue_free()
	await process_frame

	_check(session.is_active(), "Old target signals must not interrupt a later conversation.")

	paused = true
	next_target.enabled = false

	_check(not session.is_active() and paused, "Eligibility loss must terminate without taking pause ownership.")

	paused = false
	next_target.enabled = true
	session.try_start(fixture.definition, fixture.player, next_target)
	_ends.clear()

	session.ended.connect(func(reason: StringName) -> void: _ends.append(reason))
	fixture.player.queue_free()
	await process_frame

	_check(
		not session.is_active() and _ends == [&"player_unavailable"],
		"Player removal must terminate safely once."
	)

	await _free_fixture(fixture)


func _test_dialogue_interaction_composition() -> void:
	var fixture := _fixture()

	await _settle()

	var target: InteractionTarget = fixture.target
	target.request_handler = Callable()

	var owner := Node2D.new()
	fixture.world.add_child(owner)

	var interaction := DialogueInteraction.new()
	interaction.target = target
	interaction.conversation = fixture.definition
	owner.add_child(interaction)

	_check(
		not target.try_interact(fixture.player),
		"Unconfigured dialogue interaction must not accept a request."
	)

	interaction.setup(fixture.session)

	_check(
		target.try_interact(fixture.player),
		"A plain composed node must start dialogue without an NPC script."
	)
	_check(
		not target.try_interact(fixture.player),
		"The component must return rejection while a session is active."
	)

	fixture.session.cancel()
	target._on_body_exited(fixture.player)

	_check(not interaction.try_interact(fixture.player), "The component must recheck target eligibility.")

	target._on_body_entered(fixture.player)
	owner.queue_free()
	await process_frame

	_check(
		not target.request_handler.is_valid() and not target.try_interact(fixture.player),
		"Removing the component must unbind its handler safely."
	)

	var exported := DialogueInteraction.new()
	exported.target = target
	exported.conversation = fixture.definition
	exported.session = fixture.session
	fixture.world.add_child(exported)

	_check(target.try_interact(fixture.player), "An exported session must allow ready-time composition.")

	fixture.session.cancel()

	var replacement := func(_player: Node2D) -> bool: return true
	target.request_handler = replacement
	exported.queue_free()
	await process_frame

	_check(
		target.request_handler == replacement,
		"Component removal must preserve another owner's replacement handler."
	)

	await _free_fixture(fixture)


func _add_npc_floor(world: Node2D, one_way: bool = false) -> void:
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()

	rectangle.size = Vector2(600, 20)
	floor_shape.shape = rectangle
	floor_shape.one_way_collision = one_way
	floor_body.collision_layer = 2 if one_way else 1
	floor_body.position = Vector2(0, 100)
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)


func _test_npc_body_collision() -> void:
	var world := Node2D.new()

	world.position = Vector2(-6000, -6000)
	_add_npc_floor(world)

	var guide := (load("res://entities/npcs/village_guide/VillageGuide.tscn") as PackedScene).instantiate() as CharacterBody2D

	guide.position = Vector2(0, -100)
	world.add_child(guide)
	root.add_child(world)

	var initial_y := guide.global_position.y

	for frame in range(45):
		await physics_frame

	_check(guide.is_on_floor(), "NPC gravity must settle its body onto solid terrain.")
	_check(guide.global_position.y > initial_y, "An airborne NPC must fall under gravity.")
	_check(
		guide.collision_layer == 4 and guide.collision_mask == 7,
		"NPC collision must match the player and enemy body layers."
	)

	var sprite := guide.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var texture := sprite.sprite_frames.get_frame_texture(&"idle", 0) as AtlasTexture

	_check(
		sprite.is_playing() and sprite.sprite_frames.get_animation_loop(&"idle"),
		"The copied NPC sprite must play a looping idle animation."
	)
	_check(
		sprite.sprite_frames.get_frame_count(&"idle") == 11,
		"NPC idle animation must use all eleven existing frames."
	)
	_check(
		texture.atlas.resource_path == "res://entities/npcs/village_guide/assets/idle_32x32.png",
		"NPC artwork must reference its feature-owned copy."
	)

	var player := (load("res://entities/player/Player.tscn") as PackedScene).instantiate() as CharacterBody2D
	var enemy := (load("res://entities/enemies/basic_skeleton/BasicSkeleton.tscn") as PackedScene).instantiate() as CharacterBody2D

	player.position = Vector2(-140, 40)
	enemy.position = Vector2(140, 40)
	world.add_child(player)
	world.add_child(enemy)

	var player_health := player.get_node("Health") as Health
	var original_health := player_health.current
	var guide_x := guide.global_position.x

	Input.action_press(&"right")

	for frame in range(90):
		await physics_frame

	Input.action_release(&"right")

	_check(
		player.global_position.x > guide_x - 100 and player.global_position.x < guide_x - 60,
		"The real player must move toward the NPC and be blocked beside it."
	)
	_check(
		enemy.global_position.x > guide_x + 48 and enemy.global_position.x < guide_x + 100,
		"The real enemy must approach and be blocked on the opposite side of the NPC."
	)
	_check(_has_body_collision(player, guide), "Player slide collisions must identify the solid NPC body.")
	_check(_has_body_collision(enemy, guide), "Enemy slide collisions must identify the solid NPC body.")
	_check(is_equal_approx(guide.global_position.x, guide_x), "NPC contact must not move it horizontally.")
	_check(player_health.current == original_health, "NPC body contact must not apply combat damage.")
	_check(
		player.get_interactor().get_selected_target() == guide.get_node("InteractionTarget"),
		"The player must remain eligible to talk beside the solid NPC body."
	)

	world.queue_free()
	await process_frame


func _has_body_collision(body: CharacterBody2D, other: PhysicsBody2D) -> bool:
	for index in body.get_slide_collision_count():
		if body.get_slide_collision(index).get_collider() == other:
			return true

	return false


func _test_npc_one_way_platform() -> void:
	var world := Node2D.new()

	world.position = Vector2(-8000, -6000)
	_add_npc_floor(world, true)

	var guide := (load("res://entities/npcs/village_guide/VillageGuide.tscn") as PackedScene).instantiate() as CharacterBody2D

	guide.position = Vector2(0, -100)
	world.add_child(guide)
	root.add_child(world)

	for frame in range(45):
		await physics_frame

	_check(guide.is_on_floor(), "NPC must land on one-way platforms from above.")

	world.queue_free()
	await process_frame


func _test_main_integration() -> void:
	var main := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)

	var player := main.get_node("LevelRoot/Player") as CharacterBody2D
	var guide := main.get_node("LevelRoot/VillageGuide") as CharacterBody2D
	var target := guide.get_node("InteractionTarget") as InteractionTarget

	_check(guide.get_script() == null, "The guide root must not require an NPC-specific dialogue script.")

	var session := main.get_node("DialogueSession") as DialogueSession
	var panel := main.get_node("DialoguePanel") as DialoguePanel
	var interactor := player.get_interactor() as PlayerInteractor
	# Keep the live player's normal physics enabled; use a large talking area for movement tests.
	(target.get_node("CollisionShape2D").shape as CircleShape2D).radius = 500
	player.global_position = guide.global_position - Vector2(120, 0)

	await _settle()

	_check(interactor.get_selected_target() == target, "Main must wire the placed NPC into player interaction.")

	_press(interactor)

	_check(session.is_active() and panel.visible, "Main interaction must show the composed dialogue panel.")
	_check(
		panel.speaker.text == "Village Guide" and not panel.text.text.is_empty(),
		"Panel must display authored speaker and text."
	)
	_check(
		panel.get_node("PanelContainer").mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Dialogue must not intercept gameplay mouse input."
	)

	var enemy := (load("res://entities/enemies/basic_skeleton/BasicSkeleton.tscn") as PackedScene).instantiate() as CharacterBody2D
	enemy.position = player.global_position + Vector2(700, -150)
	root.add_child(enemy)

	var enemy_before := enemy.global_position
	var before := player.global_position
	Input.action_press(&"right")

	await _settle()
	Input.action_release(&"right")

	_check(
		player.global_position.x > before.x and session.is_active(),
		"Normal player movement must continue during dialogue."
	)
	_check(enemy.global_position.y > enemy_before.y, "Enemy gravity and physics must continue while talking.")

	enemy.queue_free()
	Input.action_press(&"aim_down")

	_check(
		player.get_node("AimInput").get_direction() == Vector2.DOWN,
		"Aiming must remain available while talking."
	)

	Input.action_release(&"aim_down")
	Input.action_press(&"jump")

	await _settle()
	Input.action_release(&"jump")

	_check(player.velocity.y < 0 and session.is_active(), "Jumping must remain available while talking.")

	var cooldowns := player.get_node("SpellCooldowns") as SpellCooldowns
	var invoker := player.get_node("SpellInvoker") as SpellInvoker
	var caster := player.get_node("SequenceCaster") as SequenceCaster
	# Exercise the real input-to-command pipeline while talking.
	caster._unhandled_input(_action(&"cast_attack_token"))
	caster._unhandled_input(_action(&"cast_confirm_token"))

	await _settle()

	_check(session.is_active(), "Spell input must not close or consume dialogue.")
	_check(
		cooldowns.get_remaining(&"magic_arrow") > 0.0,
		"Spell casting and cooldowns must work during dialogue."
	)

	var remaining := cooldowns.get_remaining(&"magic_arrow")

	await _settle()

	_check(
		cooldowns.get_remaining(&"magic_arrow") < remaining and session.is_active(),
		"Cooldown time must progress during dialogue."
	)
	_check(invoker != null, "Dialogue composition must preserve the existing spell invoker.")

	var first_line := session.get_current_line()
	var menu := main.get_node("PauseMenuLayer/PauseMenu") as PauseMenu
	menu.pause_game()
	await process_frame
	await process_frame

	_check(paused and session.is_active() and not panel.visible, "Pause menu must suspend and hide dialogue.")

	_press(interactor)

	_check(session.get_current_line() == first_line, "Pause interaction must not advance dialogue.")

	menu.resume_game()
	await process_frame
	await process_frame

	_check(
		not paused and panel.visible and session.get_current_line() == first_line,
		"Resume must restore the same dialogue line."
	)

	# A held action observed while paused cannot advance until released.
	interactor._unhandled_input(_action(&"interaction"))

	_check(session.get_current_line() == first_line, "Held pause input must not leak into resumed dialogue.")

	var checkpoint := main.get_node("LevelRoot/Checkpoint") as Checkpoint
	checkpoint._on_body_entered(player)

	_check(
		not checkpoint.try_interact(player) and not paused,
		"Checkpoint API must reject while dialogue is active."
	)

	player.get_node("Health").take_damage(1)

	_check(
		not session.is_active() and not panel.visible and panel.text.text.is_empty(),
		"Real player damage must clear dialogue presentation."
	)
	_check(target.try_interact(player), "A later conversation must be startable.")

	main.queue_free()
	await process_frame

	_check(not paused, "Scene teardown must not change pause state.")


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true


	return event


func _test_bindings() -> void:
	var interaction := InputMap.action_get_events(&"interaction")

	# Settings rewrites keyboard events at startup, so match by type, not order.
	_check(
		_has_key(interaction, KEY_S) and _has_joy_button(interaction, JOY_BUTTON_DPAD_DOWN),
		"Interaction must use down: S and D-pad down."
	)

	var cancel := InputMap.action_get_events(&"dialogue_cancel")

	_check(
		_has_key(cancel, KEY_Q) and _has_joy_button(cancel, JOY_BUTTON_RIGHT_STICK),
		"Cancel must use Q and right stick press."
	)

	# Interacting is pressing down by design, so it shares aim_down's inputs.
	for event in InputMap.action_get_events(&"aim_down"):
		for reserved in cancel:
			_check(not event.is_match(reserved), "Cancel must not collide with aim_down.")

	for action in [&"left", &"right", &"aim_up", &"jump", &"cast_move_token", &"cast_interaction_token", &"cast_attack_token", &"cast_confirm_token", &"pause", &"Select"]:
		for event in InputMap.action_get_events(action):
			for reserved in interaction + cancel:
				_check(not event.is_match(reserved), "Dialogue bindings must not collide with %s." % action)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _has_key(events: Array[InputEvent], key: Key) -> bool:
	for event in events:
		if event is InputEventKey and (event.physical_keycode == key or event.keycode == key):
			return true

	return false


func _has_joy_button(events: Array[InputEvent], button: JoyButton) -> bool:
	for event in events:
		if event is InputEventJoypadButton and event.button_index == button:
			return true

	return false
