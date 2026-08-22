extends SceneTree

const PLAYER_SCENE := preload("res://entities/player/Player.tscn")
const DOUBLE_JUMP_SCENE := preload("res://spells/double_jump/DoubleJumpSpell.tscn")
const DOUBLE_JUMP_DEFINITION := preload(
	"res://spells/double_jump/double_jump_spell_definition.tres"
)
const SPELL_DATABASE := preload("res://spells/spell_database.tres")

const EXPECTED_JUMP_VELOCITY := -1000.0
const COOLDOWN_WAIT := 0.3
const ONE_WAY_PLATFORM_LAYER := 2

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await process_frame

	await _test_spell_jump_component()
	await _test_definition_and_registration()
	await _test_grounded_cast()
	await _test_repeated_airborne_casts_and_cooldown_ui()
	await _test_movement_mode_coordination()
	await _test_command_failures()

	if _failures.is_empty():
		print("PASS: double jump (%d checks)" % _checks)
		quit(0)
		return

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	print("FAIL: double jump (%d failures, %d checks)" % [_failures.size(), _checks])
	quit(1)


func _test_spell_jump_component() -> void:
	var body := CharacterBody2D.new()
	var spell_jump := SpellJumpComponent.new()
	spell_jump.body = body
	body.add_child(spell_jump)
	root.add_child(body)
	await process_frame

	body.velocity = Vector2(325.0, 450.0)
	_check(spell_jump.jump(), "A configured spell-jump component must accept a jump.")
	_check(
		is_equal_approx(body.velocity.y, EXPECTED_JUMP_VELOCITY),
		"A spell jump must replace vertical velocity with its configured impulse."
	)
	_check(
		is_equal_approx(body.velocity.x, 325.0),
		"A spell jump must preserve horizontal velocity."
	)

	body.velocity.y = 200.0
	_check(spell_jump.jump(), "The component must allow another jump without a landing reset.")
	_check(
		is_equal_approx(body.velocity.y, EXPECTED_JUMP_VELOCITY),
		"Repeated component jumps must apply the same impulse."
	)
	var property_names: Array[StringName] = []
	for property in spell_jump.get_property_list():
		property_names.append(property.name)
	_check(
		not property_names.has(&"armed")
		and not property_names.has(&"consumed")
		and not property_names.has(&"jump_count"),
		"SpellJumpComponent must not expose per-airborne availability state."
	)

	await _free_node(body)


func _test_definition_and_registration() -> void:
	var database := SPELL_DATABASE as SpellDatabase
	var definition := DOUBLE_JUMP_DEFINITION as SpellDefinition

	_check(database.get_spell(&"double_jump") == definition, "Double Jump must be catalogued.")
	_check(
		definition.sequence == [&"move", &"interaction"],
		"Double Jump must use the Circle, Triangle token sequence."
	)
	_check(
		is_equal_approx(definition.cooldown, 0.25),
		"Double Jump must use the specified time-based cooldown."
	)
	_check(definition.command_scene != null, "Double Jump must reference its command scene.")
	_check(definition.icon != null, "Double Jump must provide a cooldown HUD icon.")

	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)

	var registry: SpellRegistry = player.get_node("SpellRegistry")
	var caster: SequenceCaster = player.get_node("SequenceCaster")
	_check(registry.has_spell(&"double_jump"), "The player must register Double Jump by default.")
	_check(
		caster.sequence_to_spell.get(&"move+interaction") == definition,
		"SequenceCaster must resolve Circle, Triangle to Double Jump."
	)

	await _free_node(player)


func _test_grounded_cast() -> void:
	var fixture := Node2D.new()
	var floor := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(400.0, 20.0)
	floor_shape.shape = rectangle
	floor.add_child(floor_shape)
	floor.position = Vector2(0.0, 100.0)
	fixture.add_child(floor)

	var player := PLAYER_SCENE.instantiate()
	fixture.add_child(player)
	root.add_child(fixture)

	var grounded := false
	for _frame in 120:
		await physics_frame
		if player.is_on_floor():
			grounded = true
			break

	_check(grounded, "The grounded spell fixture must place the player on a floor.")
	player.set_physics_process(false)
	var caster: SequenceCaster = player.get_node("SequenceCaster")
	_cast_double_jump(caster)
	await process_frame
	_check(
		is_equal_approx(player.velocity.y, EXPECTED_JUMP_VELOCITY),
		"Double Jump must apply its impulse while the player is on the floor."
	)

	await _free_node(fixture)


func _test_repeated_airborne_casts_and_cooldown_ui() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)

	var caster: SequenceCaster = player.get_node("SequenceCaster")
	var cooldowns: SpellCooldowns = player.get_node("SpellCooldowns")
	var hud: PlayerHud = player.get_node("PlayerHudLayer/PlayerHud")
	var cooldown_ui: CooldownUI = hud.get_node("CooldownUI")
	var rejection_reasons: Array[StringName] = []
	caster.sequence_failed.connect(
		func(_sequence: Array[StringName], reason: StringName) -> void:
			rejection_reasons.append(reason)
	)

	player.velocity = Vector2(180.0, 500.0)
	_cast_double_jump(caster)
	await process_frame
	_check(
		is_equal_approx(player.velocity.y, EXPECTED_JUMP_VELOCITY),
		"A cast while falling without a prior jump must apply the upward impulse."
	)
	_check(
		is_equal_approx(player.velocity.x, 180.0),
		"Casting through SequenceCaster must preserve horizontal velocity."
	)
	_check(
		not cooldowns.is_ready(DOUBLE_JUMP_DEFINITION),
		"An accepted Double Jump cast must start its cooldown."
	)
	_check(
		cooldown_ui.get_entry(&"double_jump") != null,
		"An accepted cast must create one cooldown HUD entry."
	)

	var remaining_before_rejection := cooldowns.get_remaining(&"double_jump")
	player.velocity.y = 250.0
	_cast_double_jump(caster)
	await process_frame
	var remaining_after_rejection := cooldowns.get_remaining(&"double_jump")
	_check(
		is_equal_approx(player.velocity.y, 250.0),
		"A cooldown-blocked cast must not change vertical velocity."
	)
	_check(
		rejection_reasons == [&"cooldown_active"],
		"A repeated cast during cooldown must report cooldown_active exactly once."
	)
	_check(
		remaining_after_rejection <= remaining_before_rejection,
		"A rejected cast must not restart the existing cooldown."
	)
	_check(
		cooldown_ui.cooldown_container.get_child_count() == 1,
		"A rejected cast must not create a duplicate cooldown HUD entry."
	)

	await create_timer(COOLDOWN_WAIT).timeout
	player.velocity.y = 600.0
	_cast_double_jump(caster)
	await process_frame
	_check(
		is_equal_approx(player.velocity.y, EXPECTED_JUMP_VELOCITY),
		"A second airborne cast must succeed after cooldown without landing."
	)

	await create_timer(COOLDOWN_WAIT).timeout
	player.velocity.y = 700.0
	_cast_double_jump(caster)
	await process_frame
	_check(
		is_equal_approx(player.velocity.y, EXPECTED_JUMP_VELOCITY),
		"A third airborne cast must succeed after cooldown without landing."
	)

	await _free_node(player)


func _test_movement_mode_coordination() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)

	player.begin_dash(Vector2.RIGHT, 500.0, 0.05)
	_check(player.is_dashing, "The movement fixture must begin in dash state.")
	_check(player.try_spell_jump(), "A spell jump must be accepted during dash.")
	_check(not player.is_dashing, "A spell jump must interrupt an active dash.")
	_check(
		is_equal_approx(player.velocity.y, EXPECTED_JUMP_VELOCITY),
		"Interrupting dash must preserve the new vertical jump impulse."
	)
	await create_timer(0.06).timeout
	_check(
		is_equal_approx(player.velocity.y, EXPECTED_JUMP_VELOCITY),
		"An interrupted dash coroutine must not erase the spell jump later."
	)

	var jump_down: JumpDownComponent = player.get_node("JumpDown")
	_check(jump_down.begin(true), "The movement fixture must begin jump-down state.")
	_check(jump_down.is_active(), "Jump down must be active before spell interruption.")
	_check(player.try_spell_jump(), "A spell jump must be accepted during jump down.")
	_check(not jump_down.is_active(), "A spell jump must cancel active jump down.")
	_check(
		player.get_collision_mask_value(ONE_WAY_PLATFORM_LAYER),
		"Cancelling jump down must restore one-way platform collision."
	)

	var knockback: KnockbackComponent = player.get_node("Knockback")
	_check(
		knockback.begin_knockback(Vector2.RIGHT, 420.0, 0.25),
		"The movement fixture must begin horizontal knockback."
	)
	player.velocity.x = knockback.calculate_horizontal_velocity(0.0)
	var knockback_velocity: float = player.velocity.x
	_check(player.try_spell_jump(), "A spell jump must be accepted during knockback.")
	_check(knockback.is_active(), "A spell jump must not cancel horizontal knockback state.")
	_check(
		is_equal_approx(player.velocity.x, knockback_velocity),
		"A spell jump must preserve active horizontal knockback velocity."
	)
	_check(
		is_equal_approx(player.velocity.y, EXPECTED_JUMP_VELOCITY),
		"A spell jump during knockback must apply its vertical impulse."
	)

	await _free_node(player)


func _test_command_failures() -> void:
	var missing_caster_command := DOUBLE_JUMP_SCENE.instantiate() as DoubleJumpSpell
	root.add_child(missing_caster_command)
	var missing_reasons: Array[StringName] = []
	missing_caster_command.failed.connect(
		func(_command: SpellCommand, reason: StringName) -> void: missing_reasons.append(reason)
	)
	missing_caster_command.execute(SpellContext.new())
	_check(missing_reasons == [&"missing_caster"], "A missing caster must fail clearly.")
	await process_frame

	var unsupported_caster := Node2D.new()
	root.add_child(unsupported_caster)
	var unsupported_command := DOUBLE_JUMP_SCENE.instantiate() as DoubleJumpSpell
	root.add_child(unsupported_command)
	var unsupported_reasons: Array[StringName] = []
	unsupported_command.failed.connect(
		func(_command: SpellCommand, reason: StringName) -> void:
			unsupported_reasons.append(reason)
	)
	var context := SpellContext.new()
	context.caster = unsupported_caster
	unsupported_command.execute(context)
	_check(
		unsupported_reasons == [&"unsupported_caster"],
		"A caster without the spell-jump capability must fail clearly."
	)
	await process_frame
	await _free_node(unsupported_caster)


func _cast_double_jump(caster: SequenceCaster) -> void:
	caster.current_sequence.append(&"move")
	caster.current_sequence.append(&"interaction")
	caster.confirm_sequence()


func _free_node(node: Node) -> void:
	if not is_instance_valid(node):
		return

	node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
