# Feature Overview

When a Basic Skeleton dies, it drops **20 Stardust** split across **two pickups**, each worth **10 Stardust**. The pickups use the existing Stardust pickup scene and sprite (`currency/pickup/CoinPickup.tscn`) and behave like any other Stardust pickup: the player attracts and collects them, and the collected amount is added to `CoinManager`.

## Goals

- Reward enemy kills with Stardust using the existing currency pickup.
- Keep the drop as a focused death-reaction component composed into the enemy scene, next to `DestroyOnDeath`.
- Let one pickup carry more than one Stardust, so a drop is a few readable pickups instead of many overlapping ones.
- Keep drop counts and values configurable in the scene.

## Non-Goals

- Random drop amounts, drop tables, or item drops.
- Physics arcs, bouncing, or despawn timers for dropped pickups. Dropped pickups fall straight down onto the floor; see [020](020_stardust_gravity.md).
- New Stardust artwork, sounds, or a different pickup visual per value.
- Saving or persisting uncollected drops.
- Drops from the training Dummy or the player.

# Behavior Rules

## Drop

- The drop happens once, when the enemy's `Health` emits `depleted`.
- It spawns `pickup_count` pickups (default `2`), each with `amount_per_pickup` Stardust (default `10`). The default total is `20`.
- Pickups are spread horizontally around the enemy's global position at the moment of death, `pickup_spacing` pixels apart (default `28`) and centred on the enemy, with an optional `spawn_offset`.
- Pickups are created and positioned immediately, then added to their parent with a deferred `add_child`, because damage can arrive inside a physics callback. The deferred call belongs to the drop parent, not to the dying enemy, so freeing the enemy in the same frame cannot cancel it.
- Pickups are not children of the enemy or of `EnemyRespawner`. They stay in the world after the enemy is freed, and `EnemyRespawner.respawn_all()` does not remove or re-register them.
- An enemy recreated by `EnemyRespawner` drops again when it dies again.

## Pickup

- `CoinPickup.amount` (default `1`) is the Stardust value added on collection. Pickups already placed in levels keep a value of `1`.
- Only bodies in the `player` group attract or collect a pickup. World geometry and enemies are ignored, so a pickup that spawns on the floor or near another enemy is not consumed.
- Collection happens once: the pickup adds its amount, plays `collected`, and frees itself.
- Pickups fall to the floor while not attracted ([020](020_stardust_gravity.md)).

## Currency

- `CoinManager.add_coins(amount)` adds a positive amount and emits `coins_changed` once with the new total. Non-positive amounts are ignored without emitting.
- `CoinManager.add_coin()` remains available and adds `1`.

# Implementation Details

```text
BasicMob (CharacterBody2D)
├── Health
├── DestroyOnDeath
└── StardustDropOnDeath   (new)

CoinPickup (Area2D, spawned by the drop)
├── AnimatedSprite2D
├── CollisionShape2D
├── AttractionArea
└── Fall                  (PickupFallComponent, spec 020)
```

| Component | Responsibility |
| --- | --- |
| `Health` | Emit `depleted` once when the enemy dies. |
| `StardustDropOnDeath` | On `depleted`, capture the enemy position and spawn the configured pickups with their amounts. Owns no currency state. |
| `DestroyOnDeath` | Free the enemy. Unchanged. |
| `CoinPickup` | Move toward and be collected by the player, adding its `amount` to `CoinManager`. |
| `CoinManager` | Own the Stardust total and emit `coins_changed`. |

## StardustDropOnDeath

`currency/drop/stardust_drop_on_death.gd`, class name `StardustDropOnDeath`, extends `Node`.

```gdscript
signal dropped(pickups: Array[Node2D])

@export var health: Health
@export var source: Node2D
@export var pickup_scene: PackedScene
@export var drop_parent: Node
@export_range(1, 20) var pickup_count: int = 2
@export_range(1, 1000) var amount_per_pickup: int = 10
@export var pickup_spacing: float = 28.0
@export var spawn_offset: Vector2 = Vector2.ZERO
```

- `drop_parent` is optional. When it is not assigned, pickups are added to the current scene, falling back to the parent of the source's scene root when there is no current scene (for example, in tests). The source may be a child of the enemy, such as the Platform Crawler's `Body`.
- Missing `health`, `source`, or `pickup_scene` is reported with `push_error` and the component does nothing.
- If `pickup_scene` does not create a `CoinPickup`, the instance is freed and an error is reported.
- `dropped` is emitted when the pickups are created, before their deferred addition to the tree.

# Failure Handling

- An unconfigured component never crashes the enemy's death; `DestroyOnDeath` still frees it.
- A freed drop parent at drop time falls back to the default parent.
- If the attracting player is freed, the pickup stops being attracted, falls back to the floor, and remains collectable.

# Implementation Plan

1. Add `CoinManager.add_coins(amount)`.
2. Add `amount` and player-only filtering to `CoinPickup`.
3. Add `StardustDropOnDeath` under `currency/drop/`.
4. Compose it into `BasicSkeleton.tscn` with `CoinPickup.tscn`, 2 pickups × 10.
5. Add the `stardust_drop` test suite.
6. Manually verify the pickups' placement, attraction, and the HUD total after killing a skeleton.

# Testing

- Depleting a skeleton's `Health` spawns exactly two `CoinPickup` nodes worth 10 each, outside the enemy.
- The pickups remain valid after the enemy is freed.
- Collecting both pickups with the player raises `CoinManager.coins` by 20.
- A pickup ignores a non-player body.
- `add_coins` ignores non-positive amounts and emits once per accepted amount.

# Acceptance Criteria

1. Killing a Basic Skeleton drops two Stardust pickups using the current Stardust sprite.
2. Each pickup adds 10 Stardust; both together add 20.
3. The pickups appear at the skeleton's death position and stay after it disappears.
4. Floor contact or enemies do not collect or attract the pickups; only the player does.
5. Existing level Stardust pickups still add 1 each.
6. Respawned skeletons drop Stardust again when killed.
