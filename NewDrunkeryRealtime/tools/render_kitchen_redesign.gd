extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Carry = preload("res://Scripts/Kitchen/CarryItemRules.gd")

func _initialize() -> void:
	call_deferred("_render")

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is CanvasLayer:
		node.hide()
	for child: Node in node.get_children():
		_stop_ticks(child)

func _render() -> void:
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	viewport.add_child(main)
	await process_frame
	paused = false
	_stop_ticks(main)
	for child: Node in main.get_children():
		if child is CanvasLayer:
			child.hide()
	var camera: Camera2D = main.get_node("Camera2D")
	camera.position = Vector2(2304, 1120)
	camera.zoom = Vector2.ONE * 0.72
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	camera.force_update_scroll()
	var player: Node = main.get_node("Player")
	player.position = Vector2(2590, 1370)
	player.clear_held_item()
	player.pick_up_item(Items.SEASONING_BOX_ID, Items.get_item_texture(Items.SEASONING_BOX_ID), &"", "", Carry.seasoning(Items.SUN_SEED_ID, Items.PROCESS_STATE_GRIND_FINE))
	main.get_node("PrepTableA").receive_item_from_player(player)
	player.pick_up_item(Items.PLATE_ID, Items.get_item_texture(Items.PLATE_ID))
	player.pick_up_item(Items.MEAT_RED_ID, Items.get_item_texture(Items.MEAT_RED_ID), Items.PROCESS_STATE_ROAST_MEDIUM)
	player.pick_up_item(Items.VEG_LEAF_ID, Items.get_item_texture(Items.VEG_LEAF_ID), Items.PROCESS_STATE_CUT)
	main.get_node("PrepTableB").receive_item_from_player(player)
	player.pick_up_item(Items.MEAT_RED_ID, Items.get_item_texture(Items.MEAT_RED_ID))
	var roast: Node = main.get_node("BakeCooker")
	roast.receive_item_from_player(player)
	roast._advance_processing(roast.auto_process_duration * 0.5, null)
	player.pick_up_item(Items.DIRTY_PLATE_ID, Items.get_item_texture(Items.DIRTY_PLATE_ID))
	player.interaction_controller._set_current_interaction_target(main.get_node("PlateSink"))
	var carry_mode: bool = "--carry" in OS.get_cmdline_user_args()
	if carry_mode:
		var sink: Node2D = main.get_node("PlateSink")
		sink.clean_plates = 2
		sink.dirty_plates = 1
		sink._refresh()
		player.clear_held_item()
		player.position = Vector2(3190, 1340)
		player.aim_direction = Vector2.DOWN
		player._pick_up_facility(sink)
		player.interaction_controller.update_interaction_progress_ui()
	for _frame in range(6):
		await process_frame
		RenderingServer.force_draw(false)
		await RenderingServer.frame_post_draw
	var output: String = "D:/NP/NewDrunkeryRealtime/_artifact_work/kitchen_redesign/kitchen.png"
	if carry_mode:
		output = "D:/NP/NewDrunkeryRealtime/_artifact_work/kitchen_redesign/kitchen_carry.png"
	var result: Error = viewport.get_texture().get_image().save_png(output)
	print("Kitchen render: %s result=%d" % [output, result])
	viewport.queue_free()
	await process_frame
	quit(result)
