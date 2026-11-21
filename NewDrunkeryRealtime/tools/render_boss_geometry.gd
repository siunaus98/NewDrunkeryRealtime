extends SceneTree

const OUT := "res://_artifact_work/boss_geometry/preview.png"

func _initialize() -> void:
	call_deferred("run")

func stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		stop_ticks(child)

func label_at(host: Node, text: String, at: Vector2, width: float, color: Color, font_size: int = 22) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	host.add_child(label)

func run() -> void:
	root.size = Vector2i(1440, 1600)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 1600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var bg := ColorRect.new()
	bg.size = Vector2(1440, 1600)
	bg.color = Color("263734")
	viewport.add_child(bg)
	label_at(viewport, "BOSS GEOMETRY / GODOT RUNTIME", Vector2(0, 20), 1440, Color("f3e4bf"), 28)
	var titles := ["MOVEMENT / BLUE", "HURT REGIONS / GREEN", "CONTACT / RED"]
	var colors := [Color("54aaff"), Color("72e88c"), Color("ff6d65")]
	var layers: Array[StringName] = [&"body", &"hurt", &"contact"]
	var kinds := ["sandworm", "scorpion", "vulture", "monitor"]
	for column in range(3):
		label_at(viewport, titles[column], Vector2(column * 480, 66), 480, colors[column])
	for row in range(4):
		for column in range(3):
			var origin := Vector2(column * 480 + 10, 110 + row * 370)
			var panel := Panel.new()
			panel.position = origin
			panel.size = Vector2(460, 355)
			var style := StyleBoxFlat.new()
			style.bg_color = Color("b5a684")
			style.set_corner_radius_all(16)
			panel.add_theme_stylebox_override("panel", style)
			viewport.add_child(panel)
			var boss: CharacterBody2D = load("res://Scenes/Enemies/%s_boss.tscn" % kinds[row]).instantiate()
			viewport.add_child(boss)
			stop_ticks(boss)
			boss.position = origin + Vector2(230, 163)
			boss.state = boss.AttackState.ACTIVE
			boss.impact_remaining = 0
			if kinds[row] == "monitor":
				boss.facing = Vector2(-1, -1).normalized()
			boss._update_visuals()
			boss.geometry.debug_visible = true
			boss.geometry.debug_layers.clear()
			boss.geometry.debug_layers.append(layers[column])
			boss.geometry.sync_ground()
			label_at(viewport, kinds[row].to_upper(), origin + Vector2(0, 319), 460, Color("302b22"), 18)
	for frame in range(5):
		await process_frame
		RenderingServer.force_draw(false)
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var result := viewport.get_texture().get_image().save_png(OUT)
	print("BOSS GEOMETRY PREVIEW: ", error_string(result))
	viewport.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
