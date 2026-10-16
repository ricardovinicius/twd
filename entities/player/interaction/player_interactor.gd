class_name PlayerInteractor
extends Node

signal prompt_changed(text: String)
signal bindings_changed

@export var player: Node2D
@export var health: Health
@export var dialogue_session: DialogueSession
@export var interaction_action: StringName = &"interaction"
@export var cancel_action: StringName = &"dialogue_cancel"

var _targets: Array[InteractionTarget] = []
var _selected: InteractionTarget
var _held_actions: Array[StringName] = []
var _using_controller: bool = false
var _prompt: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if player == null or health == null:
		push_error("PlayerInteractor: Player and Health must be assigned.")
		set_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)


func register_target(target: InteractionTarget) -> void:
	if target in _targets:
		return

	_targets.append(target)

	target.availability_changed.connect(_refresh_selection)
	target.tree_exiting.connect(unregister_target.bind(target), CONNECT_ONE_SHOT)

	_refresh_selection()


func unregister_target(target: InteractionTarget) -> void:
	if target not in _targets:
		return

	_targets.erase(target)

	if is_instance_valid(target):
		if target.availability_changed.is_connected(_refresh_selection):
			target.availability_changed.disconnect(_refresh_selection)

		var callback := unregister_target.bind(target)

		if target.tree_exiting.is_connected(callback):
			target.tree_exiting.disconnect(callback)

	if _selected == target:
		_selected = null

	_refresh_selection()


func get_selected_target() -> InteractionTarget:
	_refresh_selection()

	return _selected


func get_prompt() -> String:
	return _prompt


func get_binding_label(action: StringName) -> String:
	var labels: PackedStringArray = []

	for event in InputMap.action_get_events(action):
		if _using_controller and event is InputEventJoypadButton:
			var description := event.as_text()
			var button_name := description.get_slice("(", 1).get_slice(",", 0).trim_suffix(")")

			labels.append(button_name if not button_name.is_empty() else description)
		elif not _using_controller and event is InputEventKey:
			var code: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode

			labels.append(OS.get_keycode_string(code))

	return " / ".join(labels)


func _input(event: InputEvent) -> void:
	var controller := event is InputEventJoypadButton or event is InputEventJoypadMotion

	if controller or event is InputEventKey:
		if _using_controller != controller:
			_using_controller = controller

			bindings_changed.emit()

	# Observe releases even when menus consume input or the tree is paused.
	for action in [interaction_action, cancel_action]:
		if event.is_action_released(action):
			_held_actions.erase(action)
		elif get_tree().paused and event.is_action_pressed(action):
			if action not in _held_actions:
				_held_actions.append(action)


func _unhandled_input(event: InputEvent) -> void:
	if (
		get_tree().paused
		or not is_instance_valid(player)
		or health.is_depleted()
	):
		return

	for action in [interaction_action, cancel_action]:
		if (
			not event.is_action_pressed(action)
			or event.is_echo()
			or action in _held_actions
		):
			continue

		_held_actions.append(action)
		var active := is_instance_valid(dialogue_session) and dialogue_session.is_active()

		if action == cancel_action:
			if active:
				dialogue_session.cancel()
				get_viewport().set_input_as_handled()
		elif active:
			dialogue_session.advance()
			get_viewport().set_input_as_handled()
		else:
			_refresh_selection()
			if is_instance_valid(_selected):
				_selected.try_interact(player)
				get_viewport().set_input_as_handled()

		_refresh_selection()

		return


func _process(_delta: float) -> void:
	_refresh_selection()


func _refresh_selection() -> void:
	var nearest: InteractionTarget
	var distance := INF

	if (
		is_instance_valid(player)
		and is_instance_valid(health)
		and not health.is_depleted()
	):
		if is_instance_valid(_selected) and _selected.can_interact(player):
			nearest = _selected
			distance = player.global_position.distance_squared_to(nearest.global_position)

		for target in _targets:
			if not is_instance_valid(target) or not target.can_interact(player):
				continue

			var candidate_distance := player.global_position.distance_squared_to(target.global_position)

			if candidate_distance < distance and not is_equal_approx(candidate_distance, distance):
				nearest = target
				distance = candidate_distance

	_selected = nearest

	var text := ""

	if (
		is_instance_valid(nearest)
		and not get_tree().paused
		and not (is_instance_valid(dialogue_session) and dialogue_session.is_active())
	):
		text = "%s  %s" % [get_binding_label(interaction_action), nearest.get_prompt()]

	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)


func _exit_tree() -> void:
	for target in _targets.duplicate():
		unregister_target(target)
