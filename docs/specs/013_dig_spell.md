# Dig Spell ("Cavar")

## Feature Overview

Dig is an Action Spell that breaks the yellow diggable blocks placed in the level. The player enters **J + K** (`attack` + `interaction` tokens) and confirms with **I** (`cast_confirm_token`). A diggable block in the area in front of the player, in the aimed direction, breaks with a single cast.

## Behavior Rules

- Sequence: `[&"attack", &"interaction"]`. It does not collide with Magic Arrow (`attack`), Push (`interaction`), Dash (`move`) or Double Jump (`move + interaction`).
- The effect area points toward the aim direction (W/S or the stick) and falls back to the facing direction, so the player can dig sideways, up or down.
- Each dig dispatches one `ActionData` with `type = &"dig"` and `strength = dig_strength` (default `1.0`) to every `ActionReceiver` in the area.
- A diggable block has `Health.maximum = 1.0`, so one dig breaks it. `DestroyOnDeath` frees the block.
- Push and other actions are ignored by diggable blocks. Magic Arrow treats the block as a world obstacle and does not break it.
- Casting with no block in range has no effect and completes normally.

## Scene Composition

```
DiggableBlock (StaticBody2D, layer World, scale 3)
├── Sprite2D (destructive_block_2.png, region 32x32)
├── CollisionShape2D (32x32)
├── Health (maximum = 1)
├── DestroyOnDeath (health = Health, target = DiggableBlock)
└── ActionReceiver (Area2D, layer Action Receivers)
    ├── CollisionShape2D (32x32)
    └── DigReaction (health = Health)
```

`DigSpell.tscn` is an `ActionSpell` with an `EffectQuery` ShapeCast2D (circle radius 12, target `(24, 0)`, mask Action Receivers), as Push does.

## Component Responsibilities

| Component | Responsibility |
| --- | --- |
| `DigSpell` | Creates `dig` action data aimed with the player's aim input. |
| `ActionSpell` | Queries receivers and dispatches actions; `_get_effect_direction()` lets a subclass choose the query direction (Push keeps the facing direction). |
| `DigReaction` | Accepts `dig` actions with positive strength and applies them to `Health`. |
| `Health` / `DestroyOnDeath` | Own block durability and removal. |

## Failure Handling

- Missing `Health` on `DigReaction` logs a configuration error and the reaction ignores actions.
- Depleted blocks ignore further digs, so overlapping receivers cannot double-trigger.

## Scope Limits

- Blocks are scene instances, not painted tiles. Level 01's yellow tiles (`TileMapPrincipal1` source 4 and the whole `TileMapPrincipal2`) were replaced by six `DiggableBlock` instances; `DiggableBlock5` overrides its sprite region to show the lower block art. `DiggableBlock6` (−479, 5472) replaced four yellow tiles painted back into `TileMapPrincipal1` later, which looked diggable but were not. New diggable blocks are placed by instancing `DiggableBlock.tscn`.
- No break animation, sound or particles yet.

## Acceptance Criteria

- J + K, then I, with a yellow block in front breaks it in one cast.
- Push does not break the block; Magic Arrow stops on it.
- The spell is catalogued in the spell database and unlocked by buying it at a checkpoint (see `014_spell_shop.md`).
- Automated coverage: `tests/dig/`.
