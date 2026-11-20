class_name BigHead
extends StaticBody2D

## A giant head on a tiny body that fills a corridor two blocks tall. It sleeps
## in the way and blocks the passage. A hit wakes it up startled; it dozes off
## again after a while without hits. Defeating it clears the passage.
## Its BreakableShield must be broken with a burst of damage before its health
## can be hurt (or shattered by the Break spell); hits on the shield and the
## shield breaking wake it up too.

signal woke_up
signal fell_asleep

enum State { ASLEEP, AWAKE }

## Seconds it stays awake after the last hit before falling asleep again.
@export_range(0.1, 60.0, 0.1, "or_greater") var sleep_delay: float = 4.0
## Seconds the "!" stays above its head after a hit.
@export_range(0.05, 10.0, 0.05, "or_greater") var alert_duration: float = 0.8

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var alert: Sprite2D = $Alert
@onready var health: Health = $Health
@onready var shield: BreakableShield = $BreakableShield

var _state: State = State.ASLEEP
var _awake_time_left: float = 0.0
var _alert_time_left: float = 0.0


func _ready() -> void:
	alert.visible = false
	sprite.play(&"sleep")
	health.damaged.connect(_on_health_damaged)
	shield.hit.connect(_on_shield_hit)
	shield.broken.connect(wake_up)


func _process(delta: float) -> void:
	if _alert_time_left > 0.0:
		_alert_time_left -= delta

		if _alert_time_left <= 0.0:
			alert.visible = false

	if _state == State.AWAKE:
		_awake_time_left -= delta

		if _awake_time_left <= 0.0:
			fall_asleep()


func get_state() -> State:
	return _state


func is_asleep() -> bool:
	return _state == State.ASLEEP


## Wakes it up, or keeps it awake longer when it already is.
func wake_up() -> void:
	_awake_time_left = sleep_delay
	_alert_time_left = alert_duration
	alert.visible = true

	if _state == State.AWAKE:
		return

	_state = State.AWAKE
	sprite.play(&"awake")
	woke_up.emit()


func fall_asleep() -> void:
	if _state == State.ASLEEP:
		return

	_state = State.ASLEEP
	_alert_time_left = 0.0
	alert.visible = false
	sprite.play(&"sleep")
	fell_asleep.emit()


func _on_health_damaged(amount: float) -> void:
	if amount <= 0.0 or health.is_depleted():
		return

	wake_up()


func _on_shield_hit(absorbed: float) -> void:
	if absorbed <= 0.0:
		return

	wake_up()
