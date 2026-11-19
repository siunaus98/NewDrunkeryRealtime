extends SceneTree

const Boss = preload("res://Scripts/Enemies/MapMechanismBoss.gd")
const Tail = preload("res://Scripts/Enemies/SandwormTailStrike.gd")
const Wave = preload("res://Scripts/Hazards/SandstormWave.gd")
const Cyclone = preload("res://Scripts/Hazards/TrackingSandstorm.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var world := Node2D.new()
	root.add_child(world)
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1920, 0), Vector2(1920, 1080), Vector2(0, 1080)])
	background.color = Color("40372c")
	world.add_child(background)
	for column in range(4):
		var position := Vector2(180 + column * 400, 270)
		var label := Label.new()
		label.position = Vector2(column * 400 + 25, 24)
		label.text = ["沙暴秃鹫", "小风暴 · 蓄力路线", "俯冲 · 落点预警", "追踪沙旋 · 生效"][column]
		label.add_theme_font_size_override("font_size", 23)
		world.add_child(label)
		var boss: Boss = load("res://Scenes/Enemies/vulture_boss.tscn").instantiate()
		world.add_child(boss)
		boss.set_physics_process(false)
		boss.position = position
		boss.scale = Vector2.ONE * 0.7
		boss.movement_bounds = Rect2(-5000, -5000, 10000, 10000)
		var target := Node2D.new()
		world.add_child(target)
		target.position = position + Vector2(0, 120)
		boss.player = target
		if column == 1:
			boss.start_attack(Boss.Attack.GUST)
			boss.state_remaining = 0.5
			boss._update_visuals()
		elif column == 2:
			boss.start_attack(Boss.Attack.DIVE)
			boss.state_remaining = 0.7
			boss._update_visuals()
		elif column == 3:
			var cyclone := Cyclone.new()
			cyclone.position = position + Vector2(0, 140)
			cyclone.warning_remaining = 0.0
			cyclone.elapsed = 0.4
			world.add_child(cyclone)
			cyclone.set_physics_process(false)
			cyclone.queue_redraw()
	for i in range(4):
		var tail := Tail.new()
		tail.position = Vector2(120 + i * 230, 860)
		tail.elapsed = [0.02, 0.13, 0.25, 0.57][i]
		world.add_child(tail)
		tail.set_physics_process(false)
		tail.queue_redraw()
	var label := Label.new()
	label.position = Vector2(25, 600)
	label.text = "地底尾刺 · 破土 → 伸出 → 停留 → 回缩"
	label.add_theme_font_size_override("font_size", 24)
	world.add_child(label)
	var wave := Wave.new()
	wave.position = Vector2(1170, 780)
	wave.warning_duration = 0.0
	world.add_child(wave)
	wave.set_physics_process(false)
	wave.queue_redraw()
	label = Label.new()
	label.position = Vector2(1010, 650)
	label.text = "料理区风暴 · 两格宽"
	label.add_theme_font_size_override("font_size", 24)
	world.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var output := "D:/NP/NewDrunkeryRealtime/_artifact_work/boss-storm-feedback.png"
	root.get_texture().get_image().save_png(output)
	print(output)
	world.queue_free()
	await process_frame
	quit()
