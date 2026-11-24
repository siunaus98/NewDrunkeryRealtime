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
var facility_templates: Dictionary = {}
var lesson_nodes: Array[Node] = []
var lesson_bounds := Rect2()
var lesson_progression_snapshot: Dictionary = {}
var earned_gold := 0
var earned_xp := 0
var info_page := 0
var info_button: Button
var actions: VBoxContainer
var ui_highlight: Panel
var magic_hint: Label
var drop_stock_before := 0
var practice_time_remaining := 180.0

const TITLES = ["制作第一道料理", "盘子、接单与上菜", "烤制与研磨", "酒水与菜品", "甜品额外招待", "精英客人的逐道点单", "收益与商店", "采集补充库存", "战斗与掉落", "小技能与大技能", "菜单与夜间生活", "BOSS日与特殊客人"]
const SHOP := 6
const FORAGE := 7
const COMBAT := 8
const SKILLS := 9
const NIGHT := 10
const BOSS := 11
const LAYOUTS = [
	{"StorageCabinetCrispSprout": Vector2(384, 384), "TestCooker": Vector2(640, 384), "AssemblyStation": Vector2(960, 512)},
	{"AssemblyStation": Vector2(384, 512), "PlateSink": Vector2(768, 768), "TestServingCounter": Vector2(1152, 384)},
	{"StorageCabinetGoldenWheat": Vector2(384, 384), "BakeCooker": Vector2(640, 384), "StorageCabinetSunnyBerry": Vector2(896, 384), "GrindCooker": Vector2(1152, 384), "TutorialPrepTableA": Vector2(384, 704), "TutorialPrepTableB": Vector2(640, 704), "TrashBin": Vector2(1152, 768)},
	{"StorageCabinetCrispSprout": Vector2(384, 384), "FixedBarrelLeftA": Vector2(704, 384), "TestServingCounter": Vector2(1088, 384), "RecipeBook": Vector2(704, 768)},
	{"TestTable": Vector2(384, 384), "TestServingCounter": Vector2(1088, 384), "PlateSink": Vector2(768, 768), "TutorialDishTable": Vector2(384, 768)},
	{"TestTable": Vector2(384, 384), "TutorialDishTable": Vector2(640, 384), "TutorialMainTable": Vector2(896, 384), "TestServingCounter": Vector2(1216, 512), "PlateSink": Vector2(768, 768)},
	{"NightMerchant": Vector2(512, 384)}, {}, {},
	{"StorageCabinetCrispSprout": Vector2(384, 384), "TestCooker": Vector2(640, 384), "TestTable": Vector2(896, 384)},
	{"BlessingStatue": Vector2(640, 384), "BakeCooker": Vector2(1024, 384)},
	{}
]
const MAP_SIZES = [Vector2(1152, 768), Vector2(1280, 768), Vector2(1408, 896), Vector2(1152, 768), Vector2(1152, 768), Vector2(1280, 768), Vector2(768, 640), Vector2(1024, 768), Vector2(1152, 768), Vector2(1152, 768), Vector2(1280, 768), Vector2(1280, 768)]
var highlight_clock := 0.0
var target_label: Label
var last_guide_text := ""
var guide_portrait: Control

func setup(scene: Node) -> void:
	main = scene
	step = clampi(int(main.run_setup.get("tutorial_step", 0)), 0, BOSS)
	flow = main.get_node("LevelFlowController")
	player = main.get_node("Player")
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 180
	flow.order_manager.order_completed.connect(_record_service)
	flow.order_manager.dessert_served.connect(_record_dessert)
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
	target_label = _label(22)
	target_label.add_theme_color_override("font_color", Color("ffea90"))
	target_label.add_theme_color_override("font_outline_color", Color("3c2b16"))
	target_label.add_theme_constant_override("outline_size", 6)
	target_label.text = "▼ 下一步"
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.size = Vector2(180, 36)
	add_child(target_label)
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
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 26
	panel.offset_top = -174
	panel.offset_right = -26
	panel.offset_bottom = -20
	panel.add_theme_stylebox_override("panel", Style.panel())
	hud.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 25)
	margin.add_child(row)
	guide_portrait = preload("res://Scripts/Tutorial/TutorialGuideNPC.gd").new()
	guide_portrait.name = "GuidePortrait"
	row.add_child(guide_portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	row.add_child(column)
	lesson_title = _label(29)
	column.add_child(lesson_title)
	lesson_body = _label(22)
	lesson_body.custom_minimum_size.y = 66
	column.add_child(lesson_body)
	info_button = Button.new()
	info_button.text = "听下一句 →"
	info_button.focus_mode = Control.FOCUS_NONE
	info_button.pressed.connect(_next_info_page)
	info_button.visible = false
	column.add_child(info_button)
	actions = VBoxContainer.new()
	actions.custom_minimum_size = Vector2(300, 150)
	actions.position = Vector2(1580, 20)
	hud.add_child(actions)
	checklist = _label(21)
	actions.add_child(checklist)
	next_button = Button.new()
	next_button.text = "完成当前练习后继续"
	next_button.pressed.connect(_skip_to_next)
	actions.add_child(next_button)
	var retry := Button.new()
	retry.text = "重置当前练习 / 补给 · F5"
	retry.pressed.connect(_reset_practice)
	actions.add_child(retry)
	var leave := Button.new()
	leave.text = "退出 · 教学选关"
	leave.pressed.connect(_leave)
	actions.add_child(leave)
	for button: Node in actions.get_children():
		if button is Button:
			button.custom_minimum_size.y = 32
			button.focus_mode = Control.FOCUS_NONE

	ui_highlight = Panel.new()
	ui_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var highlight_style := StyleBoxFlat.new()
	highlight_style.bg_color = Color(1, .86, .3, .06)
	highlight_style.border_color = Color("ffe199")
	highlight_style.set_border_width_all(4)
	highlight_style.set_corner_radius_all(12)
	ui_highlight.add_theme_stylebox_override("panel", highlight_style)
	hud.add_child(ui_highlight)
	magic_hint = _label(22)
	magic_hint.text = "魔力 · U 消耗 / 自动恢复"
	magic_hint.position = Vector2(1460, 590)
	magic_hint.size = Vector2(420, 34)
	magic_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(magic_hint)

func _next_info_page() -> void:
	info_page += 1
	_update_objectives()

func _label(size_value: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", Style.LIGHT)
	return label

func record_event(id: StringName) -> void:
	events[id] = true
	if step == SKILLS and id == &"cut" and events.has(&"small"):
		if not events.has(&"skill_cut_before") and not player.skill_controller.is_big_skill_buff_active():
			events[&"skill_cut_before"] = true
		elif events.has(&"skill_cut_before") and player.skill_controller.is_big_skill_buff_active():
			events[&"skill_cut_after"] = true
	if id == &"order": _on_order_taken()

func _process(delta: float) -> void:
	if not is_instance_valid(flow) or completed:
		return
	panel.visible = not get_tree().paused
	actions.visible = panel.visible
	ui_highlight.visible = panel.visible and (step == SKILLS or step == 1 and info_page < 2)
	magic_hint.visible = panel.visible and step == SKILLS and not events.has(&"small")
	target_label.visible = panel.visible and not highlight_nodes.is_empty()
	highlight_clock += delta
	if step == 3 and main.codex_controller.is_open(): events[&"dish_book"] = true
	if step == SHOP and flow.run_context.state == Context.LevelState.NIGHT_SHOP:
		visited[flow.night_shop_controller.selected_shop_category_index] = true
	if get_tree().paused:
		return
	if step == 1: practice_time_remaining = maxf(practice_time_remaining - delta, 0.0)
	_update_lesson_hud_visibility()
	supply_clock += delta
	if supply_clock >= 2.0:
		supply_clock = 0.0
		for id: StringName in [Items.VEG_LEAF_ID, Items.RICE_ID, Items.EGG_ID, Items.MEAT_WHITE_ID]:
			if flow.storage_manager.get_stock(id) < 6:
				flow.storage_manager.add_stock(id, 6)
	# Record this before hiding the panel, as the shop itself pauses the world.

	_update_objectives()
	_update_highlights()
	queue_redraw()

func _input(_event: InputEvent) -> void:
	if not is_instance_valid(flow):
		return
	if step == SHOP and flow.run_context.state == Context.LevelState.NIGHT_SHOP:
		visited[flow.night_shop_controller.selected_shop_category_index] = true
	if not get_tree().paused and _event is InputEventKey and _event.pressed and not _event.echo:
		if _event.keycode == KEY_ENTER and info_button.visible:
			get_viewport().set_input_as_handled()
			_next_info_page()
		elif _event.keycode == KEY_ENTER and ready_to_advance:
			get_viewport().set_input_as_handled()
			advance()
		elif _event.keycode == KEY_F5:
			get_viewport().set_input_as_handled()
			_reset_practice()

func _record_service(data: Dictionary) -> void:
	events[&"courses"] = int(events.get(&"courses", 0)) + 1
	if step == 1:
		earned_gold = int(data.get("gold_reward", 0))
		earned_xp = int(data.get("xp_reward", 0))

func _on_order_taken() -> void:
	if step in [4, 5] and flow.order_manager.customers.has("slot:1"):
		var customer: Dictionary = flow.order_manager.customers["slot:1"]
		customer["time_remaining"] = float(customer.patience_duration) * .45
		flow.order_manager._publish_customer_progress("slot:1")

func _record_dessert(_data: Dictionary) -> void:
	record_event(&"dessert")
	if step == 4:
		_stage_dish("TutorialDishTable", Items.DISH_CRISP_PLATE_ID)

func _dish_ready() -> bool:
	var assembly: Node = main.get_node_or_null("AssemblyStation")
	return is_instance_valid(assembly) and not assembly.stored_items.is_empty() and assembly.stored_items[0].item_id == Items.DISH_CRISP_PLATE_ID

func _update_objectives() -> void:
	var checks: Array[Dictionary] = []
	match step:
		0: checks = [_check("组合脆芽冷盘", _dish_ready())]
		1: checks = [_check("装盘", events.has(&"plated")), _check("接单", events.has(&"order")), _check("上菜", events.has(&"serve")), _check("洗盘", events.has(&"wash"))]
		2:
			if _holds(Items.RICE_ID, Items.PROCESS_STATE_ROAST_WELL): events[&"roast_taken"] = true
			if _holds(Items.SEASONING_BOX_ID): events[&"grind_taken"] = true
			checks = [_check("全熟烤料", events.has(&"roast_taken")), _check("取出研磨小料盒", events.has(&"grind_taken"))]
		3: checks = [_check("接单并交付酒水", int(events.get(&"courses", 0)) > 0), _check("查看菜品图鉴并返回", events.has(&"dish_book") and not main.codex_controller.is_open())]
		4: checks = [_check("额外招待甜品", events.has(&"dessert")), _check("原订单仍需完成", int(events.get(&"courses", 0)) > 0)]
		5: checks = [_check("依次完成三道菜", int(events.get(&"courses", 0)) == 3)]
		SHOP: checks = [_check("浏览四栏", visited.size() == 4), _check("退出商店", flow.is_night_rest_active())]
		FORAGE:
			checks = [_check("采集入库", events.has(&"forage"))]
			if not events.has(&"forage") and (not is_instance_valid(forage) or forage.is_queued_for_deletion()): _spawn_forage()
		COMBAT: checks = [_check("冲刺", events.has(&"dash")), _check("击败沙原禽", events.has(&"kill")), _check("触碰掉落入库", events.has(&"kill") and flow.storage_manager.get_stock(Items.MEAT_WHITE_ID) > drop_stock_before)]
		SKILLS:
			if player.skill_controller.get_small_skill_remaining() > 0: events[&"small"] = true
			if player.skill_controller.is_big_skill_buff_active(): events[&"big"] = true
			checks = [_check("普通切配", events.has(&"skill_cut_before")), _check("小技能", events.has(&"small")), _check("大招切配", events.has(&"skill_cut_after"))]
		NIGHT:
			checks = [_check("了解夜间", info_page > 0), _check("祝福", not flow.get_owned_blessing_ids().is_empty()), _check("访客", flow.progression_state.events.is_complete(&"furnace"))]
		BOSS: checks = [_check("了解 BOSS 和特殊客人", info_page >= 3)]
	if step == 1 and _holds(Items.DISH_CRISP_PLATE_ID): events[&"plated"] = true
	ready_to_advance = not checks.is_empty() and checks.all(func(value: Dictionary) -> bool: return bool(value.ok))
	checklist.text = "已完成 %d / %d" % [checks.filter(func(value: Dictionary) -> bool: return bool(value.ok)).size(), checks.size()]
	next_button.disabled = false
	next_button.text = "直接进入下一关 →" if not ready_to_advance else ("教学完成 · 返回选关" if step == BOSS else "进入下一关 →")
	if step == BOSS and not ready_to_advance: next_button.text = "返回教学选关"
	lesson_title.text = "教学 %d / %d  ·  %s" % [step + 1, TITLES.size(), TITLES[step]]
	info_button.visible = step == BOSS and info_page < 3 or step in [NIGHT, COMBAT] and info_page == 0 or step == 1 and info_page < 2
	_update_current_instruction()
	panel.offset_top = -210 if info_button.visible else -174
	_update_lesson_hud_visibility()

func _guide(text: String, targets: Array = []) -> void:
	if text != last_guide_text:
		last_guide_text = text
		lesson_body.text = "小沙：" + text
	for node: Node2D in highlight_nodes:
		if is_instance_valid(node):
			node.modulate = Color.WHITE
			if node.has_method("set_guidance_highlight"): node._update_highlight_visual()
	highlight_nodes.clear()
	for target in targets:
		var node: Node = main.get_node_or_null(target) if target is String else target
		if is_instance_valid(node): highlight_nodes.append(node)


func _update_current_instruction() -> void:
	if ready_to_advance and step != BOSS:
		_guide("料理做好了，先留在组合台上。按 Enter 到下一关学习装盘和上菜。" if step == 0 else ("本关拿下！厨房暂时安全了。按 Enter 去下一关。" if step < BOSS else "教学完成！按 Enter 返回标题，开始正式冒险。"))
		return
	match step:
		0: _guide_cooking()
		1:
			if info_page == 0: _guide("先抬头看发光的时钟：这里显示营业倒计时。到点当天营业结束；在那之前客人会源源不断地逐个到来。练习关不计时失败，放心学！")
			elif info_page == 1: _guide("右侧是声望。客人等不及、服务失败会扣声望；声望归零，整局游戏就结束啦。厨房可以忙，信誉可别忙丢了！")
			elif not events.has(&"order"): _guide("营业结束前客人会持续到来，一次来一位。先到外侧桌前按住 K 接单，听听这一位想吃什么。", ["TestServingCounter"])
			elif _dish_ready():
				if _holds(Items.PLATE_ID): _guide("面对组合台按 J，将上一关做好的脆芽冷盘装进盘子。", ["AssemblyStation"])
				else: _guide("非酒水菜需要净盘。走到左侧盘架，空手按 J 取一个净盘。", [main.get_node("PlateSink").rack])
			elif not events.has(&"serve"): _guide("面对上菜口按 J 交付脆芽冷盘，上菜可获得金币和经验。", ["TestServingCounter"])
			else: _guide("盘子也要洗个澡：J 放进右侧净化池，再空手按住 J 清洗；净盘会回到左侧盘架。", ["PlateSink"])
		2:
			if not events.has(&"roast_taken"):
				_guide("烤条旁 1=微生、2=半熟、3=全熟；第4段走完就烤糊了！箱子 J 取碎金子放烤台，等全熟 J 取走。", ["BakeCooker"] if _holds(Items.RICE_ID) or main.get_node("BakeCooker").has_item else ["StorageCabinetGoldenWheat"])
			elif _holds(Items.RICE_ID):
				_guide("烤料拿稳啦。面对空桌按 J 暂存，腾出双手再去研磨。", ["TutorialPrepTableA"] if not main.get_node("TutorialPrepTableA").has_item else ["TutorialPrepTableB"])
			elif main.get_node("GrindCooker").has_item:
				_guide("磨条 1=粗磨、2=细磨。按住 K，粗磨可提前 J 取出，继续磨到细磨也可；取走小料盒后放到空桌。", ["GrindCooker"])
			else: _guide("先把烤好的食材 J 放到空桌。晴天梅箱 J 取料，再 J 放到磨台；研磨也有粗磨、细磨两档。", ["GrindCooker"] if _holds(Items.EGG_ID) else ["StorageCabinetSunnyBerry"])
		3:
			if int(events.get(&"courses", 0)) > 0: _guide("酒水自带杯子，不用净盘。面对菜谱书按 K 查看菜品分类与配方，Esc 返回。", ["RecipeBook"])
			elif not events.has(&"order"): _guide("本关客人想喝绿洲酒。先走近上菜口按住 K 接单。", ["TestServingCounter"])
			elif _holds(Items.DRINK_OASIS_WINE_ID): _guide("绿洲酒自带杯子，无需装盘。面对上菜口按 J 直接上酒。", ["TestServingCounter"])
			elif main.get_node("FixedBarrelLeftA").current_drink_item_id != &"": _guide("等待酒桶酿好，空手面对酒桶按 J 取一杯绿洲酒。", ["FixedBarrelLeftA"])
			elif _holds(Items.VEG_LEAF_ID): _guide("生脆芽无需切配，直接面对酒桶按 J 投入。", ["FixedBarrelLeftA"])
			else: _guide("酒水也是菜品。先到脆芽箱，空手按 J 取一份生脆芽。", ["StorageCabinetCrispSprout"])
		4:
			if not events.has(&"order"): _guide("甜品是额外招待，不会出现在普通点单里。先面对客人按住 K 接单。", ["TestServingCounter"])
			elif not events.has(&"dessert"):
				_guide("J 取桌上的晴梅甜羹，再 J 招待客人：增加金币和经验，并恢复部分耐心，每客限一次。", ["TestServingCounter"] if _holds(Items.DISH_QINGMEI_SWEET_BOWL_ID) else ["TestTable"])
			elif _holds(Items.DIRTY_PLATE_ID): _guide("甜品没有抵消原订单，客人仍在等冷盘。先把脏盘 J 放入净化池腾出双手。", ["PlateSink"])
			else: _guide("取另一张桌上的脆芽冷盘，再 J 交给客人，完成原订单。", ["TestServingCounter"] if _holds(Items.DISH_CRISP_PLATE_ID) else ["TutorialDishTable"])
		5:
			if not events.has(&"order"): _guide("精英客人一次点多道菜，共享耐心。先按住 K 接单；本关预扣部分耐心，观察上酒和上菜如何回耐心。", ["TestServingCounter"])
			elif _holds(Items.DIRTY_PLATE_ID): _guide("上菜后会恢复部分耐心。先 J 把脏盘放进净化池，再取下一道菜。", ["PlateSink"])
			else:
				var course: int = int(events.get(&"courses", 0))
				var ids = [Items.DRINK_OASIS_WINE_ID, Items.DISH_CRISP_PLATE_ID, Items.DISH_WHITE_PLATE_ID]
				var tables = ["TestTable", "TutorialDishTable", "TutorialMainTable"]
				_guide("按“酒水 → 小菜 → 主菜”依次交付。当前：%s；留意剩余道数与耐心：酒水回10%%，菜品回20%%。" % Items.get_item_display_name(ids[course]), ["TestServingCounter"] if _holds(ids[course]) else [tables[course]])
		SHOP:
			var reward_text := "第一次上菜获得 %d 金币、%d 经验。" % [earned_gold, earned_xp] if earned_gold > 0 else "上菜赚金币和经验；金币用来购物，经验用来成长。"
			_guide(reward_text + "商人 K 打开商店，Q/E 浏览四栏，K 退出。\n属性强化角色；厨房升级工作台；设施添置设备；冷冻食材补充原料。", ["NightMerchant"])
		FORAGE:
			if is_instance_valid(forage) and forage.state == forage.ForageState.SELECTING: _guide("选项围着你：上 W、左 A、下 S、右 D。按对应键选一种，食材直接入库。")
			else: _guide("靠近采集点，空手按住 K 搜寻。中途松开会中断，采集点会保留。", [forage])
		COMBAT:
			if info_page == 0: _guide("血量归零不是死亡：原地晕眩15秒后，以最大生命值的10%复活；夜间自动回满血。别怕打架，躺一会儿还能回来切菜！")
			elif not events.has(&"dash"): _guide("按 Space 冲刺一次，练习躲避。", [enemy])
			elif not events.has(&"kill"): _guide("靠近沙原禽，按 L 攻击。也可按住 L 后松开，发动重击。", [enemy])
			else: _guide("走过去触碰禽肉就自动进入库存，不用按 J，也不用空出双手。", get_tree().get_nodes_in_group("battle_drops"))
		SKILLS: _guide_skills()
		NIGHT:
			if info_page == 0: _guide("营业结束后才会选择下一天的新菜，今天记住流程就好，不用实操。夜间还可选祝福、逛商店、遇访客。")
			elif flow.get_owned_blessing_ids().is_empty(): _guide("面对女神像按 J 祈福。祝福不合心意可按 L 刷新当前选项；刷新次数整局共享，别一口气花光哦。", ["BlessingStatue"])
			else: _guide("烤台旁有访客啦。靠近带 ! 的小家伙按 J 交谈，接受或谢绝都可以。梵倪拉前辈说，收工也得看人情。", [flow.night_event_controller.npcs.get(&"furnace")])
		BOSS:
			var lines = [
				"BOSS 日会遇到强大的 BOSS 敌人：攻击有预警，躲开再找空隙输出，击败后带回专属食材。",
				"营业结束会迎来 BOSS 客人：酒水→小菜→主菜逐道上；主菜一定需要对应 BOSS 的专属食材。全部上完才能收工。",
				"BOSS 客人有独立耐心，超时不会直接离开，而会持续扣声望；普通上菜的回耐心规则不适用。别让厨房等到天荒地老。",
				"记住两件事：战斗看预警，厨房看当前订单。每个 BOSS 当日营业前还有专属说明卡。准备好就去正式营业吧！"]
			_guide(lines[mini(info_page, lines.size() - 1)])

func _guide_cooking() -> void:
	var station: Node = main.get_node("TestCooker")
	var assembly: Node = main.get_node("AssemblyStation")
	if assembly.stored_items.size() >= 2: _guide("两份切芽已放好。空手面对组合台按 K，做出脆芽冷盘。", ["AssemblyStation"])
	elif _holds(Items.VEG_LEAF_ID, Items.PROCESS_STATE_CUT): _guide("面对组合台按 J 放入切芽。脆芽冷盘需要两份切芽。", ["AssemblyStation"])
	elif station.has_item:
		if station.processing_active: _guide("面对切台连按 K 切配；完成后食材会留在台上。", ["TestCooker"])
		else: _guide("切配完成！脆芽不会自己跳进手里，面对切台按 J 主动取走吧。", ["TestCooker"])
	elif _holds(Items.VEG_LEAF_ID): _guide("面对切台按 J 放入脆芽，准备切配。", ["TestCooker"])
	else: _guide("WASD 移动。到脆芽箱空手按 J 取料。目标：切芽 ×2 → 组合成冷盘。", ["StorageCabinetCrispSprout"])


func _guide_skills() -> void:
	if not events.has(&"small"):
		_guide("先试小技能：U 释放“抢灶步”，短冷却、消耗魔力，是帮你跑快些的小功能。按 U，右侧魔力会自动恢复。")
		return
	if not events.has(&"skill_cut_before"):
		_guide("小技能会用了！接下来先不开大招，普通速度切一份脆芽：箱子 J 取料→切台 J 放入→连按 K。", ["TestCooker"] if player.is_holding_item() or main.get_node("TestCooker").has_item else ["StorageCabinetCrispSprout"])
	elif main.get_node("TestCooker").has_item and not main.get_node("TestCooker").processing_active or _holds(Items.VEG_LEAF_ID, Items.PROCESS_STATE_CUT):
		_guide("大技能效果强力，靠工作和战斗充能。先 J 取走切芽，放到旁边空桌，再准备第二份生脆芽来对比。", ["TestTable"] if player.is_holding_item() else ["TestCooker"])
	elif not main.get_node("TestCooker").has_item:
		_guide("再取一份生脆芽 J 放切台。准备好再开大招，就不会把强力时间花在找菜上啦。", ["TestCooker"] if _holds(Items.VEG_LEAF_ID) else ["StorageCabinetCrispSprout"])
	elif not player.skill_controller.is_big_skill_buff_active():
		player.fill_ultimate_energy()
		_guide("按 I 开“稳住这锅”，再连按 K 切第二份。对比第一次需要的按键次数。")
	else:
		_guide("趁大招生效，面对切台连按 K！同样食材更快完成，这就是强力效果。", ["TestCooker"])

func _update_lesson_hud_visibility() -> void:
	var status: Node = flow.run_status_hud
	status.day_clock.visible = step == 1
	if step == 1: status.set_day_clock(practice_time_remaining, 180.0, 0.0, "营业")
	status.gold_panel.position.y = 814
	status.xp_panel.position.y = 798
	for slot: Control in [status.action_slot_dash, status.skill_slot_small, status.skill_slot_big]: slot.position.y = 770
	status.reputation_panel.visible = step == 1 and info_page > 0
	status.reputation_panel.position = Vector2(1780, 222)
	status.gold_panel.visible = step in [1, 3, 4, 5, SHOP, NIGHT]
	status.xp_panel.visible = step in [1, 3, 4, 5, SHOP, NIGHT]
	status.magic_panel.visible = step == SKILLS
	var focus: Control = null
	if step == SKILLS:
		status.magic_panel.position = Vector2(1804, 222)
		focus = status.magic_panel if not events.has(&"skill_cut_before") else status.skill_slot_big
	elif step == 1 and info_page < 2:
		focus = status.day_clock if info_page == 0 else status.reputation_panel
	if focus != null:
		ui_highlight.position = focus.get_global_rect().position - Vector2(8, 8)
		ui_highlight.size = focus.size + Vector2(16, 16)
		ui_highlight.modulate.a = .72 + .28 * sin(highlight_clock * 4)
	status.skill_bar_root.visible = step in [COMBAT, SKILLS]
	status.skill_slot_small.visible = step == SKILLS
	status.skill_slot_big.visible = step == SKILLS and events.has(&"skill_cut_before")

func _build_lesson_map() -> void:
	# Free actual collision bodies and targets, rather than hiding unused props.
	highlight_nodes.clear()
	for node: Node in lesson_nodes:
		if is_instance_valid(node): node.free()
	lesson_nodes.clear()
	var map: Node = main.get_node("PrototypeMap")
	lesson_bounds = Rect2(Vector2(128, 128), MAP_SIZES[step])
	map.configure_tutorial_lesson(step, lesson_bounds, step in [FORAGE, COMBAT])
	for name: String in LAYOUTS[step]:
		var template_name := "TestTable" if name in ["TutorialDishTable", "TutorialMainTable", "TutorialPrepTableA", "TutorialPrepTableB"] else name
		var node: Node2D = preload("res://Scripts/Tutorial/TutorialRecipeBook.gd").new() if name == "RecipeBook" else facility_templates[template_name].instantiate()
		node.name = name
		node.position = LAYOUTS[step][name]
		node.visible = true
		if name == "NightMerchant": node.always_visible = true
		if name == "TestServingCounter":
			node.position = Vector2(lesson_bounds.position.x - 144, 512)
			node.rotation = PI / 2
			node.scale = Vector2(.44, .25)
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
	camera.zoom = Vector2.ONE * minf(1150.0 / lesson_bounds.size.x, 650.0 / lesson_bounds.size.y)
	camera.global_position = lesson_bounds.get_center() + Vector2(-100 if LAYOUTS[step].has("TestServingCounter") else 0, 75)
	camera.reset_smoothing()
	camera.force_update_scroll()

func _prepared_dish(id: StringName) -> Dictionary:
	var components: Array[Dictionary] = []
	for entry: Dictionary in Items.get_recipe_for_dish(id):
		for count in range(int(entry.get("count", 1))):
			components.append({"item_id": entry.item_id, "process_state": entry.process_state})
	var recipe: Dictionary = Items.find_matching_recipe(components, false)
	return {"item_id": id, "texture": Items.get_item_texture(id), "process_state": Items.PROCESS_STATE_NONE, "recipe_signature": String(recipe.get("recipe_signature", ""))}

func _stage_dish(table_name: String, id: StringName) -> void:
	var dish := _prepared_dish(id)
	var table: Node = main.get_node(table_name)
	table.has_item = true
	table.item_id = id
	table.item_texture = Items.get_item_texture(id)
	table.item_process_state = Items.PROCESS_STATE_NONE
	table.item_recipe_signature = dish.recipe_signature
	table.item_payload = {} if Items.is_drink(id) else {"uses_plate": true}
	table._update_item_visual()

func _add_customer(dishes: Array, elite: bool = false) -> void:
	var orders: Array[Dictionary] = []
	for index in dishes.size():
		var order := preload("res://Scripts/Orders/OrderGroupDefs.gd")._order("TUTORIAL-%d" % index, 1, dishes[index], 3600)
		order.merge({"customer_name": "练习精英客人" if elite else "练习客人", "order_take_patience_duration": 3600.0, "patience_duration": 3600.0, "elite_customer": elite, "customer_order_index": index, "customer_order_total": dishes.size()}, true)
		orders.append(order)
	flow.order_manager.add_orders(orders)

func _update_highlights() -> void:
	target_label.visible = not get_tree().paused and not highlight_nodes.is_empty()
	for node: Node2D in lesson_nodes:
		node.modulate = Color.WHITE
	for node: Node2D in highlight_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			var pulse := 1.12 + .16 * sin(highlight_clock * 4.0)
			if node.has_method("set_guidance_highlight"): node.set_guidance_highlight(true, pulse)
			else: node.modulate = Color(pulse, pulse, 1.0)
	if not highlight_nodes.is_empty() and is_instance_valid(highlight_nodes[0]):
		target_label.global_position = highlight_nodes[0].global_position + Vector2(-90, -140 + sin(highlight_clock * 4.0) * 7)

func _check(value: String, ok: bool) -> Dictionary:
	return {"text": value, "ok": ok}

func _holds(id: StringName, state_value: StringName = &"") -> bool:
	return player.get_held_item_id() == id and (state_value == &"" or player.get_held_item_process_state() == state_value)

func advance() -> void:
	_update_objectives()
	if not ready_to_advance:
		return
	if step == BOSS:
		completed = true
		_leave()
		return
	step += 1
	lesson_progression_snapshot = flow.progression_state.get_snapshot()
	_reset_practice()

func _skip_to_next() -> void:
	if step == BOSS:
		_leave()
		return
	step += 1
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
	for drop: Node in get_tree().get_nodes_in_group("battle_drops"): drop.free()
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
	info_page = 0
	practice_time_remaining = 180.0
	last_guide_text = ""
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
		1:
			main.get_node("AssemblyStation").stored_items.append(_prepared_dish(Items.DISH_CRISP_PLATE_ID))
			main.get_node("AssemblyStation")._update_item_visual()
			_add_customer([Items.DISH_CRISP_PLATE_ID])
		3: _add_customer([Items.DRINK_OASIS_WINE_ID])
		4:
			_add_customer([Items.DISH_CRISP_PLATE_ID])
			_stage_dish("TestTable", Items.DISH_QINGMEI_SWEET_BOWL_ID)
		5:
			_add_customer([Items.DRINK_OASIS_WINE_ID, Items.DISH_CRISP_PLATE_ID, Items.DISH_WHITE_PLATE_ID], true)
			_stage_dish("TestTable", Items.DRINK_OASIS_WINE_ID)
			_stage_dish("TutorialDishTable", Items.DISH_CRISP_PLATE_ID)
			_stage_dish("TutorialMainTable", Items.DISH_WHITE_PLATE_ID)
		SHOP:
			flow.run_context.state = Context.LevelState.NIGHT_REST
			preload("res://Scripts/Audio/AudioCue.gd").play_music(&"night")
		FORAGE: _spawn_forage()
		COMBAT: _spawn_enemy()
		SKILLS:
			player.skill_controller.ultimate_energy = 0.0
		NIGHT:
			flow.run_context.state = Context.LevelState.NIGHT_REST
			flow.progression_state.day_index = 1
			flow.progression_state.blessing_points = 1
			flow.progression_state.events.night_index = 1
			flow.progression_state.events.event_id = &"furnace"
			flow.progression_state.events.resolved = false
			flow.night_event_controller.refresh_night()
		BOSS: pass
	flow.overlay_controller.hide_toast()
	_update_lesson_hud_visibility()

	_update_objectives()
	_update_highlights()

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
	drop_stock_before = flow.storage_manager.get_stock(Items.MEAT_WHITE_ID)
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
		var item: Node2D = load("res://Scenes/Battle/battle_drop.tscn").instantiate()
		main.add_child(item)
		item.global_position = at
		item.max_lifetime = 3600
		item.lifetime_remaining = 3600
		item.setup_drop(id, Vector2.ZERO, lesson_bounds)
	)
	highlight_nodes.assign([enemy])

func _draw() -> void:
	for node: Node2D in highlight_nodes:
		if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
		if node.is_in_group("serving_counters"): continue
		var radius := 78.0 + sin(highlight_clock * 4.0) * 7
		draw_circle(node.global_position, radius, Color(1.0, .80, .25, .10))
		draw_arc(node.global_position, radius, 0, TAU, 56, Color(1.0, .85, .36, .95), 5, true)
		draw_arc(node.global_position, radius + 9, 0, TAU, 56, Color(1.0, .9, .55, .4), 2, true)

func _leave() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Main/tutorial_select.tscn")
