extends SceneTree

const SPELL_SHOP := preload("res://spells/shop/spell_shop.tres")

var player_scene: PackedScene
var checkpoint_scene: PackedScene

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	player_scene = load("res://entities/player/Player.tscn")
	checkpoint_scene = load("res://entities/interactive/checkpoint/Checkpoint.tscn")

	await process_frame

	await _test_offers_and_locked_spells()
	await _test_purchase_rules()
	await _test_checkpoint_menu_purchase()
	await _test_back_input_steps_out()

	CoinManager.coins = 0

	if _failures.is_empty():
		print("PASS: spell shop (%d checks)" % _checks)
		quit(0)
		return

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	print("FAIL: spell shop (%d failures, %d checks)" % [_failures.size(), _checks])
	quit(1)


func _test_offers_and_locked_spells() -> void:
	var player := await _spawn_player()
	var registry: SpellRegistry = player.get_spell_registry()
	var shop := SPELL_SHOP as SpellShop
	var offer_ids: Array[StringName] = []

	for spell in shop.get_offers(registry):
		offer_ids.append(spell.id)

	_check(shop.price == 100, "Spells must cost 100 Stardust.")
	_check(
		offer_ids.has(&"double_jump") and offer_ids.has(&"dig"),
		"Every multi-token spell must be offered in the shop."
	)
	_check(
		not offer_ids.has(&"magic_arrow")
		and not offer_ids.has(&"push")
		and not offer_ids.has(&"dash"),
		"Single-token spells must not be sold."
	)

	for spell_id in offer_ids:
		_check(
			not registry.has_spell(spell_id),
			"Shop spell '%s' must be locked until bought." % spell_id
		)

	var caster: SequenceCaster = player.get_node("SequenceCaster")
	var selected: Array[StringName] = []
	caster.spell_selected.connect(
		func(spell: SpellDefinition) -> void: selected.append(spell.id)
	)
	caster.current_sequence.append(&"attack")
	caster.current_sequence.append(&"interaction")
	caster.confirm_sequence()
	_check(selected.is_empty(), "A locked spell must not be castable.")

	await _free_node(player)


func _test_purchase_rules() -> void:
	var player := await _spawn_player()
	var registry: SpellRegistry = player.get_spell_registry()
	var shop := SPELL_SHOP as SpellShop
	var dig := registry.database.get_spell(&"dig")
	var magic_arrow := registry.database.get_spell(&"magic_arrow")

	CoinManager.coins = 99
	_check(not shop.can_buy(registry, dig), "A spell must not be buyable without enough Stardust.")
	_check(not shop.buy(registry, dig), "A rejected purchase must fail.")
	_check(CoinManager.coins == 99, "A rejected purchase must not spend Stardust.")
	_check(not registry.has_spell(&"dig"), "A rejected purchase must not unlock the spell.")

	CoinManager.coins = 250
	_check(shop.buy(registry, dig), "A purchase with enough Stardust must succeed.")
	_check(CoinManager.coins == 150, "A purchase must spend exactly the spell price.")
	_check(registry.has_spell(&"dig"), "A purchase must unlock the spell.")

	_check(not shop.buy(registry, dig), "An owned spell must not be bought again.")
	_check(CoinManager.coins == 150, "Buying an owned spell must not spend Stardust.")

	_check(not shop.buy(registry, magic_arrow), "Spells not for sale must not be bought.")
	_check(CoinManager.coins == 150, "Rejected non-shop purchases must not spend Stardust.")

	await _free_node(player)


func _test_checkpoint_menu_purchase() -> void:
	var player := await _spawn_player()
	var registry: SpellRegistry = player.get_spell_registry()
	var checkpoint := checkpoint_scene.instantiate() as Checkpoint
	root.add_child(checkpoint)
	await process_frame

	CoinManager.coins = 50
	checkpoint.body_entered.emit(player)
	checkpoint.try_interact(player)

	var menu := _find_menu()
	_check(menu != null, "The checkpoint must open its menu.")
	if menu == null:
		await _free_node(checkpoint)
		await _free_node(player)
		return

	var spells_button := menu.get_node("MenuHolder/SpellsButton") as Button
	_check(spells_button.visible, "The checkpoint menu must offer a Spells button.")

	spells_button.pressed.emit()
	_check(menu.is_spell_shop_open(), "The Spells button must open the spell shop.")

	var dig_button := menu.get_buy_button(&"dig")
	_check(dig_button != null, "The shop must list Dig.")
	_check(
		dig_button != null and dig_button.disabled,
		"Buying must be disabled without enough Stardust."
	)

	CoinManager.add_coins(50)
	dig_button = menu.get_buy_button(&"dig")
	_check(
		dig_button != null and not dig_button.disabled,
		"Collecting Stardust must enable an affordable purchase."
	)

	if dig_button != null:
		dig_button.pressed.emit()

	_check(registry.has_spell(&"dig"), "Buying in the menu must unlock Dig.")
	_check(CoinManager.coins == 0, "Buying in the menu must spend 100 Stardust.")

	dig_button = menu.get_buy_button(&"dig")
	_check(
		dig_button != null and dig_button.disabled and dig_button.text == "Owned",
		"An owned spell must be shown as owned."
	)

	(menu.get_node("%ShopBackButton") as Button).pressed.emit()
	_check(not menu.is_spell_shop_open(), "Shop Back must return to the checkpoint menu.")

	(menu.get_node("MenuHolder/BackButton") as Button).pressed.emit()
	await process_frame
	_check(not paused, "Closing the checkpoint menu must resume gameplay.")

	var caster: SequenceCaster = player.get_node("SequenceCaster")
	_check(
		caster.sequence_to_spell.has(&"attack+interaction"),
		"A bought spell must be castable immediately."
	)

	await _free_node(checkpoint)
	await _free_node(player)


func _test_back_input_steps_out() -> void:
	var player := await _spawn_player()
	var checkpoint := checkpoint_scene.instantiate() as Checkpoint
	root.add_child(checkpoint)
	await process_frame

	checkpoint.body_entered.emit(player)
	checkpoint.try_interact(player)

	var menu := _find_menu()
	_check(menu != null, "The checkpoint must open its menu for back-input checks.")
	if menu == null:
		await _free_node(checkpoint)
		await _free_node(player)
		return

	menu.open_spell_shop()
	menu._unhandled_input(_action_event(&"pause"))
	_check(not menu.is_spell_shop_open(), "ESC must close the spell shop first.")
	_check(paused, "Closing the shop must keep the checkpoint menu open and paused.")

	menu._unhandled_input(_action_event(&"pause"))
	await process_frame
	_check(_find_menu() == null, "ESC on the checkpoint menu must close it.")
	_check(not paused, "Closing the checkpoint menu with ESC must resume gameplay.")

	checkpoint.try_interact(player)
	menu = _find_menu()
	_check(menu != null, "The checkpoint menu must reopen after closing with ESC.")
	if menu != null:
		menu._unhandled_input(_action_event(&"dialogue_cancel"))
		await process_frame
		_check(_find_menu() == null, "The cancel button must also close the checkpoint menu.")

	paused = false
	await _free_node(checkpoint)
	await _free_node(player)


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true

	return event


func _spawn_player() -> Node2D:
	var player := player_scene.instantiate() as Node2D
	player.position = Vector2(-1000.0, -1000.0)
	player.set_physics_process(false)
	root.add_child(player)
	await process_frame

	return player


func _find_menu() -> CheckpointMenu:
	for child in root.get_children():
		if child is CheckpointMenu:
			return child

	return null


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)


func _free_node(node: Node) -> void:
	if not is_instance_valid(node):
		return

	node.queue_free()
	await process_frame
