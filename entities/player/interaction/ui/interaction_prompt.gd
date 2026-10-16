extends CanvasLayer

@export var interactor: PlayerInteractor

@onready var label: Label = $Prompt


func _ready() -> void:
	if interactor == null:
		push_error("InteractionPrompt: PlayerInteractor must be assigned.")
		hide()
		return

	interactor.prompt_changed.connect(_on_prompt_changed)

	_on_prompt_changed(interactor.get_prompt())


func _on_prompt_changed(text: String) -> void:
	label.text = text
	visible = not text.is_empty()
