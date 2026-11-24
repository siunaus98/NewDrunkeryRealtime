extends Node

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const OrderGroupDefs = preload("res://Scripts/Orders/OrderGroupDefs.gd")
const SERVED_DRINK_PATIENCE_FRACTION: float = 0.10
const SERVED_DISH_PATIENCE_FRACTION: float = 0.20

signal orders_changed(order_list: Array)
signal waiting_orders_changed(order_list: Array)
signal order_progress_changed(order_id: String, time_remaining: float, patience_duration: float)
signal waiting_order_progress_changed(order_id: String, time_remaining: float, patience_duration: float)
signal order_completed(order_data: Dictionary)
signal dessert_served(dish_data: Dictionary)
signal order_expired(order_data: Dictionary)
signal special_guest_penalty_tick(amount: int)
signal special_guest_completed

@export var default_order_take_patience_duration: float = 75.0
@export var default_order_take_action_duration: float = 0.8

# Dish records keep recipe/reward data. Acceptance and timers belong only to
# the customer occupying a window; public dish snapshots mirror that state.
var waiting_orders: Array[Dictionary] = []
var active_orders: Array[Dictionary] = []
var customers: Dictionary = {}
var day_customer_counter: int = 0
var special_guest_active: bool = false
var special_guest_time_remaining: float = 0.0
var special_guest_patience_duration: float = 0.0
var special_guest_pressure_active: bool = false
var special_guest_penalty_cooldown: float = 0.0
var special_guest_penalty_interval: float = 5.0
var special_guest_overdue: bool = false
var flame_chain_bonus := 0.0

func _process(delta: float) -> void:
	_process_special_guest(delta)
	var expired_customers: Array[String] = []
	var flow: Node = null
	if is_inside_tree():
		var refs := preload("res://Scripts/Core/LevelRefs.gd").find_from(self)
		flow = refs.get_level_flow_controller() if refs != null else null
	for customer_id: String in customers:
		var customer: Dictionary = customers[customer_id]
		var accepted: bool = bool(customer.get("accepted", false))
		var remaining_key := "time_remaining" if accepted else "order_take_time_remaining"
		if bool(customer.get("special_guest", false)):
			if accepted:
				customer["time_remaining"] = special_guest_time_remaining
		else:
			var decay_multiplier: float = 1.25 if accepted and special_guest_pressure_active else 1.0
			if flow != null and flow.has_method("get_run_modifier_multiplier"):
				decay_multiplier *= float(flow.get_run_modifier_multiplier(&"patience_decay"))
			if flow != null and flow.has_method("get_patience_speed_playtest_multiplier"):
				decay_multiplier *= float(flow.get_patience_speed_playtest_multiplier())
			customer[remaining_key] = maxf(float(customer[remaining_key]) - maxf(delta, 0.0) * decay_multiplier, 0.0)
			if float(customer[remaining_key]) <= 0.0:
				expired_customers.append(customer_id)
		var action_frame := int(customer.get("order_take_action_frame", -2))
		if Engine.get_process_frames() - action_frame > 1:
			customer["order_take_action_progress"] = 0.0
		_publish_customer_progress(customer_id)
	for customer_id: String in expired_customers:
		_expire_customer(customer_id)

func clear_orders() -> void:
	waiting_orders.clear()
	active_orders.clear()
	customers.clear()
	special_guest_active = false
	special_guest_pressure_active = false
	special_guest_time_remaining = 0.0
	special_guest_patience_duration = 0.0
	special_guest_overdue = false
	special_guest_penalty_cooldown = special_guest_penalty_interval
	_emit_waiting_orders_changed()
	_emit_orders_changed()

func set_orders(order_list: Array) -> void:
	clear_orders()
	add_orders(order_list)

func add_orders(order_list: Array) -> void:
	# Arrival must not clear existing customers, claims, acceptance or timers.
	var occupied_customers := customers.keys()
	var blessing_runtime := _get_blessing_runtime()
	var run_patience: float = _run_patience_multiplier()
	for source_order: Variant in order_list:
		if not source_order is Dictionary:
			continue
		var order: Dictionary = source_order.duplicate(true)
		var slot: int = int(order.get("target_slot", -1))
		var customer_id := "slot:%d" % slot if slot > 0 else "order:%s" % String(order.get("order_id", ""))
		if occupied_customers.has(customer_id):
			push_error("Cannot add a customer to an occupied window: %s" % customer_id)
			continue
		var cook_patience: float = maxf(float(order.get("patience_duration", TestItemDefs.get_dish_patience_duration(StringName(order.get("dish_item_id", &""))))), 0.001)
		if not bool(order.get("special_guest", false)):
			cook_patience *= run_patience
		if not customers.has(customer_id):
			var customer: Dictionary = order.duplicate(true)
			customer["day_customer_index"] = day_customer_counter
			day_customer_counter += 1
			if blessing_runtime != null and not bool(customer.get("special_guest", false)):
				customer = blessing_runtime.modify_waiting_order(customer)
			var take_patience: float = maxf(float(customer.get("order_take_patience_duration", default_order_take_patience_duration)) * float(customer.get("order_take_patience_multiplier", 1.0)), 0.001)
			if not bool(customer.get("special_guest", false)):
				take_patience *= run_patience
			customer["accepted"] = false
			customer["rewards_disabled"] = special_guest_overdue and not bool(customer.get("special_guest", false))
			customer["patience_duration"] = cook_patience
			customer["time_remaining"] = cook_patience
			customer["order_take_patience_duration"] = take_patience
			customer["order_take_time_remaining"] = take_patience
			if bool(customer.get("special_guest", false)):
				special_guest_active = true
				special_guest_patience_duration = maxf(float(customer.get("special_guest_patience_duration", OrderGroupDefs.SPECIAL_GUEST_PATIENCE_DURATION)), 1.0)
				special_guest_time_remaining = special_guest_patience_duration
				customer["patience_duration"] = special_guest_patience_duration
				customer["time_remaining"] = special_guest_time_remaining
			customers[customer_id] = customer
			AudioCue.play_sfx(&"boss_alert" if bool(customer.get("special_guest", false)) else &"event", -7.0)
		elif not bool(customers[customer_id].get("special_guest", false)):
			# The countdown belongs to the customer. Adding another course must
			# never reset the clock that has already started for that customer.
			customers[customer_id]["patience_duration"] = maxf(float(customers[customer_id]["patience_duration"]), cook_patience)
			customers[customer_id]["time_remaining"] = minf(float(customers[customer_id]["time_remaining"]), customers[customer_id]["patience_duration"])
		order["customer_id"] = customer_id
		order["day_customer_index"] = customers[customer_id]["day_customer_index"]
		order["customer_name"] = customers[customer_id].get("customer_name", "客人")
		if bool(customers[customer_id].get("rewards_disabled", false)):
			order["gold_reward"] = 0
			order["xp_reward"] = 0
		if not order.has("recipe_items"):
			order["recipe_items"] = TestItemDefs.instantiate_order_recipe_for_dish(StringName(order.get("dish_item_id", &"")))
		waiting_orders.append(order)
	_emit_waiting_orders_changed()
	_emit_orders_changed()

func has_active_order() -> bool:
	return not waiting_orders.is_empty() or not active_orders.is_empty()

func has_active_order_for_slot(slot_number: int) -> bool:
	return not get_active_order_for_slot(slot_number).is_empty()

func has_waiting_order_for_slot(slot_number: int) -> bool:
	return not get_waiting_order_for_slot(slot_number).is_empty()

func get_active_order_for_slot(slot_number: int) -> Dictionary:
	for order: Dictionary in active_orders:
		if int(order.get("target_slot", -1)) == slot_number:
			return _order_snapshot(order)
	return {}

func get_waiting_order_for_slot(slot_number: int) -> Dictionary:
	var candidate: Dictionary = {}
	for order: Dictionary in waiting_orders:
		if int(order.get("target_slot", -1)) != slot_number:
			continue
		if candidate.is_empty() or _order_sequence_index(order) < _order_sequence_index(candidate):
			candidate = order
	return _order_snapshot(candidate) if not candidate.is_empty() else {}

func get_active_order_for_delivery(slot_number: int, dish_id: StringName, signature: String) -> Dictionary:
	for order: Dictionary in active_orders:
		if int(order.get("target_slot", -1)) != slot_number or StringName(order.get("dish_item_id", &"")) != dish_id:
			continue
		if TestItemDefs.is_barrel_drink(dish_id) or TestItemDefs.signature_matches_recipe(signature, order.get("recipe_items", [])):
			return _order_snapshot(order)
	return {}

func get_first_unresolved_order() -> Dictionary:
	if not waiting_orders.is_empty():
		return _order_snapshot(waiting_orders[0])
	return _order_snapshot(active_orders[0]) if not active_orders.is_empty() else {}

func take_order_at_slot(slot_number: int, player: Node = null) -> bool:
	var order := get_waiting_order_for_slot(slot_number)
	if slot_number <= 0 or order.is_empty():
		return false
	var customer_id: String = order.customer_id
	var customer: Dictionary = customers[customer_id]
	if bool(customer.get("accepted", false)):
		return false
	if not bool(customer.get("special_guest", false)):
		var was_quick := float(customer.order_take_patience_duration) - float(customer.order_take_time_remaining) <= 3.0
		var blessing_runtime := _get_blessing_runtime()
		if blessing_runtime != null:
			customer = blessing_runtime.on_order_taken(customer, was_quick)
		customer["time_remaining"] = customer["patience_duration"]
	else:
		# The independent cooking clock starts only after accepting the guest.
		customer["time_remaining"] = special_guest_time_remaining
	customer["accepted"] = true
	customers[customer_id] = customer
	var accepted: Array[Dictionary] = []
	var sequential_guest := _is_sequential_customer(customer)
	if sequential_guest:
		# get_waiting_order_for_slot returns a snapshot; remove the matching
		# live record so Array.erase can actually move it to active_orders.
		for pending: Dictionary in waiting_orders:
			if String(pending.get("order_id", "")) == String(order.get("order_id", "")):
				accepted.append(pending)
				break
	else:
		for pending: Dictionary in waiting_orders:
			if String(pending.customer_id) == customer_id:
				accepted.append(pending)
	for pending: Dictionary in accepted:
		waiting_orders.erase(pending)
		active_orders.append(pending)
	_emit_waiting_orders_changed()
	_emit_orders_changed()
	preload("res://Scripts/Player/UltimateEnergyRules.gd").award(player, &"order")
	preload("res://Scripts/Player/PlayerWorkEvents.gd").completed(player, &"order")
	return true

func process_take_order_at_slot(slot_number: int, delta: float, player: Node = null) -> bool:
	var order := get_waiting_order_for_slot(slot_number)
	if order.is_empty():
		return false
	var customer: Dictionary = customers[order.customer_id]
	if bool(customer.get("accepted", false)):
		return false
	var required := _get_take_action_duration(customer)
	if float(customer.get("order_take_action_progress", 0.0)) <= 0.001 and player != null and player.has_method("consume_instant_work") and player.consume_instant_work(&"order"):
		customer["order_take_action_progress"] = required
		customer["order_take_action_frame"] = Engine.get_process_frames()
		return take_order_at_slot(slot_number, player)
	var speed: float = float(player.get_work_progress_multiplier()) if player != null and player.has_method("get_work_progress_multiplier") else 1.0
	customer["order_take_action_progress"] = minf(float(customer.get("order_take_action_progress", 0.0)) + maxf(delta, 0.0) * maxf(speed, 0.0), required)
	customer["order_take_action_frame"] = Engine.get_process_frames()
	return take_order_at_slot(slot_number, player) if float(customer.order_take_action_progress) >= required else true

func get_take_order_action_progress(slot_number: int) -> Dictionary:
	var order := get_waiting_order_for_slot(slot_number)
	if order.is_empty():
		return {}
	var customer: Dictionary = customers[order.customer_id]
	var progress: float = float(customer.get("order_take_action_progress", 0.0))
	return {"visible": progress > 0.0, "progress": clampf(progress / _get_take_action_duration(customer), 0.0, 1.0)}

func _get_take_action_duration(customer: Dictionary) -> float:
	return maxf(default_order_take_action_duration * float(customer.get("order_take_action_multiplier", 1.0)), 0.05)

func complete_current_order(slot_number: int = -1, exact_recipe: bool = true, order_id: String = "", dish_payload: Dictionary = {}) -> void:
	if not exact_recipe:
		return
	var target: Dictionary = {}
	for order: Dictionary in active_orders:
		if slot_number > 0 and int(order.get("target_slot", -1)) != slot_number:
			continue
		if not order_id.is_empty() and String(order.get("order_id", "")) != order_id:
			continue
		target = order
		break
	if target.is_empty():
		return
	var completed := _order_snapshot(target)
	_apply_served_dish_facility_rewards(completed, dish_payload)
	active_orders.erase(target)
	var customer_id: String = completed.customer_id
	var sequential_customer := _is_sequential_order(completed)
	if sequential_customer:
		_promote_next_sequential_order(customer_id)
	var customer_finished := not active_orders.any(func(order: Dictionary) -> bool: return String(order.customer_id) == customer_id) and not waiting_orders.any(func(order: Dictionary) -> bool: return String(order.customer_id) == customer_id)
	completed["customer_completed"] = customer_finished
	completed["exact_recipe"] = true
	if customer_finished:
		customers.erase(customer_id)
	elif not bool(customers[customer_id].get("special_guest", false)):
		var customer: Dictionary = customers[customer_id]
		var fraction: float = SERVED_DRINK_PATIENCE_FRACTION if TestItemDefs.is_drink(StringName(completed.dish_item_id)) else SERVED_DISH_PATIENCE_FRACTION
		var duration: float = float(customer.patience_duration)
		customer["time_remaining"] = minf(float(customer.time_remaining) + duration * fraction, duration)
	if is_inside_tree():
		preload("res://Scripts/Player/UltimateEnergyRules.gd").award_team(get_tree(), &"serve")
	order_completed.emit(completed)
	_emit_waiting_orders_changed()
	_emit_orders_changed()
	if bool(completed.get("special_guest", false)) and customer_finished:
		special_guest_active = false
		special_guest_pressure_active = false
		special_guest_completed.emit()

func get_active_orders() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for order: Dictionary in active_orders:
		result.append(_order_snapshot(order))
	return result

func get_waiting_orders() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for order: Dictionary in waiting_orders:
		result.append(_order_snapshot(order))
	return result

func _order_snapshot(order: Dictionary) -> Dictionary:
	var result := order.duplicate(true)
	var customer: Dictionary = customers.get(String(order.get("customer_id", "")), {})
	for key: String in ["patience_duration", "time_remaining", "order_take_patience_duration", "order_take_time_remaining"]:
		if customer.has(key):
			result[key] = customer[key]
	if bool(order.get("special_guest", false)):
		result["special_guest_time_remaining"] = special_guest_time_remaining
	if not customer.is_empty():
		result["elite_customer"] = bool(customer.get("elite_customer", result.get("elite_customer", false)))
		result["special_guest"] = bool(customer.get("special_guest", result.get("special_guest", false)))
	result["customer_order_index"] = _order_sequence_index(order)
	result["customer_order_total"] = _order_sequence_total(order)
	result["customer_orders_remaining"] = _get_customer_orders_remaining(order)
	return result

func _is_sequential_customer(customer: Dictionary) -> bool:
	return bool(customer.get("special_guest", false)) or bool(customer.get("elite_customer", false)) or bool(customer.get("sequential_guest", false))

func _is_sequential_order(order: Dictionary) -> bool:
	return bool(order.get("special_guest", false)) or bool(order.get("elite_customer", false)) or int(order.get("customer_order_total", 1)) > 1

func _order_sequence_index(order: Dictionary) -> int:
	if order.has("customer_order_index"):
		return maxi(int(order.get("customer_order_index", 0)), 0)
	return maxi(int(order.get("special_guest_index", 0)), 0)

func _order_sequence_total(order: Dictionary) -> int:
	if order.has("customer_order_total"):
		return maxi(int(order.get("customer_order_total", 1)), 1)
	return maxi(int(order.get("special_guest_total", 1)), 1)

func _get_customer_orders_remaining(order: Dictionary) -> int:
	if not _is_sequential_order(order):
		return 0
	var customer_id := String(order.get("customer_id", ""))
	var remaining := 0
	for pending: Dictionary in waiting_orders:
		if String(pending.get("customer_id", "")) == customer_id:
			remaining += 1
	for active: Dictionary in active_orders:
		if String(active.get("customer_id", "")) == customer_id:
			remaining += 1
	# The counter describes courses still waiting after the one currently shown.
	return maxi(remaining - 1, 0)

func _promote_next_sequential_order(customer_id: String) -> void:
	var next_order: Dictionary = {}
	for pending: Dictionary in waiting_orders:
		if String(pending.get("customer_id", "")) != customer_id:
			continue
		if next_order.is_empty() or _order_sequence_index(pending) < _order_sequence_index(next_order):
			next_order = pending
	if next_order.is_empty():
		return
	waiting_orders.erase(next_order)
	active_orders.append(next_order)

func _publish_customer_progress(customer_id: String) -> void:
	var customer: Dictionary = customers[customer_id]
	var accepted: bool = bool(customer.get("accepted", false))
	var orders: Array[Dictionary] = active_orders if accepted else waiting_orders
	for order: Dictionary in orders:
		if String(order.customer_id) != customer_id:
			continue
		if accepted:
			order_progress_changed.emit(String(order.order_id), float(customer.time_remaining), float(customer.patience_duration))
		else:
			waiting_order_progress_changed.emit(String(order.order_id), float(customer.order_take_time_remaining), float(customer.order_take_patience_duration))

func adjust_order_time(order_id: String, seconds: float, is_waiting: bool = false) -> bool:
	var orders: Array[Dictionary] = waiting_orders if is_waiting else active_orders
	for order: Dictionary in orders:
		if String(order.get("order_id", "")) != order_id:
			continue
		var customer: Dictionary = customers.get(String(order.get("customer_id", "")), {})
		if customer.is_empty() or bool(customer.get("special_guest", false)):
			return false
		var duration_key := "order_take_patience_duration" if is_waiting else "patience_duration"
		var remaining_key := "order_take_time_remaining" if is_waiting else "time_remaining"
		customer[remaining_key] = clampf(float(customer[remaining_key]) + seconds, 0.0, float(customer[duration_key]))
		_publish_customer_progress(String(order.customer_id))
		return true
	return false

func restore_all_active_order_patience_fraction(fraction: float) -> void:
	for customer_id: String in customers:
		var customer: Dictionary = customers[customer_id]
		if not bool(customer.get("accepted", false)) or bool(customer.get("special_guest", false)):
			continue
		var duration: float = float(customer.patience_duration)
		customer["time_remaining"] = minf(float(customer.time_remaining) + duration * maxf(fraction, 0.0), duration)
	_emit_orders_changed()

func can_offer_dessert(slot: int, dish_id: StringName, signature: String) -> bool:
	var customer: Dictionary = customers.get("slot:%d" % slot, {})
	return not customer.is_empty() and bool(customer.get("accepted", false)) and not bool(customer.get("dessert_received", false)) and TestItemDefs.is_dessert(dish_id) and TestItemDefs.signature_matches_recipe(signature, TestItemDefs.get_recipe_for_dish(dish_id))

func offer_dessert(slot: int, dish_id: StringName, signature: String, dish_payload: Dictionary = {}) -> bool:
	if not can_offer_dessert(slot, dish_id, signature):
		return false
	var id := "slot:%d" % slot
	var customer: Dictionary = customers[id]
	customer["dessert_received"] = true
	# Dessert has its own dish value, independent of the guest's requested dishes
	# and boss-order bonuses. Reward eligibility is fixed when the guest arrives.
	var reward_data: Dictionary = {
		"dish_item_id": dish_id,
		"gold_reward": 0 if bool(customer.get("rewards_disabled", false)) else TestItemDefs.get_dish_gold_reward(dish_id),
		"xp_reward": 0 if bool(customer.get("rewards_disabled", false)) else TestItemDefs.get_dish_xp_reward(dish_id),
		"day_customer_index": customer.get("day_customer_index", 0),
		"facility_reward_multiplier": customer.get("facility_reward_multiplier", 1.0),
		"exact_recipe": true,
		"customer_completed": false,
	}
	_apply_served_dish_facility_rewards(reward_data, dish_payload)
	if not bool(customer.get("special_guest", false)):
		var duration: float = float(customer.patience_duration)
		customer["time_remaining"] = minf(float(customer.time_remaining) + duration * SERVED_DISH_PATIENCE_FRACTION, duration)
	if is_inside_tree():
		preload("res://Scripts/Player/UltimateEnergyRules.gd").award_team(get_tree(), &"serve")
	dessert_served.emit(reward_data)
	_publish_customer_progress(id)
	_emit_orders_changed()
	return true

func _apply_served_dish_facility_rewards(dish_data: Dictionary, dish_payload: Dictionary) -> void:
	if bool(dish_payload.get("flame_blessed", false)):
		flame_chain_bonus = minf(flame_chain_bonus + 0.05, 0.5) if flame_chain_bonus > 0.0 else 0.1
	else:
		flame_chain_bonus = 0.0
	var multiplier := float(dish_data.get("facility_reward_multiplier", 1.0)) * (1.0 + flame_chain_bonus)
	for reward: String in ["gold_reward", "xp_reward"]:
		dish_data[reward] = roundi(float(dish_data.get(reward, 0)) * multiplier)

func can_offer_water(slot: int) -> bool:
	var customer: Dictionary = customers.get("slot:%d" % slot, {})
	return not customer.is_empty() and bool(customer.get("accepted", false)) and not bool(customer.get("special_guest", false)) and not bool(customer.get("water_received", false))

func offer_water(slot: int) -> bool:
	if not can_offer_water(slot):
		return false
	var id := "slot:%d" % slot
	var customer: Dictionary = customers[id]
	var lost := maxf(float(customer.patience_duration) - float(customer.time_remaining), 0)
	customer["time_remaining"] = float(customer.time_remaining) + lost * 0.3
	customer["water_received"] = true
	_publish_customer_progress(id)
	_emit_orders_changed()
	_emit_waiting_orders_changed()
	return true

func _expire_customer(customer_id: String) -> void:
	AudioCue.play_sfx(&"warning", -5.0)
	var expired: Array[Dictionary] = []
	for orders: Array[Dictionary] in [waiting_orders, active_orders]:
		for index in range(orders.size() - 1, -1, -1):
			if String(orders[index].customer_id) == customer_id:
				expired.push_front(_order_snapshot(orders[index]))
				orders.remove_at(index)
	customers.erase(customer_id)
	for index in range(expired.size()):
		# Resolve every outstanding dish, but charge one lost customer once.
		expired[index]["customer_resolved"] = index == expired.size() - 1
		if index > 0:
			expired[index]["reputation_penalty"] = 0
		order_expired.emit(expired[index])
	_emit_waiting_orders_changed()
	_emit_orders_changed()

func _process_special_guest(delta: float) -> void:
	if not special_guest_active:
		return
	var elapsed := maxf(delta, 0.0)
	var previous_remaining := 0.0
	var special_guest_accepted := false
	for customer: Dictionary in customers.values():
		if not bool(customer.get("special_guest", false)):
			continue
		special_guest_accepted = bool(customer.get("accepted", false))
		if special_guest_accepted:
			previous_remaining = special_guest_time_remaining
			special_guest_time_remaining = maxf(previous_remaining - elapsed, 0.0)
		else:
			previous_remaining = float(customer.order_take_time_remaining)
			customer["order_take_time_remaining"] = maxf(previous_remaining - elapsed, 0.0)
		break
	var overdue_elapsed := elapsed if special_guest_overdue else maxf(elapsed - previous_remaining, 0.0)
	if previous_remaining <= elapsed:
		special_guest_overdue = true
	special_guest_pressure_active = special_guest_accepted and (special_guest_overdue or special_guest_time_remaining <= special_guest_patience_duration * 0.5)
	if not special_guest_overdue:
		return
	special_guest_penalty_cooldown -= overdue_elapsed
	while special_guest_penalty_cooldown <= 0.0 and special_guest_active:
		special_guest_penalty_cooldown += special_guest_penalty_interval
		special_guest_penalty_tick.emit(1)

func get_special_guest_clock() -> Dictionary:
	if special_guest_active:
		for customer: Dictionary in customers.values():
			if bool(customer.get("special_guest", false)):
				var accepted := bool(customer.get("accepted", false))
				return {
					"accepted": accepted,
					"remaining": special_guest_time_remaining if accepted else float(customer.order_take_time_remaining),
					"duration": special_guest_patience_duration if accepted else float(customer.order_take_patience_duration),
					"overdue": special_guest_overdue
				}
	return {}

func reset_day_tracking() -> void:
	flame_chain_bonus = 0.0
	day_customer_counter = 0

func _run_patience_multiplier() -> float:
	if not is_inside_tree():
		return 1.0
	var refs := preload("res://Scripts/Core/LevelRefs.gd").find_from(self)
	var flow: Node = refs.get_level_flow_controller() if refs != null else null
	return float(flow.get_run_modifier_multiplier(&"patience")) if flow != null and flow.has_method("get_run_modifier_multiplier") else 1.0

func _get_blessing_runtime() -> RefCounted:
	if not is_inside_tree():
		return null
	var player := get_tree().get_first_node_in_group("player")
	return player.get_blessing_controller() if player != null and player.has_method("get_blessing_controller") else null

func _emit_orders_changed() -> void:
	orders_changed.emit(get_active_orders())

func _emit_waiting_orders_changed() -> void:
	waiting_orders_changed.emit(get_waiting_orders())
