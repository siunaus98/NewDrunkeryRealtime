extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Spot = preload("res://Scripts/Enemies/MonitorFeedingSpot.gd")
const Pause = preload("res://Scripts/Facilities/FacilityWorkPause.gd")

func _initialize() -> void:
	call_deferred("run")

func label(parent: Node, text: String, at: Vector2) -> void:
	var view := Label.new()
	view.text = text
	view.position = at
	view.add_theme_font_size_override("font_size", 27)
	view.add_theme_color_override("font_outline_color", Color("513420"))
	view.add_theme_constant_override("outline_size", 5)
	parent.add_child(view)

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 1000)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node2D.new()
	viewport.add_child(world)
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1600, 0), Vector2(1600, 1000), Vector2(0, 1000)])
	background.color = Color("b6966a")
	world.add_child(background)
	for index in range(4):
		var origin := Vector2(index % 2 * 800, index / 2 * 500)
		label(world, ["准备投喂 · 自由取放 · 巨蜥正常行动", "伸舌运送 · 尚未吞下 · 巨蜥正常行动", "10秒附着期 · 按住K修理 · 保住食物", "深度失控 · 15/30秒后仍需修理"][index], origin + Vector2(18, 20))
		var boss: CharacterBody2D = load("res://Scenes/Enemies/monitor_boss.tscn").instantiate()
		world.add_child(boss)
		boss.set_physics_process(false)
		boss.position = origin + Vector2(200, 280)
		boss.facing = Vector2.RIGHT
		if index < 2:
			boss.tongue.phase = boss.tongue.Phase.LOCK if index == 0 else boss.tongue.Phase.EXTEND
			boss.tongue.remaining = 22 if index == 0 else 0.3
			var spot: Node2D = Spot.new()
			world.add_child(spot)
			spot.position = origin + Vector2(600, 280)
			spot.head = boss.tongue
			spot.locked = index == 1
			spot.stored = {"item_id": Items.DISH_RED_ROLL_ID, "payload": {}}
			boss.tongue.spots.append(spot)
			boss.tongue.branches.append({"target": {"position": spot.global_position}, "cancelled": false, "food": {}})
		else:
			var cooker: Node2D = load("res://Scenes/Restaurant/bake_cooker.tscn").instantiate()
			world.add_child(cooker)
			cooker.set_process(false)
			cooker.scale = Vector2.ONE * 0.2
			cooker.position = origin + Vector2(600, 260)
			var effect := Pause.attach(cooker, boss)
			if index == 3:
				effect._process(10)
				effect.remaining = 0
			effect.set_process(false)
		boss._update_visuals()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://_artifact_work/monitor_feedback.png"
	var result := viewport.get_texture().get_image().save_png(path)
	print("Monitor feedback render: ", ProjectSettings.globalize_path(path), " result ", result)
	viewport.queue_free()
	await process_frame
	quit(result)
