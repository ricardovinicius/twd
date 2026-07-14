# Interface for spell commands. Each command should implement the _execute() method to define its behavior.

class_name SpellCommand
extends Node

signal finished
signal failed(command: SpellCommand, reason: StringName)

var context: SpellContext


func execute(new_context: SpellContext) -> void:
    context = new_context
    _execute()


func _execute() -> void:
    push_error("SpellCommand::_execute() must be overridden in subclasses.")
    fail(&"not_implemented")


func complete() -> void:
    finished.emit()
    queue_free()


func fail(reason: StringName) -> void:
    failed.emit(self, reason)
    queue_free()


func cancel() -> void:
    fail(&"cancelled")