extends SceneTree

const ART_ROOT := "res://ArtResource/"
const OUT := "res://_artifact_work/art_overhaul/"

func _initialize() -> void:
	call_deferred("run")

func label_at(host: Node, text: String, at: Vector2, width: float = 200, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(width, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f3e4bf"))
	host.add_child(label)
	return label

func files_in(folder: String) -> Array[String]:
	var files: Array[String] = []
	for file: String in DirAccess.get_files_at(ART_ROOT + folder):
		if file.ends_with(".svg"):
			files.append(folder + "/" + file)
	return files

func capture(viewport: Viewport, name: String) -> void:
	for frame in range(4):
		await process_frame
		RenderingServer.force_draw(false)
		await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png(OUT + name + ".png")
	assert(result == OK)
	print("ART CAPTURE: " + name)

func sheet(name: String, files: Array[String], columns: int, rows: int) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var bg := ColorRect.new()
	bg.size = Vector2(1920, 1080)
	bg.color = Color("243835")
	viewport.add_child(bg)
	label_at(viewport, name.to_upper().replace("_", " "), Vector2(80, 22), 1760, 30)
	var cell := Vector2(1760.0 / float(columns), 936.0 / float(rows))
	for index in range(files.size()):
		var at := Vector2(80, 88) + Vector2(index % columns, index / columns) * cell
		var panel := Panel.new()
		panel.position = at + Vector2(6, 6)
		panel.size = cell - Vector2(12, 12)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("ddccaa")
		style.set_corner_radius_all(14)
		style.border_color = Color("a88c64")
		style.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", style)
		viewport.add_child(panel)
		var texture: Texture2D = load(ART_ROOT + files[index])
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.position = at + Vector2(22, 10)
		icon.size = cell - Vector2(44, 44)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		viewport.add_child(icon)
		var label := label_at(viewport, files[index].get_file().trim_suffix(".svg"), at + Vector2(8, cell.y - 33), cell.x - 16, 14)
		label.add_theme_color_override("font_color", Color("574c3b"))
	await capture(viewport, name)
	viewport.queue_free()
	await process_frame

func stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		stop_ticks(child)

func run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await sheet("ingredients", files_in("Generated/Ingredient"), 6, 3)
	await sheet("enemies", files_in("Generated/Enemy"), 5, 3)
	var facilities := files_in("Cooker")
	facilities.append_array(files_in("Kitchen"))
	facilities.append_array(files_in("Facilities"))
	await sheet("facilities", facilities, 6, 5)
	await sheet("characters", files_in("Events"), 5, 2)
	await sheet("dishes", files_in("Generated/DishPlated"), 7, 6)
	await sheet("drinks", files_in("Generated/Dish").filter(func(file: String) -> bool: return file.get_file().begins_with("drink_")), 5, 2)
	var start: Node = load("res://Scenes/Main/game_start.tscn").instantiate()
	root.add_child(start)
	await capture(root, "title")
	start._show_prepare()
	await capture(root, "prepare")
	start.queue_free()
	await process_frame
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	stop_ticks(main)
	var flow: Node = main.get_node("LevelFlowController")
	flow.overlay_controller.set_transition_visible(false)
	for child: Node in main.get_children():
		if child is CanvasLayer:
			child.hide()
	var camera: Camera2D = main.get_node("Camera2D")
	camera.position_smoothing_enabled = false
	camera.position = Vector2(2304, 1300)
	camera.zoom = Vector2.ONE * 0.65
	camera.reset_smoothing()
	camera.force_update_scroll()
	var player: Node2D = main.get_node("Player")
	player.position = Vector2(2470, 1410)
	var Items = load("res://Scripts/Kitchen/TestItemDefs.gd")
	player.clear_held_item()
	player.pick_up_item(Items.EGG_ID, Items.get_item_texture(Items.EGG_ID))
	main.get_node("PrepTableA").receive_item_from_player(player)
	player.pick_up_item(Items.DISH_CRISP_PLATE_ID, Items.get_item_texture(Items.DISH_CRISP_PLATE_ID))
	main.get_node("PrepTableB").receive_item_from_player(player)
	main.get_node("RunStatusHud").set_status_visible(true)
	flow.night_event_controller.indicators.update_targets(flow.night_event_controller.npcs)
	await capture(root, "kitchen")
	flow.night_event_controller.open_dialogue(&"prankster")
	await capture(root, "dialogue")
	flow.night_event_controller.close_dialogue()
	var roast: Node = main.get_node("BakeCooker")
	player.clear_held_item()
	player.pick_up_item(Items.TEST_ITEM_ID, Items.get_item_texture(Items.TEST_ITEM_ID))
	roast.receive_item_from_player(player)
	roast.process_progress = roast._get_required_process_progress() * 0.55
	roast._update_stage_process_state()
	roast._update_station_progress_visual()
	for effect: Node in roast.get_children():
		if effect.get_script() == load("res://Scripts/Kitchen/CookerWorkArt.gd"):
			effect.elapsed = 0.7
			effect.queue_redraw()
	camera.position = roast.global_position + Vector2(-80, 80)
	camera.zoom = Vector2.ONE * 1.1
	camera.force_update_scroll()
	player.position = roast.global_position + Vector2(-110, 150)
	player.pick_up_item(Items.PLATE_ID, Items.get_item_texture(Items.PLATE_ID), &"", "", {"items": [{"item_id": Items.TEST_ITEM_ID, "process_state": Items.PROCESS_STATE_ROAST_MEDIUM}, {"item_id": Items.EGG_ID, "process_state": Items.PROCESS_STATE_CUT}]})
	player._process(0)
	await capture(root, "cooking")
	player.clear_held_item()
	camera.position = Vector2(2170, 200)
	camera.zoom = Vector2.ONE * 0.8
	camera.force_update_scroll()
	player.position = Vector2(2200, 210)
	var attack: Node2D = load("res://Scripts/Player/AttackVisualizer.gd").new()
	player.add_child(attack)
	attack.preview_charge(Vector2(1, -0.2), 0.85, true)
	for index in range(4):
		var enemy: Node2D = flow.battle_manager._get_enemy_scene_for_id([&"chaser", &"sprinter", &"ranged", &"bullet_fan"][index]).instantiate()
		main.add_child(enemy)
		enemy.position = Vector2(1800 + index * 220, 180 + index % 2 * 170)
		stop_ticks(enemy)
	flow.night_event_controller.indicators.update_targets(flow.night_event_controller.npcs)
	await capture(root, "battle")
	attack.stop_charge_preview()
	attack.play_charged(0, 1, true)
	attack.remaining_time = 0.1
	attack.set_process(false)
	await capture(root, "strike")
	var points: Array[Node] = get_nodes_in_group("forage_points")
	# Night preparation has no natural resources; preview the real point scene.
	if points.is_empty():
		for index in range(3):
			var point: Node2D = load("res://Scenes/Forage/forage_point.tscn").instantiate()
			point.forage_item_ids.assign([[Items.VEG_LEAF_ID], [Items.RICE_ID], [Items.TOFU_ID]][index])
			main.add_child(point)
			point.position = Vector2(1950 + index * 220, 80)
			stop_ticks(point)
			points.append(point)
	if not points.is_empty():
		camera.position = points[0].global_position + Vector2(80, 70)
		camera.zoom = Vector2.ONE
		camera.force_update_scroll()
		player.position = points[0].global_position + Vector2(-100, 80)
		flow.night_event_controller.indicators.update_targets(flow.night_event_controller.npcs)
		await capture(root, "forage")
	var sink: Node2D = main.get_node("PlateSink")
	sink.dirty_plates = 2
	sink._refresh()
	sink.splash_visible = true
	sink.splash_time = 0.4
	sink.queue_redraw()
	camera.position = sink.global_position + Vector2(-80, 40)
	camera.zoom = Vector2.ONE * 1.1
	camera.force_update_scroll()
	player.position = sink.global_position + Vector2(65, 140)
	flow.night_event_controller.indicators.update_targets(flow.night_event_controller.npcs)
	await capture(root, "washing")
	flow.overlay_controller.show_result(true, "营业顺利结束，明日的冒险等待你的选择。", flow.run_context, flow.progression_state)
	await capture(root, "settlement")
	main.queue_free()
	await process_frame
	quit()
