class_name DialoguePanel
extends CanvasLayer

@export var session: DialogueSession
@export var interactor: PlayerInteractor

@onready var speaker: Label = %Speaker
@onready var text: Label = %Text
@onready var hints: Label = %Hints


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if session == null or interactor == null:
		push_error("DialoguePanel: DialogueSession and PlayerInteractor must be assigned.")
		hide()
		set_process(false)
		return

	session.line_changed.connect(_on_line_changed)
	session.ended.connect(_on_ended)
	interactor.bindings_changed.connect(_on_bindings_changed)

	_on_line_changed(session.get_current_line())


func _process(_delta: float) -> void:
	visible = session.is_active() and not get_tree().paused


func _on_line_changed(line: DialogueLine) -> void:
	speaker.text = line.speaker_name if line != null else ""
	text.text = line.text if line != null else ""

	_on_bindings_changed()
	visible = line != null and not get_tree().paused


func _on_bindings_changed() -> void:
	hints.text = "%s  Continue     %s  End conversation" % [
		interactor.get_binding_label(interactor.interaction_action),
		interactor.get_binding_label(interactor.cancel_action)
	]


func _on_ended(_reason: StringName) -> void:
	_on_line_changed(null)
