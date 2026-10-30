# 028 — Burn spell and burning status

## Overview

**Burn** is an attack spell cast with **J + J** (then confirm). It fires a fireball like Magic Arrow, deals fire damage to the first enemy it hits, and sets that enemy on fire: the enemy keeps taking damage for a few seconds, flickering orange with small flames on it. Art is placeholder, very low fidelity.

## Behavior rules

1. **Definition.** `burn` in `SpellDatabase`: sequence `[attack, attack]`, cooldown 2.5 s, icon `spells/attack/burn/sprites/burn_icon.png`. As a two-token spell it is sold in the checkpoint shop like the other multi-token spells, and must be owned (registered) before J + J casts it. The pause menu's Spell Registry debug window can register it for testing.
2. **Projectile.** `BurnSpell` (a `MagicArrowSpell`) launches `FireballProjectile` in the aimed direction at 800 px/s for 0.6 s. It reuses the Magic Arrow projectile behavior: passes through walls and stops on the first enemy Attack Receiver.
3. **Hit.** The attack has `attack_type = &"burn"`, `damage_type = &"fire"`, 15 damage, and a `BurnEffect` (3 s, a tick every 0.5 s, 4 damage per tick).
4. **Burning.** An enemy's `BurnStatusReaction` handles attacks carrying a `BurnEffect`:
   - it ignites the enemy, damaging its `Health` on every tick (6 ticks, 24 damage by default);
   - it flickers the enemy's visual orange (`self_modulate`) and adds animated flames to it;
   - when the duration ends the flames and the flicker go away.
5. **No stacking.** A new burn while burning refreshes the duration (and uses the new effect's values) without starting a second tick timer.
6. **Death.** A depleted health stops the burn.
7. **Blocking.** Setting `blocked` puts out an active burn and rejects new ones. The Star Man blocks burning while he rolls (rolling smothers the flames), matching his roll invulnerability.
8. **Other attacks.** Attacks without a `BurnEffect` never ignite. Unsupported effects are ignored.

## Data contracts

- `AttackData` gains `damage_type: StringName` (default `&"physical"`) and `effects: Array[RefCounted]`.
- `BurnEffect` (`components/attack_reactions/burn/`): `duration`, `tick_interval`, `tick_damage`, `static find_in(attack) -> BurnEffect`.

## Scene composition

```text
spells/attack/burn/
├── burn_definition.tres    SpellDefinition (J + J)
├── BurnSpell.tscn          BurnSpell → FireballProjectile.tscn
├── FireballProjectile.tscn MagicArrowProjectile script, fireball art (12×12, 2 frames)
└── sprites/                fireball_12x12.png, burn_icon.png

components/attack_reactions/burn/
├── burn_effect.gd
├── burn_status_reaction.gd
└── sprites/flames_8x8.png  (2 frames)

Every enemy: AttackReceiver
└── BurnStatusReaction (health, visual)
```

`BurnStatusReaction` lives in shared `components/` because every enemy feature uses it. It was added to the skeleton, platform crawler, dummy, flying eye, homunculi, life moth, orb roller, Star Man, and Scorpion Man.

## Public contracts

- `BurnSpell`: `burn_duration`, `burn_tick_interval`, `burn_tick_damage` (plus Magic Arrow's `speed`, `lifetime`, `damage`).
- `BurnStatusReaction`: `health`, `visual`, `flame_offset`, `burn_color`, `blocked`, `ignite(effect)`, `extinguish()`, `is_burning()`, `get_time_left()`; signals `burn_started`, `burn_ticked(damage)`, `burn_ended`.

## Scope limits

- No fire resistances or weaknesses yet; `damage_type` is recorded for them.
- The player cannot be set on fire.
- Burning does not spread between enemies.

## Acceptance criteria

- Burn is catalogued with J + J, sold in the shop, and casts only once registered.
- The fireball deals 15 on hit and ignites the enemy; burning ticks 6 × 4 and then goes out with flames and flicker removed.
- Re-igniting refreshes without stacking; plain attacks never ignite.
- Every enemy scene has a wired `BurnStatusReaction`; the rolling Star Man cannot burn.

## Testing

`tests/burn/`. Manually verify the flame position on each enemy (adjust `flame_offset`) and the fireball's look in motion.
