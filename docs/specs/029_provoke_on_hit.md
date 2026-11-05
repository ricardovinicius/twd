# 029 — Provoke on hit

## Overview

Enemies used to react only to a player inside their detection areas. A player could hit them from afar (Magic Arrow, Burn) without them reacting. Now, when an attack from the player lands, the enemy treats the attacker as detected for a while, wherever they are, and reacts as if it had seen them: chasing, charging, screaming, shooting, or fleeing, depending on the enemy.

## Behavior rules

1. **Provocation.** `TargetDetector.provoke(target, duration)` makes the target count as detected (`has_target`, `get_targets`, `target_entered`) for `duration` seconds, inside or outside the area. Provoking again refreshes the time without announcing the target again.
2. **End.** When the provocation ends, the target is announced as exited unless it is inside the area. A target that leaves the area while provoked stays detected until the provocation ends.
3. **On hit.** `ProvokeOnHitReaction`, under an enemy's `AttackReceiver`, provokes the attacker on the enemy's detectors for `duration` (8 s by default). The attacker is the attack's source, or its first ancestor, in `target_group` (`player`). Attacks from other sources do not provoke. Damage is still applied by the other reactions.
4. **Sight checks.** A provoked target bypasses the extra sight checks enemies use on top of their detectors:
   - Flying Eye: line of sight;
   - Star Man: vision distance and line of sight (he screams, then rolls);
   - Platform Crawler: front cone and line of sight (it charges);
   - Life Moth and Orb Roller: a provoked attacker counts as being right next to them (they flee and do not calm down while provoked).
   The skeleton and the Scorpion Man rely on their aggro detector only and react directly.
5. **Homunculus Couple.** They already wake up and chase whoever hurts them (spec 024), so they have no provoke reaction.
6. **Calming down.** Once the provocation ends, an enemy whose detector no longer contains the player behaves as before (for example, the skeleton goes idle).

## Scene composition

Each enemy scene has, under its `AttackReceiver`:

```text
ProvokeOnHitReaction (detectors = [the enemy's TargetDetector])
```

| Enemy | Detector |
| --- | --- |
| BasicSkeleton | `AggroDetector` |
| PlatformCrawler | `Body/Vision` |
| FlyingEye | `AggroDetector` |
| LifeMoth, DungBeetle | `ThreatDetector` |
| StarMan | `Vision` |
| ScorpionMan | `AggroDetector` |

## Public contracts

- `TargetDetector`: `provoke(target, duration)`, `is_provoked(target)`; `has_target` and `get_targets` include provoked targets.
- `ProvokeOnHitReaction`: `detectors`, `duration`, `target_group`, `find_attacker(attack)`; signal `provoked(attacker)`.

## Failure handling

- A reaction without detectors reports an error and never handles attacks.
- Freed provoked targets are dropped silently.

## Acceptance criteria

- Detector provocation, refresh, expiry, and leaving-while-provoked behave as above.
- Non-player attacks never provoke.
- Every enemy with detectors is wired; each one reacts to a far (or hidden, or behind) attacker; the skeleton gives up after the provocation when the player is out of range.
- A real Magic Arrow fired from outside the detection radius provokes the enemy.

## Testing

`tests/provoke/`.
