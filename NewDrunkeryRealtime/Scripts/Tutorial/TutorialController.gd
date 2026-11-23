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
var practice_positions: Dictionary = {}

const TITLES = ["食材箱、切台与酒桶", "烤制与研磨", "组合料理与空盘", "点单与上菜", "收益与商店", "采集补充库存", "战斗与掉落", "小技能与大技能", "菜单与夜间生活"]
const BODIES = [
	"WASD 移动，面向目标操作。J 取放，K 加工。\n从脆芽箱取一份 → J 放到切台 → 连按 K，切好自动回到手中。\n再取一份生脆芽 → J 投入酒桶 → 等待酿好 → J 取一杯。\n备料桌可暂存物品，空手 J 也能拾回地面物品。",
	"把生碎金子放入烤台，自动经过微生、半熟、全熟，及时 J 取走。\n全熟后继续加热会焦糊；垃圾桶 J 可处理失误物品。\n取生晴天梅放磨台，按住 K 研磨；粗磨可提前 J 取出，再放回继续磨到细磨。\n磨完自动拿到小料盒，组合时按份使用，留意剩余份数。",
	"练习菜：脆芽冷盘 = 切脆芽 ×2。\n用 J 把两份切芽放进组合台，空手按 K 组合。\n到盘架 J 取空净盘，再面对组合台 J 装盘。\n非酒水菜必须用净盘，酒水有自己的杯子。盘子也能收集多份半成品。",
	"客人先点单，靠近上菜口按住 K 接单，才会出现菜谱与等餐耐心。\n按当前订单制作并 J 上菜。请将刚才的脆芽冷盘交给客人。\n上菜后手中变成脏盘：到净化池 J 放入，空手按住 J 净化。\n留意窗口编号与耐心；Tab 展开订单，L 查看当前食材来源。",
	"上菜获得金币和经验；升级得到祝福点，去女神像选择祝福。\n商店四栏：属性强化角色；厨房升级工作设施；设施增加运输、辅助或防守能力；冷冻食材补充原料。\n靠近商人按 K，使用 Q/E 浏览四个分类，K 退出。此处不要求购买。\n设施按 K 搬起、J 放置，搬运中 L 旋转支持旋转的设施；白天移动设施会消耗魔力。",
	"前往小地图上方的采集点，空手按住 K 搜寻。\n出现卡片后，按卡片所示的 W/A/S/D 选择一种收获。\n食材直接进入库存，再从箱子取用。中途打断会保留采集点。\n选项有时限；本练习给更长时间，超时会重新提供采集点。",
	"前往上方练习区，轻按 L 攻击沙原禽，按住 L 后松开可重击；Space 冲刺躲避。\n击杀后掉落禽肉，靠近掉落物 J 拾取即可。\n食材路线从中区开始，再左区、最后右区，路牌和 L 提示可以查来源。\n生命归零会原地晕眩10秒，以1血复活；每晚回满生命。",
	"U 释放小技能“抢灶步”：消耗魔力，短时加速，留意冷却；魔力自动恢复。\nI 释放大技能“稳住这锅”：加速工作，需大招能量充满。\n加工、采集、上菜与战斗都可积攒能量，教学已为本次练习充满。\n分别成功释放一次 U 和 I，体验后进入夜间。",
	"夜间没有营业倒计时：查看菜单 → 去女神像花祝福点 → 与 ! 访客交谈。\n组合台夜间按 K 查看菜单，新增菜时选择同类替换；小菜2、主菜2、甜品1，酒水单独保留。\n本次菜单会提供一道新菜；在女神像按 J 祈福，再与烤台旁访客 J 交谈。\n正式流程：备菜后营业、到点成功；夜间库存减半、生命回满。甜品可额外招待每位客人一次，不抵消原订单。"
]

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
	var keep = ["PrototypeMap", "Player", "Camera2D", "OrderHud", "RunStatusHud", "OrderManager", "StorageManager", "BattleManager", "ScarabMechanismController", "QuicksandMechanismController", "WindSandMechanismController", "LevelFlowController", "LevelRefs", "TestCooker", "BakeCooker", "GrindCooker", "AssemblyStation", "TestTable", "FixedBarrelLeftA", "TestServingCounter", "NightMerchant", "BlessingStatue", "PlateSink", "TrashBin", "StorageCabinetCrispSprout", "StorageCabinetGoldenWheat", "StorageCabinetSunnyBerry", "StorageCabinetDesertBird", "TutorialController"]
	for child: Node in main.get_children():
		if child is Node2D and child.name not in keep:
			child.free()
	var positions = {"StorageCabinetCrispSprout": Vector2(320, 800), "StorageCabinetGoldenWheat": Vector2(448, 800), "StorageCabinetSunnyBerry": Vector2(576, 800), "StorageCabinetDesertBird": Vector2(704, 800), "TestCooker": Vector2(512, 1088), "BakeCooker": Vector2(768, 1088), "GrindCooker": Vector2(1024, 1088), "AssemblyStation": Vector2(768, 1312), "TestTable": Vector2(1088, 1312), "FixedBarrelLeftA": Vector2(1472, 800), "PlateSink": Vector2(1408, 1280), "TrashBin": Vector2(1600, 1280), "NightMerchant": Vector2(1216, 800), "BlessingStatue": Vector2(960, 800), "TestServingCounter": Vector2(256, 1184)}
	for name: String in positions:
		main.get_node(name).global_position = positions[name]
	practice_positions = positions.duplicate()
	var counter: Node2D = main.get_node("TestServingCounter")
	counter.rotation = 0.0
	counter.scale = Vector2(.3, .25)
	counter._rebuild_slot_marker_positions()
	counter._ensure_highlight_nodes()
	counter._update_marker_layer()
	main.get_node("NightMerchant").always_visible = true
	for cabinet: Node in get_tree().get_nodes_in_group("storage_facilities"):
		cabinet.clear_menu_filter()
	var refs: Node = main.get_node("LevelRefs")
	refs.station_paths.assign([NodePath("../TestCooker"), NodePath("../BakeCooker"), NodePath("../GrindCooker"), NodePath("../AssemblyStation"), NodePath("../FixedBarrelLeftA"), NodePath("../TestTable"), NodePath("../TestServingCounter")])
	flow.run_setup_controller.station_nodes = refs.get_station_nodes()
	flow.progression_state.menu_non_drink_ids.assign([Items.DISH_CRISP_PLATE_ID, Items.DISH_WHITE_PLATE_ID])
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	preload("res://Scripts/Audio/AudioCue.gd").play_music(&"day")
	flow.run_context.selected_order_group = {"day_index": 0, "tutorial": true, "map_mechanism_ids": [], "menu_dish_ids": flow.progression_state.get_menu_dish_ids()}
	player.global_position = Vector2(896, 960)
	player.movement_bounds = main.get_node("PrototypeMap").get_world_bounds()
	var camera: Camera2D = main.get_node("Camera2D")
	camera.set_physics_process(false)
	camera.global_position = Vector2(896, 768)
	camera.zoom = Vector2.ONE * .72
	camera.reset_smoothing()
	camera.force_update_scroll()
	flow.night_shop_controller.purchase_completed.connect(func(_gold: int) -> void: record_event(&"purchase"))
	_build_hud()
	_reset_practice()
	get_tree().paused = false
	player.suppress_action_inputs_until_release()

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 75
	add_child(hud)
	panel = PanelContainer.new()
	panel.position = Vector2(26, 20)
	panel.size = Vector2(1868, 240)
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
			button.custom_minimum_size.y = 38
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
	flow.run_status_hud.day_clock.visible = false
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
			checks = [_check("取出全熟烤麦", events.has(&"roast_taken")), _check("完成一次研磨", events.has(&"grind_coarse") or events.has(&"grind_fine"))]
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
	checklist.text = "\n".join(checks.map(func(value: Dictionary) -> String: return ("✓ " if value.ok else "○ ") + String(value.text)))
	next_button.disabled = not ready_to_advance
	next_button.text = "教学完成 · Enter 返回标题" if step == 8 and ready_to_advance else ("下一课 → Enter" if ready_to_advance else "完成当前练习后继续")
	lesson_title.text = "教学 %d / 9  ·  %s" % [step + 1, TITLES[step]]
	lesson_body.text = BODIES[step]
	if step == 4:
		lesson_body.text = "刚才上菜获得 %d 金币、%d 经验。\n" % [int(events.get(&"earned_gold", 0)), int(events.get(&"earned_xp", 0))] + BODIES[step]

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
	var earned_gold: int = int(events.get(&"reward_gold", 0))
	var earned_xp: int = int(events.get(&"reward_xp", 0))
	_reset_practice()
	if step == 4:
		events[&"earned_gold"] = earned_gold
		events[&"earned_xp"] = earned_xp

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
	main.get_node("PlateSink").reset_state()
	if player.is_carrying_facility():
		player.facility_carry_controller.cancel_carry()
	for name: String in practice_positions:
		main.get_node(name).global_position = practice_positions[name]
	if step != 3:
		player.clear_held_item()
		for station: Node in [main.get_node("TestCooker"), main.get_node("BakeCooker"), main.get_node("GrindCooker"), main.get_node("AssemblyStation"), main.get_node("TestTable"), main.get_node("FixedBarrelLeftA")]:
			station.reset_state()
	for loose: Node in get_tree().get_nodes_in_group("loose_items"): loose.queue_free()
	if is_instance_valid(enemy): enemy.queue_free()
	if is_instance_valid(forage): forage.queue_free()
	events.clear()
	visited.clear()
	flow.order_manager.clear_orders()
	flow.storage_manager.fill_test_stock(20)
	for cabinet: Node in get_tree().get_nodes_in_group("storage_facilities"):
		cabinet.clear_menu_filter()
	player.reset_temporary_state()
	player.global_position = Vector2(896, 960)
	player.suppress_action_inputs_until_release()
	highlight_nodes.clear()
	match step:
		0: _targets(["StorageCabinetCrispSprout", "TestCooker", "FixedBarrelLeftA"])
		1: _targets(["StorageCabinetGoldenWheat", "StorageCabinetSunnyBerry", "BakeCooker", "GrindCooker", "TrashBin"])
		2: _targets(["TestCooker", "AssemblyStation", "PlateSink"])
		3:
			if not _holds(Items.DISH_CRISP_PLATE_ID):
				player.clear_held_item()
				main.get_node("AssemblyStation").reset_state()
				for count in range(2):
					main.get_node("AssemblyStation").stored_items.append({"item_id": Items.VEG_LEAF_ID, "process_state": Items.PROCESS_STATE_CUT, "texture": Items.get_item_texture(Items.VEG_LEAF_ID)})
				main.get_node("AssemblyStation").interact_with_player(player)
				main.get_node("PlateSink").rack.take_item_to_player(player)
				main.get_node("AssemblyStation").take_item_to_player(player)
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
			_targets(["TestCooker"])
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
	forage.global_position = Vector2(640, 480)
	highlight_nodes.assign([forage])

func _spawn_enemy() -> void:
	enemy = load("res://Scenes/Enemies/chicken_enemy.tscn").instantiate()
	enemy.max_health = 130
	enemy.move_speed = 75
	enemy.contact_damage = 2
	enemy.drop_item_id = Items.MEAT_WHITE_ID
	main.add_child(enemy)
	enemy.global_position = Vector2(1152, 480)
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
