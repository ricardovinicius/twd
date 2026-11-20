extends SceneTree

# The fizzle animation shown on the player when a spell cannot be cast.

const PLAYER_SCENE := "res://entities/player/Player.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Node2D
	root.add_child(player)
	player.set_physics_process(false)
	await process_frame

	var fizzle := player.get_node_or_null("SpellFizzle") as SpellFizzle
	var caster := player.get_node("SequenceCaster") as SequenceCaster

	_check(fizzle != null, "The player must have a SpellFizzle.")

	if fizzle != null:
		await _test_failed_sequence_fizzles(fizzle, caster)
		await _test_successful_cast_does_not_fizzle(player, fizzle, caster)

	player.queue_free()
	await process_frame

	if _failures.is_empty():
		print("PASS: spell fizzle (%d checks)" % _checks)
		quit(0)
		return

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	print("FAIL: spell fizzle (%d failures, %d checks)" % [_failures.size(), _checks])
	quit(1)


func _test_failed_sequence_fizzles(fizzle: SpellFizzle, caster: SequenceCaster) -> void:
	_check(not fizzle.visible, "The fizzle must start hidden.")

	_confirm_sequence_without_spell(caster)

	_check(fizzle.visible and fizzle.is_playing(), "A sequence with no spell must play the fizzle.")

	await create_timer(0.2).timeout
	_confirm_sequence_without_spell(caster)

	_check(fizzle.frame == 0, "A new failure must restart the fizzle.")

	await create_timer(1.0).timeout

	_check(not fizzle.visible, "The fizzle must hide when its animation ends.")


func _confirm_sequence_without_spell(caster: SequenceCaster) -> void:
	# No spell uses five move tokens.
	for i in 5:
		caster._add_token_to_sequence(&"move")

	caster.confirm_sequence()


func _test_successful_cast_does_not_fizzle(
	player: Node2D,
	fizzle: SpellFizzle,
	caster: SequenceCaster
) -> void:
	var registry := player.get_node("SpellRegistry") as SpellRegistry
	registry.register_spell(&"dig")

	caster._add_token_to_sequence(&"attack")
	caster._add_token_to_sequence(&"interaction")
	caster.confirm_sequence()

	_check(not fizzle.visible, "A spell that is cast must not fizzle.")


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
