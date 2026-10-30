class_name BurnStatusReaction
extends AttackReaction

## Lets an entity catch fire. Placed under its AttackReceiver, it reacts to
## attacks carrying a BurnEffect: the entity burns for the effect's duration,
## taking damage on every tick, flickering orange with small flames on it.
## A new burn while burning refreshes the duration; it does not stack.

signal burn_started
signal burn_ticked(damage: float)
signal burn_ended

const FLAME_TEXTURE := preload("res://components/attack_reactions/burn/sprites/flames_8x8.png")

@export var health: Health
## Sprite or visual node that flickers and carries the flames.
@export var visual: CanvasItem
## Flame position relative to the visual, in its local pixels.
@export var flame_offset: Vector2 = Vector2(0, -6)
@export var burn_color: Color = Color(1.0, 0.55, 0.25)

## While blocked, no burn is applied and an active burn goes out (for example
## while the Star Man rolls).
var blocked: bool = false:
	set(value):
		blocked = value
		if blocked:
			extinguish()

var _burning: bool = false
var _time_left: float = 0.0
var _tick_left: float = 0.0
var _effect: BurnEffect
var _elapsed: float = 0.0
var _flames: AnimatedSprite2D


func _ready() -> void:
	if health == null:
		push_error("BurnStatusReaction: Health is not assigned.")

	set_physics_process(false)


func supports(attack: AttackData) -> bool:
	return (
		health != null
		and not blocked
		and not health.is_depleted()
		and BurnEffect.find_in(attack) != null
	)


func react(attack: AttackData) -> void:
	ignite(BurnEffect.find_in(attack))


func ignite(effect: BurnEffect) -> void:
	if effect == null or blocked or health == null or health.is_depleted():
		return

	var was_burning := is_burning()

	_effect = effect
	_time_left = effect.duration

	if was_burning:
		return

	_burning = true
	_tick_left = effect.tick_interval
	_elapsed = 0.0
	_show_flames(true)
	set_physics_process(true)
	burn_started.emit()


func extinguish() -> void:
	if not _burning:
		return

	_burning = false
	_time_left = 0.0
	_effect = null
	_show_flames(false)
	set_physics_process(false)
	burn_ended.emit()


func is_burning() -> bool:
	return _burning


func get_time_left() -> float:
	return _time_left


func _physics_process(delta: float) -> void:
	if health == null or health.is_depleted():
		extinguish()
		return

	_elapsed += delta
	_time_left -= delta
	_tick_left -= delta

	if _tick_left <= 0.0:
		_tick_left += _effect.tick_interval
		var dealt := health.take_damage(_effect.tick_damage)
		burn_ticked.emit(dealt)

	if is_instance_valid(visual):
		var flicker := 0.5 + 0.5 * sin(_elapsed * 30.0)
		visual.self_modulate = Color.WHITE.lerp(burn_color, 0.4 + 0.4 * flicker)

	if _time_left <= 0.0:
		extinguish()


func _show_flames(show: bool) -> void:
	if not is_instance_valid(visual):
		return

	if not show:
		visual.self_modulate = Color.WHITE
		if is_instance_valid(_flames):
			_flames.queue_free()
		_flames = null
		return

	if is_instance_valid(_flames):
		return

	var frames := SpriteFrames.new()

	for index in 2:
		var atlas := AtlasTexture.new()

		atlas.atlas = FLAME_TEXTURE
		atlas.region = Rect2(index * 8, 0, 8, 8)
		frames.add_frame(&"default", atlas)

	frames.set_animation_speed(&"default", 10.0)
	_flames = AnimatedSprite2D.new()
	_flames.name = "BurnFlames"
	_flames.sprite_frames = frames
	_flames.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flames.position = flame_offset
	visual.add_child(_flames)
	_flames.play(&"default")
