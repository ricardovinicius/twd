extends SceneTree

# Test entry point. Godot compiles a --script main loop before autoloads are
# registered, so suites that reference autoloads (CoinManager, SaveGame, ...)
# or scripts that do fail to compile. This bootstrap has no dependencies: once
# the tree (and its autoloads) is running, it swaps in the real suite script
# and starts it. Usage: --script res://tests/bootstrap.gd -- res://tests/x.gd


func _initialize() -> void:
	call_deferred(&"_start_suite")


func _start_suite() -> void:
	var args := OS.get_cmdline_user_args()

	if args.is_empty():
		push_error("Bootstrap: Pass the suite path after '--'.")
		quit(1)
		return

	var suite := load(args[0]) as GDScript

	if suite == null:
		push_error("Bootstrap: Could not load suite '%s'." % args[0])
		quit(1)
		return

	# Calls queued on this object run against the new script after the swap.
	call_deferred(&"_initialize")
	set_script(suite)
