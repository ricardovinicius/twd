class_name SequenceUI
extends Node2D

@export var sequence_caster: SequenceCaster

@export var attack_icon: Texture2D
@export var interaction_icon: Texture2D
@export var move_icon: Texture2D

@onready var sequence_container: HBoxContainer = $SequenceContainer
@onready var timeout_bar: ProgressBar = $TimeoutBar


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	assert(sequence_caster != null, "SequenceUI: sequence_caster is not assigned.")

	sequence_caster.sequence_changed.connect(_on_sequence_changed)
	sequence_caster.sequence_failed.connect(_on_sequence_failed)

	timeout_bar.min_value = 0.0
	timeout_bar.max_value = 1.0

	visible = false  # Hide the UI initially


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not visible:
		return
	
	timeout_bar.value = sequence_caster.get_timeout_ratio()


func _on_sequence_changed(new_sequence: Array[StringName]) -> void:
	# Update the UI to reflect the new sequence.
	_clear_icons()

	for token in new_sequence:
		var icon_texture: Texture2D = null
		match token:
			"attack":
				icon_texture = attack_icon
			"interaction":
				icon_texture = interaction_icon
			"move":
				icon_texture = move_icon
			_:
				push_warning("SequenceUI: Unknown token '%s' in sequence." % token)
		
		if icon_texture != null:
			var icon = TextureRect.new()
			icon.texture = icon_texture
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sequence_container.add_child(icon)
	
	visible = not new_sequence.is_empty()  # Show the UI only if there's a sequence.


func _clear_icons() -> void:
	for child in sequence_container.get_children():
		child.queue_free()


func _on_sequence_failed(sequence: Array[StringName], reason: StringName) -> void:
	push_warning("SequenceUI: Sequence failed due to '%s'." % reason)
	# You might want to add some visual feedback here, like flashing the sequence container or playing a sound.
