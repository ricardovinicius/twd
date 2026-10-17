extends SceneTree

# Autoload-dependent scripts are reached at runtime and kept untyped so this
# file compiles before autoloads are registered.

const RING_PATH := "res://entities/items/definitions/regular_ring.tres"

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.get_node("SaveGame").delete_save()
	change_scene_to_file("res://Main.tscn")
	await _frames(3)

	var menu = current_scene.get_node("PauseMenuLayer/PauseMenu")
	var player = current_scene.get_node("LevelRoot/Player")

	_test_opening(menu)
	_test_tab_switching(menu)
	_test_inventory(menu, player)
	_test_inventory_sections(menu, player)
	_test_spells(menu, player)
	_test_settings(menu)
	await _test_quit(menu)

	for failure in _failures:
		push_error("FAIL: %s" % failure)

	if _failures.is_empty():
		print("PASS: pause menu (%d checks)" % _checks)
		quit(0)
	else:
		quit(1)


func _test_opening(menu: Node) -> void:
	_check(not menu.visible, "The menu must start hidden.")

	_press(menu, &"pause")
	_check(menu.visible and paused, "Pause must open the menu and pause the game.")
	_check(menu.current_tab == 0, "The menu must open on the Inventory tab.")
	_check(menu.pages[0].visible and not menu.pages[1].visible, "Only the Inventory page must be visible.")
	_check(menu.artifact_slots[0].has_focus(), "The first artifact slot must receive focus.")


func _test_tab_switching(menu: Node) -> void:
	_press(menu, &"menu_tab_next")
	_check(menu.current_tab == 1 and menu.pages[1].visible, "Next tab must open Spells.")
	_check(menu.tab_buttons[1].button_pressed, "The active tab button must be highlighted.")

	_press(menu, &"menu_tab_next")
	_press(menu, &"menu_tab_next")
	_check(menu.current_tab == 3, "Next tab must reach Quit.")

	_press(menu, &"menu_tab_next")
	_check(menu.current_tab == 0, "Next tab must wrap from Quit to Inventory.")

	_press(menu, &"menu_tab_prev")
	_check(menu.current_tab == 3, "Previous tab must wrap from Inventory to Quit.")

	menu.tab_buttons[2].pressed.emit()
	_check(menu.current_tab == 2 and menu.pages[2].visible, "Clicking a tab must open it.")

	menu.select_tab(0)


func _test_inventory(menu: Node, player: Node) -> void:
	var ring = load(RING_PATH)
	player.get_inventory().add_item(ring, 2)
	menu.refresh_inventory()

	_check(menu.get_stat_text("hp") == "100/100", "The status panel must show current and maximum HP.")
	_check(menu.get_stat_text("res_arc") == "+0", "Resistances must be shown as signed values.")
	_check(menu.artifact_slots[0].text == "Vazio", "Empty artifact slots must say so.")

	menu.artifact_slots[0].pressed.emit()
	_check(menu.overlay.visible, "An artifact slot must open the item picker.")
	_check(_find_overlay_button(menu, "Ring") != null, "The item picker must list inventory items.")

	_find_overlay_button(menu, "Ring").pressed.emit()
	_check(not menu.overlay.visible, "Choosing an item must close the picker.")
	_check(player.get_equipment().get_item(0) == ring, "Choosing an item must equip it.")
	_check(menu.artifact_slots[0].text == ring.display_name, "The slot must show the equipped item.")
	_check(menu.get_stat_text("move_speed") == "+50", "Equipping must update the status panel.")

	menu.artifact_slots[0].pressed.emit()
	_find_overlay_button(menu, "Remover").pressed.emit()
	_check(player.get_equipment().get_item(0) == null, "Remove must unequip the artifact.")
	_check(menu.get_stat_text("move_speed") == "+0", "Unequipping must update the status panel.")


func _test_inventory_sections(menu: Node, player: Node) -> void:
	menu.general_items_button.pressed.emit()
	_check(menu.overlay_title.text == "Itens gerais", "General items must open its section.")
	_check(_find_overlay_button(menu, "Ring  x2") != null, "General items must list quantities.")

	_press(menu, &"pause")
	_check(not menu.overlay.visible and paused and menu.visible, "Pause must close a section, not the menu.")

	_press(menu, &"menu_tab_next")
	_check(menu.current_tab == 1, "Tabs must switch again after closing a section.")
	menu.select_tab(0)

	menu.chains_button.pressed.emit()
	_check(menu.overlay_title.text == "Correntes", "Chains must open its section.")
	menu.overlay_back_button.pressed.emit()
	_check(not menu.overlay.visible, "Back must close a section.")

	menu.monster_guide_button.pressed.emit()
	_check(_find_overlay_button(menu, "Esqueleto") != null, "The monster guide must list the skeleton.")
	_check(_find_overlay_button(menu, "Rastejador") != null, "The monster guide must list the crawler.")
	_check(menu.overlay_detail.visible, "The monster guide must show the selected monster's details.")
	_check(_overlay_detail_has_text(menu, "Vida: 50"), "The monster details must show its health.")
	menu.close_overlay()


func _test_spells(menu: Node, player: Node) -> void:
	menu.select_tab(1)

	var database = player.get_spell_registry().database
	_check(menu.spell_list.get_child_count() == database.get_spells().size(), "The Spells tab must list every spell.")
	_check(menu.get_spell_button(&"double_jump").text.contains("bloqueada"), "Unowned spells must be marked locked.")
	_check(not menu.get_spell_button(&"magic_arrow").text.contains("bloqueada"), "Owned spells must not be marked locked.")
	_check(menu.spell_name_label.text == "Magic Arrow", "The first spell must be shown on open.")

	menu.show_spell(database.get_spell(&"double_jump"))
	_check(menu.spell_name_label.text == "Double Jump", "Selecting a spell must show its name.")
	_check(menu.spell_keys_label.text == "Botões:  L + K", "The detail must show the spell's keys.")
	_check(menu.spell_cooldown_label.text == "Cooldown:  0.25 s", "The detail must show the cooldown.")
	_check(not menu.spell_effect_label.text.is_empty(), "The detail must describe the effect.")
	_check(menu.spell_icon.texture != null, "The detail must show the spell's symbol.")

	menu.show_spell(database.get_spell(&"push"))
	_check(menu.spell_cooldown_label.text == "Cooldown:  nenhum", "Spells without cooldown must say so.")


func _test_settings(menu: Node) -> void:
	menu.select_tab(2)

	var panel = menu.options_panel
	_check(panel.is_visible_in_tree(), "The Settings tab must show the options.")
	_check(panel.get_binding_button(&"jump") != null, "The Settings tab must list controls.")

	panel.begin_capture(&"jump")
	menu.select_tab(3)
	_check(not panel.is_capturing(), "Changing tabs must cancel a key capture.")


func _test_quit(menu: Node) -> void:
	menu.select_tab(3)
	_check(menu.resume_button.has_focus(), "The Quit tab must focus Continue.")

	menu.resume_button.pressed.emit()
	await create_timer(0.5, true, false, true).timeout
	_check(not paused and not menu.visible, "Continue must resume the game.")

	menu.pause_game()
	menu.select_tab(3)
	menu.main_menu_button.pressed.emit()
	await _frames(3)
	_check(current_scene != null and current_scene.name == "MainMenu", "Quit to menu must open the main menu.")
	_check(not paused, "Quitting to the menu must unpause.")


func _press(menu: Node, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	menu._unhandled_input(event)


func _find_overlay_button(menu: Node, text: String) -> Button:
	for child in menu.overlay_list.get_children():
		if child is Button and (child as Button).text.contains(text):
			return child

	return null


func _overlay_detail_has_text(menu: Node, text: String) -> bool:
	for child in menu.overlay_detail.get_children():
		if child is Label and (child as Label).text == text:
			return true

	return false


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1

	if not condition:
		_failures.append(message)
