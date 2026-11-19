extends SceneTree

func _initialize() -> void:
	call_deferred("run")

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
		var panel := Vector2(index % 2 * 800, index / 2 * 500)
		var label := Label.new()
		label.text = ["向右跳跃 · 空中弱点与身体同步", "向左跳跃 · 空中弱点与身体同步", "斜向跳跃 · 朝头部方向前进", "猛冲 · 朝向与前进路线一致"][index]
		label.position = panel + Vector2(20, 20)
		label.add_theme_font_size_override("font_size", 27)
		label.add_theme_color_override("font_outline_color", Color("513420"))
		label.add_theme_constant_override("outline_size", 5)
		world.add_child(label)
		var boss: CharacterBody2D = load("res://Scenes/Enemies/monitor_boss.tscn").instantiate()
		world.add_child(boss)
		boss.set_physics_process(false)
		boss.position = panel + (Vector2(570, 330) if index == 1 else Vector2(230, 330))
		boss.movement_bounds = Rect2(panel, Vector2(800, 500))
		boss.facing = [Vector2.RIGHT, Vector2.LEFT, Vector2(1, -1).normalized(), Vector2.RIGHT][index]
		boss.attack = boss.Attack.STING if index < 3 else boss.Attack.RUSH
		boss.state = boss.AttackState.WINDUP if index < 3 else boss.AttackState.CHARGE
		boss.attack_origin = boss.position
		boss.attack_direction = boss.facing
		boss.attack_target = boss.position + boss.facing * 280
		boss.windup_total = 1.1
		boss.state_remaining = boss.windup_total * 0.45
		boss._update_visuals()
		var route := Line2D.new()
		route.points = PackedVector2Array([boss.position, boss.attack_target])
		route.width = 4
		route.default_color = Color("e6d6a8")
		route.z_index = -1
		world.add_child(route)
	await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://_artifact_work/monitor_movement.png"
	var result := viewport.get_texture().get_image().save_png(output)
	print("Monitor movement render: ", ProjectSettings.globalize_path(output), " result ", result)
	viewport.queue_free()
	await process_frame
	quit(result)
