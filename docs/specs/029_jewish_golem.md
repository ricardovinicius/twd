# 029 — Jewish Golem (boss)

## Overview

The golem of the old legends: a giant of clay brought to life by the rune (the *shem*) in his chest. He is almost twice the player's height, walks slowly, and is the first boss. He lobs lumps of clay that rise as small clay monsters, now and then raises a clay version of the Flying Eye or the Homunculus (never more than two on screen), and hides behind breakable blocks, the same diggable blocks spread across the map. When defeated, the rune slips out of his chest and he falls asleep on his knees; he stays that way for the rest of the game. Placeholder art is low fidelity (64×64 frames, scaled 3×) and will be replaced.

## Behavior rules

1. **Dormant.** He stands still until a player enters `AggroDetector` (720 px). Then he chases the player at 60 px/s and stops within 80% of `slam_range`.
2. **Attack choice.** `choose_attack(offset)` returns, once the pause after the previous attack (`attack_cooldown`, 0.9 s) is over, the first that applies:
   - `SLAM` when the player is within `slam_range` (150) horizontally and `slam_height` (170) vertically;
   - `SHIELD` when `shield_cooldown` (8 s) is over, none of his blocks are standing, and he has lost at least 10% of his health (`shield_health_ratio` 0.9);
   - `SUMMON` when `summon_cooldown` (14 s) is over and the summoner has room for every summon slot;
   - `CLAY_SHOT` when `clay_shot_cooldown` (2.6 s) is over;
   - `NONE` otherwise: he walks closer.
   Cooldowns start when the attack starts. The first throw waits 1.2 s and the first summon 6 s after he spawns. Since minions are capped, most of the fight is clay throws and walls. `attack_chosen(attack)` is emitted when an attack starts.
3. **Slam (close).** He raises both fists for 0.85 s and smashes the ground in front of him: one hit of 30. `MeleeAttackComponent`.
4. **Clay shot.** He holds a lump of clay up for 0.7 s, then lobs a `ClayBall` in an arc that passes through the player's position (gravity 1400, flight time from the horizontal distance at 520 px/s, clamped to 0.45–1.4 s). A ball that hits the player deals 20 and splatters. A ball that lands on world geometry (floor, wall, or one of his blocks) asks the summoner to raise a minion there. Other enemies are ignored.
5. **Summon.** He raises his arms for 0.9 s, pours clay, and one minion rises at `summon_offsets` (mirrored to his facing), beside him on the ground.
6. **Minions.** `ClayMinionSummoner` uses its scenes in turn: `ClayHomunculus`, then `ClayFlyingEye`. At most `max_alive` (2) exist at once, counting both summoned minions and balls that became minions; extra requests are rejected, so a ball that lands while two minions live just splatters, and he does not choose the summon. The clay homunculus is told to chase the golem's target; the clay eye finds the player with its own sight. Minions are clay-shaded versions of the originals (shader `clay.gdshader`), with 15 HP, weaker hits, and no Stardust drop. Killed by the player, each has a 35% chance (`HealthOrbDropOnDeath.drop_chance`) to drop a health orb; minions that crumble when the golem falls drop nothing. The clay homunculus collides only with the world (mask World + One-way), so it never stands on the player's or the golem's head; it hurts through its contact area.
7. **Shield.** He lifts his arms for 0.8 s, presses his palms to the ground, and `ShieldBlockSpawner` raises `ClayShieldBlock`s in four slots: two stacked on each side of him. A slot occupied by world geometry, the player, or a standing block is skipped. A `ClayShieldBlock` is the map's `DiggableBlock` plus an `AttackReceiver` with a `ShieldAbsorbReaction`: player projectiles (Magic Arrow, fireball) stop on the first attack receiver they touch, so the wall catches them and he takes no damage through it. Attacks never break the blocks. One Dig cast on either block of a side breaks both blocks of that column (`break_column`), opening that side; the other side stays. Shots from above the walls still reach him.
8. **Enrage.** At half health (`enrage_health_ratio`) he is enraged once (`enraged` signal): cooldowns are multiplied by 0.65 and each throw lobs two balls, 110 px apart around the player.
9. **No interruption.** Damage only flashes the sprite; attacks continue.
10. **Contact.** Touching him deals 15 with strong knockback.
11. **Defeat.** At 0 HP (750 HP total) he stops, cancels his attack, and every minion and block he made crumbles. He stops hurting on contact, ignores attacks, and stops burning. The rune floats up out of his chest (70 px over 1.6 s) and fades while he sinks to his knees, ending asleep (`defeat` frame 2). `defeated` is emitted once. He drops 10 × 25 Stardust and stays in the room as a sleeping statue.
12. **Remembered.** The defeat is recorded with `SaveGame.mark_boss_defeated(boss_id)`. A golem whose `boss_id` is already defeated appears asleep on his knees on his first physics frame, without the rune, attacks, or drops. Like level pickups, a defeat is kept once the player rests at a checkpoint (saves) and forgotten when the game restarts without saving.

## Scene composition

```text
JewishGolem (CharacterBody2D, JewishGolem, scale 3, layer Entities, mask World + One-way)
├── AnimatedSprite2D     idle (2), walk (4), slam (3), throw (2), summon (2), shield (2), defeat (3)
├── Rune                 Sprite2D, hidden until defeat
├── CollisionShape2D
├── HorizontalMovement   max 60
├── Gravity
├── Summons              Node: balls, minions, and blocks he creates (freed with him)
├── Slam                 MeleeAttackComponent + Hitbox (ground in front)
├── ClayShot             ClayShotComponent → ClayBall.tscn, Summoner, Summons
├── Summoner             ClayMinionSummoner [ClayHomunculus, ClayFlyingEye], max 2 → Summons
├── ShieldSpawner        ShieldBlockSpawner → shield_block/ClayShieldBlock.tscn, Summons
├── AggroDetector        TargetDetector
├── ContactImpact
├── Health               750
├── StardustDropOnDeath  10 × 25
└── AttackReceiver       + HealthDamageReaction + BurnStatusReaction
```

`Summons` is a plain `Node`, so what it holds keeps its own world position instead of following the golem, and goes away with him when the respawner recreates him.

## Component responsibilities

| Component | Responsibility |
| --- | --- |
| `JewishGolem` | Target, attack choice, cooldowns, enrage, the timed summon and shield attacks, presentation, defeat sequence, and reading/writing his defeat in `SaveGame`. |
| `MeleeAttackComponent` | The slam. New `cancel_attack()` stops a swing without landing it. |
| `ClayShotComponent` | Wind-up, throwing one or more balls at the target, and forwarding landings to the summoner. |
| `ClayBall` | Ballistic flight, damaging the player, and reporting where it landed. |
| `ClayMinionSummoner` | Minion scenes in turn, the alive cap, deferred entry into the tree, pointing ground minions at the target, and crumbling them all. |
| `ShieldBlockSpawner` | Free-slot checks, raising shield blocks, breaking a whole column when one block breaks, and removing them. |
| `ClayShieldBlock` / `ShieldAbsorbReaction` | A diggable block that also catches player attacks without effect. |
| `SaveGame` | Defeated boss ids (`mark_boss_defeated`, `is_boss_defeated`), saved under `world/defeated_bosses`. |
| `StardustDropOnDeath` | `pickup_count = 0` now means no drop (used by the minions). |
| `HealthOrbDropOnDeath` | New `drop_chance` (default 1 = always, as before); the clay minions use 0.35. |

## Public contracts

- `JewishGolem`: `get_state()`, `get_target()`, `get_current_attack()`, `choose_attack(offset)`, `is_enraged()`, `is_defeated()`, `facing_direction`, `boss_id`; signals `state_changed(state)`, `attack_chosen(attack)`, `enraged`, `defeated`.
- `ClayShotComponent`: `begin_attack(target) -> bool`, `cancel_attack()`, `is_attacking()`, `has_thrown()`, `shots`; signals `attack_started(target)`, `ball_thrown(ball)`, `attack_finished`.
- `ClayBall`: `launch(origin, target_point, attack, horizontal_speed, gravity, lifetime, target_group, flight_time_bounds)`; signal `landed(point)`.
- `ClayMinionSummoner`: `summon_at(point, target) -> Node2D` (null at the cap), `can_summon(count)`, `get_alive_count()`, `get_minions()`, `clear()`; signal `minion_summoned(minion)`.
- `ShieldBlockSpawner`: `raise_blocks() -> int`, `break_column(block)`, `is_slot_free(center)`, `get_alive_count()`, `get_blocks()`, `clear()`; signal `blocks_raised(blocks)`.

## Failure handling

- Missing scenes, containers, or anchors report a configuration error and the component rejects its requests.
- A ball whose target is gone still flies and lands; a summon request for a freed target raises a minion that simply has no one to chase.
- A golem freed mid-fight takes its balls, minions, and blocks with it.

## Placement

Instance `JewishGolem.tscn` under the level's `EnemyRespawner`, on the floor of a room large enough for the block walls (about 300 px wide around him). Give each placed boss a unique `boss_id`. The player needs the Dig spell to break the blocks; place the fight after Dig can be obtained. Jumping onto the blocks also works.

## Art replacement

Sprites in `entities/enemies/jewish_golem/sprites/`, 64×64 frames facing right; the body is about 52 px tall (the player is about 27):

| File | Frames | Use |
| --- | --- | --- |
| `idle_64x64.png` | 2 | Breathing. |
| `walk_64x64.png` | 4 | Heavy steps. |
| `slam_64x64.png` | 3 | 0: fists raised. 1: fists on the ground in front (strike, recovery). 2: spare/recover. |
| `throw_64x64.png` | 2 | 0: clay held up behind. 1: arm forward after the throw. |
| `summon_64x64.png` | 2 | 0: arms raised. 1: clay pouring to both sides. |
| `shield_64x64.png` | 2 | 0: arms raised. 1: palms on the ground. |
| `defeat_64x64.png` | 3 | 0: stagger, rune still in the chest. 1: kneeling, empty chest. 2: asleep on his knees, head bowed. |
| `rune_10x12.png` | 1 | The rune that leaves his chest. |
| `portrait.png` | 1 | Monster guide (32×32). |

`clay_ball/sprites/clay_ball_8x8.png` has 2 frames.

## Scope limits

- No boss health bar, arena doors, or music yet.
- He is not placed in a level yet.
- No crumble animation for minions and blocks; they disappear.

## Acceptance criteria

- He waits until the player comes near, then walks slowly toward them.
- Close: he raises his fists, then slams once.
- He throws clay in a readable arc; a ball that hits the player hurts once, a ball that lands raises a clay minion.
- He raises a clay homunculus or a clay eye now and then; never more than two minions are on screen, and while two live, landing balls only splatter.
- Minions killed by the player sometimes drop a health orb.
- Once hurt, he raises breakable blocks on both sides, never where the player stands.
- Arrows and fireballs fired at a wall do not hurt him and do not break it.
- One Dig on a wall breaks both blocks of that side; then attacks from that side hit him.
- Below half health he attacks more often and throws two balls.
- Damage does not interrupt him.
- At 0 HP the rune leaves his chest, everything he made crumbles, he drops Stardust, and he ends asleep on his knees, harmless.
- After resting at a checkpoint, dying, or reloading the save, he stays asleep.
- Monster guide entry exists.

## Testing

`tests/jewish_golem/`. Manually verify the readability of the wind-ups, the ball arc against the real player, the block walls against the room geometry, and the rune animation.
