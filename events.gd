extends Node

signal player_died
## Emitted after the player rests at a checkpoint (health restored, checkpoint set).
signal checkpoint_rested
signal item_collected(item: ItemDefinition, new_quantity: int)
