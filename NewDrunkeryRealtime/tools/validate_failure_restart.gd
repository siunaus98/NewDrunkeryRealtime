extends SceneTree

const Context = preload("res://Scripts/Core/LevelContext.gd")
const Adapter = preload("res://Scripts/Core/LevelFlowInputAdapter.gd")

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
	var old_progression: Object = flow.progression_state
	flow.run_context.state = Context.LevelState.LEVEL_FAILED
	flow._handle_flow_input_action(Adapter.Action.CONFIRM)
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.scene_file_path == "res://Scenes/Main/game_start.tscn", "A failed run must return to the title scene.")
	_check(paused == false, "The title scene must not remain paused after a failed run.")
	_check(old_progression != null, "The failed-run fixture must have initialized persistent progression before restart.")
	if current_scene != null:
		_check(current_scene.get_node_or_null("LevelFlowController") == null, "The failed main scene must be fully replaced before a new run starts.")
	if failures.is_empty():
		print("PASS: failed result returns to a fresh title scene and clears pause state.")
	quit(0 if failures.is_empty() else 1)
