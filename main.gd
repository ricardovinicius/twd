extends Node2D

@export var pause_menu: PauseMenu
@export var spell_registry: SpellRegistry
@export var equipment: Equipment
@export var stats: PlayerStats
@export var health: Health
@export var inventory: Inventory
@export var interactor: PlayerInteractor
@export var dialogue_session: DialogueSession
@export var dialogue_interaction: DialogueInteraction
@export var player: CharacterBody2D


func _ready() -> void:
	if (
		interactor == null
		or dialogue_session == null
		or dialogue_interaction == null
	):
		push_error("Main: DialogueSession, PlayerInteractor, and DialogueInteraction must be assigned.")
		return

	interactor.dialogue_session = dialogue_session
	dialogue_interaction.setup(dialogue_session)

	if pause_menu == null:
		push_error("Main: PauseMenu is not assigned.")
		return

	pause_menu.setup(spell_registry, equipment, stats, health, inventory)

	_load_saved_game()


func _load_saved_game() -> void:
	if player == null:
		push_error("Main: Player is not assigned; the saved game cannot be loaded.")
		return

	# Without a save, Stardust collected or spent since the game started is
	# not kept: the level's pickups reappear, so the total starts over too.
	if not SaveGame.has_save() or not SaveGame.load_into_player(player):
		CoinManager.set_coins(0)
