extends RefCounted

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const BlessingDefs = preload("res://Scripts/Progression/BlessingDefs.gd")

var player: CharacterBody2D
var owned: Dictionary = {}
var rng := RandomNumberGenerator.new()
var timers: Dictionary = {}
var cooldowns: Dictionary = {}
var day_elapsed: float = 0.0
var distance_since_stop: float = 0.0
var continuous_move_time: float = 0.0
var still_time: float = 0.0
var last_position: Vector2 = Vector2.ZERO
var last_dish_id: StringName = &""
var same_dish_stacks: int = 0
var varied_dish_stacks: int = 0
var previous_order_exact: bool = false
var last_assembled_dish_id: StringName = &""
var last_manual_process_family: StringName = &""
var light_combo_target_id: int = 0
var light_combo_stacks: int = 0
var light_combo_remaining: float = 0.0
var recent_kill_times: Array[float] = []
var runtime_clock: float = 0.0
var daily_cheat_death_used: bool = false
var shield_amount: float = 0.0
var shield_remaining: float = 0.0
var today_luck_stat: StringName = &""
var lazy_gold_elapsed: float = 0.0
var last_dash_active: bool = false
var pending_next_attack_multiplier: float = 1.0
var pending_next_light_multiplier: float = 1.0
var current_attack_multiplier: float = 1.0
var last_magic_spend_refund: int = 0
var storage_free_ready: bool = true
var last_zone_id: StringName = &""

func setup(new_player: CharacterBody2D) -> void:
	player = new_player
	rng.randomize()
	last_position = player.global_position if player != null else Vector2.ZERO

func set_owned_blessings(blessing_ids: Array[StringName]) -> void:
	owned.clear()
	for blessing_id in blessing_ids:
		if BlessingDefs.is_valid_id(blessing_id):
			owned[blessing_id] = true

func apply_blessing(blessing_id: StringName) -> bool:
	if not BlessingDefs.is_valid_id(blessing_id):
		return false
	owned[blessing_id] = true
	return true

func has_title(title: String) -> bool:
	var blessing_id := BlessingDefs.get_id_by_title(title)
	return blessing_id != &"" and owned.has(blessing_id)

func begin_day() -> void:
	day_elapsed = 0.0
	timers.clear()
	cooldowns.clear()
	distance_since_stop = 0.0
	continuous_move_time = 0.0
	still_time = 0.0
	last_position = player.global_position if player != null else Vector2.ZERO
	last_zone_id = _get_player_zone_id()
	last_dish_id = &""
	same_dish_stacks = 0
	varied_dish_stacks = 0
	previous_order_exact = false
	last_assembled_dish_id = &""
	last_manual_process_family = &""
	light_combo_target_id = 0
	light_combo_stacks = 0
	light_combo_remaining = 0.0
	daily_cheat_death_used = false
	shield_amount = 0.0
	shield_remaining = 0.0
	lazy_gold_elapsed = 0.0
	recent_kill_times.clear()
	pending_next_attack_multiplier = 1.0
	pending_next_light_multiplier = 1.0
	current_attack_multiplier = 1.0
	storage_free_ready = true
	today_luck_stat = &""
	if has_title("今日大吉"):
		var choices: Array[StringName] = [&"attack", &"work", &"move"]
		today_luck_stat = choices[rng.randi_range(0, choices.size() - 1)]

func tick(delta: float) -> void:
	runtime_clock += delta
	day_elapsed += delta
	_tick_dictionary(timers, delta)
	_tick_dictionary(cooldowns, delta)
	if float(timers.get("next_attack", 0.0)) <= 0.0:
		pending_next_attack_multiplier = 1.0
	shield_remaining = maxf(shield_remaining - delta, 0.0)
	if shield_remaining <= 0.0:
		shield_amount = 0.0
	light_combo_remaining = maxf(light_combo_remaining - delta, 0.0)
	if light_combo_remaining <= 0.0:
		light_combo_target_id = 0
		light_combo_stacks = 0
	if player != null:
		var moved := player.global_position.distance_to(last_position)
		if moved > 0.5:
			distance_since_stop += moved
			continuous_move_time += delta
			still_time = 0.0
		else:
			still_time += delta
			if still_time >= 0.5:
				distance_since_stop = 0.0
				continuous_move_time = 0.0
		last_position = player.global_position
		var current_zone := _get_player_zone_id()
		if last_zone_id != &"" and current_zone != &"" and current_zone != last_zone_id:
			on_door_crossed()
		last_zone_id = current_zone
		var dash_active: bool = player.is_dash_active_for_blessings() if player.has_method("is_dash_active_for_blessings") else false
		if last_dash_active and not dash_active:
			on_dash_finished()
		last_dash_active = dash_active
	_tick_lazy_gold(delta)
	if not storage_free_ready and float(cooldowns.get("storage_free", 0.0)) <= 0.0:
		storage_free_ready = true

func get_move_speed_multiplier() -> float:
	var result := 1.0
	if has_title("迅捷祝福"):
		result *= 1.15
	var direction: Vector2 = player.movement_input_direction if player != null else Vector2.ZERO
	if direction.y > 0.1 and has_title("重力加速度"):
		result *= 1.25
	if direction.y < -0.1 and has_title("一路向北"):
		result *= 1.25
	if has_title("长跑选手"):
		result *= 1.0 + minf(floor(distance_since_stop / 128.0) * 0.05, 0.20)
	if has_title("合理摸鱼"):
		result *= 0.8 if day_elapsed < 100.0 else 1.2
	if has_title("欢迎光临") and _is_player_in_kitchen():
		result *= 1.25
	if has_title("热盘快递") and _held_item_is_finished_dish():
		result *= 1.20
	if has_title("预备动作"):
		if _held_item_is_raw():
			result *= 1.15
		elif _held_item_is_processed_ingredient():
			result *= 1.10
	if has_title("半成品快递") and _held_item_is_processed_ingredient():
		result *= 1.15
	if has_title("设施亲和") and player != null and player.get_facility_carry_move_multiplier() < 1.0:
		# The normal carry multiplier is 0.45. Multiplying by 1.611 reduces its lost speed by 50% (to 0.725).
		result *= 1.611111
	if has_title("多桌调度") and _waiting_order_count() >= 2:
		result *= 1.15
	if has_title("紧急供能") and _magic_ratio() < 0.25:
		result *= 1.20
	if today_luck_stat == &"move":
		result *= 1.20
	for timer_name in ["kill_move", "door_move", "exact_move", "serve_move", "station_move", "hot_move", "response_move", "dash_move", "revive_move", "shared_move", "bullet_move"]:
		if float(timers.get(timer_name, 0.0)) > 0.0:
			result *= float(_timer_multiplier(timer_name))
	return result

func get_work_multiplier(station_state: StringName = &"") -> float:
	var result := 1.0
	if has_title("合理摸鱼"):
		result *= 0.8 if day_elapsed < 100.0 else 1.2
	var station_family := TestItemDefs.get_process_family(station_state)
	if float(timers.get("assembly_work", 0.0)) > 0.0 and station_family in [&"cut", &"grind"]:
		result *= 1.25
	if float(timers.get("take_work", 0.0)) > 0.0:
		result *= 1.20
	if station_family in [&"cut", &"grind"]:
		if has_title("稳步作业") and still_time >= 1.0:
			result *= 1.15
		if has_title("备料熟手"):
			result *= 1.10
	if float(timers.get("manual_chain_work", 0.0)) > 0.0:
		result *= 1.20
	if float(timers.get("cross_station_work", 0.0)) > 0.0 and _is_other_manual_family(station_state):
		result *= 1.30
	if has_title("流水线意识") and _nearby_working_station_count() >= 2:
		result *= 1.15
	if has_title("刀口清亮") and TestItemDefs.normalize_process_state(station_state) == TestItemDefs.PROCESS_STATE_CUT:
		result *= 1.33
	if has_title("需求预判") and _active_orders_require_state(station_state):
		result *= 1.15
	if has_title("越忙越稳") and _active_order_count() >= 2:
		result *= 1.15
	if has_title("满溢魔力") and _is_magic_full():
		result *= 1.25
	if float(timers.get("revive_work", 0.0)) > 0.0:
		result *= 1.25
	if today_luck_stat == &"work":
		result *= 1.20
	return result

func get_health_regen_multiplier() -> float:
	return 1.20 if has_title("坚韧祝福") else 1.0

func modify_attack_damage(base_damage: int, target: Node, is_heavy: bool, distance: float) -> int:
	var result := float(base_damage) * current_attack_multiplier
	if has_title("力量祝福"):
		result *= 1.15
	if has_title("战神之锋") and not is_heavy:
		result *= 1.25
	if has_title("战神之利") and is_heavy:
		result *= 1.25
	if has_title("战神之瞩"):
		result *= 1.25
	if has_title("连斩余势") and float(timers.get("kill_attack", 0.0)) > 0.0:
		result *= 1.20
	if has_title("满溢魔力") and _is_magic_full():
		result *= 1.25
	if today_luck_stat == &"attack":
		result *= 1.20
	var is_boss := _is_boss_target(target)
	if has_title("非首领猎手"):
		result *= 0.9 if is_boss else 1.2
	if has_title("首领挑战"):
		result *= 1.2 if is_boss else 0.9
	if not is_heavy and has_title("轻刃回响"):
		var target_id := target.get_instance_id()
		if target_id == light_combo_target_id and light_combo_remaining > 0.0:
			light_combo_stacks = mini(light_combo_stacks + 1, 3)
		else:
			light_combo_target_id = target_id
			light_combo_stacks = 1
		light_combo_remaining = 2.0
		result *= 1.0 + float(light_combo_stacks) * 0.05
	if not is_heavy and has_title("近身回报") and distance <= 105.0 and _cooldown_ready("close_heal"):
		_heal_fraction(0.02)
		_set_cooldown("close_heal", 3.0)
	if has_title("幸运一击") and rng.randf() < 0.15:
		result *= 2.0
	if has_title("异界来客的威压") and not is_boss and rng.randf() < 0.05:
		return 100000000
	if target != null and target.has_meta("blessing_exposed"):
		result *= 1.15
		target.remove_meta("blessing_exposed")
	if is_heavy and has_title("破甲余波") and (is_boss or _is_elite_target(target)):
		target.set_meta("blessing_exposed", true)
	return maxi(int(round(result)), 1)

func modify_incoming_damage(damage: int, is_heavy_charging: bool) -> int:
	var result := float(maxi(damage, 0))
	if has_title("战神之瞩"):
		result *= 1.15
	if has_title("重击蓄势") and is_heavy_charging:
		result *= 0.80
	if shield_amount > 0.0 and shield_remaining > 0.0:
		var absorbed := minf(shield_amount, result)
		shield_amount -= absorbed
		result -= absorbed
	return maxi(int(round(result)), 0)

func prevent_fatal_damage(current_health: int, pending_damage: int) -> bool:
	if current_health - pending_damage > 0 or daily_cheat_death_used or not has_title("一线生机"):
		return false
	daily_cheat_death_used = true
	timers["invulnerable"] = 1.0
	return true

func is_invulnerable() -> bool:
	return float(timers.get("invulnerable", 0.0)) > 0.0

func get_heavy_range_multiplier(is_full_heavy: bool) -> float:
	return 1.15 if is_full_heavy and has_title("满弦重击") else 1.0

func get_dash_cooldown_rate_multiplier() -> float:
	var result := 1.0
	if has_title("临界闪身") and _health_ratio() < 0.35:
		result *= 1.25
	return result

func get_skill_cooldown_rate_multiplier() -> float:
	return 0.90 if has_title("紧急供能") and _magic_ratio() < 0.25 else 1.0

func get_next_dash_distance_multiplier() -> float:
	return 1.20 if has_title("节奏冲刺") and continuous_move_time >= 1.0 else 1.0

func begin_player_attack(is_heavy: bool) -> void:
	current_attack_multiplier = 1.0
	if float(timers.get("next_attack", 0.0)) > 0.0 and pending_next_attack_multiplier > 1.0:
		current_attack_multiplier *= pending_next_attack_multiplier
		pending_next_attack_multiplier = 1.0
		timers["next_attack"] = 0.0
	if not is_heavy and pending_next_light_multiplier > 1.0:
		current_attack_multiplier *= pending_next_light_multiplier
		pending_next_light_multiplier = 1.0

func end_player_attack() -> void:
	current_attack_multiplier = 1.0

func on_dash_started() -> float:
	if has_title("冲刺返券") and rng.randf() < 0.25:
		return 0.40
	return 1.0

func on_dash_finished() -> void:
	if has_title("冲刺余速"):
		timers["dash_move"] = 2.0
	if has_title("冲锋余威"):
		pending_next_attack_multiplier = maxf(pending_next_attack_multiplier, 1.20)
		timers["next_attack"] = 3.0

func on_unit_killed(_unit: Node, original_drop_count: int) -> int:
	if has_title("猎神之风"):
		timers["kill_move"] = 3.0
	if has_title("猎神之护"):
		shield_amount = float(_max_health()) * 0.20
		shield_remaining = 5.0
	if has_title("击杀冲锋") and _cooldown_ready("kill_dash"):
		if player != null and player.has_method("reduce_dash_cooldown_fraction"):
			player.reduce_dash_cooldown_fraction(0.25)
		_set_cooldown("kill_dash", 5.0)
	if has_title("连斩余势"):
		recent_kill_times.append(runtime_clock)
		while not recent_kill_times.is_empty() and runtime_clock - recent_kill_times[0] > 5.0:
			recent_kill_times.remove_at(0)
		if recent_kill_times.size() >= 2:
			timers["kill_attack"] = 5.0
	var result := original_drop_count
	if has_title("猎神之刃"):
		result += 1
	return result

func on_forage_yield(amount: int) -> int:
	return amount + 1 if has_title("农耕血脉") and rng.randf() < 0.30 else amount

func should_consume_storage_item() -> bool:
	if has_title("盘点时间") and storage_free_ready and rng.randf() < 0.15:
		storage_free_ready = false
		_set_cooldown("storage_free", 15.0)
		return false
	return true

func on_magic_spent(amount: int) -> int:
	last_magic_spend_refund = 0
	if amount <= 0:
		return 0
	if has_title("魔力免单") and rng.randf() < 0.20:
		last_magic_spend_refund = amount
	elif has_title("魔力回响") and _cooldown_ready("magic_echo") and rng.randf() < 0.25:
		last_magic_spend_refund = 1
		_set_cooldown("magic_echo", 6.0)
	return last_magic_spend_refund

func on_door_crossed() -> void:
	if has_title("虚空步伐") and _cooldown_ready("door"):
		timers["door_move"] = 3.0
		_set_cooldown("door", 10.0)

func modify_waiting_order(order_data: Dictionary) -> Dictionary:
	var result := order_data.duplicate(true)
	if has_title("幸运预约") and rng.randf() < 0.30:
		result["order_take_patience_multiplier"] = 1.50
	if has_title("热情好客") and rng.randf() < 0.35:
		result["order_take_action_multiplier"] = 0.50
	return result

func on_order_taken(order_data: Dictionary, was_quick: bool) -> Dictionary:
	var result := order_data.duplicate(true)
	var patience := float(result.get("patience_duration", 36.0))
	if has_title("耐心招待"):
		patience *= 1.08
	if has_title("快速响应") and was_quick:
		patience *= 1.15
	if has_title("开门红") and int(result.get("day_customer_index", 99)) < 3:
		patience *= 1.20
	result["patience_duration"] = patience
	result["time_remaining"] = patience
	if has_title("及时回应") and was_quick:
		timers["response_move"] = 4.0
	return result

func on_order_completed(order_data: Dictionary) -> Dictionary:
	var result := order_data.duplicate(true)
	var exact := bool(result.get("exact_recipe", true))
	var dish_id := StringName(result.get("dish_item_id", &""))
	var reward_multiplier := 1.0
	if has_title("满意加餐") and exact and previous_order_exact:
		reward_multiplier *= 1.10
	if has_title("开门红") and int(result.get("day_customer_index", 99)) < 3:
		reward_multiplier *= 1.10
	if has_title("古代复读机"):
		if dish_id == last_dish_id:
			same_dish_stacks = mini(same_dish_stacks + 1, 5)
		else:
			same_dish_stacks = 0
		reward_multiplier *= 1.0 + float(same_dish_stacks) * 0.04
	if has_title("多彩餐盘"):
		if last_dish_id != &"" and dish_id != last_dish_id:
			varied_dish_stacks = mini(varied_dish_stacks + 1, 5)
		else:
			varied_dish_stacks = 0
		reward_multiplier *= 1.0 + float(varied_dish_stacks) * 0.03
	if has_title("天降小费") and exact and rng.randf() < 0.25:
		reward_multiplier *= 1.40
	result["gold_reward"] = int(round(float(result.get("gold_reward", 0)) * reward_multiplier))
	result["xp_reward"] = int(round(float(result.get("xp_reward", 0)) * reward_multiplier))
	if exact and has_title("余温回馈"):
		timers["exact_move"] = 3.0
	if has_title("空盘回程"):
		timers["serve_move"] = 3.0
	previous_order_exact = exact
	last_dish_id = dish_id
	lazy_gold_elapsed = 0.0
	return result

func on_other_customer_completed() -> void:
	if not has_title("清台有方"):
		return
	var order_manager := _order_manager()
	if order_manager != null and order_manager.has_method("restore_all_active_order_patience_fraction"):
		order_manager.restore_all_active_order_patience_fraction(0.05)

func on_assembly_result(success: bool, output_id: StringName, input_items: Array) -> Dictionary:
	var result: Dictionary = {}
	if success:
		if has_title("组合巧手"):
			timers["assembly_work"] = 6.0
		var repeated := output_id == last_assembled_dish_id and output_id != &""
		last_assembled_dish_id = output_id
		if repeated and has_title("配方记忆"):
			result = _pick_refund_item(input_items)
		elif has_title("配方赠品") and rng.randf() < 0.20:
			result = _pick_refund_item(input_items)
	elif has_title("不浪费") and not input_items.is_empty():
		result = (input_items[input_items.size() - 1] as Dictionary).duplicate(true)
	return result

func on_station_item_taken(process_state: StringName, was_finished: bool) -> void:
	var family := TestItemDefs.get_process_family(process_state)
	if was_finished and has_title("归位本能") and family in [&"cut", &"grind"]:
		timers["take_work"] = 4.0
	if was_finished and has_title("趁热出锅") and family == &"roast":
		timers["hot_move"] = 3.0

func on_manual_process_completed(process_state: StringName) -> void:
	var family := TestItemDefs.get_process_family(process_state)
	if has_title("台面余裕"):
		timers["station_move"] = 3.0
	if has_title("手不停歇"):
		timers["manual_chain_work"] = 5.0
	if has_title("刀磨同心"):
		last_manual_process_family = family
		timers["cross_station_work"] = 8.0

func modify_tap_progress_count(base_count: int, press_number: int) -> int:
	var result := base_count
	if has_title("节奏刀法") and press_number % 3 == 0:
		result += 1
	if has_title("多切一刀") and rng.randf() < 0.20:
		result += 1
	return result

func get_initial_grind_progress_ratio() -> float:
	return 0.40 if has_title("石臼彩头") and rng.randf() < 0.40 else 0.0

func get_auto_stage_duration_multiplier() -> float:
	return 1.50 if has_title("火候偏爱") and rng.randf() < 0.40 else 1.0

func on_grind_completed() -> void:
	if has_title("研磨回弹"):
		timers["grind_rebound"] = 6.0

func get_grind_rebound_ratio() -> float:
	if float(timers.get("grind_rebound", 0.0)) <= 0.0:
		return 0.0
	timers["grind_rebound"] = 0.0
	return 0.30

func on_revived() -> void:
	if has_title("回光返照"):
		timers["revive_move"] = 8.0
		timers["revive_work"] = 8.0

func on_bullet_warning_started(duration: float = 2.0) -> void:
	if has_title("弹幕预感"):
		timers["bullet_move"] = maxf(duration, 0.0)

func on_bullet_dodged() -> void:
	if has_title("弹幕回避"):
		pending_next_light_multiplier = maxf(pending_next_light_multiplier, 1.30)

func on_other_player_magic_spent() -> void:
	if has_title("共享节拍"):
		timers["shared_move"] = 3.0

func get_drop_attract_range_multiplier(defeat_position: Vector2) -> float:
	if not has_title("狩猎路线") or not _is_battle_region_center(defeat_position):
		return 1.0
	return 1.30

func get_end_of_day_gold(magic_remaining: int) -> int:
	return maxi(magic_remaining, 0) * 2 if has_title("余量管理") else 0

func get_low_cost_skill_duration_multiplier(cost: int) -> float:
	return 1.25 if has_title("节约施法") and cost < 3 else 1.0

func _tick_lazy_gold(delta: float) -> void:
	if not has_title("懒惰之手") or not _is_service_active():
		return
	lazy_gold_elapsed += delta
	if lazy_gold_elapsed < 15.0:
		return
	lazy_gold_elapsed -= 15.0
	var flow := _level_flow()
	if flow != null and flow.has_method("add_blessing_gold"):
		flow.add_blessing_gold(5)

func _tick_dictionary(values: Dictionary, delta: float) -> void:
	for key in values.keys():
		values[key] = maxf(float(values[key]) - delta, 0.0)

func _timer_multiplier(timer_name: String) -> float:
	match timer_name:
		"kill_move": return 1.25
		"door_move": return 1.35
		"exact_move": return 1.25
		"serve_move": return 1.25
		"station_move": return 1.20
		"hot_move": return 1.35
		"response_move": return 1.40
		"dash_move": return 1.25
		"revive_move": return 1.25
		"shared_move": return 1.15
		"bullet_move": return 1.20
		_: return 1.0

func _cooldown_ready(key: String) -> bool:
	return float(cooldowns.get(key, 0.0)) <= 0.0

func _set_cooldown(key: String, duration: float) -> void:
	cooldowns[key] = duration

func _level_flow() -> Node:
	return player.get_level_flow_controller_for_blessings() if player != null and player.has_method("get_level_flow_controller_for_blessings") else null

func _order_manager() -> Node:
	var flow := _level_flow()
	return flow.get_order_manager_for_blessings() if flow != null and flow.has_method("get_order_manager_for_blessings") else null

func _active_order_count() -> int:
	var manager := _order_manager()
	return manager.get_active_orders().size() if manager != null and manager.has_method("get_active_orders") else 0

func _waiting_order_count() -> int:
	var manager := _order_manager()
	return manager.get_waiting_orders().size() if manager != null and manager.has_method("get_waiting_orders") else 0

func _active_orders_require_state(station_state: StringName) -> bool:
	var manager := _order_manager()
	if manager == null or not manager.has_method("get_active_orders"):
		return false
	var family := TestItemDefs.get_process_family(station_state)
	for order_data in manager.get_active_orders():
		for recipe_item in order_data.get("recipe_items", []):
			if TestItemDefs.get_process_family(StringName(recipe_item.get("process_state", &""))) == family:
				return true
	return false

func _nearby_working_station_count() -> int:
	if player == null:
		return 0
	var count := 0
	for station in player.get_tree().get_nodes_in_group("cooking_stations"):
		if station is Node2D and player.global_position.distance_to(station.global_position) <= 256.0 and station.has_method("is_processing_for_blessings") and station.is_processing_for_blessings():
			count += 1
	return count

func _is_other_manual_family(station_state: StringName) -> bool:
	var family := TestItemDefs.get_process_family(station_state)
	return last_manual_process_family != &"" and family != &"" and family != last_manual_process_family

func _is_player_in_kitchen() -> bool:
	if player == null:
		return false
	var map: Node = player.get_prototype_map_node() if player.has_method("get_prototype_map_node") else null
	return map != null and map.has_method("is_point_in_kitchen_zone") and map.is_point_in_kitchen_zone(player.global_position)

func _get_player_zone_id() -> StringName:
	if player == null:
		return &""
	var map: Node = player.get_prototype_map_node() if player.has_method("get_prototype_map_node") else null
	return StringName(map.get_zone_for_point(player.global_position)) if map != null and map.has_method("get_zone_for_point") else &""

func _held_item_is_finished_dish() -> bool:
	return player != null and player.has_method("get_held_item_id") and TestItemDefs.is_dish(player.get_held_item_id())

func _held_item_is_raw() -> bool:
	return (
		player != null
		and player.has_method("get_held_item_id")
		and player.has_method("get_held_item_process_state")
		and TestItemDefs.is_ingredient(player.get_held_item_id())
		and TestItemDefs.is_raw_state(player.get_held_item_process_state())
	)

func _held_item_is_processed_ingredient() -> bool:
	return player != null and player.has_method("get_held_item_id") and TestItemDefs.is_ingredient(player.get_held_item_id()) and not _held_item_is_raw()

func _health_ratio() -> float:
	return player.get_health_ratio_for_blessings() if player != null and player.has_method("get_health_ratio_for_blessings") else 1.0

func _max_health() -> int:
	return player.get_current_max_health() if player != null and player.has_method("get_current_max_health") else 100

func _heal_fraction(value: float) -> void:
	if player != null and player.has_method("heal_for_blessings"):
		player.heal_for_blessings(maxi(int(round(float(_max_health()) * value)), 1))

func _magic_ratio() -> float:
	var flow := _level_flow()
	return flow.get_magic_ratio_for_blessings() if flow != null and flow.has_method("get_magic_ratio_for_blessings") else 1.0

func _is_magic_full() -> bool:
	return _magic_ratio() >= 0.999

func _is_service_active() -> bool:
	var flow := _level_flow()
	return flow != null and flow.has_method("is_service_active_for_blessings") and flow.is_service_active_for_blessings()

func _is_boss_target(target: Node) -> bool:
	return target != null and (target.is_in_group("bosses") or bool(target.get_meta("is_boss", false)))

func _is_elite_target(target: Node) -> bool:
	return target != null and (target.is_in_group("elites") or bool(target.get_meta("is_elite", false)))

func _is_battle_region_center(point: Vector2) -> bool:
	if player == null:
		return false
	var map: Node = player.get_prototype_map_node() if player.has_method("get_prototype_map_node") else null
	if map == null or not map.has_method("get_battle_region_for_point") or not map.has_method("get_region_bounds"):
		return false
	var region_id: StringName = map.get_battle_region_for_point(point)
	if region_id == &"":
		return false
	var rect: Rect2 = map.get_region_bounds(region_id)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	# "中心范围"使用区域中央 50% 的矩形，边界清楚且不会把沙丘附近算进去。
	return rect.grow_individual(-rect.size.x * 0.25, -rect.size.y * 0.25, -rect.size.x * 0.25, -rect.size.y * 0.25).has_point(point)

func _pick_refund_item(input_items: Array) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for item_data in input_items:
		if item_data is Dictionary and not TestItemDefs.is_drink(StringName(item_data.get("item_id", &""))):
			candidates.append((item_data as Dictionary).duplicate(true))
	return candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else {}
