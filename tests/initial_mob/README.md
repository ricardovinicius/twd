# Initial mob tests

Run all suites headlessly from the project root:

```bash
tests/initial_mob/run_tests.sh
```

Set `GODOT_BIN` if the Godot executable has a different name or path. Test logs and isolated Godot user data are written under `${TMPDIR:-/tmp}/twd-initial-mob-tests`.

## Spec coverage

| Suite | Acceptance criteria | Coverage |
| --- | --- | --- |
| `test_mob_behavior.gd` | 1–6, 12–13, 16 | Idle, group-based acquisition, chase, de-aggro, attack transitions, animation reset, recovery, and independent mobs |
| `test_combat.gd` | 7–11, 14–15 | Melee timing and deduplication, attack reaction pipeline, Magic Arrow damage, mob health, and mob death |
| `test_player_contact.gd` | 17–22 | Contact damage/action payloads, overlap deduplication, cooldown, knockback direction, gravity, and later contact |

The combat suite also protects projectile world-collision and lifetime behavior. The player/contact suite additionally verifies the melee hit animation, vertical contact in both directions, collision-exception cleanup, and player death reload.
