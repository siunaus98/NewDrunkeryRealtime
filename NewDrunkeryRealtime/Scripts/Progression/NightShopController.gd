extends Node

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

signal purchase_completed(new_gold: int)

const RunProgressionState = preload("res://Scripts/Core/RunProgressionState.gd")
const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const AttributeForgeDefs = preload("res://Scripts/Progression/AttributeForgeDefs.gd")

var overlay_title_label: Label
var overlay_body_label: Label
var overlay_hint_label: Label
var blessing_timer_label: Label
var blessing_timer_bar_frame: ColorRect
var blessing_cards_root: HBoxContainer
var shop_root: VBoxContainer
var shop_category_tabs: HBoxContainer
var shop_scroll: ScrollContainer
var shop_item_list: GridContainer

var player: Node
var storage_manager: Node
var progression_state: RunProgressionState
var facility_purchase_callback: Callable
var kitchen_upgrade_callback: Callable
var attribute_forge_callback: Callable

var pending_shop_message: String = ""
var merchant_shop_items: Array[Dictionary] = []
var selected_shop_index: int = -1
var hovered_shop_index: int = -1
var selected_shop_category_index: int = 0
var is_refreshing_shop_ui: bool = false
var shop_item_panels: Array[Panel] = []
var shop_item_panel_by_index: Dictionary = {}
var shop_item_footer_by_index: Dictionary = {}
var pending_forge_options: Array[Dictionary] = []
var pending_forge_tier: StringName = &""
var pending_forge_selection: int = 0
var reward_forge_active: bool = false
var scroll_request_id: int = 0

func configure_ui(
	new_overlay_title_label: Label,
	new_overlay_body_label: Label,
	new_overlay_hint_label: Label,
	new_blessing_timer_label: Label,
	new_blessing_timer_bar_frame: ColorRect,
	new_blessing_cards_root: HBoxContainer,
	new_shop_root: VBoxContainer,
	new_shop_category_tabs: HBoxContainer,
	new_shop_scroll: ScrollContainer,
	new_shop_item_list: GridContainer
) -> void:
	overlay_title_label = new_overlay_title_label
	overlay_body_label = new_overlay_body_label
	overlay_hint_label = new_overlay_hint_label
	blessing_timer_label = new_blessing_timer_label
	blessing_timer_bar_frame = new_blessing_timer_bar_frame
	blessing_cards_root = new_blessing_cards_root
	shop_root = new_shop_root
	shop_category_tabs = new_shop_category_tabs
	shop_scroll = new_shop_scroll
	shop_item_list = new_shop_item_list

func set_scene_refs(new_player: Node, new_storage_manager: Node) -> void:
	player = new_player
	storage_manager = new_storage_manager

func set_facility_purchase_callback(callback: Callable) -> void:
	facility_purchase_callback = callback

func set_kitchen_upgrade_callback(callback: Callable) -> void:
	kitchen_upgrade_callback = callback

func set_attribute_forge_callback(callback: Callable) -> void:
	attribute_forge_callback = callback

func reset_persistent_state(state: RunProgressionState) -> void:
	progression_state = state
	pending_shop_message = ""
	selected_shop_index = -1
	hovered_shop_index = -1
	selected_shop_category_index = 0
	merchant_shop_items.clear()
	pending_forge_options.clear()
	pending_forge_tier = &""
	reward_forge_active = false

func prepare_for_open(state: RunProgressionState) -> void:
	progression_state = state
	selected_shop_index = -1
	hovered_shop_index = -1
	pending_shop_message = ""
	_open_reward_forge_if_available()
	_rebuild_merchant_shop_items()
	_refresh_night_shop_overlay()

func get_current_gold() -> int:
	return progression_state.gold if progression_state != null else 0

func clear_runtime_selection() -> void:
	selected_shop_index = -1
	hovered_shop_index = -1

func has_pending_forge() -> bool:
	return not pending_forge_options.is_empty()

func move_forge_selection(direction: int) -> void:
	if pending_forge_options.is_empty():
		return
	pending_forge_selection = wrapi(pending_forge_selection + direction, 0, pending_forge_options.size())
	_refresh_forge_overlay()

func confirm_forge_selection(index: int = -1) -> bool:
	if pending_forge_options.is_empty() or progression_state == null:
		return false
	var chosen_index := pending_forge_selection if index < 0 else index
	if chosen_index < 0 or chosen_index >= pending_forge_options.size():
		return false
	progression_state.add_forged_attribute(pending_forge_options[chosen_index])
	AudioCue.play_sfx(&"forge", -1.0)
	if attribute_forge_callback.is_valid():
		attribute_forge_callback.call(pending_forge_options[chosen_index])
	if reward_forge_active:
		progression_state.modifiers.pending_forges.pop_front()
		reward_forge_active = false
	pending_forge_options.clear()
	pending_forge_tier = &""
	pending_forge_selection = 0
	_open_reward_forge_if_available()
	_rebuild_merchant_shop_items()
	_refresh_night_shop_overlay()
	return true

func move_category_selection(direction: int) -> void:
	var category_count: int = _get_shop_categories().size()
	if category_count <= 0:
		return
	selected_shop_category_index = wrapi(selected_shop_category_index + direction, 0, category_count)
	selected_shop_index = -1
	hovered_shop_index = -1
	_refresh_night_shop_overlay()

func move_selection(direction: int) -> void:
	var category_items: Array[int] = _get_shop_item_indices_for_category(selected_shop_category_index)
	if category_items.is_empty():
		selected_shop_index = -1
		_refresh_night_shop_overlay()
		return
	if selected_shop_index < 0 or not category_items.has(selected_shop_index):
		selected_shop_index = category_items[0]
		hovered_shop_index = -1
		_update_shop_item_highlight_states()
		_scroll_shop_item_into_view(selected_shop_index)
		return
	var current_local_index: int = category_items.find(selected_shop_index)
	var next_local_index: int = wrapi(current_local_index + direction, 0, category_items.size())
	selected_shop_index = category_items[next_local_index]
	hovered_shop_index = -1
	_update_shop_item_highlight_states()
	_scroll_shop_item_into_view(selected_shop_index)

func move_selection_2d(dx: int, dy: int) -> void:
	var category_items: Array[int] = _get_shop_item_indices_for_category(selected_shop_category_index)
	if category_items.is_empty():
		selected_shop_index = -1
		_refresh_night_shop_overlay()
		return

	var columns: int = 3
	if selected_shop_index < 0 or not category_items.has(selected_shop_index):
		selected_shop_index = category_items[0]
		hovered_shop_index = -1
		_update_shop_item_highlight_states()
		_scroll_shop_item_into_view(selected_shop_index)
		return

	var current_local_index: int = category_items.find(selected_shop_index)
	var target_local_index: int = get_grid_target_index(current_local_index, category_items.size(), columns, dx, dy)
	if target_local_index == current_local_index:
		return

	selected_shop_index = category_items[target_local_index]
	hovered_shop_index = -1
	_update_shop_item_highlight_states()
	_scroll_shop_item_into_view(selected_shop_index)

static func get_grid_target_index(current_index: int, item_count: int, columns: int, dx: int, dy: int) -> int:
	if current_index < 0 or current_index >= item_count or item_count <= 0 or columns <= 0:
		return current_index
	if dx != 0:
		return wrapi(current_index + dx, 0, item_count)
	var current_row: int = int(current_index / columns)
	var last_row: int = int((item_count - 1) / columns)
	if dy > 0 and current_row == last_row:
		return 0
	if dy < 0 and current_row == 0:
		return item_count - 1
	return clampi(current_index + dy * columns, 0, item_count - 1)

func purchase_selected() -> bool:
	if has_pending_forge():
		return false
	if merchant_shop_items.is_empty():
		return false

	var target_index: int = selected_shop_index
	if target_index < 0 and hovered_shop_index >= 0:
		target_index = hovered_shop_index
	if target_index < 0 or target_index >= merchant_shop_items.size():
		pending_shop_message = "还没有选中商品。"
		_refresh_night_shop_overlay()
		return false

	var item_data: Dictionary = merchant_shop_items[target_index]
	var previous_local_index: int = _get_shop_item_indices_for_category(selected_shop_category_index).find(target_index)
	if StringName(item_data.get("type", &"")) == &"forklift_repair":
		# Price the current damage at commit, not the old card's snapshot.
		item_data = _build_forklift_repair_item()
		if item_data.is_empty():
			pending_shop_message = "铲车无需修理。"
			_rebuild_merchant_shop_items()
			_restore_purchased_item_selection(&"forklift_repair", previous_local_index)
			_refresh_night_shop_overlay()
			return false
	var cost: int = int(item_data.get("cost", 0))
	if progression_state == null or not progression_state.can_afford(cost):
		pending_shop_message = "金币不足。"
		_refresh_night_shop_overlay()
		return false

	var purchased: bool = false
	match StringName(item_data.get("type", &"")):
		&"stat":
			purchased = _purchase_forge(item_data)
		&"frozen_food":
			purchased = _purchase_frozen_food(item_data)
		&"facility":
			purchased = _purchase_facility(item_data)
		&"kitchen_upgrade":
			purchased = _purchase_kitchen_upgrade(item_data)
		&"forklift_repair":
			var vehicle: Node = _get_damaged_forklift()
			purchased = vehicle != null and vehicle.repair()

	if not purchased:
		if pending_shop_message == "":
			pending_shop_message = "购买失败。"
		_refresh_night_shop_overlay()
		return false

	progression_state.spend_gold(cost)
	AudioCue.play_sfx(&"forge" if StringName(item_data.get("type", &"")) == &"stat" else &"purchase", -3.0)
	_rebuild_merchant_shop_items()
	_restore_purchased_item_selection(StringName(item_data.get("id", &"")), previous_local_index)
	if has_pending_forge():
		pending_shop_message = "请选择一项属性锻造。"
		_refresh_forge_overlay()
		purchase_completed.emit(progression_state.gold)
		return true
	pending_shop_message = "已购买：%s" % String(item_data.get("title", "商品"))
	_refresh_night_shop_overlay()
	purchase_completed.emit(progression_state.gold)
	return true

func _restore_purchased_item_selection(item_id: StringName, previous_local_index: int) -> void:
	var indices: Array[int] = _get_shop_item_indices_for_category(selected_shop_category_index)
	hovered_shop_index = -1
	selected_shop_index = -1
	for index: int in indices:
		if StringName(merchant_shop_items[index].get("id", &"")) == item_id:
			selected_shop_index = index
			return
	# Removing a limited item leaves its successor in the old slot. Removing
	# the last item wraps to the category's first item, never another category.
	if not indices.is_empty():
		selected_shop_index = indices[wrapi(previous_local_index, 0, indices.size())]

func scroll_list(amount: int) -> void:
	if shop_scroll == null:
		return
	shop_scroll.scroll_vertical = maxi(shop_scroll.scroll_vertical + amount, 0)

func _refresh_night_shop_overlay() -> void:
	if has_pending_forge():
		_refresh_forge_overlay()
		if overlay_title_label != null:
			overlay_title_label.text = "属性锻造"
		if overlay_hint_label != null:
			overlay_hint_label.text = "方向/WASD：选择属性    Space：确认"
		if overlay_body_label != null:
			overlay_body_label.text = "品质：%s\n%s，请选择一项属性。" % [_tier_display_name(pending_forge_tier), "关卡奖励（免费）" if reward_forge_active else "购买已完成"]
		return
	is_refreshing_shop_ui = true
	if overlay_title_label != null:
		overlay_title_label.text = "夜间商人"
	if overlay_hint_label != null:
		overlay_hint_label.text = "Q/E：切分类    方向/WASD：选商品    鼠标/滚轮可用    Space：购买    K：关闭（Esc 备用）"
	if blessing_timer_label != null:
		blessing_timer_label.visible = false
	if blessing_timer_bar_frame != null:
		blessing_timer_bar_frame.visible = false
	if blessing_cards_root != null:
		blessing_cards_root.visible = false
	if shop_root != null:
		shop_root.visible = true
	_refresh_shop_category_tabs()
	_refresh_shop_item_list()
	if overlay_body_label != null:
		overlay_body_label.text = "金币：%d    ·    %s" % [
			get_current_gold(),
			pending_shop_message if pending_shop_message != "" else "浏览当前分类的商品。"
		]
	is_refreshing_shop_ui = false
	_scroll_shop_item_into_view(selected_shop_index)

func _tier_display_name(tier: StringName) -> String:
	match tier:
		AttributeForgeDefs.SILVER:
			return "白银"
		AttributeForgeDefs.GOLD:
			return "黄金"
		AttributeForgeDefs.DIAMOND:
			return "钻石"
	return "未知"

func _rebuild_merchant_shop_items() -> void:
	merchant_shop_items.clear()
	merchant_shop_items.append(_build_stat_shop_item(&"random_forge", "随机属性锻造器", "随机获得白银、黄金或钻石品质。购买后从三个不同属性中选择一个。", 45, "三选一，不可刷新"))
	merchant_shop_items.append(_build_stat_shop_item(&"diamond_forge", "钻石属性锻造器", "必定获得钻石品质高级词条。购买后从三个不同属性中选择一个。", 120, "三选一，不可刷新"))
	merchant_shop_items.append(_build_kitchen_upgrade_shop_item(&"magic_capacity", "蓝晶酒袋", "魔力上限 +1，增加战斗技能的施放余量。", 13, "魔力上限提高"))
	merchant_shop_items.append(_build_kitchen_upgrade_shop_item(&"magic_regen", "泉眼滤芯", "魔力恢复速度提高 12%。运营越忙，收益越明显。", 15, "魔力恢复更快"))
	merchant_shop_items.append(_build_kitchen_upgrade_shop_item(&"station_speed", "厨具改良", "所有现有及之后购买的料理台加工速度提高 15%。烤台熟成窗口也会相应缩短。", 24, "加工速度提高"))
	merchant_shop_items.append(_build_facility_shop_item(&"cut_station", "切菜台", "将生食材加工为切片。", 24, "购入新料理台"))
	merchant_shop_items.append(_build_facility_shop_item(&"roast_station", "烤台", "自动烤制食材，过久会焦糊。", 30, "购入新料理台"))
	merchant_shop_items.append(_build_facility_shop_item(&"grind_station", "研磨台", "将食材研磨为4份小料。", 28, "购入新料理台"))
	merchant_shop_items.append(_build_facility_shop_item(&"prep_table", "备料桌", "存放食材、小料盒与盘子。", 10, "增加备料空间"))
	merchant_shop_items.append(_build_frozen_food_shop_item())
	merchant_shop_items.append(_build_facility_shop_item(&"conveyor", "履带", "占地两格，沿固定方向运输物品与玩家。", 14, "推动玩家/物品"))
	merchant_shop_items.append(_build_facility_shop_item(&"lamp", "明光灯", "范围内加工、酿造、净化与培养效率+22%，并加速履带与摇摇车。", 16, "光照范围内效率 +22%"))
	for entry: Dictionary in preload("res://Scripts/Facilities/FacilityCatalog.gd").ENTRIES:
		var id := StringName(entry.id)
		var count: int = progression_state.get_stat_purchase_count(StringName("facility_%s" % id)) if progression_state != null else 0
		if preload("res://Scripts/Facilities/FacilityCatalog.gd").available(id, count):
			merchant_shop_items.append(_build_facility_shop_item(id, String(entry.name), String(entry.detail), int(entry.cost) + (count * 12 if id == &"culture" else 0), "限购%d" % int(entry.limit) if int(entry.limit) > 0 else "可重复购买"))
	var repair_item: Dictionary = _build_forklift_repair_item()
	if not repair_item.is_empty():
		merchant_shop_items.append(repair_item)

func _get_damaged_forklift() -> Node:
	if not is_inside_tree():
		return null
	for vehicle: Node in get_tree().get_nodes_in_group("forklifts"):
		if not vehicle.is_queued_for_deletion() and vehicle.get_repair_cost() > 0:
			return vehicle
	return null

func _build_forklift_repair_item() -> Dictionary:
	var vehicle: Node = _get_damaged_forklift()
	if vehicle == null:
		return {}
	return {
		"id": &"forklift_repair", "type": &"forklift_repair", "category": &"facilities",
		"title": "修理铲车", "description": "恢复铲车全部耐久，每损失%d点耐久花费1金币。" % vehicle.REPAIR_HEALTH_PER_GOLD,
		"cost": vehicle.get_repair_cost(), "state_text": "当前耐久 %d/%d" % [vehicle.health, vehicle.MAX_HEALTH]
	}

func _build_stat_shop_item(stat_id: StringName, title: String, description: String, base_cost: int, detail: String) -> Dictionary:
	var purchase_count: int = progression_state.get_stat_purchase_count(stat_id) if progression_state != null else 0
	var cost: int = base_cost + purchase_count * max(2, int(round(float(base_cost) * 0.35)))
	return {
		"id": stat_id,
		"type": &"stat",
		"category": &"stats",
		"title": title,
		"description": "%s\n%s" % [description, detail],
		"cost": cost,
		"state_text": "已购买 %d 次" % purchase_count
	}

func _open_reward_forge_if_available() -> void:
	if progression_state == null or has_pending_forge() or progression_state.modifiers.pending_forges.is_empty():
		return
	reward_forge_active = true
	pending_forge_tier = progression_state.modifiers.pending_forges[0]
	pending_forge_options = _build_forge_options(pending_forge_tier)
	pending_forge_selection = 0

func _purchase_forge(item_data: Dictionary) -> bool:
	if progression_state == null:
		return false
	var id := StringName(item_data.get("id", &""))
	var tier := AttributeForgeDefs.DIAMOND if id == &"diamond_forge" else _roll_forge_tier()
	pending_forge_tier = tier
	pending_forge_options = _build_forge_options(tier)
	pending_forge_selection = 0
	return not pending_forge_options.is_empty()

func _roll_forge_tier() -> StringName:
	var roll := randf()
	if roll < 0.60:
		return AttributeForgeDefs.SILVER
	if roll < 0.90:
		return AttributeForgeDefs.GOLD
	return AttributeForgeDefs.DIAMOND

func _build_forge_options(tier: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array[StringName] = []
	for id in AttributeForgeDefs.ATTRIBUTE_NAMES.keys():
		ids.append(StringName(id))
	ids.shuffle()
	for attribute_id in ids:
		if result.size() >= 3:
			break
		if tier == AttributeForgeDefs.DIAMOND:
			for option in AttributeForgeDefs.DIAMOND_OPTIONS:
				if StringName(option.get("attribute_id", &"")) == attribute_id:
					result.append(option.duplicate(true))
					break
		else:
			result.append({
				"id": StringName("%s_%s" % [String(tier), String(attribute_id)]),
				"attribute_id": attribute_id,
				"tier": tier,
				"title": "%s·%s" % ["黄金" if tier == AttributeForgeDefs.GOLD else "白银", AttributeForgeDefs.get_attribute_name(attribute_id)],
				"description": "%s %s" % [AttributeForgeDefs.get_attribute_name(attribute_id), AttributeForgeDefs.format_value(attribute_id, AttributeForgeDefs.get_fixed_value(tier, attribute_id))],
				"fixed": AttributeForgeDefs.get_fixed_value(tier, attribute_id)
			})
	return result

func _refresh_forge_overlay() -> void:
	if shop_root != null:
		shop_root.visible = false
	if blessing_cards_root == null:
		return
	blessing_cards_root.visible = true
	blessing_cards_root.alignment = BoxContainer.ALIGNMENT_CENTER
	blessing_cards_root.add_theme_constant_override("separation", 24)
	var cards_scroll := blessing_cards_root.get_parent()
	if cards_scroll != null and cards_scroll is ScrollContainer:
		cards_scroll.visible = true
		(cards_scroll as ScrollContainer).scroll_horizontal = 0
		(cards_scroll as ScrollContainer).scroll_vertical = 0
	var panels: Array[Node] = blessing_cards_root.get_children()
	for i in range(panels.size()):
		var panel := panels[i] as Panel
		if panel == null:
			continue
		panel.visible = i < pending_forge_options.size()
		for child in panel.get_children():
			child.free()
		if i >= pending_forge_options.size():
			continue
		# Forge choices use a compact, fixed card size so the three options fit
		# inside the night overlay instead of inheriting the taller blessing-card
		# layout and clipping their descriptions.
		panel.custom_minimum_size = Vector2(320.0, 320.0)
		panel.size = Vector2(320.0, 320.0)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var data: Dictionary = pending_forge_options[i]
		var label := Label.new()
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 24)
		label.text = "%s\n\n%s\n\n%s" % [String(data.get("title", "属性")), String(data.get("description", "")), "已选择" if i == pending_forge_selection else "选项 %d" % (i + 1)]
		panel.add_child(label)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.48, 0.48, 0.48, 0.98) if i == pending_forge_selection else Color(0.34, 0.34, 0.34, 0.95)
		style.border_color = Color(1.0, 0.88, 0.36, 1.0) if i == pending_forge_selection else Color(0.72, 0.72, 0.72, 0.88)
		style.set_border_width_all(4)
		panel.add_theme_stylebox_override("panel", style)

func _build_frozen_food_shop_item() -> Dictionary:
	var item_cycle: Array[StringName] = [
		TestItemDefs.MEAT_RED_ID,
		TestItemDefs.MEAT_WHITE_ID,
		TestItemDefs.VEG_LEAF_ID,
		TestItemDefs.VEG_ROOT_ID
	]
	var current_day_index: int = progression_state.day_index if progression_state != null else 0
	var selected_item_id: StringName = item_cycle[current_day_index % item_cycle.size()]
	return {
		"id": &"frozen_food",
		"type": &"frozen_food",
		"category": &"frozen",
		"title": "冷冻%s" % TestItemDefs.get_item_display_name(selected_item_id),
		"description": "购买 3 份冷冻食材。冷冻库存不会在营业结束后减半。",
		"cost": 9,
		"state_text": "会立刻送入冷冻库存",
		"item_id": selected_item_id,
		"amount": 3
	}

func _build_facility_shop_item(facility_type: StringName, title: String, description: String, base_cost: int, state_text: String) -> Dictionary:
	var facility_shop_id := StringName("facility_%s" % String(facility_type))
	var purchase_count: int = progression_state.get_stat_purchase_count(facility_shop_id) if progression_state != null else 0
	return {
		"id": facility_shop_id,
		"type": &"facility",
		"category": &"facilities",
		"title": title,
		"description": description,
		"cost": base_cost + purchase_count * 4,
		"state_text": "%s | 已购买 %d 个" % [state_text, purchase_count],
		"facility_type": facility_type
	}

func _build_kitchen_upgrade_shop_item(upgrade_id: StringName, title: String, description: String, base_cost: int, state_text: String) -> Dictionary:
	var shop_id := StringName("kitchen_%s" % String(upgrade_id))
	var purchase_count: int = progression_state.get_stat_purchase_count(shop_id) if progression_state != null else 0
	return {
		"id": shop_id,
		"type": &"kitchen_upgrade",
		"category": &"kitchen",
		"title": title,
		"description": description,
		"cost": base_cost + purchase_count * max(3, int(round(float(base_cost) * 0.3))),
		"state_text": "%s | 已购买 %d 次" % [state_text, purchase_count],
		"upgrade_id": upgrade_id
	}

func _purchase_stat_upgrade(item_data: Dictionary) -> bool:
	if player == null:
		return false
	var stat_id: StringName = StringName(item_data.get("id", &""))
	match stat_id:
		&"move_speed":
			if player.has_method("add_shop_move_speed_bonus"):
				player.add_shop_move_speed_bonus(1.1)
		&"attack_damage":
			if player.has_method("add_shop_attack_damage_bonus"):
				player.add_shop_attack_damage_bonus(1.1)
		&"max_health":
			if player.has_method("add_shop_max_health_bonus"):
				player.add_shop_max_health_bonus(1)
		_:
			return false
	if progression_state != null:
		progression_state.increment_stat_purchase_count(stat_id)
	return true

func _purchase_frozen_food(item_data: Dictionary) -> bool:
	if storage_manager == null or not storage_manager.has_method("add_stock"):
		return false
	var item_id: StringName = StringName(item_data.get("item_id", &""))
	var amount: int = int(item_data.get("amount", 0))
	if amount <= 0:
		return false
	storage_manager.add_stock(item_id, amount, &"frozen")
	return true

func _purchase_facility(item_data: Dictionary) -> bool:
	var facility_type := StringName(item_data.get("facility_type", &""))
	var catalog = preload("res://Scripts/Facilities/FacilityCatalog.gd")
	if not catalog.definition(facility_type).is_empty():
		var count: int = progression_state.get_stat_purchase_count(StringName(item_data.id)) if progression_state != null else 0
		if not catalog.available(facility_type, count):
			pending_shop_message = "该设施已达到购买上限。"
			return false
	if not facility_purchase_callback.is_valid():
		return false
	if not bool(facility_purchase_callback.call(item_data)):
		pending_shop_message = "厨房暂时没有安全位置放下这个设施。"
		return false
	if progression_state != null:
		progression_state.increment_stat_purchase_count(StringName(item_data.get("id", &"facility")))
	return true

func _purchase_kitchen_upgrade(item_data: Dictionary) -> bool:
	if not kitchen_upgrade_callback.is_valid():
		return false
	if not bool(kitchen_upgrade_callback.call(item_data)):
		return false
	if progression_state != null:
		progression_state.increment_stat_purchase_count(StringName(item_data.get("id", &"kitchen_upgrade")))
	return true

func _get_shop_categories() -> Array[Dictionary]:
	return [
		{"id": &"stats", "title": "属性"},
		{"id": &"kitchen", "title": "厨房"},
		{"id": &"facilities", "title": "设施"},
		{"id": &"frozen", "title": "冷冻食材"}
	]

func _get_shop_item_indices_for_category(category_index: int) -> Array[int]:
	var categories: Array[Dictionary] = _get_shop_categories()
	if category_index < 0 or category_index >= categories.size():
		return []
	var category_id: StringName = StringName(categories[category_index].get("id", &""))
	var indices: Array[int] = []
	for i in range(merchant_shop_items.size()):
		if StringName(merchant_shop_items[i].get("category", &"")) == category_id:
			indices.append(i)
	return indices

func _refresh_shop_category_tabs() -> void:
	if shop_category_tabs == null:
		return
	for child in shop_category_tabs.get_children():
		child.queue_free()

	var left_hint := Label.new()
	left_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_hint.custom_minimum_size = Vector2(56.0, 42.0)
	left_hint.add_theme_font_size_override("font_size", 20)
	left_hint.modulate = Color(1.0, 0.9, 0.52, 0.96)
	left_hint.text = "[Q]"
	shop_category_tabs.add_child(left_hint)

	var categories: Array[Dictionary] = _get_shop_categories()
	for i in range(categories.size()):
		var category_data: Dictionary = categories[i]
		var tab := Label.new()
		tab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tab.custom_minimum_size = Vector2(180.0, 42.0)
		tab.add_theme_font_size_override("font_size", 20)
		tab.text = String(category_data.get("title", "Category"))
		tab.modulate = Color(1.0, 0.9, 0.52, 1.0) if i == selected_shop_category_index else Color(0.78, 0.8, 0.84, 0.92)
		shop_category_tabs.add_child(tab)

	var right_hint := Label.new()
	right_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_hint.custom_minimum_size = Vector2(56.0, 42.0)
	right_hint.add_theme_font_size_override("font_size", 20)
	right_hint.modulate = Color(1.0, 0.9, 0.52, 0.96)
	right_hint.text = "[E]"
	shop_category_tabs.add_child(right_hint)

func _refresh_shop_item_list() -> void:
	if shop_item_list == null:
		is_refreshing_shop_ui = false
		return
	for child in shop_item_list.get_children():
		shop_item_list.remove_child(child)
		child.queue_free()
	shop_item_panels.clear()
	shop_item_panel_by_index.clear()
	shop_item_footer_by_index.clear()

	var item_indices: Array[int] = _get_shop_item_indices_for_category(selected_shop_category_index)
	if item_indices.is_empty():
		var empty_label := Label.new()
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 22)
		empty_label.text = "这个分类下暂时没有商品。"
		shop_item_list.add_child(empty_label)
		return

	for item_index in item_indices:
		var item_data: Dictionary = merchant_shop_items[item_index]
		var panel := Panel.new()
		panel.process_mode = Node.PROCESS_MODE_ALWAYS
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.custom_minimum_size = Vector2(260.0, 280.0)
		shop_item_list.add_child(panel)
		shop_item_panels.append(panel)
		shop_item_panel_by_index[item_index] = panel

		var effective_highlight_index: int = _get_shop_highlighted_item_index()
		var is_selected: bool = item_index >= 0 and item_index == selected_shop_index and effective_highlight_index == selected_shop_index
		var is_hovered: bool = item_index >= 0 and item_index == hovered_shop_index
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.48, 0.48, 0.48, 0.98) if is_selected else (Color(0.4, 0.4, 0.4, 0.96) if is_hovered else Color(0.34, 0.34, 0.34, 0.95))
		style.border_color = Color(1.0, 0.88, 0.36, 1.0) if is_selected else (Color(0.92, 0.82, 0.46, 0.96) if is_hovered else Color(0.72, 0.72, 0.72, 0.88))
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
		style.shadow_size = 8
		panel.add_theme_stylebox_override("panel", style)
		if not panel.mouse_entered.is_connected(_on_shop_item_mouse_entered.bind(item_index)):
			panel.mouse_entered.connect(_on_shop_item_mouse_entered.bind(item_index))
		if not panel.mouse_exited.is_connected(_on_shop_item_mouse_exited.bind(item_index)):
			panel.mouse_exited.connect(_on_shop_item_mouse_exited.bind(item_index))
		if not panel.gui_input.is_connected(_on_shop_item_gui_input.bind(item_index)):
			panel.gui_input.connect(_on_shop_item_gui_input.bind(item_index))

		var content := MarginContainer.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.add_theme_constant_override("margin_left", 20)
		content.add_theme_constant_override("margin_top", 18)
		content.add_theme_constant_override("margin_right", 20)
		content.add_theme_constant_override("margin_bottom", 18)
		panel.add_child(content)

		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		content.add_child(column)

		var title := Label.new()
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 26)
		title.text = String(item_data.get("title", "未知商品"))
		column.add_child(title)

		var cost_label := Label.new()
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_size_override("font_size", 24)
		var cost: int = int(item_data.get("cost", 0))
		var is_affordable: bool = get_current_gold() >= cost
		cost_label.modulate = Color(1.0, 0.92, 0.56, 1.0) if is_affordable else Color(1.0, 0.52, 0.42, 1.0)
		cost_label.text = "%d 金" % cost
		column.add_child(cost_label)

		var description := Label.new()
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 19)
		description.modulate = Color(0.9, 0.92, 0.94, 0.88)
		description.text = String(item_data.get("description", ""))
		column.add_child(description)

		var footer := Label.new()
		footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		footer.add_theme_font_size_override("font_size", 17)
		footer.modulate = Color(0.96, 0.96, 0.9, 0.9)
		var prefix: String = "已选择" if is_selected else ("悬停中" if is_hovered else "可购买")
		footer.text = "%s | %s" % [prefix, String(item_data.get("state_text", ""))]
		column.add_child(footer)
		shop_item_footer_by_index[item_index] = footer

func _on_shop_item_mouse_entered(item_index: int) -> void:
	AudioCue.play_ui(&"ui_move")
	if is_refreshing_shop_ui:
		return
	hovered_shop_index = item_index
	_update_shop_item_highlight_states()

func _on_shop_item_mouse_exited(item_index: int) -> void:
	if is_refreshing_shop_ui:
		return
	if hovered_shop_index == item_index:
		hovered_shop_index = -1
	_update_shop_item_highlight_states()

func _on_shop_item_gui_input(event: InputEvent, item_index: int) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		selected_shop_index = item_index
		hovered_shop_index = -1
		_refresh_night_shop_overlay()
		purchase_selected()

func _update_shop_item_highlight_states() -> void:
	var effective_highlight_index: int = _get_shop_highlighted_item_index()
	for item_index in shop_item_panel_by_index.keys():
		var panel: Panel = shop_item_panel_by_index[item_index]
		if panel == null:
			continue
		var footer: Label = shop_item_footer_by_index.get(item_index)
		var is_selected: bool = int(item_index) == selected_shop_index and effective_highlight_index == selected_shop_index
		var is_hovered: bool = int(item_index) == hovered_shop_index
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.48, 0.48, 0.48, 0.98) if is_selected else (Color(0.4, 0.4, 0.4, 0.96) if is_hovered else Color(0.34, 0.34, 0.34, 0.95))
		style.border_color = Color(1.0, 0.88, 0.36, 1.0) if is_selected else (Color(0.92, 0.82, 0.46, 0.96) if is_hovered else Color(0.72, 0.72, 0.72, 0.88))
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
		style.shadow_size = 8
		panel.add_theme_stylebox_override("panel", style)
		if footer != null:
			var prefix: String = "已选择" if is_selected else ("悬停中" if is_hovered else "可购买")
			var item_data: Dictionary = merchant_shop_items[int(item_index)] if int(item_index) >= 0 and int(item_index) < merchant_shop_items.size() else {}
			footer.text = "%s | %s" % [prefix, String(item_data.get("state_text", ""))]

func _scroll_shop_item_into_view(item_index: int) -> void:
	scroll_request_id += 1
	var request_id: int = scroll_request_id
	if not is_inside_tree() or shop_scroll == null or item_index < 0:
		return
	# Nested containers sort at the end of the frame. Rebuilt cards otherwise
	# still have their initial position, and the scrollbar range may be stale.
	await get_tree().process_frame
	if request_id != scroll_request_id or item_index != selected_shop_index:
		return
	if not is_instance_valid(shop_scroll) or not shop_scroll.is_visible_in_tree():
		return
	var target_panel: Control = shop_item_panel_by_index.get(item_index)
	if is_instance_valid(target_panel):
		shop_scroll.ensure_control_visible(target_panel)

func _get_shop_highlighted_item_index() -> int:
	if hovered_shop_index >= 0:
		return hovered_shop_index
	return selected_shop_index
