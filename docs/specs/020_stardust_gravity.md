# Feature Overview

Stardust pickups (`currency/pickup/CoinPickup.tscn`) have a little gravity. A pickup in the air falls until it lands on world collision (physics layer 1) and stays there. This includes the pickups that `StardustDropOnDeath` drops when an enemy dies (see [011](011_enemy_stardust_drop.md)), so drops no longer float at the enemy's centre. Attraction toward the player and player-only collection keep working.

## Goals

- Make Stardust read as a physical object that settles on the floor.
- Keep the fall in a focused component composed into the pickup scene.
- Keep attraction, collection, `CoinManager`, and the save's collected-pickup tracking unchanged.

## Non-Goals

- Bouncing, rolling, sliding on slopes, or horizontal scatter velocity.
- Landing on one-way platforms (layer 2) or on props, enemies, or the player.
- Turning the pickup into a physics body.
- Despawn timers for pickups that fall into a pit.

# Behavior Rules

## Falling

- A pickup that is not being attracted falls with `gravity` (default `900` px/s²), capped at `max_fall_speed` (default `600` px/s).
- Every physics tick a ray from the pickup's origin, `rest_height + step` long, looks for the floor on `floor_mask` (default layer 1, World). Areas are ignored.
- On a hit, the pickup is placed `rest_height` (default `12` px, half of the 24 px sprite) above the hit point, stops, and emits `landed` once.
- A pickup whose origin starts inside world collision stays where it is and stops; it is never pushed through or out of the floor.
- A pickup that falls `max_fall_distance` (default `4000` px) without finding a floor stops in place, so pickups over a pit do not process forever.
- Pickups placed in levels fall too. A pickup already resting on the floor settles on the first tick.

## Attraction and collection

- When the player enters `AttractionArea`, the fall is suspended and the pickup moves toward the player as before. Gravity never pulls an attracted pickup away from the player.
- If the attracting player is freed, attraction stops and the fall resumes from the current position, landing on the floor below.
- Collection is unchanged: only bodies in the `player` group collect, once, adding `amount` to `CoinManager` and calling `SaveGame.mark_collected`.

## Persistence

- `PersistentPickup` identifies level pickups by scene path, not position, so falling does not change a pickup's save id. Runtime drops stay non-persistent.

# Scene Composition

```text
CoinPickup (Area2D, coin_pickup.gd)     fall -> Fall
├── AnimatedSprite2D
├── CollisionShape2D
├── AttractionArea (Area2D)
│   └── CollisionShape2D
└── Fall (Node, PickupFallComponent)    body -> ..
```

| Component | Responsibility |
| --- | --- |
| `PickupFallComponent` (`currency/pickup/pickup_fall_component.gd`) | Owns fall speed, floor detection, resting state, and suspension. Moves its `body`; knows nothing about currency. |
| `CoinPickup` | Coordinates attraction and collection; suspends the fall while attracted and resumes it when the player is gone. |
| `StardustDropOnDeath` | Unchanged; its pickups fall because the scene composes `Fall`. |

# Public Contracts

```gdscript
class_name PickupFallComponent
extends Node

signal landed

@export var body: Node2D
@export var gravity: float = 900.0
@export var max_fall_speed: float = 600.0
@export var rest_height: float = 12.0
@export_flags_2d_physics var floor_mask: int = 1
@export var max_fall_distance: float = 4000.0

func set_suspended(suspended: bool) -> void
func is_falling() -> bool
func is_resting() -> bool
```

- `set_suspended(true)` stops falling and clears the fall speed. `set_suspended(false)` starts a new fall from the current position. Repeating the current value does nothing.
- `CoinPickup.fall` is optional. Without it, the pickup floats in place like before.

# Failure Handling

- A missing `body` is reported with `push_error` and the component stays idle.
- A freed attracting player resumes the fall instead of leaving the pickup in mid-air.

# Implementation Plan

1. Add `PickupFallComponent` under `currency/pickup/`.
2. Compose it into `CoinPickup.tscn` and wire `CoinPickup.fall`.
3. Suspend/resume the fall from `CoinPickup` attraction.
4. Add the `stardust_gravity` test suite.
5. Manually check drops landing on Level 01 floors and slopes.

# Testing

`tests/stardust_gravity/`:

- The scene composes the fall component on layer 1 with positive gravity.
- A pickup above a layer-1 floor falls and rests `rest_height` above it, stays there, and emits `landed` once.
- A pickup falls through a body on a non-world layer.
- A pickup that starts inside the floor does not move.
- Attraction suspends the fall; freeing the player resumes it and the pickup lands.
- A falling pickup is still collected exactly once and stays non-persistent.
- A skeleton's two drops land on the floor and keep their amounts.

# Acceptance Criteria

1. Stardust dropped by an enemy falls to the floor and stays there.
2. Level Stardust in the air falls to the floor below it.
3. Pickups do not fall through world collision and do not land on enemies or the player.
4. The player still attracts and collects pickups; only the player collects.
5. Collected level pickups are still remembered by the save.
