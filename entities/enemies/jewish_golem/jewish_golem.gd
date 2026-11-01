class_name JewishGolem
extends CharacterBody2D

## Boss: the golem of the old legends, a giant of clay brought to life by the
## rune in his chest. Almost twice the player's height, slow and relentless.
## He wakes when the player comes near and picks one attack at a time:
## - Slam: up close he raises both fists and smashes the ground in front.
## - Clay shot: he lobs lumps of clay; one that lands becomes a clay minion.
## - Summon: now and then he pours clay and raises a minion directly.
##   Never more than two minions (from balls or summons) exist at once.
## - Shield: he raises breakable clay blocks around himself (dig them).
## Below half health he is enraged: shorter cooldowns, two balls per throw.
## Damage never interrupts him. When defeated the rune leaves his chest and
## he falls asleep on his knees. The defeat is remembered by the save.

enum State {
	DORMANT,
	CHASE,
	ATTACK,
	DEFEATED,
}

enum Attack {
	NONE,
	SLAM,
	CLAY_SHOT,
	SUMMON,
	SHIELD,
}

signal state_changed(state: State)
signal attack_chosen(attack: Attack)
signal enraged
signal defeated

@export var facing_direction: float = -1.0
## Remembered by SaveGame once he is defeated. Unique per placed boss.
@export var boss_id: StringName = &"jewish_golem"

@export_category("Attack Choice")
## Horizontal distance within which he slams.
@export_range(0.0, 1000.0, 1.0, "or_greater") var slam_range: float = 150.0
## Height difference allowed for the slam.
@export_range(0.0, 1000.0, 1.0, "or_greater") var slam_height: float = 170.0
## Pause after any attack.
@export_range(0.0, 10.0, 0.05, "or_greater") var attack_cooldown: float = 0.9
@export_range(0.0, 60.0, 0.05, "or_greater") var clay_shot_cooldown: float = 2.6
@export_range(0.0, 60.0, 0.05, "or_greater") var summon_cooldown: float = 14.0
@export_range(0.0, 60.0, 0.05, "or_greater") var shield_cooldown: float = 8.0
## He only starts shielding after losing this share of his health.
@export_range(0.0, 1.0, 0.01) var shield_health_ratio: float = 0.9

@export_category("Summon")
## Where minions rise, relative to him (x is mirrored to his facing). One
## minion per offset; the summoner's cap (2 on screen) still applies.
@export var summon_offsets: Array[Vector2] = [Vector2(170.0, 40.0)]
@export_range(0.0, 5.0, 0.01, "or_greater") var summon_windup: float = 0.9
@export_range(0.0, 5.0, 0.01, "or_greater") var summon_recovery: float = 0.6

@export_category("Shield")
@export_range(0.0, 5.0, 0.01, "or_greater") var shield_windup: float = 0.8
@export_range(0.0, 5.0, 0.01, "or_greater") var shield_recovery: float = 0.6

@export_category("Enrage")
## Enraged once health falls to this share.
@export_range(0.0, 1.0, 0.01) var enrage_health_ratio: float = 0.5
## Cooldowns are multiplied by this while enraged.
@export_range(0.05, 1.0, 0.01) var enraged_cooldown_scale: float = 0.65
@export_range(1, 5) var enraged_shots: int = 2

@export_category("Defeat")
## How far the rune floats up out of his chest.
@export_range(0.0, 500.0, 1.0, "or_greater") var rune_rise: float = 70.0
@export_range(0.1, 10.0, 0.05, "or_greater") var rune_duration: float = 1.6

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var rune: Sprite2D = $Rune
@onready var horizontal_movement: HorizontalMovementComponent = $HorizontalMovement
@onready var gravity: GravityComponent = $Gravity
@onready var aggro_detector: TargetDetector = $AggroDetector
@onready var slam: MeleeAttackComponent = $Slam
@onready var clay_shot: ClayShotComponent = $ClayShot
@onready var summoner: ClayMinionSummoner = $Summoner
@onready var shield_spawner: ShieldBlockSpawner = $ShieldSpawner
@onready var contact_area: Area2D = $ContactImpact/ContactArea
@onready var attack_receiver: AttackReceiver = $AttackReceiver
@onready var burn_reaction: BurnStatusReaction = $AttackReceiver/BurnStatusReaction
@onready var health: Health = $Health

var _state: State = State.DORMANT
var _target: Node2D
var _current_attack: Attack = Attack.NONE
var _enraged: bool = false
var _save_checked: bool = false

var _cooldown_left: float = 0.0
var _clay_shot_cooldown_left: float = 1.2
var _summon_cooldown_left: float = 6.0
var _shield_cooldown_left: float = 0.0

# Summon and shield are timed here: wind-up, then the effect, then recovery.
var _timed_left: float = 0.0
var _timed_effect_done: bool = false


func _ready() -> void:
	aggro_detector.target_entered.connect(_on_target_entered)
	slam.attack_active.connect(_on_slam_active)
	slam.attack_finished.connect(_on_attack_finished)
	clay_shot.attack_finished.connect(_on_attack_finished)
	health.damaged.connect(_on_damaged)
	health.depleted.connect(_on_health_depleted)
	tree_exiting.connect(_on_tree_exiting)

	rune.visible = false
	sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	# The save is loaded after the level is ready, so it is read here.
	if not _save_checked:
		_save_checked = true

		if SaveGame.is_boss_defeated(boss_id):
			_enter_defeated(false)

	_apply_gravity(delta)

	if _state == State.DEFEATED:
		velocity.x = 0.0
		move_and_slide()
		return

	_tick_cooldowns(delta)
	_validate_target()

	var direction := 0.0

	if _state == State.ATTACK:
		_process_timed_attack(delta)
	else:
		direction = _resolve_movement()

	velocity.x = horizontal_movement.calculate_velocity(velocity.x, direction, delta)
	move_and_slide()
	_update_walk_animation()


func get_state() -> State:
	return _state


func get_target() -> Node2D:
	return _target


func get_current_attack() -> Attack:
	return _current_attack


func is_enraged() -> bool:
	return _enraged


func is_defeated() -> bool:
	return _state == State.DEFEATED


## Which attack fits a target at this offset right now (NONE = walk closer).
func choose_attack(offset: Vector2) -> Attack:
	if _state == State.DEFEATED or _cooldown_left > 0.0:
		return Attack.NONE

	if absf(offset.x) <= slam_range and absf(offset.y) <= slam_height:
		return Attack.SLAM

	if _can_shield():
		return Attack.SHIELD

	if _summon_cooldown_left <= 0.0 and summoner.can_summon(summon_offsets.size()):
		return Attack.SUMMON

	if _clay_shot_cooldown_left <= 0.0:
		return Attack.CLAY_SHOT

	return Attack.NONE


func _can_shield() -> bool:
	return (
		_shield_cooldown_left <= 0.0
		and shield_spawner.get_alive_count() == 0
		and health.current <= health.maximum * shield_health_ratio
	)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity = gravity.calculate_velocity(velocity, get_gravity(), delta)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _tick_cooldowns(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_clay_shot_cooldown_left = maxf(_clay_shot_cooldown_left - delta, 0.0)
	_summon_cooldown_left = maxf(_summon_cooldown_left - delta, 0.0)
	_shield_cooldown_left = maxf(_shield_cooldown_left - delta, 0.0)


func _resolve_movement() -> float:
	if not is_instance_valid(_target):
		_set_state(State.DORMANT if _state == State.DORMANT else State.CHASE)
		return 0.0

	var offset := _target.global_position - global_position
	var attack := choose_attack(offset)

	_face(signf(offset.x))

	if attack != Attack.NONE:
		_start_attack(attack, offset)
		return 0.0

	_set_state(State.CHASE)

	if absf(offset.x) <= slam_range * 0.8:
		return 0.0

	return signf(offset.x)


func _start_attack(attack: Attack, offset: Vector2) -> void:
	var toward := signf(offset.x) if not is_zero_approx(offset.x) else facing_direction
	var scale_factor := enraged_cooldown_scale if _enraged else 1.0

	_current_attack = attack
	_set_state(State.ATTACK)
	_face(toward)
	attack_chosen.emit(attack)

	match attack:
		Attack.SLAM:
			_show_frame(&"slam", 0)
			slam.begin_attack(self, Vector2(toward, 0.0))
		Attack.CLAY_SHOT:
			_clay_shot_cooldown_left = clay_shot_cooldown * scale_factor
			clay_shot.shots = enraged_shots if _enraged else 1
			_show_frame(&"throw", 0)
			clay_shot.begin_attack(_target)
		Attack.SUMMON:
			_summon_cooldown_left = summon_cooldown * scale_factor
			_begin_timed(&"summon", summon_windup)
		Attack.SHIELD:
			_shield_cooldown_left = shield_cooldown * scale_factor
			_begin_timed(&"shield", shield_windup)


func _begin_timed(animation_name: StringName, windup: float) -> void:
	_timed_left = windup
	_timed_effect_done = false
	_show_frame(animation_name, 0)


func _process_timed_attack(delta: float) -> void:
	if _current_attack == Attack.CLAY_SHOT:
		if clay_shot.has_thrown():
			_show_frame(&"throw", 1)
		return

	if _current_attack != Attack.SUMMON and _current_attack != Attack.SHIELD:
		return

	_timed_left -= delta

	if _timed_left > 0.0:
		return

	if _timed_effect_done:
		_on_attack_finished()
		return

	_timed_effect_done = true

	if _current_attack == Attack.SUMMON:
		_show_frame(&"summon", 1)
		_summon_minions()
		_timed_left = summon_recovery
	else:
		_show_frame(&"shield", 1)
		shield_spawner.raise_blocks()
		_timed_left = shield_recovery


func _summon_minions() -> void:
	for offset in summon_offsets:
		var point := global_position + Vector2(offset.x * facing_direction, offset.y)
		summoner.summon_at(point, _target)


func _validate_target() -> void:
	if is_instance_valid(_target) and _target.is_inside_tree() and aggro_detector.has_target(_target):
		return

	if _state == State.ATTACK:
		return

	_target = null

	var targets := aggro_detector.get_targets()

	if not targets.is_empty():
		_target = targets[0]


func _face(direction: float) -> void:
	if is_zero_approx(direction):
		return

	facing_direction = signf(direction)
	sprite.flip_h = facing_direction < 0.0
	clay_shot.position.x = absf(clay_shot.position.x) * facing_direction


func _set_state(new_state: State) -> void:
	if new_state == _state:
		return

	_state = new_state
	state_changed.emit(_state)


func _update_walk_animation() -> void:
	if _state == State.ATTACK or _state == State.DEFEATED:
		return

	if absf(velocity.x) > 1.0:
		_play(&"walk")
	else:
		_play(&"idle")


func _play(animation_name: StringName) -> void:
	if sprite.animation == animation_name and sprite.is_playing():
		return

	sprite.play(animation_name)


# Attack frames follow the attack phases instead of a timer.
func _show_frame(animation_name: StringName, frame: int) -> void:
	sprite.animation = animation_name
	sprite.pause()
	sprite.frame = frame


func _on_target_entered(target: Node2D) -> void:
	if not is_instance_valid(_target):
		_target = target


func _on_slam_active() -> void:
	_show_frame(&"slam", 1)


func _on_attack_finished() -> void:
	if _state == State.DEFEATED:
		return

	if slam.is_attacking() or clay_shot.is_attacking():
		return

	_current_attack = Attack.NONE
	_cooldown_left = attack_cooldown * (enraged_cooldown_scale if _enraged else 1.0)
	_set_state(State.CHASE if is_instance_valid(_target) else State.DORMANT)
	_play(&"idle")


# Damage never interrupts him; it only flashes the sprite.
func _on_damaged(amount: float) -> void:
	if amount <= 0.0 or health.is_depleted():
		return

	if not _enraged and health.current <= health.maximum * enrage_health_ratio:
		_enraged = true
		enraged.emit()

	var tween := create_tween()

	sprite.modulate = Color(1.0, 0.5, 0.45)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _on_health_depleted() -> void:
	_enter_defeated(true)


## Stops everything, crumbles what he made, and kneels. With `animate`, the
## rune floats out of his chest first; without it (already defeated in the
## save) he simply appears asleep on his knees.
func _enter_defeated(animate: bool) -> void:
	if _state == State.DEFEATED:
		return

	_set_state(State.DEFEATED)
	_current_attack = Attack.NONE
	_target = null

	slam.cancel_attack()
	clay_shot.cancel_attack()
	summoner.clear()
	shield_spawner.clear()

	# He no longer hurts or can be hurt; he stays as a sleeping statue.
	contact_area.set_deferred(&"monitoring", false)
	attack_receiver.set_deferred(&"monitorable", false)
	aggro_detector.set_deferred(&"monitoring", false)
	burn_reaction.blocked = true

	SaveGame.mark_boss_defeated(boss_id)

	if not animate:
		_show_frame(&"defeat", 2)
		defeated.emit()
		return

	sprite.modulate = Color.WHITE
	_show_frame(&"defeat", 0)
	_release_rune()


func _release_rune() -> void:
	var start := rune.position

	rune.visible = true
	rune.modulate = Color.WHITE

	var tween := create_tween()

	# The rune slips out of his chest and fades as he sinks to his knees.
	tween.tween_property(rune, "position", start + Vector2(0.0, -rune_rise / scale.y), rune_duration)
	tween.parallel().tween_property(rune, "modulate:a", 0.0, rune_duration).set_delay(rune_duration * 0.4)
	tween.parallel().tween_callback(_show_frame.bind(&"defeat", 1)).set_delay(rune_duration * 0.3)
	tween.tween_callback(_finish_defeat)


func _finish_defeat() -> void:
	rune.visible = false
	_show_frame(&"defeat", 2)
	defeated.emit()


# Respawns and level changes free him; take his blocks and minions along.
func _on_tree_exiting() -> void:
	summoner.clear()
	shield_spawner.clear()
