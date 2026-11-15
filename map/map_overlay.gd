class_name MapOverlay
extends Control

## Full-screen map toggled with the Select action (Tab / controller Back).
## Like Hollow Knight, opening it does not pause the game: the world keeps
## running and the player can still move, only more slowly.

signal opened
signal closed

const TOGGLE_ACTION := &"Select"

@export_category("Dependencies")
@export var player: Node2D
@export var horizontal_movement: HorizontalMovementComponent
## Tile layers whose filled cells are drawn as walls on the map.
@export var tile_layers: Array[TileMapLayer] = []

@export_category("Movement")
## Fraction of the walking speed the player keeps while the map is open.
@export_range(0.0, 1.0, 0.05) var move_speed_multiplier: float = 0.4

@export_category("Presentation")
@export var screen_margin: float = 72.0
@export var background_color: Color = Color(0.04, 0.04, 0.07, 0.88)
@export var wall_color: Color = Color(0.86, 0.8, 0.64)
@export var player_marker_color: Color = Color(1.0, 0.32, 0.26)
@export var player_marker_radius: float = 6.0
@export var title_text: String = "MAP"
@export var hint_text: String = "Tab: close"

var _is_open: bool = false
var _map_texture: ImageTexture
## World area covered by the map texture (one texture pixel per tile).
var _world_bounds: Rect2 = Rect2()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

	if player == null or horizontal_movement == null:
		push_error("MapOverlay: Player and HorizontalMovement must be assigned.")


func _exit_tree() -> void:
	if _is_open:
		_restore_move_speed()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(TOGGLE_ACTION):
		return

	get_viewport().set_input_as_handled()
	toggle()


func _process(_delta: float) -> void:
	# The player keeps moving while the map is open, so the marker follows.
	queue_redraw()


func is_open() -> bool:
	return _is_open


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	if _is_open:
		return

	if _map_texture == null:
		_build_map_texture()

	_is_open = true
	visible = true
	set_process(true)

	if horizontal_movement != null:
		horizontal_movement.speed_multiplier = move_speed_multiplier

	queue_redraw()
	opened.emit()


func close() -> void:
	if not _is_open:
		return

	_is_open = false
	visible = false
	set_process(false)
	_restore_move_speed()
	closed.emit()


func get_map_texture() -> Texture2D:
	return _map_texture


## Converts a world position into this control's local coordinates on the map.
func world_to_map(world_position: Vector2) -> Vector2:
	var map_rect := _get_map_rect()

	if _world_bounds.size == Vector2.ZERO:
		return map_rect.get_center()

	var normalized := (world_position - _world_bounds.position) / _world_bounds.size

	return map_rect.position + normalized * map_rect.size


func _restore_move_speed() -> void:
	if is_instance_valid(horizontal_movement):
		horizontal_movement.speed_multiplier = 1.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	_draw_labels()

	if _map_texture == null:
		return

	draw_texture_rect(_map_texture, _get_map_rect(), false, wall_color)

	if player != null:
		_draw_player_marker()


func _draw_labels() -> void:
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var text_width := size.x - screen_margin * 2.0

	draw_string(
		font,
		Vector2(screen_margin, screen_margin * 0.7),
		title_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size * 2,
		wall_color
	)
	draw_string(
		font,
		Vector2(screen_margin, size.y - screen_margin * 0.4),
		hint_text,
		HORIZONTAL_ALIGNMENT_RIGHT,
		text_width,
		font_size,
		wall_color
	)


func _draw_player_marker() -> void:
	var marker_position := world_to_map(player.global_position)
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)

	draw_circle(marker_position, player_marker_radius + 3.0, Color(0.0, 0.0, 0.0, 0.6))
	draw_circle(marker_position, player_marker_radius * pulse, player_marker_color)


func _get_map_rect() -> Rect2:
	var available := size - Vector2.ONE * screen_margin * 2.0

	if _map_texture == null or available.x <= 0.0 or available.y <= 0.0:
		return Rect2(size * 0.5, Vector2.ZERO)

	var texture_size := Vector2(_map_texture.get_size())
	var scale_factor := minf(available.x / texture_size.x, available.y / texture_size.y)
	var drawn_size := texture_size * scale_factor

	return Rect2((size - drawn_size) * 0.5, drawn_size)


## Bakes the level's tiles into a small texture: one white pixel per tile,
## tinted with wall_color when drawn.
func _build_map_texture() -> void:
	var wall_rects := _collect_wall_rects()

	if wall_rects.is_empty():
		push_warning("MapOverlay: The assigned tile layers have no tiles; the map is empty.")
		return

	var tile_world_size := wall_rects[0].size
	var bounds := wall_rects[0]

	for rect in wall_rects:
		bounds = bounds.merge(rect)

	var image_size := Vector2i((bounds.size / tile_world_size).ceil())
	var image := Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)

	for rect in wall_rects:
		var pixel_position := Vector2i(((rect.position - bounds.position) / tile_world_size).round())
		var pixel_size := Vector2i((rect.size / tile_world_size).ceil()).max(Vector2i.ONE)
		image.fill_rect(Rect2i(pixel_position, pixel_size), Color.WHITE)

	_world_bounds = Rect2(bounds.position, Vector2(image_size) * tile_world_size)
	_map_texture = ImageTexture.create_from_image(image)


func _collect_wall_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []

	for layer in tile_layers:
		if layer == null or layer.tile_set == null:
			continue

		var tile_size := Vector2(layer.tile_set.tile_size) * layer.global_scale.abs()

		for cell in layer.get_used_cells():
			var center := layer.to_global(layer.map_to_local(cell))
			rects.append(Rect2(center - tile_size * 0.5, tile_size))

	return rects
