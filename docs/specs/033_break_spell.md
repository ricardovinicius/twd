# 033 Break Spell

## Overview

Break shatters shields. The player enters **J + L** (`attack` + `move`) and confirms. A small blue shard flies in the aimed direction like Magic Arrow. It deals no damage: the first enemy it hits loses its `BreakableShield` at once, whatever the shield's strength, so its health is open to the next attacks.

## Behavior rules

1. **Definition.** `break` in `SpellDatabase`: sequence `[attack, move]`, cooldown 3 s, icon `spells/attack/break/sprites/break_icon.png`. As a two-token spell it is sold in the checkpoint shop and must be bought before it can be cast.
2. **Projectile.** `BreakSpell` (a `MagicArrowSpell`) launches `BreakProjectile` (8x8 shard, scale 3) at 900 px/s for 0.5 s. It reuses the Magic Arrow projectile: it stops at walls and on the first enemy Attack Receiver.
3. **Hit.** The attack has `attack_type = &"break"` and 0 damage. A `ShieldBreakReaction` under the target's AttackReceiver calls `BreakableShield.shatter()`; the shield's normal regeneration (4 s without hits) follows.
4. **No shield.** Enemies without a `ShieldBreakReaction`, or whose shield is already broken, take nothing (the hit can still provoke them).

## Components

| Component | Responsibility |
| --- | --- |
| `BreakSpell` | Creates the zero-damage `break` attack. |
| `BreakProjectile.tscn` | Shard visuals and collision; script shared with Magic Arrow. |
| `ShieldBreakReaction` | Shatters its shield when a `break` attack lands. |
| `BreakableShield.shatter()` | Breaks the shield immediately; returns false when already broken. |

## Acceptance criteria

Covered by `tests/break_spell/`.
