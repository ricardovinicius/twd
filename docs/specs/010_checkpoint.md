# Feature Overview

The existing checkpoint interaction is a reusable feature under `entities/interactive/checkpoint/`. A level places `Checkpoint.tscn`; the feature owns its detection area, spawn marker, script, and checkpoint menu.

# Behavior Rules

- An overlapping player can open the menu with the `interaction` action.
- Opening the menu pauses gameplay and focuses Save. Repeated interaction creates no duplicate menu.
- Save calls the player's public `set_checkpoint()` capability with the marker's global position.
- Back closes the menu without changing the saved checkpoint.
- Either action resumes gameplay and frees the menu.
- Leaving the area disables interaction. A freed player cannot open the menu.
- Player respawn continues to belong to `entities/player/respawn/`, independent of the checkpoint's presentation.

# Implementation Details

```text
Checkpoint (Area2D)
├── CollisionShape2D
├── SpawnPoint (Marker2D)
└── ColorRect

CheckpointMenu (CanvasLayer, created while interacting)
└── MenuHolder
    ├── SaveButton
    └── BackButton
```

| Component | Responsibility |
| --- | --- |
| `Checkpoint` | Track an eligible player and open one configured menu at a time. |
| `SpawnPoint` | Provide the world-space respawn location. |
| `CheckpointMenu` | Present Save and Back, request checkpoint changes through the player API, and restore gameplay on close. |
| `RespawnOnDeath` | Own the player's saved checkpoint, health restoration, and respawn lifecycle. |
| `Level01` | Place the reusable checkpoint without embedding its implementation. |

`Checkpoint` receives an exported `spawn_point: Marker2D` and `menu_scene: PackedScene`. Missing configuration reports an error and disables interaction. The menu scene must have a `CheckpointMenu` root. The menu checks whether its player is still valid before saving.

# Scope

This extraction preserves the original level's checkpoint location, collision area, appearance, input, and save behavior. Persistent save files, multiple-player checkpoint selection, new artwork, and a redesigned pause flow are outside this change.

# Implementation Plan

1. Extract the checkpoint nodes into `Checkpoint.tscn`, retaining their world placement through local offsets.
2. Colocate the menu and scripts within the checkpoint feature and update resource references.
3. Verify menu focus, duplicate protection, Save, Back, and respawn integration.

# Acceptance Criteria

1. `Level01` instances the reusable checkpoint at `(95, 3187)` with the original collision and presentation offsets.
2. Interaction opens one menu, pauses gameplay, and focuses Save.
3. Back leaves the player's spawn destination unchanged.
4. Save changes the spawn destination to the marker's global position.
5. Both close actions resume gameplay and free the menu; the menu can subsequently be reopened.
6. Interaction after leaving the checkpoint does not open a menu.

Run `bash tests/checkpoint/run_tests.sh` for the feature's automated integration checks.
