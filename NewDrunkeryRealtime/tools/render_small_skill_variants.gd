extends SceneTree

const Defs = preload("res://Scripts/Player/SmallSkillDefs.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
const OUTPUT: String = "res://_artifact_work/small_skill_balance_20261022/"

func _initialize() -> void:
	call_deferred("_run")

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is CanvasLayer:
		node.hide()
	for child: Node in node.get_children():
		_stop_ticks(child)

func _capture(name: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	picture.save_png(OUTPUT + name + ".png")
	print("Captured ", name, " ", picture.get_size())

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var start: Node = load("res://Scenes/Main/game_start.tscn").instantiate()
	root.add_child(start)
	current_scene = start
	start._show_prepare()
	start._select_character(&"chi_baobao", true)
	start._on_small_skill_test_selected(4)
	await _capture("selector")
	start.free()
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	_stop_ticks(main)
	# Startup transition is deliberately frozen by the render fixture.
	for child: Node in main.get_children():
		if child is CanvasLayer:
			child.hide()
	var player: Node2D = main.get_node("Player")
	var camera: Camera2D = main.get_node("Camera2D")
	camera.position = player.position
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	camera.force_update_scroll()
	var flow: Node = main.get_node("LevelFlowController")
	flow.run_context.state = Context.LevelState.PREPARE_PHASE
	flow.magic_current = 6
	player.set_small_skill_variant(Defs.FIELD)
	player.skill_controller.try_activate_small()
	player.skill_controller.small.field.set_process(false)
	await _capture("aura")
	player.set_small_skill_variant(Defs.DIRECTION)
	flow.magic_current = 6
	player.skill_controller.try_activate_small()
	player.skill_controller.small.before_motion(Vector2(1, -1).normalized())
	player.queue_redraw()
	await _capture("direction")
	player.set_small_skill_variant(Defs.RANDOM)
	var random_skill: RefCounted = player.skill_controller.small
	random_skill.rng.seed = 20261022
	for result: int in [1, -1, 0]:
		for attempt in range(60):
			random_skill.reset_temporary_state()
			flow.magic_current = 4
			player.skill_controller.try_activate_small()
			if random_skill.magic_feedback_delta == result:
				break
		player.queue_redraw()
		await _capture("random_%d" % result)
	player.set_small_skill_variant(Defs.TRAIL)
	flow.magic_current = 6
	player.skill_controller.try_activate_small()
	var small: RefCounted = player.skill_controller.small
	var point: Vector2 = player.global_position
	small.after_motion(Vector2.LEFT, point, point + Vector2(-250, 0), 250)
	small.after_motion(Vector2.DOWN, point + Vector2(-250, 0), point + Vector2(-250, 200), 200)
	small.field.set_process(false)
	await _capture("trail_dormant")
	small.tick(4.0, 1.0)
	await _capture("trail_active")
	main.queue_free()
	await process_frame
	quit()
