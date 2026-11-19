extends Node

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const Defs = preload("res://Scripts/Progression/NightEventDefs.gd")
const NPC = preload("res://Scripts/Restaurant/NightEventNPC.gd")
const Dialogue = preload("res://Scripts/UI/NightEventDialogue.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
const Indicators = preload("res://Scripts/UI/NightEventIndicators.gd")
const Blessings = preload("res://Scripts/Progression/BlessingDefs.gd")

var flow: Node
var npc: Node2D
var dialogue: CanvasLayer
var active_id: StringName = &""
var page: StringName = &"offer"
var options: Array[Dictionary] = []
var selected_relation: StringName = &""
var host_facility: Node2D
var spawned_night: int = -1
var npcs: Dictionary = {}
var hosts: Dictionary = {}
var indicators: CanvasLayer

func setup(host: Node) -> void:
	flow = host
	dialogue = Dialogue.new()
	add_child(dialogue)
	dialogue.choice_selected.connect(_on_choice_selected)
	dialogue.dialogue_closed.connect(close_dialogue)
	indicators = Indicators.new()
	add_child(indicators)

func refresh_night() -> void:
	# Initial flow readiness precedes the scene's remaining facilities.
	if not flow.level_refs.get_runtime_root().is_node_ready():
		call_deferred("refresh_night")
		return
	var state = flow.progression_state
	state.events.ensure_night(state.day_index, state.modifiers.run_seed)
	_sync_plate_allocations()
	var ids: Array[StringName] = _night_event_ids()
	if spawned_night != state.day_index:
		for visitor: Node2D in npcs.values():
			if is_instance_valid(visitor):
				visitor.free()
		npcs.clear()
		hosts.clear()
		spawned_night = state.day_index
	var appeared: bool = false
	for id: StringName in ids:
		if npcs.has(id):
			continue
		host_facility = _find_host(id)
		hosts[id] = host_facility
		npc = NPC.new()
		npc.controller = self
		npc.event_id = id
		flow.level_refs.get_runtime_root().add_child(npc)
		npc.global_position = _spawn_position(id)
		npcs[id] = npc
		appeared = true
	if not ids.is_empty() and (not ids.has(active_id) or appeared):
		active_id = ids[0]
		npc = npcs[active_id]
		host_facility = hosts[active_id]
	sync_presence()
	if appeared:
		AudioCue.play_sfx(&"warning", -3.0)
		if ids.size() > 1:
			var names: Array[String] = []
			for id: StringName in ids:
				names.append(String(Defs.TITLES[id]))
			flow.overlay_controller.show_toast("夜间访客已到访：%s\n跟随屏外指引，靠近按 J 交谈。" % "、".join(names), 10.0)
		else:
			var location := "烤台旁" if active_id == &"furnace" else ("净化池旁" if active_id == &"porcelain" else ("酒馆内" if active_id == &"repayment" else "战斗区靠近料理区的入口旁"))
			flow.overlay_controller.show_toast("%s出现在%s，头顶有 ! 标记。" % [Defs.TITLES[active_id], location], 5.0)

func _night_event_ids() -> Array[StringName]:
	var state = flow.progression_state
	var ids: Array[StringName] = []
	if state.events.investment_due(state.day_index):
		ids.append(&"repayment")
	elif state.events.ALL_EVENTS_PLAYTEST and state.day_index == 0:
		ids.assign(state.events.FIRST_BATCH)
		ids.append_array(state.events.SECOND_BATCH)
	elif state.events.INITIAL_NIGHT_PLAYTEST and state.day_index == 0:
		ids.assign(state.events.FIRST_BATCH)
	elif state.events.SECOND_NIGHT_PLAYTEST and state.day_index == 0:
		ids.assign(state.events.SECOND_BATCH)
	elif state.events.event_id != &"":
		ids.append(state.events.event_id)
	return ids

func sync_presence() -> void:
	var events = flow.progression_state.events
	var ids: Array[StringName] = _night_event_ids()
	for id: StringName in npcs:
		var visitor: Node2D = npcs[id]
		visitor.set_presence(flow.is_night_rest_active() and ids.has(id) and (id == &"repayment" or not events.is_complete(id)))
	indicators.update_targets(npcs)

func open_dialogue(id: StringName = &"") -> void:
	if not flow.is_night_rest_active():
		return
	if id != &"":
		if not npcs.has(id) or not npcs[id].visible:
			return
		active_id = id
		npc = npcs[id]
		host_facility = hosts[id]
	if active_id == &"" or (active_id != &"repayment" and flow.progression_state.events.is_complete(active_id)):
		return
	# The NPC cue carries the character identity; avoid stacking the generic
	# event jingle over it, which previously made every visitor sound alike.
	AudioCue.npc(active_id)
	flow.run_context.state = Context.LevelState.NIGHT_EVENT
	get_tree().paused = true
	page = &"offer"
	options = Defs.chaos_choices(hash("chaos:%d:%d" % [flow.progression_state.modifiers.run_seed, flow.progression_state.events.night_index])) if active_id == &"prankster" else Defs.choices(active_id)
	for option: Dictionary in options:
		option["disabled"] = not _can_choose(StringName(option.id))
	_append_decline_option()
	var body: String = Defs.OPENINGS[active_id]
	if active_id == &"repayment":
		body += "\n本次返还：%d 金币。" % int(flow.progression_state.events.investment.payout)
	_show(body)

func close_dialogue() -> void:
	dialogue.visible = false
	flow.run_context.state = Context.LevelState.NIGHT_REST
	flow.get_tree().paused = false
	flow.input_release_guard_active = true
	refresh_night()

func blocks_next_day() -> bool:
	return flow.progression_state.events.investment_due(flow.progression_state.day_index) or flow.progression_state.pending_menu_offer_kind == &"event"

func handle_action(action: int) -> void:
	dialogue.handle_action(action)

func finish_menu_exchange() -> void:
	var state = flow.progression_state
	state.events.complete(&"exchange", "付费更换一道菜单菜品", active_id)
	_result("新的做法已经刻好了。愿你明天用得顺手。")

func _show(body: String) -> void:
	flow.overlay_controller.hide_toast()
	dialogue.show_page(Defs.TITLES[active_id], body, active_id, options)

func _on_choice_selected(index: int) -> void:
	if index < 0 or index >= options.size():
		return
	var id := StringName(options[index].id)
	if id == &"decline":
		if active_id != &"repayment" and page in [&"offer", &"old_recipe"] and flow.progression_state.pending_menu_offer_kind != &"event":
			flow.progression_state.events.complete(&"decline", "拒绝交易，NPC 当晚离开", active_id)
			close_dialogue()
		return
	if page == &"result":
		close_dialogue()
		return
	if page == &"old_recipe":
		_buy_recipe(id)
		return
	if active_id != &"repayment" and flow.progression_state.events.is_complete(active_id):
		return
	if not _can_choose(id):
		return
	var state = flow.progression_state
	var events = state.events
	var result_detail: String = String(options[index].get("detail", ""))
	match active_id:
		&"merchant":
			var principal: int = state.gold / 2 if id == &"half" else state.gold
			var investment_day: int = 1 if state.day_index == 0 and (state.events.SECOND_NIGHT_PLAYTEST or state.events.ALL_EVENTS_PLAYTEST) else state.day_index
			if not events.begin_investment(principal, id == &"all", investment_day):
				return
			state.add_gold(-principal)
		&"devil":
			if id == &"health":
				events.apply_devil(id)
				var current_player: Node = flow.player
				if current_player != null and current_player.has_method("set_event_max_health_penalty"):
					current_player.set_event_max_health_penalty(events.max_health_penalty)
				state.add_gold(100)
			else:
				var remove_count: int = 1 if id == &"blessing" else 2
				var blessing_ids: Array[StringName] = state.get_owned_blessing_ids()
				var rng := RandomNumberGenerator.new()
				rng.seed = hash("devil:%d:%s" % [state.modifiers.run_seed, id])
				var removed_names: Array[String] = []
				for remove_index in range(remove_count):
					if blessing_ids.is_empty():
						break
					var blessing_index: int = rng.randi_range(0, blessing_ids.size() - 1)
					var removed_id: StringName = blessing_ids[blessing_index]
					if state.remove_blessing(removed_id):
						removed_names.append(String(Blessings.get_definition(removed_id).get("title", removed_id)))
					blessing_ids.remove_at(blessing_index)
				state.add_gold(160 if id == &"blessing" else 280)
				result_detail = "失去祝福：%s。\n获得 %d 金币，当前剩余 %d 个祝福。" % ["、".join(removed_names), 160 if id == &"blessing" else 280, state.get_owned_blessing_ids().size()]
			_sync_player_blessings()
		&"sand_spirit":
			if not _consume_random_ordinary_ingredients(10 if id == &"patience" else (20 if id == &"grind" else 30)):
				return
			events.apply_sand_spirit(id)
		&"prankster":
			events.apply_chaos(options[index], state.day_index)
		&"furnace":
			events.roast_speed *= 1.1 if id == &"flame" else 1.3
			if id == &"core":
				events.burn_speed *= 1.5
		&"engraver":
			selected_relation = id
			page = &"old_recipe"
			options.clear()
			for dish: StringName in state.get_menu_dish_ids():
				if state.event_menu_candidates(dish, id).is_empty() or state._is_special_recipe(dish):
					continue
				options.append({"id": dish, "text": Items.get_item_display_name(dish), "detail": "支付 60 金币后，进入新菜选择。本次不可刷新。"})
			_append_decline_option()
			_show("要抹去石板上的哪一道菜？选定后立即支付 60 金币。")
			return
		&"porcelain":
			var change: int = 1 if id == &"buy" else -1
			if id == &"buy":
				if not state.spend_gold(Defs.PLATE_COST):
					return
			else:
				state.add_gold(Defs.PLATE_COST)
			events.extra_plates += change
			events.wash_speed *= 0.8 if change > 0 else 1.25
			var key := String(host_facility.get_path())
			events.plate_allocations[key] = int(events.plate_allocations.get(key, 0)) + change
			_sync_plate_allocations()
		&"gambler":
			if id == &"charm":
				if not state.spend_gold(Defs.CHARM_COST):
					return
				events.daily_charm = true
			else:
				events.begin_wager(state.day_index)
		&"repayment":
			state.add_gold(events.collect_investment(state.day_index))
			_result("钱已全部交给你，去准备明天的营业吧。")
			return
	events.complete(id, result_detail, active_id)
	_result("说定了。\n" + result_detail)

func _append_decline_option() -> void:
	if active_id != &"repayment":
		options.append({"id": &"decline", "text": "拒绝交易，请对方离开", "detail": "放弃今晚这次事件，NPC 将离开。按 K 则只关闭对话，保留事件。"})

func _buy_recipe(old_id: StringName) -> void:
	var state = flow.progression_state
	if not state.can_afford(Defs.ENGRAVER_COST) or not state.create_event_menu_offer(old_id, selected_relation):
		return
	state.spend_gold(Defs.ENGRAVER_COST)
	dialogue.visible = false
	flow._open_menu_dish_overlay(true, "刻碑师：选择新菜", "已支付 60 金币 · 不可刷新")

func _can_choose(id: StringName) -> bool:
	var state = flow.progression_state
	match active_id:
		&"merchant":
			var valid_day: bool = state.day_index == 1 or (state.day_index == 0 and (state.events.SECOND_NIGHT_PLAYTEST or state.events.ALL_EVENTS_PLAYTEST))
			return state.events.investment.is_empty() and valid_day and state.gold >= (2 if id == &"half" else 1) and id in [&"half", &"all"]
		&"devil":
			if id == &"health":
				return is_instance_valid(flow.player) and flow.player.get_current_max_health() > 20
			var required: int = 1 if id == &"blessing" else 2
			return state.get_owned_blessing_ids().size() >= required
		&"sand_spirit":
			return _get_ordinary_ingredient_total() >= (10 if id == &"patience" else (20 if id == &"grind" else 30))
		&"engraver":
			if not state.can_afford(Defs.ENGRAVER_COST) or state.has_pending_menu_offer():
				return false
			for dish: StringName in state.get_menu_dish_ids():
				if not state._is_special_recipe(dish) and not state.event_menu_candidates(dish, id).is_empty():
					return true
			return false
		&"porcelain":
			if not is_instance_valid(host_facility):
				return false
			if id == &"buy":
				return state.can_afford(Defs.PLATE_COST)
			var total := 0
			for sink: Node in get_tree().get_nodes_in_group("plate_sinks"):
				total += sink.STARTING_PLATES + sink.event_plate_bonus
			return total > 2 and host_facility.clean_plates > 0 and host_facility.STARTING_PLATES + host_facility.event_plate_bonus > 0
		&"gambler":
			if state.events.daily_charm:
				return false
			return id == &"wager" or state.can_afford(Defs.CHARM_COST)
	return true

func _get_ordinary_ingredient_total() -> int:
	var total: int = 0
	var storage: Node = flow.storage_manager
	if storage == null:
		return 0
	for item_id: StringName in _get_event_ingredient_ids():
		total += int(storage.get_available_stock(item_id))
	return total

func _get_event_ingredient_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for cabinet: Node in get_tree().get_nodes_in_group("storage_facilities"):
		if not cabinet.has_method("is_ordinary_stock_event_source") or not cabinet.is_ordinary_stock_event_source():
			continue
		if cabinet.storage_manager != flow.storage_manager:
			continue
		var item_id: StringName = cabinet.stored_item_id
		if item_id not in ids:
			ids.append(item_id)
	return ids

func _consume_random_ordinary_ingredients(amount: int) -> bool:
	if _get_ordinary_ingredient_total() < amount:
		return false
	var ids: Array[StringName] = []
	for item_id: StringName in _get_event_ingredient_ids():
		if flow.storage_manager.get_available_stock(item_id) > 0:
			ids.append(item_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("sand-spirit:%d:%d" % [flow.progression_state.modifiers.run_seed, flow.progression_state.events.night_index])
	var remaining: int = amount
	while remaining > 0 and not ids.is_empty():
		var index: int = rng.randi_range(0, ids.size() - 1)
		var item_id: StringName = ids[index]
		if flow.storage_manager.consume_stock(item_id, 1):
			remaining -= 1
		if flow.storage_manager.get_available_stock(item_id) <= 0:
			ids.remove_at(index)
	return remaining == 0

func _sync_player_blessings() -> void:
	var current_player: Node = flow.player
	if current_player != null and current_player.has_method("set_owned_blessings_for_run"):
		current_player.set_owned_blessings_for_run(flow.progression_state.get_owned_blessing_ids())

func _result(body: String) -> void:
	page = &"result"
	flow.run_context.state = Context.LevelState.NIGHT_EVENT
	flow.get_tree().paused = true
	flow._set_overlay_visible(false)
	flow._update_run_status_hud()
	options = [{"id": &"done", "text": "告别", "detail": "返回夜间备战。"}]
	_show(body)

func _sync_plate_allocations() -> void:
	var allocations: Dictionary = flow.progression_state.events.plate_allocations
	for sink: Node in get_tree().get_nodes_in_group("plate_sinks"):
		sink.set_event_plate_bonus(int(allocations.get(String(sink.get_path()), 0)))

func _find_host(id: StringName) -> Node2D:
	var hosts: Array[Node] = []
	if id == &"porcelain":
		hosts = get_tree().get_nodes_in_group("plate_sinks")
	elif id == &"furnace":
		for station: Node in get_tree().get_nodes_in_group("cooking_stations"):
			if station.cooking_process_mode == &"auto":
				hosts.append(station)
	if hosts.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("event-host:%d:%d" % [flow.progression_state.modifiers.run_seed, spawned_night])
	return hosts[rng.randi_range(0, hosts.size() - 1)] as Node2D

func _spawn_position(id: StringName) -> Vector2:
	var map: Node2D = flow.level_refs.get_prototype_map()
	var bounds: Rect2 = map.get_kitchen_zone_bounds() if id in [&"furnace", &"porcelain", &"repayment"] else map.get_region_bounds(&"near")
	var origin := host_facility.global_position if is_instance_valid(host_facility) else Vector2(bounds.get_center().x + 190, bounds.end.y - 190)
	# Keep the NPC's feet clear of bodies and item/vehicle footprints.
	for ring in range(1, 9):
		for offset: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(1, 1), Vector2(-1, 1)]:
			var point := origin + offset * 96 * ring
			if not bounds.grow(-65).has_point(point) or not map.is_point_in_playable_area(point, Vector2(35, 35)):
				continue
			var overlaps_visitor: bool = false
			for visitor: Node2D in npcs.values():
				if visitor.global_position.distance_to(point) < 150.0:
					overlaps_visitor = true
					break
			if overlaps_visitor:
				continue
			var shape := CircleShape2D.new()
			shape.radius = 45
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape
			query.transform = Transform2D(0, point)
			query.collision_mask = 1 | 4 | 16
			if map.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				return point
	return bounds.get_center()
