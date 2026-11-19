extends SceneTree

const Boss = preload("res://Scripts/Enemies/MapMechanismBoss.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var world := Node2D.new()
	root.add_child(world)
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1920, 0), Vector2(1920, 1080), Vector2(0, 1080)])
	background.color = Color("29241e")
	world.add_child(background)
	var kinds: Array[int] = [Boss.Attack.STING, Boss.Attack.SWEEP, Boss.Attack.LEAP, Boss.Attack.SUMMON]
	for row in range(2):
		for column in range(4):
			var origin := Vector2(220 + column * 480, 280 + row * 520)
			var boss: Boss = load("res://Scenes/Enemies/scorpion_boss.tscn").instantiate()
			world.add_child(boss)
			boss.set_physics_process(false)
			boss.position = origin
			boss.scale = Vector2.ONE * 0.72
			boss.movement_bounds = Rect2(-2000, -2000, 6000, 6000)
			var player := Node2D.new()
			world.add_child(player)
			player.position = origin + Vector2(100, 70)
			boss.player = player
			boss.start_attack(kinds[column])
			boss.state_remaining = boss.windup_total * 0.25
			if row == 1:
				boss._resolve_attack()
				for effect in get_nodes_in_group("scorpion_skill_effects"):
					effect.set_process(false)
					effect.elapsed = 0.12
					effect.scale = Vector2.ONE * 0.72
					effect.queue_redraw()
			boss._update_visuals()
			var label := Label.new()
			label.position = Vector2(column * 480 + 24, row * 520 + 22)
			label.add_theme_font_size_override("font_size", 24)
			label.text = ["刺击", "甩尾", "跳砸", "召唤圣甲虫"][column] + (" · 蓄力" if row == 0 else " · 生效")
			world.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("TEMP").path_join("scorpion-skills-review.png")
	root.get_texture().get_image().save_png(output)
	print(output)
	world.queue_free()
	await process_frame
	quit()
