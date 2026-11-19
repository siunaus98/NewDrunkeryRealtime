extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1400, 600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node2D.new()
	viewport.add_child(world)
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1400, 0), Vector2(1400, 600), Vector2(0, 600)])
	background.color = Color("b6966a")
	world.add_child(background)
	for index in range(2):
		var boss: CharacterBody2D = load("res://Scenes/Enemies/monitor_boss.tscn").instantiate()
		world.add_child(boss)
		boss.set_physics_process(false)
		boss.position = Vector2(260 + index * 700, 340)
		boss.facing = Vector2.RIGHT
		boss.attack = boss.Attack.BITE
		boss.attack_origin = boss.position
		boss.attack_direction = boss.facing
		boss.state = boss.AttackState.WINDUP if index == 0 else boss.AttackState.RECOVERY
		boss.windup_total = 0.55
		boss.state_remaining = 0.3
		boss._update_visuals()
		if index == 1:
			boss._spawn_scorpion_effect(&"bite", boss.position, boss.facing, boss.bite_radius)
			var effect: Node = get_nodes_in_group("scorpion_skill_effects").back()
			effect.elapsed = 0.2
			effect.set_process(false)
		var label := Label.new()
		label.text = "双颚连咬 · 正面扇形预警" if index == 0 else "双颚连咬 · 咬合特效"
		label.position = Vector2(60 + index * 700, 40)
		label.add_theme_font_size_override("font_size", 28)
		world.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png("res://_artifact_work/monitor_bite.png")
	print("Monitor bite render: ", result)
	viewport.queue_free()
	await process_frame
	quit(result)
