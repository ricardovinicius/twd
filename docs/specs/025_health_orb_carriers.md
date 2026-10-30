# 025 — Health Orb Carriers

## Overview

Two harmless creatures carry a health orb in their hands and are the player's source of healing:

- **Life Moth** — flutters back and forth and flies away when the player gets close.
- **Orb Roller** (dung beetle) — plays with the orb and, when the player gets close, rolls it away and flees.

Both are a little slower than the player, so a determined chase catches them. Killing one makes it let go of its orb, which falls to the floor and then releases its health for the player to collect. Art is placeholder, very low fidelity (16×16 frames, 8×8 orb, scaled 3×), and will be replaced.

## Goals

- Give the player a way to recover health that has to be earned by chasing.
- Add healing to `Health` and the player through small public APIs.
- Share one orb pickup and one drop component between both creatures.

## Behavior rules

### Health and healing

1. `Health.heal(amount)` restores up to `amount` without exceeding `maximum` and returns the health restored. It emits `healed(amount)` and `changed`. Full health, depleted health, and non-positive amounts restore nothing and emit nothing.
2. The player exposes `heal(amount)` and `can_heal()` (not full, not depleted).

### Health orb

3. A dropped orb falls with `PickupFallComponent` and cannot be collected while falling.
4. When it lands (or stops over a pit), it is **released**: it glows and can be collected.
5. A released orb is collected by a body in `player_group` that has `heal()` and can heal. It heals `heal_amount` (25 by default) once and frees itself. A player already standing on the spot collects it as it lands.
6. A player at full health leaves the orb where it is; it stays until the player can heal.

### Carrying and dropping

7. `HealthOrbDropOnDeath` spawns a `HealthOrb` at the carrier's hand when its health is depleted, hides the held orb, and adds the orb to the current scene (or `drop_parent`). It can override the heal amount.
8. Both creatures deal no contact damage and drop no Stardust.

### Life Moth

9. **Patrol:** flutters along a horizontal sine path of `patrol_distance` around its spot, with a vertical flutter.
10. **Flee:** when the player comes within `flee_radius` (200), it flies away horizontally with a slight upward lean at `flee_speed` (340, below the player's 400), staying within `max_height_offset` of its spot's height. Walls stop it.
11. **Calm:** once the player is farther than `calm_radius` (320), it patrols again around where it ended up, returning to its original height.
12. 10 HP (one Magic Arrow).

### Orb Roller

13. **Play:** shuffles slowly around its spot and tosses the orb in its hands.
14. **Flee:** when the player comes within `flee_radius` (200), it puts the orb on the ground ahead of it and runs away at its top speed (330), spinning the orb as it rolls. Walls corner it (`is_cornered()`), and it can run off ledges.
15. **Calm:** after the player has been farther than `calm_radius` (360) for `calm_delay` (1 s), it picks the orb up and plays where it stopped.
16. 20 HP (two Magic Arrows).

### Respawn

17. Both are placed under `EnemyRespawner`. Their spots are read on the first physics frame, after placement, and respawned creatures hold a new orb.

## Scene composition

```text
health/orb/HealthOrb.tscn (Area2D, HealthOrb, mask Entities)
├── AnimatedSprite2D   falling (1), released (2, glow) — 8×8, scale 3
├── CollisionShape2D
└── Fall               PickupFallComponent (currency/pickup)

LifeMoth (CharacterBody2D, floating, scale 3, layer 0, mask World)
├── AnimatedSprite2D   fly (4), hit (1)
├── HeldOrb            Sprite2D with the orb art (the hand)
├── CollisionShape2D
├── ThreatDetector     TargetDetector (radius = calm_radius)
├── Health             10
├── DestroyOnDeath
├── HealthOrbDropOnDeath (hand + held orb = HeldOrb)
└── AttackReceiver     + HealthDamageReaction

DungBeetle (CharacterBody2D, scale 3, layer 0, mask World + One-way)
├── AnimatedSprite2D   play (4), roll (4), hit (1)
├── Orb                Sprite2D with the orb art (held or rolled)
├── CollisionShape2D
├── HorizontalMovement max 330
├── Gravity
├── ThreatDetector     TargetDetector (radius = calm_radius)
├── Health             20
├── DestroyOnDeath
├── HealthOrbDropOnDeath (hand + held orb = Orb)
└── AttackReceiver     + HealthDamageReaction
```

`PickupFallComponent` now has a second consumer outside the currency feature. It is referenced in place; move it to `components/` when convenient.

## Component responsibilities

| Component | Responsibility |
| --- | --- |
| `Health` | Health state, now including `heal()`, `is_full()`, and `healed`. |
| `Player` | Narrow `heal()` / `can_heal()` capability for pickups. |
| `HealthOrb` | Falling, release on landing, collection, and freeing. |
| `HealthOrbDropOnDeath` | Spawning the orb at the hand on death and hiding the held orb. |
| `LifeMoth` | Patrol, flee, calm, flight, flutter, and presentation. |
| `DungBeetle` | Play, flee, calm, orb toss and roll presentation, and facing. |

## Public contracts

- `Health`: `heal(amount) -> float`, `is_full()`, signal `healed(amount)`.
- `Player`: `heal(amount) -> float`, `can_heal() -> bool`.
- `HealthOrb`: `heal_amount`, `is_released()`, `is_collected()`; signals `released`, `collected(target, restored)`.
- `HealthOrbDropOnDeath`: `health`, `hand`, `orb_scene`, `held_orb`, `heal_amount`, `drop_parent`; signal `dropped(orb)`.
- `LifeMoth`: `get_state()`, `get_threat()`, `get_home()`, `set_home(point)`; signal `state_changed(state)`.
- `DungBeetle`: `get_state()`, `get_threat()`, `get_facing()`, `get_home_x()`, `set_home_x(x)`, `is_cornered()`; signal `state_changed(state)`.

## Failure handling

- Missing health, hand, or orb scene on the drop component reports an error and drops nothing.
- An orb scene that does not create a `HealthOrb`, or no drop parent, reports an error and drops nothing.
- An orb without a fall component is released immediately.
- Bodies without `heal()` or outside the player group never collect orbs.

## Art replacement

| File | Frames | Use |
| --- | --- | --- |
| `health/orb/sprites/health_orb_8x8.png` | 2 | Frame 0: idle/falling and held. Frame 1: glow pulse once released. |
| `entities/enemies/life_moth/sprites/fly_16x16.png` | 4 (10 fps) | Wing flaps, facing right, hands free under the body. |
| `entities/enemies/life_moth/sprites/hit_16x16.png` | 1 | Damage flash. |
| `entities/enemies/dung_beetle/sprites/play_16x16.png` | 4 (6 fps) | Playing, arms up and down, facing right. |
| `entities/enemies/dung_beetle/sprites/roll_16x16.png` | 4 (12 fps) | Running behind the orb, facing right. |
| `entities/enemies/dung_beetle/sprites/hit_16x16.png` | 1 | Damage flash. |
| `.../sprites/portrait.png` | 1 | Monster guide portraits. |

The orb is drawn separately on both creatures (`HeldOrb`, `Orb`), so a new orb drawing updates the held, rolled, and dropped orb at once. Adjust `HeldOrb`'s position or the beetle's `held_orb_position` / `rolled_orb_position` to match new hands.

## Scope limits

- No jumping or pathfinding for the beetle; no obstacle avoidance for the moth.
- Orbs dropped by carriers are not saved; carriers respawn with the other enemies.

## Acceptance criteria

- `heal()` clamps to maximum, reports what it restored, and never revives.
- A dropped orb falls, releases on landing, heals 25 once, and stays while the player is at full health.
- The moth patrols, flees close players without exceeding its speed or height band, can be caught by a player at full speed with effort, and calms down where it fled to.
- The beetle plays and tosses the orb, flees rolling the orb ahead and spinning it, can be caught with effort, is cornered by walls, and calms down after a delay.
- Both drop their orb from their hands on death, respawn with their configuration, and appear in the monster guide.

## Testing

`tests/health_orb/`, `tests/life_moth/`, and `tests/dung_beetle/` cover the acceptance criteria. Manually verify that the chases feel catchable but tense in a level, and the art alignment of held and rolled orbs.
