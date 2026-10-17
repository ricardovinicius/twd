class_name CheckpointMenu
extends CanvasLayer

signal spell_purchased(spell: SpellDefinition)

# ESC / Start (pause), Q / controller cancel (dialogue_cancel) and the
# built-in UI cancel all step back through the menu.
const BACK_ACTIONS: Array[StringName] = [&"pause", &"dialogue_cancel", &"ui_cancel"]

## Spells sold at checkpoints. Without a shop, the Spells button is hidden.
@export var spell_shop: SpellShop

@onready var menu_holder: Control = $MenuHolder
@onready var save_button: Button = $MenuHolder/SaveButton
@onready var spells_button: Button = $MenuHolder/SpellsButton
@onready var shop_panel: Control = $ShopPanel
@onready var stardust_label: Label = %StardustLabel
@onready var offer_list: VBoxContainer = %OfferList
@onready var shop_back_button: Button = %ShopBackButton

var _player: Node = null
var _checkpoint_position: Vector2 = Vector2.ZERO
var _buy_buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	shop_panel.hide()
	spells_button.visible = spell_shop != null
	CoinManager.coins_changed.connect(_on_coins_changed)


func _exit_tree() -> void:
	if CoinManager.coins_changed.is_connected(_on_coins_changed):
		CoinManager.coins_changed.disconnect(_on_coins_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_back_event(event):
		return

	# Consume the event so the pause menu does not also react and unpause
	# the game underneath this menu.
	get_viewport().set_input_as_handled()
	go_back()


## Closes the shop when it is open; otherwise closes the checkpoint menu.
func go_back() -> void:
	if is_spell_shop_open():
		close_spell_shop()
	else:
		_close()


func open(player: Node, checkpoint_position: Vector2) -> void:
	_player = player
	_checkpoint_position = checkpoint_position
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	show()
	save_button.grab_focus()


func open_spell_shop() -> void:
	menu_holder.hide()
	shop_panel.show()
	_refresh_shop()
	_focus_shop()


func close_spell_shop() -> void:
	shop_panel.hide()
	menu_holder.show()
	spells_button.grab_focus()


func is_spell_shop_open() -> bool:
	return shop_panel.visible


func get_buy_button(spell_id: StringName) -> Button:
	return _buy_buttons.get(spell_id) as Button


func _refresh_shop() -> void:
	for child in offer_list.get_children():
		offer_list.remove_child(child)
		child.queue_free()

	_buy_buttons.clear()
	stardust_label.text = "Stardust: %d" % CoinManager.coins

	var registry := _get_registry()
	var offers: Array[SpellDefinition] = []

	if spell_shop != null:
		offers = spell_shop.get_offers(registry)

	if offers.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No spells for sale."
		offer_list.add_child(empty_label)
		return

	for spell in offers:
		offer_list.add_child(_create_offer_row(registry, spell))


func _create_offer_row(registry: SpellRegistry, spell: SpellDefinition) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)

	var name_label := Label.new()
	name_label.text = spell.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var sequence_label := Label.new()
	sequence_label.text = _format_sequence(spell.sequence)
	row.add_child(sequence_label)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(200.0, 0.0)

	if spell_shop.is_owned(registry, spell):
		buy_button.text = "Owned"
		buy_button.disabled = true
	else:
		buy_button.text = "Buy - %d Stardust" % spell_shop.price
		buy_button.disabled = not spell_shop.can_buy(registry, spell)

	buy_button.pressed.connect(_on_buy_pressed.bind(spell))
	row.add_child(buy_button)
	_buy_buttons[spell.id] = buy_button

	return row


func _focus_shop() -> void:
	for button: Button in _buy_buttons.values():
		if not button.disabled:
			button.grab_focus()
			return

	shop_back_button.grab_focus()


func _is_back_event(event: InputEvent) -> bool:
	if event.is_echo():
		return false

	for action in BACK_ACTIONS:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return true

	return false


func _get_registry() -> SpellRegistry:
	if not is_instance_valid(_player) or not _player.has_method(&"get_spell_registry"):
		return null

	return _player.get_spell_registry() as SpellRegistry


func _format_sequence(sequence: Array[StringName]) -> String:
	var keys := PackedStringArray()

	for token in sequence:
		keys.append(_get_token_key_label(token))

	return " + ".join(keys)


func _get_token_key_label(token: StringName) -> String:
	var action := StringName("cast_%s_token" % token)

	if not InputMap.has_action(action):
		return String(token)

	for event in InputMap.action_get_events(action):
		var key_event := event as InputEventKey

		if key_event == null:
			continue

		var code := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode

		return OS.get_keycode_string(code)

	return String(token)


func _on_buy_pressed(spell: SpellDefinition) -> void:
	if spell_shop == null or not spell_shop.buy(_get_registry(), spell):
		return

	_save_purchase()
	spell_purchased.emit(spell)
	_refresh_shop()
	_focus_shop()


## Purchases are saved immediately so death or a restart never undoes them.
## Without an earlier save, this checkpoint becomes the saved one.
func _save_purchase() -> void:
	if not is_instance_valid(_player):
		return

	if not _player.has_checkpoint():
		_player.set_checkpoint(_checkpoint_position)

	SaveGame.save_player(_player)


func _on_coins_changed(_coins: int) -> void:
	if shop_panel.visible:
		_refresh_shop()


func _on_save_btn_pressed() -> void:
	if is_instance_valid(_player):
		# Resting heals the player and respawns enemies (see RespawnOnDeath and
		# EnemyRespawner); the save captures the rested state.
		_player.rest_at_checkpoint(_checkpoint_position)
		SaveGame.save_player(_player)

	_close()


func _on_spells_btn_pressed() -> void:
	open_spell_shop()


func _on_shop_back_btn_pressed() -> void:
	close_spell_shop()


func _on_back_btn_pressed() -> void:
	_close()


func _close() -> void:
	get_tree().paused = false
	queue_free()
