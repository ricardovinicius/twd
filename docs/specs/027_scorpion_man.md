# 027 — Scorpion Man

## Overview

A crouching man with a big segmented tail where his head should be, ending in a large stinger, and two pincers on his butt. His attack depends on distance: up close he slams the big stinger into the ground; far away he turns his back and leaps across the room butt-first, pincers open. He has far more health than regular enemies and is not interrupted by damage. Placeholder art is very low fidelity (32×32 frames, scaled 3×) and will be replaced.

## Behavior rules

1. **Chase.** He targets a player inside `AggroDetector` (660 px) and walks toward them at 170.
2. **Choice by distance.** `choose_attack(offset)` returns, once the pause after the previous attack (`attack_cooldown`, 0.35 s) is over:
   - `SLAM` when the player is within `slam_range` (110) horizontally and `slam_height` (110) vertically;
   - `LEAP` when the player is at least `leap_trigger_distance` (240) away, the leap cooldown (`leap_cooldown`, 3.5 s) is over, and he is on the floor;
   - `NONE` otherwise: he walks closer.
   `attack_chosen(attack)` is emitted when an attack starts.
3. **Tail slam (close).** He faces the player, raises the big tail for 0.7 s, and slams the stinger into the ground in front of him: one hit of 25.
4. **Pincer leap (far).** He turns his back to the player (the butt pincers lead) and crouches for `windup_duration` (0.9 s, the warning). Then he flies across the room at `leap_speed` (600 px/s, slow enough to see coming and jump over) in a low arc of `leap_height` (40 px), landing `overshoot` (160) past the player (distance clamped to 200–900). The pincers hit the player at most once per leap for 20. A wall stops the flight. After landing he is stuck for `recovery_duration` (1.2 s), the window to hit him. `LeapAttackComponent` moves the body during the leap.
5. **No interruption.** Damage only flashes the sprite; attacks continue.
6. **Contact.** Touching him deals 10 with knockback (including while he flies past).
7. **Death.** 300 HP (six times the skeleton); drops 5 × 20 Stardust.

## Scene composition

```text
ScorpionMan (CharacterBody2D, ScorpionMan, scale 3, layer Entities, mask World + One-way)
├── AnimatedSprite2D   walk (4), slam (3), leap (2) — attack frames follow the attack phases
├── CollisionShape2D
├── HorizontalMovement max 170
├── Slam               MeleeAttackComponent + Hitbox (ground in front)
├── Leap               LeapAttackComponent
├── LeapHitbox         AttackHitbox (butt pincers, flipped toward the leap)
├── Gravity
├── AggroDetector      TargetDetector
├── ContactImpact
├── Health             300
├── DestroyOnDeath
├── StardustDropOnDeath 5 × 20
└── AttackReceiver     + HealthDamageReaction
```

## Public contracts

- `ScorpionMan`: `get_state()`, `get_target()`, `get_current_attack()`, `choose_attack(offset)`, `facing_direction`; signals `state_changed(state)`, `attack_chosen(attack)`.
- `LeapAttackComponent`: `begin_leap(source, target_x) -> bool`, `cancel()`, `is_attacking()`, `is_airborne()`, `get_direction()`; signals `leap_started(direction)`, `took_off`, `landed`, `attack_finished`. Missing body or hitbox reports an error and rejects leaps.

## Art replacement

Sprites in `entities/enemies/scorpion_man/sprites/`, 32×32 frames facing right (tail at the front/right, butt pincers at the back/left):

| File | Frames | Use |
| --- | --- | --- |
| `walk_32x32.png` | 4 | Walking. |
| `slam_32x32.png` | 3 | 0: tail raised (wind-up). 1: stinger hitting the ground in front (strike and recovery). 2: spare/recover. |
| `leap_32x32.png` | 2 | 0: crouch before take-off and landing. 1: in the air, pincers open. He faces away from the leap, so the pincers (left side of the drawing) lead. |

## Scope limits

- He is a regular (tough) enemy, not a boss: `EnemyRespawner` recreates him when the player dies or rests, like the other enemies. There is no boss fight structure (arena, boss health bar) yet.

## Acceptance criteria

- Close: he faces the player, raises the tail, then slams for one hit.
- Mid range: he walks closer, then slams.
- Far: he turns his back, crouches long enough to react to, flies past the player at `leap_speed`, hits once with the pincers, lands, stays stuck during recovery, and does not leap again until the cooldown ends.
- Damage does not interrupt him; he is much tougher than regular enemies.
- Death drops Stardust; respawn and monster guide entry work.

## Testing

`tests/scorpion_man/`. Manually verify the readability of both wind-ups, the leap arc against the real player's height, and hitbox reach against the final art.
