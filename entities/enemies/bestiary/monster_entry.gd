class_name MonsterEntry
extends Resource

## One enemy's page in the monster guide. Presentation data only; gameplay
## values stay in the enemy's own scene.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var portrait: Texture2D
## Shown when there is no portrait (e.g. placeholder enemies).
@export var placeholder_color: Color = Color(0.5, 0.5, 0.5, 1.0)
@export var max_health: float = 0.0
@export var damage: float = 0.0
@export var stardust_drop: int = 0
@export var weakness: String = ""
