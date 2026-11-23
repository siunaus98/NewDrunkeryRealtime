extends Node2D

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
const Style = preload("res://Scripts/UI/AtelierStyle.gd")
var main: Node
var flow: Node
var player: Node2D
var step := 0
var events: Dictionary = {}
var visited: Dictionary = {}
var ready_to_advance := false
var lesson_title: Label
var lesson_body: Label
var checklist: Label
var next_button: Button
var hud: CanvasLayer
var panel: PanelContainer
var forage: Node2D
var enemy: Node2D
var highlight_nodes: Array[Node2D] = []
var supply_clock := 0.0
var completed := false
var baseline_gold := 0
var baseline_xp := 0
var facility_templates: Dictionary = {}
var lesson_nodes: Array[Node] = []
var lesson_bounds := Rect2()
var lesson_progression_snapshot: Dictionary = {}
var earned_gold := 0
var earned_xp := 0

const TITLES = ["食材箱、切台与酒桶", "烤制与研磨", "组合料理与空盘", "点单与上菜", "收益与商店", "采集补充库存", "战斗与掉落", "小技能与大技能", "菜单与夜间生活"]
# Each lesson instantiates only its required facilities, with its own map bounds.
const LAYOUTS = [
	{"StorageCabinetCrispSprout": Vector2(384, 384), "TestCooker": Vector2(640, 384), "FixedBarrelLeftA": Vector2(960, 384)},
	{"StorageCabinetGoldenWheat": Vector2(384, 384), "BakeCooker": Vector2(640, 384), "StorageCabinetSunnyBerry": Vector2(896, 384), "GrindCooker": Vector2(1152, 384), "TrashBin": Vector2(1152, 768)},
	{"TestTable": Vector2(384, 384), "TutorialPrepTable": Vector2(640, 384), "AssemblyStation": Vector2(896, 512), "PlateSink": Vector2(512, 768)},
	{"TestServingCounter": Vector2(512, 384), "PlateSink": Vector2(896, 640)},
	{"NightMerchant": Vector2(512, 384)}, {}, {}, {},
	{"AssemblyStation": Vector2(384, 384), "BlessingStatue": Vector2(768, 384), "BakeCooker": Vector2(1152, 512)}
]
const MAP_SIZES = [Vector2(1024, 640), Vector2(1152, 768), Vector2(1152, 768), Vector2(1024, 768), Vector2(768, 640), Vector2(1024, 768), Vector2(1152, 768), Vector2(1024, 640), Vector2(1280, 768)]

func setup(scene: Node) -> void:
	main = scene
	flow = main.get_node("LevelFlowController")
	player = main.get_node("Player")
	process_mode = Node.PROCESS_MODE_ALWAYS
	flow.input_release_guard_active = false
	flow.day_transition_active = false
	flow.overlay_controller.set_transition_visible(false)
	flow._set_overlay_visible(false)
	flow._stop_map_mechanisms()
	flow.battle_manager.reset_runtime_state()
	flow.battle_manager.set_process(false)
	flow.order_manager.set_process(false)
	main.get_node("PrototypeLabel").hide()
	var keep = ["PrototypeMap", "Player", "Camera2D", "OrderHud", "RunStatusHud", "OrderManager", "StorageManager", "BattleManager", "ScarabMechanismController", "QuicksandMechanismController", "WindSandMechanismController", "LevelFlowController", "LevelRefs", "TestCooker", "BakeCooker", "GrindCooker", "AssemblyStation", "TestTable", "FixedBarrelLeftA", "TestServingCounter", "NightMerchant", "BlessingStatue", "PlateSink", "TrashBin", "StorageCabinetCrispSprout", "StorageCabinetGoldenWheat", "StorageCabinetSunnyBerry", "TutorialController"]
	for child: Node in main.get_children():
		if child is Node2D and child.name not in keep:
			child.free()
	for name: String in ["StorageCabinetCrispSprout", "StorageCabinetGoldenWheat", "StorageCabinetSunnyBerry", "TestCooker", "BakeCooker", "GrindCooker", "AssemblyStation", "TestTable", "FixedBarrelLeftA", "PlateSink", "TrashBin", "NightMerchant", "BlessingStatue", "TestServingCounter"]:
		var original: Node = main.get_node(name)
		var template := PackedScene.new()
		template.pack(original)
		facility_templates[name] = template
		original.free()
	flow.progression_state.menu_non_drink_ids.assign([Items.DISH_CRISP_PLATE_ID, Items.DISH_WHITE_PLATE_ID])
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	preload("res://Scripts/Audio/AudioCue.gd").play_music(&"day")
	flow.run_context.selected_order_group = {"day_index": 0, "tutorial": true, "map_mechanism_ids": [], "menu_dish_ids": flow.progression_state.get_menu_dish_ids()}
	flow.night_shop_controller.purchase_completed.connect(func(_gold: int) -> void: record_event(&"purchase"))
	_build_hud()
	lesson_progression_snapshot = flow.progression_state.get_snapshot()
	_reset_practice()
	get_tree().paused = false
	player.suppress_action_inputs_until_release()

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 75
	add_child(hud)
	panel = PanelContainer.new()
	panel.position = Vector2(26, 20)
	panel.size = Vector2(1868, 174)
	panel.add_theme_stylebox_override("panel", Style.panel())
	hud.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 25)
	margin.add_child(row)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	row.add_child(column)
	lesson_title = _label(29)
	column.add_child(lesson_title)
	lesson_body = _label(22)
	lesson_body.custom_minimum_size.y = 66
	column.add_child(lesson_body)
	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x = 300
	row.add_child(actions)
	checklist = _label(21)
	actions.add_child(checklist)
	next_button = Button.new()
	next_button.text = "完成当前练习后继续"
	next_button.pressed.connect(advance)
	actions.add_child(next_button)
	var retry := Button.new()
	retry.text = "重置当前练习 / 补给 · F5"
	retry.pressed.connect(_reset_practice)
	actions.add_child(retry)
	var leave := Button.new()
	leave.text = "返回标题"
	leave.pressed.connect(_leave)
	actions.add_child(leave)
	for button: Node in actions.get_children():
		if button is Button:
			button.custom_minimum_size.y = 32
			button.focus_mode = Control.FOCUS_NONE

func _label(size_value: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", Style.LIGHT)
	return label

func record_event(id: StringName) -> void:
	events[id] = true

func _process(delta: float) -> void:
	if not is_instance_valid(flow) or completed:
		return
	panel.visible = not get_tree().paused
	if step == 4 and flow.run_context.state == Context.LevelState.NIGHT_SHOP:
		visited[flow.night_shop_controller.selected_shop_category_index] = true
	if get_tree().paused:
		return
	_update_lesson_hud_visibility()
	supply_clock += delta
	if supply_clock >= 2.0:
		supply_clock = 0.0
		for id: StringName in [Items.VEG_LEAF_ID, Items.RICE_ID, Items.EGG_ID, Items.MEAT_WHITE_ID]:
			if flow.storage_manager.get_stock(id) < 6:
				flow.storage_manager.add_stock(id, 6)
	# Record this before hiding the panel, as the shop itself pauses the world.
	_update_objectives()
	queue_redraw()

func _input(_event: InputEvent) -> void:
	if not is_instance_valid(flow):
		return
	if step == 4 and flow.run_context.state == Context.LevelState.NIGHT_SHOP:
		visited[flow.night_shop_controller.selected_shop_category_index] = true
	if not get_tree().paused and _event is InputEventKey and _event.pressed and not _event.echo:
		if _event.keycode == KEY_ENTER and ready_to_advance:
			get_viewport().set_input_as_handled()
			advance()
		elif _event.keycode == KEY_F5:
			get_viewport().set_input_as_handled()
			_reset_practice()

func _update_objectives() -> void:
	var checks: Array[Dictionary] = []
	match step:
		0:
			if _holds(Items.VEG_LEAF_ID, Items.PROCESS_STATE_CUT): events[&"cut_taken"] = true
			if _holds(Items.DRINK_OASIS_WINE_ID): events[&"drink_taken"] = true
			checks = [_check("取回切好的脆芽", events.has(&"cut_taken")), _check("从酒桶取出酒水", events.has(&"drink_taken"))]
		1:
			if _holds(Items.RICE_ID, Items.PROCESS_STATE_ROAST_WELL): events[&"roast_taken"] = true
			checks = [_check("取出全熟碎金子", events.has(&"roast_taken")), _check("完成一次研磨", events.has(&"grind_coarse") or events.has(&"grind_fine"))]
		2: checks = [_check("组合并持有装盘冷菜", _holds(Items.DISH_CRISP_PLATE_ID) and bool(player.get_held_item_payload().get("uses_plate", false)))]
		3: checks = [_check("按住K接单", events.has(&"order")), _check("交付冷菜", events.has(&"serve")), _check("净化脏盘", events.has(&"wash"))]
		4:
			checks = [_check("浏览商店四个分类", visited.size() == 4), _check("退出商店", flow.is_night_rest_active())]
		5:
			checks = [_check("完成一次采集并入库", events.has(&"forage"))]
			if not events.has(&"forage") and (not is_instance_valid(forage) or forage.is_queued_for_deletion()): _spawn_forage()
		6:
			checks = [_check("使用一次冲刺", events.has(&"dash")), _check("击败练习沙原禽", events.has(&"kill")), _check("拾取掉落的禽肉", events.has(&"kill") and _holds(Items.MEAT_WHITE_ID))]
		7:
			if player.skill_controller.get_small_skill_remaining() > 0: events[&"small"] = true
			if player.skill_controller.is_big_skill_buff_active(): events[&"big"] = true
			checks = [_check("释放一次小技能 U", events.has(&"small")), _check("释放一次大技能 I", events.has(&"big"))]
		8:
			if flow.progression_state.menu_non_drink_ids.size() > 2: events[&"menu"] = true
			checks = [_check("选择一道新菜", events.has(&"menu")), _check("获得一次祝福", not flow.get_owned_blessing_ids().is_empty()), _check("完成或谢绝夜间访客", flow.progression_state.events.is_complete(&"furnace"))]
	ready_to_advance = not checks.is_empty() and checks.all(func(value: Dictionary) -> bool: return bool(value.ok))
	checklist.text = "已完成 %d / %d" % [checks.filter(func(value: Dictionary) -> bool: return bool(value.ok)).size(), checks.size()]
	next_button.disabled = not ready_to_advance
	next_button.text = "教学完成 · Enter 返回标题" if step == 8 and ready_to_advance else ("下一课 → Enter" if ready_to_advance else "完成当前练习后继续")
	lesson_title.text = "教学 %d / 9  ·  %s" % [step + 1, TITLES[step]]
	_update_current_instruction()

func _guide(text: String, targets: Array = []) -> void:
	lesson_body.text = text
	highlight_nodes.clear()
	for target in targets:
		var node: Node = main.get_node_or_null(target) if target is String else target
		if is_instance_valid(node): highlight_nodes.append(node)

func _update_current_instruction() -> void:
	if ready_to_advance:
		_guide("本关完成！按 Enter 进入下一张教学地图。" if step < 8 else "教学完成！按 Enter 返回标题，开始正式冒险。")
		return
	match step:
		0:
			if not events.has(&"cut_taken"):
				if _holds(Items.VEG_LEAF_ID):
					_guide("面对切台按 J 放入脆芽，再连按 K 切好。切好的食材会自动回到手中。", ["TestCooker"])
				elif main.get_node("TestCooker").has_item:
					_guide("面对切台连按 K，完成切配。", ["TestCooker"])
				else:
					_guide("WASD 移动。靠近脆芽箱，空手按 J 取一份脆芽。", ["StorageCabinetCrispSprout"])
			else:
				var barrel: Node = main.get_node("FixedBarrelLeftA")
				if player.is_holding_item() and not _holds(Items.VEG_LEAF_ID, Items.PROCESS_STATE_NONE):
					_guide("按 J 放下手中的切芽，再到食材箱按 J 取一份生脆芽。", ["StorageCabinetCrispSprout"])
				elif not player.is_holding_item() and barrel.current_drink_item_id == &"":
					_guide("从脆芽箱按 J 取生脆芽，准备酿酒。", ["StorageCabinetCrispSprout"])
				else:
					_guide("把生脆芽按 J 投入酒桶。酿好后空手按 J 取酒。", ["FixedBarrelLeftA"])
		1:
			if not events.has(&"roast_taken"):
				_guide("碎金子箱 J 取料 → 烤台 J 放入。等到“全熟”后及时 J 取走，久烤会焦糊。", ["BakeCooker"] if _holds(Items.RICE_ID) or main.get_node("BakeCooker").has_item else ["StorageCabinetGoldenWheat"])
			else:
				_guide("放下手中物品。从晴天梅箱 J 取料 → 磨台 J 放入 → 按住 K 研磨。", ["GrindCooker"] if _holds(Items.EGG_ID) or main.get_node("GrindCooker").has_item else ["StorageCabinetSunnyBerry"])
		2:
			var assembly: Node = main.get_node("AssemblyStation")
			if not assembly.stored_items.is_empty() and assembly.stored_items[0].item_id == Items.DISH_CRISP_PLATE_ID:
				_guide("成品需要净盘：到盘架 J 取空盘，再面对组合台 J 装盘。", ["AssemblyStation"] if _holds(Items.PLATE_ID) else ["PlateSink"])
			elif assembly.stored_items.size() >= 2:
				_guide("两份切芽已就位。空手面对组合台按 K，组合成脆芽冷盘。", ["AssemblyStation"])
			else:
				_guide("备料桌上各有一份切芽。J 取走，再面对组合台 J 放入；共需要两份。", ["AssemblyStation"] if player.is_holding_item() else ["TestTable", "TutorialPrepTable"])
		3:
			if not events.has(&"order"):
				_guide("手中已准备好一盘冷菜。走近客人，按住 K 接单。", ["TestServingCounter"])
			elif not events.has(&"serve"):
				_guide("客人要一份脆芽冷盘。面对上菜口按 J 交付手中菜品。", ["TestServingCounter"])
			else:
				_guide("脏盘按 J 放进净化池，再空手按住 J 清洗。洗净的盘子会回到盘架。", ["PlateSink"])
		4:
			_guide("上菜获得 %d 金币、%d 经验。靠近商人按 K，Q/E 浏览四个分类，再按 K 退出。\n属性强化角色；厨房升级工作台；设施添置设备；冷冻食材补充原料。" % [int(events.get(&"earned_gold", 0)), int(events.get(&"earned_xp", 0))], ["NightMerchant"])
		5:
			if is_instance_valid(forage) and forage.state == forage.ForageState.SELECTING:
				_guide("按卡片上的 W/A/S/D 选择一种收获，食材会直接进入库存。", [forage])
			else:
				_guide("靠近采集点，空手按住 K 搜寻。中途松开会中断，采集点会保留。", [forage])
		6:
			if not events.has(&"dash"):
				_guide("按 Space 冲刺一次，练习躲避。", [enemy])
			elif not events.has(&"kill"):
				_guide("靠近沙原禽，按 L 攻击。也可按住 L 后松开，发动重击。", [enemy])
			else:
				_guide("靠近地上的禽肉按 J 拾取，完成一次战斗取材。", get_tree().get_nodes_in_group("loose_items"))
		7:
			if not events.has(&"small"):
				_guide("按 U 释放小技能“抢灶步”，体验短时加速。技能消耗魔力，魔力会自动恢复。")
			else:
				_guide("按 I 释放大技能“稳住这锅”。平时通过工作和战斗积攒能量，本次已充满。")
		8:
			if not events.has(&"menu"):
				_guide("夜间可以规划下一天。面对组合台按 K 打开菜单，选入一道新菜。", ["AssemblyStation"])
			elif flow.get_owned_blessing_ids().is_empty():
				_guide("经验升级会获得祝福点。面对女神像按 J 祈福，选择一项祝福。", ["BlessingStatue"])
			else:
				_guide("夜间设施会迎来访客。靠近烤台旁带 ! 的访客按 J 交谈，可接受或谢绝。", [flow.night_event_controller.npcs.get(&"furnace")])

func _update_lesson_hud_visibility() -> void:
	var status: Node = flow.run_status_hud
	status.day_clock.visible = false
	status.reputation_panel.visible = false
	status.gold_panel.visible = step in [3, 4, 8]
	status.xp_panel.visible = step in [3, 4, 8]
	status.magic_panel.visible = step == 7
	if step == 7:
		status.magic_panel.position = Vector2(1804, 224)
	status.skill_bar_root.visible = step in [6, 7]
	status.skill_slot_small.visible = step == 7
	status.skill_slot_big.visible = step == 7

func _build_lesson_map() -> void:
	# Free actual collision bodies and targets, rather than hiding unused props.
	highlight_nodes.clear()
	for node: Node in lesson_nodes:
		if is_instance_valid(node): node.free()
	lesson_nodes.clear()
	var map: Node = main.get_node("PrototypeMap")
	lesson_bounds = Rect2(Vector2(128, 128), MAP_SIZES[step])
	map.configure_tutorial_lesson(step, lesson_bounds, step in [5, 6])
	for name: String in LAYOUTS[step]:
		var template_name := "TestTable" if name == "TutorialPrepTable" else name
		var node: Node2D = facility_templates[template_name].instantiate()
		node.name = name
		node.position = LAYOUTS[step][name]
		node.visible = true
		if name == "NightMerchant": node.always_visible = true
		if name == "TestServingCounter":
			node.rotation = 0
			node.scale = Vector2(.3, .25)
		main.add_child(node)
		lesson_nodes.append(node)
	var refs: Node = main.get_node("LevelRefs")
	refs.station_paths.clear()
	for node: Node in lesson_nodes:
		if node.has_method("reset_state"): refs.station_paths.append(NodePath("../" + String(node.name)))
	flow.run_setup_controller.station_nodes = refs.get_station_nodes()
	flow.serving_counter = refs.get_serving_counter()
	player.movement_bounds = lesson_bounds
	player.global_position = lesson_bounds.get_center() + Vector2(-64, 144)
	var camera: Camera2D = main.get_node("Camera2D")
	camera.set_physics_process(false)
	camera.zoom = Vector2.ONE * (.88 if lesson_bounds.size.y > 640 else 1.05)
	camera.global_position = lesson_bounds.get_center() - Vector2(0, 60)
	camera.reset_smoothing()
	camera.force_update_scroll()

func _provide_prepared_sprouts() -> void:
	for name: String in ["TestTable", "TutorialPrepTable"]:
		var table: Node = main.get_node(name)
		player.pick_up_item(Items.VEG_LEAF_ID, Items.get_item_texture(Items.VEG_LEAF_ID), Items.PROCESS_STATE_CUT)
		table.receive_item_from_player(player)

func _provide_plated_dish() -> void:
	var components: Array[Dictionary] = []
	for index in range(2):
		components.append({"item_id": Items.VEG_LEAF_ID, "process_state": Items.PROCESS_STATE_CUT})
	var recipe: Dictionary = Items.find_matching_recipe(components, false)
	player.pick_up_item(Items.DISH_CRISP_PLATE_ID, Items.get_item_texture(Items.DISH_CRISP_PLATE_ID), Items.PROCESS_STATE_NONE, String(recipe.get("recipe_signature", "")), {"uses_plate": true})

func _check(value: String, ok: bool) -> Dictionary:
	return {"text": value, "ok": ok}

func _holds(id: StringName, state_value: StringName = &"") -> bool:
	return player.get_held_item_id() == id and (state_value == &"" or player.get_held_item_process_state() == state_value)

func advance() -> void:
	_update_objectives()
	if not ready_to_advance:
		return
	if step == 8:
		completed = true
		_leave()
		return
	step += 1
	if step == 4:
		earned_gold = int(events.get(&"reward_gold", 0))
		earned_xp = int(events.get(&"reward_xp", 0))
	lesson_progression_snapshot = flow.progression_state.get_snapshot()
	_reset_practice()

func _reset_practice() -> void:
	if not is_instance_valid(flow): return
	get_tree().paused = false
	flow._set_overlay_visible(false)
	flow._set_blessing_overlay_visible(false)
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	flow.magic_current = flow.magic_max
	if player.interaction_controller != null:
		var target: Node = player.interaction_controller.get_current_interaction_target()
		if is_instance_valid(target) and target.has_method("cancel_interaction"):
			target.cancel_interaction(player)
		player.interaction_controller._set_current_interaction_target(null)
	if player.is_carrying_facility():
		player.facility_carry_controller.cancel_carry()
	player.clear_held_item()
	for loose: Node in get_tree().get_nodes_in_group("loose_items"): loose.free()
	if is_instance_valid(enemy): enemy.queue_free()
	if is_instance_valid(forage): forage.queue_free()
	var visitors: Node = flow.night_event_controller
	for visitor: Node in visitors.npcs.values():
		if is_instance_valid(visitor): visitor.free()
	visitors.npcs.clear()
	visitors.hosts.clear()
	visitors.spawned_night = -1
	visitors.active_id = &""
	flow.order_manager.clear_orders()
	flow.progression_state.apply_snapshot(lesson_progression_snapshot)
	_build_lesson_map()
	events.clear()
	if step == 4:
		events[&"earned_gold"] = earned_gold
		events[&"earned_xp"] = earned_xp
	visited.clear()
	flow.order_manager.clear_orders()
	flow.storage_manager.fill_test_stock(20)
	for cabinet: Node in get_tree().get_nodes_in_group("storage_facilities"):
		cabinet.clear_menu_filter()
	player.reset_temporary_state()
	if is_instance_valid(player.interaction_controller.hint_label):
		player.interaction_controller.hint_generation += 1
		player.interaction_controller.hint_label.hide()
	player.suppress_action_inputs_until_release()
	highlight_nodes.clear()
	match step:
		2: _provide_prepared_sprouts()
		3:
			_provide_plated_dish()
			var order := preload("res://Scripts/Orders/OrderGroupDefs.gd")._order("TUTORIAL", 1, Items.DISH_CRISP_PLATE_ID, 3600.0)
			order["order_take_patience_duration"] = 3600.0
			flow.order_manager.add_orders([order])
			baseline_gold = flow.progression_state.gold
			baseline_xp = flow.progression_state.xp
			_targets(["TestServingCounter", "PlateSink"])
		4:
			flow.run_context.state = Context.LevelState.NIGHT_REST
			preload("res://Scripts/Audio/AudioCue.gd").play_music(&"night")
			_targets(["NightMerchant"])
		5: _spawn_forage()
		6: _spawn_enemy()
		7:
			player.fill_ultimate_energy()
		8:
			flow.run_context.state = Context.LevelState.NIGHT_REST
			flow.progression_state.day_index = 1
			flow.progression_state.blessing_points = maxi(flow.progression_state.blessing_points, 1)
			flow.progression_state.create_next_non_drink_offer()
			flow.progression_state.events.night_index = 1
			flow.progression_state.events.event_id = &"furnace"
			flow.progression_state.events.resolved = false
			flow.night_event_controller.refresh_night()
			_targets(["AssemblyStation", "BlessingStatue", "BakeCooker"])
	flow.overlay_controller.hide_toast()
	_update_lesson_hud_visibility()
	_update_objectives()

func _targets(names: Array) -> void:
	for name: String in names:
		highlight_nodes.append(main.get_node(name))

func _spawn_forage() -> void:
	forage = load("res://Scenes/Forage/forage_point.tscn").instantiate()
	forage.search_duration = 3.0
	forage.selection_duration = 5.0
	forage.forage_item_ids.assign([Items.VEG_LEAF_ID, Items.RICE_ID, Items.EGG_ID])
	forage.remove_after_attempt = true
	main.add_child(forage)
	forage.global_position = lesson_bounds.get_center() - Vector2(0, 128)
	highlight_nodes.assign([forage])

func _spawn_enemy() -> void:
	enemy = load("res://Scenes/Enemies/chicken_enemy.tscn").instantiate()
	enemy.max_health = 130
	enemy.move_speed = 75
	enemy.contact_damage = 2
	enemy.drop_item_id = Items.MEAT_WHITE_ID
	main.add_child(enemy)
	enemy.global_position = lesson_bounds.get_center() + Vector2(192, -64)
	enemy.setup_for_battle(Items.MEAT_WHITE_ID, main.get_node("PrototypeMap").get_region_bounds(&"near"))
	enemy.defeated.connect(func(_actor: Node2D, id: StringName, _count: int, at: Vector2) -> void:
		record_event(&"kill")
		var item: Node2D = load("res://Scenes/Restaurant/loose_item.tscn").instantiate()
		main.add_child(item)
		item.global_position = at
		item.setup_item(id, Items.get_item_texture(id), Items.PROCESS_STATE_NONE)
	)
	highlight_nodes.assign([enemy])

func _draw() -> void:
	for node: Node2D in highlight_nodes:
		if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
		draw_arc(node.global_position, 76, 0, TAU, 40, Color("f4d796"), 3, true)

func _leave() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Main/game_start.tscn")
