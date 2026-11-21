extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Sources = preload("res://Scripts/Core/IngredientSourceDefs.gd")
const Codex = preload("res://Scripts/UI/CodexCatalog.gd")
const OUT = "res://_artifact_work/menu_progression/"

func _initialize() -> void:
	call_deferred("run")

func text_at(host: Node, value: String, at: Vector2, bounds: Vector2, font_size: int, color: Color = Color("513420")) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = value
	label.position = at
	label.size = bounds
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	host.add_child(label)
	return label

func capture(view: Viewport, name: String) -> void:
	for frame in range(5):
		await process_frame
		RenderingServer.force_draw(false)
		await RenderingServer.frame_post_draw
	assert(view.get_texture().get_image().save_png(OUT + name + ".png") == OK)
	print("MENU CAPTURE: " + name)

func sheet(stage: int) -> void:
	var ids: Array[StringName] = []
	for entry: Dictionary in Codex.get_dish_entries():
		if Sources.get_dish_stage(entry.id) == stage:
			ids.append(entry.id)
	var columns := 5
	var rows := ceili(float(ids.size()) / columns)
	var view := SubViewport.new()
	view.size = Vector2i(1600, 112 + rows * 330)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var bg := ColorRect.new()
	bg.size = Vector2(view.size)
	bg.color = Color("eadcc1")
	view.add_child(bg)
	text_at(view, ["中区菜单 · 开局原料", "左区菜单 · 第3天起", "右区菜单 · 第5天起", "BOSS 专属菜单"][stage - 1], Vector2(30, 16), Vector2(1540, 50), 32)
	text_at(view, "中区 → 左区 → 右区；三种初级酒开局全部提供", Vector2(30, 62), Vector2(1540, 35), 21)
	for index in range(ids.size()):
		var at := Vector2(24 + (index % columns) * 314, 108 + (index / columns) * 330)
		var panel := Panel.new()
		panel.position = at
		panel.size = Vector2(302, 316)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f5e9ce")
		style.set_corner_radius_all(12)
		panel.add_theme_stylebox_override("panel", style)
		view.add_child(panel)
		var icon := TextureRect.new()
		icon.position = at + Vector2(87, 0)
		icon.size = Vector2(128, 128)
		icon.texture = Items.get_item_texture(ids[index])
		view.add_child(icon)
		text_at(view, Items.get_item_display_name(ids[index]), at + Vector2(12, 128), Vector2(278, 32), 23)
		text_at(view, Codex._format_recipe(ids[index]), at + Vector2(12, 165), Vector2(278, 145), 17)
	await capture(view, "stage_%d" % stage)
	view.queue_free()
	await process_frame

func stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		stop_ticks(child)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for stage in range(1, 5):
		await sheet(stage)
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	stop_ticks(main)
	var flow: Node = main.get_node("LevelFlowController")
	flow.overlay_controller.set_transition_visible(false)
	flow.run_context.state = preload("res://Scripts/Core/LevelContext.gd").LevelState.MENU_DISH_SELECT
	flow._set_overlay_layout_mode(true)
	flow._set_overlay_visible(true)
	var offers: Array[StringName] = [Items.DISH_FOWL_SAND_ROLL_ID, Items.DISH_QINGMEI_SWEET_BOWL_ID, Items.DISH_SAND_POTATO_PLATE_ID]
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.content_scale_size = Vector2i(1920, 1080)
		root.size = size
		flow.menu_dish_select_controller.offer_selection_index = 0
		flow.menu_dish_select_controller.prepare_for_open(offers, flow.progression_state.get_menu_dish_ids(), 5, -1)
		flow.menu_dish_select_controller.move_replace_selection(1)
		flow.menu_dish_select_controller.move_replace_selection(1)
		await capture(root, "menu_%d" % size.x)
		var menu: Node = flow.menu_dish_select_controller
		var row: Control = menu.menu_row_controls[0][2]
		var visible_rect: Rect2 = menu.menu_scroll_containers[0].get_global_rect().intersection(flow.overlay_controller.cards_scroll.get_global_rect())
		assert(visible_rect.encloses(row.get_global_rect()), "Selected third recipe must remain fully visible")
	main.queue_free()
	paused = false
	await process_frame
	quit()
