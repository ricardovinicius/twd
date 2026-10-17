# Feature Overview

Resting at a checkpoint (the "bonfire") now works like a Souls-style rest: it restores the player's health, recreates the level's enemies, sets the respawn point, and persists the player's progress to disk. Starting the game loads that save, placing the player at the last checkpoint where they saved.

# Behavior Rules

## Resting

- Pressing **Save** in the checkpoint menu rests the player at that checkpoint's spawn marker.
- Resting sets the player's checkpoint, fully restores health and shield (`Health.reset()`), and emits `Events.checkpoint_rested` once.
- `EnemyRespawner` recreates all of its placed enemies on `checkpoint_rested`, exactly as it does on `player_died`. Killed enemies come back at their original placement and with full health.
- **Back** and the spell shop do not rest, heal, respawn enemies, or save.

## Saving

- After resting, the checkpoint menu calls `SaveGame.save_player(player)`.
- The save stores: the checkpoint position, Stardust (`CoinManager.coins`), registered spell IDs, inventory quantities (by item resource path), and equipped items per slot (by resource path).
- The save is written to `user://savegame.cfg` as a `ConfigFile` with a `version` key. Saving overwrites the previous save; there is a single slot.
- A player without a checkpoint is not saved (warning, no file written).
- Buying a spell at a checkpoint saves immediately, so neither death nor Restart undoes the purchase. If the player has never saved, that checkpoint becomes the saved one.

## Loading

- On startup, `Main` loads the save when one exists and applies it to the player: Stardust, spells (added to the initial spells), inventory, equipment, then checkpoint, and finally `spawn_player()` to move the player there at full health.
- An unknown save version or a save without a checkpoint is ignored with a warning; the game starts normally.
- Without a usable save, Stardust starts at 0. The level's pickups reappear on Restart, so unsaved Stardust is not kept either.
- Saved items or spells that no longer exist are skipped with a warning; the rest of the save still loads.

## Main menu

- When a save exists, the main menu shows **Continue** (focused) and labels Start as **New Game**.
- **Continue** opens `Main.tscn`, which loads the save.
- **New Game** deletes the save, resets Stardust to 0, and opens `Main.tscn`.

# Implementation Details

| Component | Responsibility |
| --- | --- |
| `SaveGame` (autoload, `save/save_game.gd`) | Own the save file: write, read, delete, version check. Capture and restore state through each owner's public API. |
| `RespawnOnDeath` | Own the checkpoint and the rest lifecycle (`rest_at()`), emit `rested` and `Events.checkpoint_rested`. |
| `Player` | Expose narrow capabilities: `rest_at_checkpoint()`, `has_checkpoint()`, `get_checkpoint_position()`, `get_inventory()`, `get_equipment()`. |
| `CheckpointMenu` | On Save, request a rest through the player API, then ask `SaveGame` to persist. |
| `EnemyRespawner` | Recreate placed enemies on `player_died` and `checkpoint_rested`. |
| `CoinManager` | `set_coins()` replaces the total for loading and new games. |
| `Main` | Load the save into its player on startup. |
| `MainMenu` | Offer Continue / New Game. |

```text
CheckpointMenu.Save
  -> Player.rest_at_checkpoint(spawn)
       -> RespawnOnDeath.rest_at(spawn)
            set checkpoint, Health.reset(), rested, Events.checkpoint_rested
                 -> EnemyRespawner.respawn_all()
  -> SaveGame.save_player(player) -> user://savegame.cfg

Main._ready -> SaveGame.load_into_player(player)
  -> CoinManager.set_coins, SpellRegistry.register_spell, Inventory.add_item,
     Equipment.equip, Player.set_checkpoint, Player.spawn_player
```

# Scope

Out of scope for this change: multiple save slots, saving the current level (there is only `Level01`), persisting world state such as collected pickups, opened doors, levers, or dug blocks, and autosaving outside checkpoints. Because world state is not saved, coin and item pickups placed in the level reappear after loading.

# Acceptance Criteria

1. Saving at a checkpoint restores full health, sets that checkpoint as the respawn point, and writes the save file.
2. Saving at a checkpoint recreates killed enemies at their placed positions.
3. Back closes the menu without healing, respawning enemies, or saving.
4. Loading a save places the player at the saved checkpoint at full health, and later deaths respawn there.
5. Loading restores Stardust, acquired spells, inventory quantities, and equipped slots.
6. Without a save, the game starts at the level's default spawn and nothing changes.
7. The main menu shows Continue only when a save exists; New Game deletes it.
8. A purchased spell and the Stardust left after buying it survive death and Restart, even when the menu is closed with Back.
9. Restart without a save resets Stardust to 0.

Run `bash tests/save_system/run_tests.sh` for the automated checks.

# Update: Level Pickups

- Coins and items placed in a level (`CoinPickup`, `ItemPickup` with a scene owner) are tracked by `SaveGame`. Collecting one marks it pending; saving records it under `[world] collected` (paths relative to the running scene).
- When `Main` starts, `SaveGame.apply_world_state()` removes pickups recorded in the save and forgets unsaved ones. Unsaved pickups therefore return on Restart together with the unsaved Stardust, and saved ones never return, so pickups cannot be farmed.
- Runtime drops (enemy Stardust) have no scene owner and are not tracked; enemies respawn by design.
- New Game asks for confirmation before deleting an existing save.
