class_name VariableJumpHeightComponent
extends Node

@export_category("Variable Jump Height")
## Multiplies the player's remaining upward velocity when jump is released.
## Lower values create shorter tap jumps; higher values preserve more height.
## A value of 0 stops upward movement immediately, while 1 disables the cut.
@export_range(0.0, 1.0, 0.05) var jump_cut_multiplier: float = 0.25


func cut_jump(vertical_velocity: float) -> float:
	if vertical_velocity >= 0.0:
		return vertical_velocity

	return vertical_velocity * jump_cut_multiplier
