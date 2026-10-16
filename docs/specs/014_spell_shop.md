# Spell Shop

## Feature Overview

Checkpoints sell new spells. Every spell cast with more than one button (sequence of two or more tokens, such as Double Jump `L + K` and Dig `J + K`) is locked at the start and costs **100 Stardust** to unlock. Single-button spells (Magic Arrow, Push, Dash) stay available from the start.

## Behavior Rules

- The player starts with `magic_arrow`, `push` and `dash`. Multi-token spells are not in `initial_spell_ids`, so `SequenceCaster` cannot resolve them until bought.
- Interacting with a checkpoint opens `CheckpointMenu` with **SAVE**, **SPELLS** and **BACK**.
- **SPELLS** opens the shop panel: current Stardust and one row per multi-token spell in the database, with its name, key sequence and a Buy button.
- Buy is enabled only when the spell is not owned and the player has at least the price. Owned spells show **Owned** (disabled).
- A purchase spends the price through `CoinManager.spend_coins()` and registers the spell in the player's `SpellRegistry`. The spell is castable immediately.
- Rejected purchases (not enough Stardust, already owned, not for sale) spend nothing and change nothing.
- The shop list updates when Stardust changes while it is open. Shop **BACK** returns to the checkpoint menu; menu **BACK** closes it and resumes gameplay.
- ESC (`pause`), Q / controller cancel (`dialogue_cancel`) and `ui_cancel` act as Back: they close the shop first, then the checkpoint menu. The menu consumes these events so the pause menu cannot unpause the game underneath it.
- New multi-token spells added to `spell_database.tres` appear in the shop automatically.

## Scene Composition

```text
CheckpointMenu (CanvasLayer, spell_shop = spells/shop/spell_shop.tres)
├── MenuHolder
│   ├── SaveButton
│   ├── SpellsButton
│   └── BackButton
└── ShopPanel (PanelContainer, hidden until SPELLS)
    └── Margin/Content
        ├── TitleLabel
        ├── StardustLabel
        ├── OfferList (rows built at runtime)
        └── ShopBackButton
```

## Component Responsibilities

| Component | Responsibility |
| --- | --- |
| `SpellShop` (resource) | Price (100) and the sale rule (`min_sequence_length = 2`); lists offers and performs validated purchases. |
| `CoinManager` | Owns Stardust; `can_afford()` and `spend_coins()` reject insufficient funds without changing state. |
| `SpellRegistry` | Owns which spells the player has unlocked. |
| `CheckpointMenu` | Presents the shop, requests purchases through `SpellShop`, and refreshes from Stardust and registry state. |
| `Player.get_spell_registry()` | Exposes the player's registry to the menu. |

## Scope Limits

- Purchases last for the current play session; there is no save file yet.
- Prices are uniform; per-spell prices would need a field on `SpellDefinition`.
- UI uses the default Godot theme.

## Acceptance Criteria

1. A new game cannot cast `J + K` or `L + K`.
2. With fewer than 100 Stardust, Buy is disabled and nothing is spent.
3. With 100 or more, Buy spends exactly 100, unlocks the spell and marks it Owned.
4. A bought spell is castable right after closing the menu.
5. Automated coverage: `tests/spell_shop/`.
