extends SceneTree

const Boss = preload("res://Scripts/Enemies/MapMechanismBoss.gd")
const Sand = preload("res://Scripts/Hazards/QuicksandHazard.gd")

func _initialize() -> void:
	call_deferred("_render")

func _label(parent: Node, caption: String, position: Vector2) -> void:
	var label := Label.new()
	label.text = caption
	label.position = position
	label.add_theme_font_size_override("font_size", 24)
	parent.add_child(label)

func _render() -> void:
	root.size = Vector2i(1920, 1080)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node2D.new()
	viewport.add_child(world)
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1920, 0), Vector2(1920, 1080), Vector2(0, 1080)])
	background.color = Color("29241e")
	world.add_child(background)
	var worm: Boss
	for stage in range(4):
		worm = load("res://Scenes/Enemies/sandworm_boss.tscn").instantiate()
		world.add_child(worm)
		worm.set_physics_process(false)
		worm.position = Vector2(130 + stage * 480, 290)
		worm.movement_bounds = Rect2(Vector2(-1000, -1000), Vector2(5000, 5000))
		var target := Node2D.new()
		world.add_child(target)
		target.position = worm.position + Vector2(220, 80)
		worm.player = target
		worm.start_attack(Boss.Attack.SLAM)
		match stage:
			0:
				worm.state_remaining = worm.windup_total
			1:
				worm.state_remaining = worm.windup_total * 0.3
			2:
				worm._resolve_attack()
				worm.impact_remaining = 0.5
			3:
				worm._resolve_attack()
				worm.impact_remaining = 0.0
		worm._update_visuals()
		_label(world, ["1. Windup", "2. Rear up", "3. Impact / dust", "4. Recovery"][stage], Vector2(35 + stage * 480, 28))
	for stage in range(3):
		var sand := Sand.new()
		sand.position = Vector2(320 + stage * 640, 760)
		sand.scale = Vector2.ONE * 0.68
		if stage > 0:
			sand.configure_boss(worm, 400.0, 0.8, 180.0)
		world.add_child(sand)
		sand.set_physics_process(false)
		if stage != 1:
			sand.warning_remaining = 0.0
		else:
			sand.warning_remaining = 0.2
		if stage == 2:
			sand.birth_flash_remaining = 0.24
		sand.queue_redraw()
		_label(world, ["Normal pool: radius 270", "Boss warning: 0.8 seconds", "Boss activation: pull ring / radius 400"][stage], Vector2(60 + stage * 640, 465))
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var path := OS.get_environment("TEMP").path_join("boss-feedback-review.png")
	var result := image.save_png(path)
	print("Boss feedback render: %s (result %d)" % [path, result])
	world.queue_free()
	viewport.queue_free()
	await process_frame
	quit(result)
