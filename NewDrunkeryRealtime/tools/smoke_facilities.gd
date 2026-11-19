extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var flow: Node = main.get_node("LevelFlowController")
	flow.set_process(false)
	flow.run_context.state = 6
	paused = false
	for entry: Dictionary in preload("res://Scripts/Facilities/FacilityCatalog.gd").ENTRIES:
		if not flow.purchase_support_facility({"facility_type": entry.id}):
			push_error("Live smoke purchase failed: %s" % entry.id)
			quit(1)
			return
	for frame in range(180):
		await physics_frame
	print("SMOKE COMPLETED: all facilities ran together for 180 live physics frames; inspect the log for script errors.")
	main.queue_free()
	await process_frame
	quit()
