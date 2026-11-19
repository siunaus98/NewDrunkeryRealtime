extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var flow: Node = main.get_node("LevelFlowController")
	var expected_day := -1
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		arguments = OS.get_cmdline_args()
	for argument in arguments:
		if String(argument).begins_with("--test-day="):
			expected_day = String(argument).trim_prefix("--test-day=").to_int() - 1
	_check(expected_day >= 0, "This validator must be launched with --test-day=N.")
	_check(flow.progression_state.day_index == expected_day, "The requested test day must become the progression day index.")
	_check(flow.progression_state.get_active_map_mechanism_ids().size() == clampi(expected_day, 0, 3), "The test day must use the formal mechanism unlock count.")
	if failures.is_empty():
		print("PASS: explicit test day %d uses day index %d and %d active mechanisms." % [expected_day + 1, expected_day, clampi(expected_day, 0, 3)])
	main.queue_free()
	quit(0 if failures.is_empty() else 1)
