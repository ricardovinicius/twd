# 031 Big Head

## Overview

Big Head is a giant head on a tiny body that is exactly as tall as a corridor (two blocks, 96 px). It sleeps in the passage and blocks it. A hit wakes it up startled; it never fights back and dozes off again after a while. Defeating it clears the passage. This MVP uses a placeholder sprite: a grey block with two eyes (closed while asleep, open while awake) and a yellow "!" when hit.

## Behavior rules

1. **Blocking.** `BigHead` is a `StaticBody2D` on the Entities layer (4), so the player (mask World + One-way + Entities) cannot walk, jump or dash through it. It is not on the World layer, so projectiles do not treat it as a wall and hit its Attack Receiver.
2. **Sleeping.** It starts asleep (`sleep` animation, closed eyes).
3. **Waking.** Any damage wakes it: the `awake` animation (open eyes) plays and the `Alert` "!" shows for `alert_duration` (0.8 s). Every hit refreshes both timers. `woke_up` is emitted once per wake.
4. **Dozing off.** After `sleep_delay` (4 s) without hits it falls asleep again (`fell_asleep`).
5. **Harmless.** No contact damage and no attacks.
6. **Shield.** A `BreakableShield` guards its health (see `032_breakable_shield.md`): 50 damage within 1 s breaks it, which spells alone cannot reach yet, so the Break spell (J + L) is the way through: it shatters the shield at once (`ShieldBreakReaction`). Until then hits only drain the shield, which refills when the window runs out. Broken, hits go to health; after 4 s without hits it comes back full. `ShieldVisual` draws a blue bubble with a bar above it. Hits on the shield wake it up too.
7. **Death.** 60 HP. When depleted it is freed (`DestroyOnDeath`), clearing the passage, and drops 2 Stardust pickups of 15 (`StardustDropOnDeath`).
8. **Fire.** It can burn like every other enemy (`BurnStatusReaction`).
9. **Respawn.** Place it under an `EnemyRespawner`; it comes back asleep at the same spot.

## Scene composition

```
BigHead (StaticBody2D, BigHead, scale 3, layer Entities, mask none)
├── AnimatedSprite2D (sleep / awake, 16x32 frames from sprites/big_head_16x32.png)
├── Alert (Sprite2D, "!" frame, hidden)
├── CollisionShape2D (16x32 → 48x96 in the world)
├── BreakableShield (maximum 50, window 1 s, regen 4 s: the script defaults)
├── ShieldVisual (bubble 20x36, shield = BreakableShield)
├── Health (maximum 60, breakable_shield = BreakableShield)
├── DestroyOnDeath
├── StardustDropOnDeath (2 × 15)
└── AttackReceiver (Area2D, layer Attack Receivers)
    ├── CollisionShape2D (16x32)
    ├── HealthDamageReaction
    ├── BurnStatusReaction
    └── ShieldBreakReaction (shield = BreakableShield)
```

## Placement

Instance `BigHead.tscn` under Level 01's `EnemyRespawner` in a corridor two blocks tall. Its origin is its center, so place it one block above the corridor floor's surface (48 px), centered in the corridor.

## Scope limits

Placeholder art only. No provoke reaction (it has no detectors and never chases), no hit flash, no sound.

## Acceptance criteria

Covered by `tests/big_head/`: two blocks tall, blocks the player but not projectiles, sleeps until hit, wakes with the alert, falls asleep again, dies and drops Stardust, respawns, and appears in the monster guide. `tests/burn/` includes it in the burnable enemies.
