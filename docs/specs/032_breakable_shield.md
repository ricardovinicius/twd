# 032 Breakable Shield

## Overview

A shield that has to be broken with a burst of damage before a character's health can be hurt. Dealing the shield's `maximum` damage within `break_window` seconds (2 s) of the first hit breaks it. While it is broken, attacks hit health directly. After `regen_delay` seconds (4 s) without being hit, it comes back at full strength. Any character with a `Health` can use it (enemies now, the player later); only Big Head has one for now.

## Behavior rules

1. **Intact.** All damage that reaches `Health.take_damage()` (spells, projectiles, burning, contact) goes to the shield first. Health takes nothing while the shield holds.
2. **Break window.** The first hit on a full shield starts the window. If the shield's `current` reaches 0 before the window ends, it breaks. If the window runs out first, the shield snaps back to full and the next hit starts a new window.
3. **Overflow.** The hit that breaks the shield passes its leftover damage on to health (40-point shield, two 25-point arrows: the second arrow deals 10 to health).
4. **Broken.** Hits go straight to health. Every hit restarts the regeneration delay, so keeping up the pressure keeps the shield down.
5. **Regeneration.** After `regen_delay` without hits, the shield returns to full (`restored`).
6. **Break spell.** A `break` attack (the Break spell, J + L, see `033_break_spell.md`) shatters the shield at once through a `ShieldBreakReaction` on the character's AttackReceiver. It deals no damage and is ignored by a shield that is already broken; regeneration then works as after any break.
7. **Reset.** `Health.reset()` (respawn, checkpoint rest) also restores the shield.
8. **Equipment shield.** Health's existing equipment shield (`shield_maximum`, `set_shield_maximum`) is unchanged. It absorbs damage that gets past the breakable shield.

## Components

| Component | Responsibility |
| --- | --- |
| `BreakableShield` (`health/shield/breakable_shield.gd`) | Owns shield strength, break window and regeneration. `absorb(amount)` returns the damage that passes through. Signals: `changed`, `hit(absorbed)`, `broken`, `restored`. |
| `Health` | Optional exported `breakable_shield`; routes damage through it in `take_damage()` and resets it in `reset()`. |
| `ShieldBreakReaction` (`components/attack_reactions/shield_break/`) | Under an AttackReceiver: shatters the assigned shield when a `break` attack lands (`BreakableShield.shatter()`). |
| `ShieldVisual` (`health/shield/shield_visual.gd`) | Placeholder look: translucent bubble that fades as the shield drains, a bar during a break attempt, a burst when it breaks, nothing while broken. |

## Adding it to a character

1. Add a `BreakableShield` node (set `maximum`, `break_window`, `regen_delay`).
2. Assign it to the character's `Health.breakable_shield`.
3. Add a `ShieldBreakReaction` under its AttackReceiver with `shield` assigned, so the Break spell works on it.
4. Optionally add a `ShieldVisual` with `shield` assigned and `size` matching the character.

For the player, the HUD does not show the breakable shield yet.

## Scope limits

Placeholder visuals only; no sound. Damage while `Health` is invulnerable is ignored before it reaches the shield.

## Acceptance criteria

Covered by `tests/breakable_shield/` and, for Big Head, `tests/big_head/`.
