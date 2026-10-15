# Interface for spell commands. Each command should implement the _execute() method to define its behavior.

class_name SpellCommand
extends Node

signal finished
signal failed(command: SpellCommand, reason: StringName)

var context: SpellContext
var _is_finished: bool = false


func execute(new_context: SpellContext) -> void:
	if _is_finished:
		return
	context = new_context
	_execute()


func _execute() -> void:
	push_error("SpellCommand::_execute() must be overridden in subclasses.")
	fail(&"not_implemented")


func complete() -> void:
	if _is_finished:
		return
	_is_finished = true
	finished.emit()
	queue_free()


func fail(reason: StringName) -> void:
	if _is_finished:
		return
	_is_finished = true
	failed.emit(self, reason)
	queue_free()


func cancel() -> void:
	fail(&"cancelled")
