# 023 — Flying Eye

## Overview

The Flying Eye is a winged eyeball enemy that ignores gravity. It drifts back and forth around where it was placed. When it sees the player, it hovers at a distance above them, charges its pupil, and spits a bolt toward them. Its art is deliberately very low fidelity: 16×16 frames scaled 3× like the other entities.

## Goals

- Add a ranged enemy that pressures the player from the air.
- Reuse the existing detection, health, contact, receiver, drop, respawn, and bestiary pipelines.
- Keep the projectile independent from the eye that fired it.

## Behavior rules

1. **Patrol.** Without a visible player, the eye flies a horizontal sine path of `patrol_distance` around its home (the placement position) over `patrol_period` seconds. Home is read on the first physics frame, after the `EnemyRespawner` has placed the instance.
2. **Sight.** The eye sees a player that is inside `AggroDetector` and has a clear ray to it on `line_of_sight_mask` (World by default). Walls and floors block sight. It sees in every direction.
3. **Engage.** While it sees a player, the eye flies toward a point `keep_distance` to the side and `hover_height` (70) above them, keeping the side it is already on. That point bobs up and down by `engage_sway` (60) every `engage_sway_period` (2.4 s), so the eye regularly dips into the player's horizontal line of fire (the player only aims in four directions). It starts an attack whenever the ranged attack is ready.
4. **Attack.** An attack winds up for `windup_duration` (shoot animation, glowing pupil) while aiming at the target, then launches one `EyeBolt` from the pupil and starts `cooldown`. Attacks are rejected during a wind-up or cooldown without changing state.
5. **Losing the player** returns the eye to patrol, cancels a wind-up without firing or starting the cooldown, and resumes the patrol from the eye's current position.
6. **Bolt.** A bolt flies straight at `projectile_speed` (340 px/s on the Flying Eye) for at most `projectile_lifetime`. It damages the first Attack Receiver that belongs to the target group (`player`) once, then frees itself. It passes through other enemies' receivers and one-way platforms and stops on World geometry.
7. **Contact.** Touching the eye applies contact damage and knockback through `ContactImpactComponent`, like the other enemies.
8. **Damage and death.** Damage plays the hit animation. At zero health the eye is freed and drops 2 × 10 Stardust.
9. **Collision.** The eye body has no collision layer (the player cannot stand on it) and collides only with the World, so it cannot fly through walls.

## Scene composition

```text
FlyingEye (CharacterBody2D, FlyingEye, floating, scale 3, layer 0, mask World)
├── AnimatedSprite2D          fly (4), shoot (3), hit (2) — 16×16 frames
├── CollisionShape2D
├── Flight                    HoverFlightComponent
├── AggroDetector             TargetDetector (mask Entities)
├── RangedAttack              ProjectileAttackComponent → EyeBolt.tscn
├── ContactImpact             ContactImpactComponent + ContactArea
├── Health                    40 HP
├── DestroyOnDeath
├── StardustDropOnDeath       2 × 10
└── AttackReceiver            + HealthDamageReaction

EyeBolt (Area2D, EyeBolt, top_level, scale 3, mask World + Attack Receivers, monitorable)
├── AnimatedSprite2D          2-frame flicker, 8×8
└── CollisionShape2D
```

The bolt stays monitorable: Godot does not pair non-monitorable areas with static bodies, so a non-monitorable bolt would fly through walls.

## Component responsibilities

| Component | Responsibility |
| --- | --- |
| `FlyingEye` | Coordinates state (patrol/engage), sight, flight targets, and animation. |
| `HoverFlightComponent` | Eases a `CharacterBody2D` toward a point without gravity, using `move_and_slide()`. |
| `ProjectileAttackComponent` | Wind-up, aim tracking, cooldown, building `AttackData`, and launching bolts into the projectile parent. |
| `EyeBolt` | Its own movement, target filtering, obstacle stops, lifetime, and freeing. |
| `TargetDetector`, `ContactImpactComponent`, `Health`, `AttackReceiver`, `DestroyOnDeath`, `StardustDropOnDeath` | Existing shared enemy behavior. |

## Public contracts

- `FlyingEye`: `get_state()`, `get_target()`, `get_home()`, `set_home(point)`, `has_line_of_sight(point)`, `can_see(target)`, signal `state_changed(state)`.
- `HoverFlightComponent`: `fly_toward(point, delta)`, `desired_velocity_toward(point)`.
- `ProjectileAttackComponent`: `can_attack()`, `is_attacking()`, `get_cooldown_left()`, `begin_attack(target) -> bool`, `cancel_attack()`; signals `attack_started(target)`, `projectile_fired(projectile)`, `attack_finished`.
- `EyeBolt`: `launch(origin, direction, attack, speed, lifetime, target_group)`, `is_consumed()`.

## Failure handling

- Missing `source` or `projectile_scene` on the ranged attack reports an error and disables attacking.
- A projectile scene that does not create an `EyeBolt`, or no available projectile parent, reports an error and fires nothing.
- An invalid launch (null attack, zero direction, non-positive speed or lifetime) reports an error and frees the bolt.
- A removed target during a wind-up keeps the last aim direction.

## Scope limits

- No pathfinding: the eye flies straight and slides along walls.
- No predictive aiming; bolts aim at the target's position when fired.
- No death animation; the eye is freed like the other enemies.

## Acceptance criteria

- The eye patrols within `patrol_distance` of its placement and keeps its height.
- A visible player in range makes it engage, wind up with the shoot animation, and fire exactly one bolt toward them per cooldown.
- A wall between the eye and the player prevents it from seeing them.
- Bolts damage the player once, pass through other enemies, stop on walls, and expire.
- Death frees the eye and drops two 10-Stardust pickups.
- The respawner recreates the eye with its configuration around its placement.
- The monster guide lists the Flying Eye with a portrait.

## Testing

`tests/flying_eye/` covers composition, patrol bounds, engage and fire, cooldown and rejection, line of sight, bolt filtering, obstacles, lifetime, death drops, respawn, and the bestiary entry. Manually verify the animations and the feel of dodging bolts in a level.
