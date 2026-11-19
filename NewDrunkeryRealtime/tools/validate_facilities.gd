extends SceneTree

const Catalog = preload("res://Scripts/Facilities/FacilityCatalog.gd")
var failures: Array[String] = []
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Cargo = preload("res://Scripts/Facilities/FacilityItems.gd")
const Effects = preload("res://Scripts/Facilities/FacilityControlEffect.gd")
var main: Node
var player: Node2D
var flow: Node
var made: Array[Node] = []
var completions: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	for entry: Dictionary in Catalog.ENTRIES:
		var facility: Node2D = Catalog.create(StringName(entry.id))
		check(facility != null, "Create %s" % entry.id)
		if facility == null:
			continue
		root.add_child(facility)
		check(facility.is_in_group("movable_facilities") == (entry.id != &"forklift"), "Carry permission %s" % entry.id)
		var sprite: Sprite2D = facility.get("body_sprite")
		check(sprite != null and sprite.texture != null, "Sprite %s" % entry.id)
		if sprite != null and sprite.texture != null:
			sprite.texture.get_image().save_png("res://_artifact_work/art_%s.png" % entry.id)
		facility.free()
	main = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in main.find_children("*", "", true, false):
		if child is CollisionObject2D:
			child.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		child.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	player = main.get_node("Player")
	flow = main.get_node("LevelFlowController")
	check(flow.progression_state.gold == 2000, "New run starts with 2000 test gold")
	var manager: Node = main.get_node("OrderManager")
	for connection: Dictionary in manager.order_completed.get_connections():
		manager.order_completed.disconnect(connection.callable)
	flow.run_context.state = 7
	flow.magic_current = 8
	await physics_frame
	flow.run_context.state = 7
	_test_removed_facilities()
	_test_items()
	_test_orders()
	_test_culture()
	await _test_portal()
	await _test_shuttle()
	await _test_vehicle()
	await _test_forklift_repair()
	_test_controls()
	await _test_tools_and_harvest()
	await _test_purchases()
	_test_shop_selection()
	for node: Node in made:
		if is_instance_valid(node):
			node.queue_free()
	await process_frame
	main.free()
	print("FACILITY VALIDATION: %d entries; %d failures" % [Catalog.ENTRIES.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)

func create(id: StringName, at: Vector2 = Vector2(2304, 1152)) -> Node2D:
	var node := Catalog.create(id)
	main.add_child(node)
	if node is CollisionObject2D:
		node.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	node.global_position = at
	made.append(node)
	return node

func hold(id: StringName, state: StringName = &"", payload: Dictionary = {}) -> void:
	player.clear_held_item()
	check(player.pick_up_item(id, Items.get_item_texture(id), state, "", payload), "Hold %s" % id)

func _test_removed_facilities() -> void:
	var shop: Node = flow.night_shop_controller
	shop._rebuild_merchant_shop_items()
	for id: StringName in [&"kettle", &"auto_cut", &"auto_grind", &"auto_wash"]:
		check(Catalog.definition(id).is_empty() and Catalog.create(id) == null, "Removed facility has no catalog factory: %s" % id)
		check(not flow.purchase_support_facility({"facility_type": id}), "Removed facility cannot be purchased: %s" % id)
		check(_shop_index(shop, StringName("facility_%s" % id)) == -1, "Removed facility absent from shop: %s" % id)
	check(_shop_index(shop, &"forklift_repair") == -1, "No repair item without a forklift")
	for item: Dictionary in shop.merchant_shop_items:
		if item.type == &"facility":
			var description: String = item.description
			check(not "J" in description and not "K" in description and not "L" in description and not "购买后" in description, "Facility description contains no controls: %s" % item.id)

func _test_items() -> void:
	var duplicate := create(&"duplicator")
	hold(Items.SEASONING_BOX_ID, &"", {"item_id": Items.SUN_SEED_ID, "process_state": &"grind_fine", "servings": 2, "process_energy_rewarded": true})
	check(duplicate.receive_item_from_player(player), "Copy seasoning")
	check(flow.magic_current == 5 and player.is_holding_item(), "Copy pays once, preserves original")
	check(int(duplicate.stored.payload.servings) == 2 and bool(duplicate.stored.payload.process_energy_rewarded), "Copy retains quantity and energy marker")
	player.clear_held_item()
	check(duplicate.take_item_to_player(player), "Take copied box")
	check(int(player.get_held_item_payload().servings) == 2, "Copied box output")
	hold(Items.SANDWORM_CORE_ID)
	check(not duplicate.can_receive_item(player), "No boss copy")
	var stack := create(&"stack_table")
	for index in range(5):
		hold(Items.VEG_ROOT_ID, &"cut")
		check(stack.receive_item_from_player(player), "Stack five ordinary items")
	hold(Items.VEG_ROOT_ID, &"cut")
	check(not stack.can_receive_item(player) and stack.count == 5, "Stack maximum five")
	player.clear_held_item()
	for index in range(5):
		check(stack.take_item_to_player(player), "Withdraw stack")
		player.clear_held_item()
	for index in range(5):
		hold(Items.SEASONING_BOX_ID, &"", {"item_id": Items.SUN_SEED_ID, "process_state": &"grind_fine", "servings": 4})
		check(stack.receive_item_from_player(player), "Stack seasoning")
	check(stack.count == 20, "Seasoning capacity twenty")
	hold(Items.PLATE_ID)
	check(stack.take_item_to_player(player) and stack.count == 19, "Plate withdraws exactly one")
	player.clear_held_item()
	check(stack.take_item_to_player(player) and int(player.get_held_item_payload().servings) == 4 and stack.count == 15, "Empty hands withdraw four")
	var furnace := create(&"fire_furnace")
	flow.magic_current = 8
	hold(Items.DISH_RED_ID, &"", {"uses_plate": true, "keep": 7})
	check(furnace.receive_item_from_player(player), "Bless dish")
	check(not furnace.can_take_item(player), "No premature blessing pickup")
	furnace._process(6.1)
	check(furnace.take_item_to_player(player) and bool(player.get_held_item_payload().flame_blessed) and int(player.get_held_item_payload().keep) == 7, "Blessing preserves plate and metadata")
	check(not furnace.can_receive_item(player), "No repeat blessing")
	player.clear_held_item()
	var spring := create(&"healing_spring")
	flow.magic_current = 8
	player.combat_controller.current_health = 1
	check(spring.take_item_to_player(player), "Full heal")
	spring._process(0.016)
	player.combat_controller.current_health = 1
	check(not spring.take_item_to_player(player), "Healing personal cooldown")
	spring._process(181)
	check(spring.take_item_to_player(player), "Healing cooldown expires")

func order(id: String, slot: int) -> Dictionary:
	return {"order_id": id, "target_slot": slot, "dish_item_id": Items.DISH_RED_ID, "patience_duration": 100.0, "gold_reward": 100, "xp_reward": 100}

func _test_orders() -> void:
	var manager: Node = main.get_node("OrderManager")
	manager.clear_orders()
	manager.order_completed.connect(func(data: Dictionary) -> void: completions.append(data))
	manager.add_orders([order("first", 1)])
	check(not manager.can_offer_water(1) and not manager.offer_water(1), "Water rejects unaccepted customers")
	check(not bool(manager.customers["slot:1"].get("water_received", false)), "Rejected water does not consume allowance")
	manager.take_order_at_slot(1)
	manager.customers["slot:1"].time_remaining = 50.0
	check(manager.offer_water(1), "Water accepted")
	check(is_equal_approx(float(manager.customers["slot:1"].time_remaining), 65.0) and not manager.offer_water(1), "Water restores thirty percent lost only once")
	manager.complete_current_order(1, true, "first", {"flame_blessed": true})
	check(int(completions.back().gold_reward) == 110, "First blessed dish ten percent")
	manager.add_orders([order("second", 1)])
	manager.take_order_at_slot(1)
	manager.complete_current_order(1, true, "second", {"flame_blessed": true})
	check(int(completions.back().gold_reward) == 115, "Blessing chain uses actual serving order")
	manager.add_orders([order("plain", 1)])
	manager.take_order_at_slot(1)
	manager.complete_current_order(1, true, "plain")
	check(manager.flame_chain_bonus == 0, "Plain dish resets chain")
	var guest := order("special", 1)
	guest["special_guest"] = true
	manager.add_orders([guest])
	check(not manager.can_offer_water(1), "Water excludes special guest")
	manager.clear_orders()
	manager.special_guest_overdue = true
	var flyer_order := order("flyer", 1)
	flyer_order["facility_reward_multiplier"] = 1.05
	manager.add_orders([flyer_order])
	manager.take_order_at_slot(1)
	manager.complete_current_order(1, true, "flyer", {"flame_blessed": true})
	check(int(completions.back().gold_reward) == 0 and int(completions.back().xp_reward) == 0, "Facility buffs cannot restore overdue rewards")
	manager.clear_orders()

func _test_culture() -> void:
	flow.run_context.state = 7
	var culture := create(&"culture")
	check("放入种子" in culture.get_interaction_button_prompt(player), "Unseeded culture prompt")
	hold(Items.MEAT_RED_ID)
	check(not culture.can_receive_item(player), "No meat seed")
	hold(Items.VEG_ROOT_ID)
	check(culture.receive_item_from_player(player), "Seed culture")
	culture._process(12.5)
	check(is_equal_approx(culture.get_growth_progress(), 0.5), "Next ingredient production progress")
	check(not "放入种子" in culture.get_interaction_button_prompt(player), "Seeded culture stops advertising seeds")
	culture._process(62.5)
	check(culture.stock == 3, "Culture day production")
	check("J 按住收集" in culture.get_interaction_button_prompt(player), "Harvestable culture shows collection key")
	flow.run_context.state = 1
	culture._process(100)
	check(culture.stock == 3, "No culture night production")
	flow.run_context.state = 7
	player.clear_held_item()
	var stock_before: int = main.get_node("StorageManager").get_available_stock(Items.VEG_ROOT_ID)
	check(culture.process_hold_interaction(player, 3), "Collect culture")
	check(culture.stock == 0 and main.get_node("StorageManager").get_available_stock(Items.VEG_ROOT_ID) == stock_before + 3, "Culture collect quantity")

func _test_portal() -> void:
	flow.run_context.state = 7
	var a := create(&"portal", Vector2(1472, 1728))
	var b := create(&"portal", Vector2(3008, 1728))
	a.partner = b
	b.partner = a
	player.global_position = a.global_position - Vector2(128, 0)
	flow.magic_current = 8
	hold(Items.PLATE_ID, &"", {"items": [Cargo.Carry.portion(Items.VEG_ROOT_ID, &"cut")]})
	check(a.receive_item_from_player(player), "Portal accepts loaded plate")
	check(flow.magic_current == 7 and a.is_busy() and b.is_busy(), "Portal pays once and shares transit lock")
	hold(Items.VEG_ROOT_ID)
	check(not b.can_receive_item(player), "No opposing simultaneous send")
	player.clear_held_item()
	var blocker := create(&"stack_table", b.output_at(b.global_position))
	await physics_frame
	await process_frame
	await physics_frame
	a._process(10)
	check(not a.transit.is_empty(), "Blocked portal retains cargo")
	blocker.global_position = Vector2(50000, 50000)
	await physics_frame
	await process_frame
	await physics_frame
	a._process(1)
	check(a.transit.is_empty() and not b.is_busy(), "Portal resumes after clearing exit")
	var found := false
	for item: Node2D in get_nodes_in_group("loose_items"):
		if item.global_position.distance_to(b.output_at(b.global_position)) < 20 and item.item_id == Items.PLATE_ID:
			found = Array(item.item_payload.get("items", [])).size() == 1
	check(found, "Loaded plate payload survives portal")
	var map: Node = main.get_node("PrototypeMap")
	check(map.is_cell_reserved_for_fixed_layout(map.get_cell_for_point(b.output_at(b.global_position))), "Portal output cell reserved")

func _test_shuttle() -> void:
	flow.run_context.state = 7
	var a := create(&"shuttle", Vector2(1800, 1500))
	var b := create(&"shuttle", Vector2(2200, 1500))
	a.partner = b
	b.partner = a
	for index in range(3):
		hold(Items.VEG_ROOT_ID, &"cut")
		check(a.receive_item_from_player(player), "Shuttle load")
	hold(Items.VEG_ROOT_ID)
	check(not a.can_receive_item(player), "Shuttle capacity three")
	player.clear_held_item()
	check(a.interact_with_player(player), "Shuttle departs")
	a._process(5)
	check(a.cargo.is_empty() and b.cargo.size() == 3, "Shuttle arrives with same three items")
	check(b.take_item_to_player(player) and b.cargo.size() == 2, "Shuttle manual unload")
	player.clear_held_item()
	b.take_item_to_player(player)
	player.clear_held_item()
	b.take_item_to_player(player)
	player.clear_held_item()
	check(a.interact_with_player(player), "Call empty shuttle back")
	b._process(5)
	check(a.cart_here and not b.cart_here, "Single cart returns empty")

func _test_vehicle() -> void:
	flow.run_context.state = 7
	var vehicle := create(&"forklift", Vector2(2304, 0))
	player.clear_held_item()
	player.global_position = vehicle.global_position + Vector2(0, 120)
	check(not vehicle.can_be_moved_by_player(player), "Vehicle can never be carried")
	check(not player.facility_carry_controller.pick_up(vehicle), "Carry controller also rejects vehicle")
	player.interaction_controller._set_current_interaction_target(vehicle)
	player._handle_pickup_drop()
	check(player.has_meta("facility_vehicle"), "J mounts vehicle through actual player input route")
	var health_before: int = player.combat_controller.current_health
	player.take_damage(100)
	check(vehicle.health == 1900 and player.combat_controller.current_health == health_before, "Vehicle absorbs damage")
	await physics_frame
	check(vehicle._try_exit(), "Vehicle dismounts safely")
	vehicle.reset_state()
	check(vehicle.health == 1900 and not player.has_meta("facility_vehicle") and player.visible, "Vehicle durability persists and player restored")
	flow.run_context.state = 1
	check(vehicle.take_item_to_player(player), "Night driving is allowed")
	check(vehicle._try_exit(), "Night dismount")
	vehicle.cargo = {Items.VEG_ROOT_ID: 3}
	check(vehicle.get_hold_interaction_action() == &"interact", "K holds vehicle unloading")
	check(vehicle.interact_with_player(player) or vehicle.work_progress > 0.0, "K starts unloading rather than carrying")
	await process_frame
	await process_frame
	var unloaded: bool = vehicle.process_hold_interaction(player, 2)
	check(unloaded and vehicle.amount() == 0, "Vehicle manual unloading at night")
	flow.run_context.state = 7
	check(vehicle.take_item_to_player(player), "Remount for actual reciprocal contact")
	var left := _enemy("pig_enemy", vehicle.global_position + Vector2(-82, 0))
	var right := _enemy("chicken_enemy", vehicle.global_position + Vector2(78, 0))
	var left_before: int = left.current_health
	var right_before: int = right.current_health
	await physics_frame
	await process_frame
	await physics_frame
	vehicle.contacts.check_contacts()
	check(left.current_health == left_before - 50 and right.current_health == right_before - 50, "Both contacting enemies receive ram damage")
	check(vehicle.health == 1890, "Each simultaneous contact also deals half damage back to vehicle")
	check(not player.take_damage(10, Vector2.RIGHT, &"contact") and vehicle.health == 1890, "Enemy radius contact does not double-charge or stun driver")
	vehicle.contacts.check_contacts()
	check(left.current_health == left_before - 50 and vehicle.health == 1890, "Pair cooldown suppresses both sides together")
	var original: Vector2 = left.global_position
	vehicle.contacts.tick(0.045)
	var partial_distance: float = left.global_position.distance_to(original)
	check(partial_distance > 0 and partial_distance < 80, "Ram knockback is gradual")
	vehicle.contacts.tick(0.135)
	check(left.global_position.distance_to(original) >= partial_distance and left.global_position.distance_to(original) <= 80.1, "Swept knockback respects world obstacles and distance cap")
	var car_start: Vector2 = vehicle.global_position
	vehicle._move_driven(Vector2(12, 0))
	check(vehicle.global_position.x > car_start.x, "Vehicle responds to movement immediately after contact")
	left.global_position = Vector2(15000, 15000)
	right.global_position = Vector2(16000, 15000)
	await physics_frame
	check(vehicle._try_exit(), "Exit after collision")
	vehicle.global_position = Vector2(14000, 14000)

func _test_forklift_repair() -> void:
	var shop: Node = flow.night_shop_controller
	var vehicle: Node2D = get_nodes_in_group("forklifts").front()
	player.clear_held_item()
	vehicle.health = vehicle.MAX_HEALTH
	shop.selected_shop_category_index = 2
	shop._rebuild_merchant_shop_items()
	check(_shop_index(shop, &"forklift_repair") == -1, "Full durability needs no repair item")
	for sample: Vector2i in [Vector2i(1, 1), Vector2i(20, 1), Vector2i(21, 2), Vector2i(1000, 50), Vector2i(2000, 100)]:
		vehicle.health = vehicle.MAX_HEALTH - sample.x
		shop._rebuild_merchant_shop_items()
		var index: int = _shop_index(shop, &"forklift_repair")
		check(index >= 0 and vehicle.get_repair_cost() == sample.y, "Repair cost rounds up for %d damage" % sample.x)
		if index >= 0:
			check(shop.merchant_shop_items[index].cost == sample.y, "Repair card quotes current damage")
	vehicle.health = 1900
	vehicle.cargo = {Items.VEG_ROOT_ID: 3}
	var original_position: Vector2 = vehicle.global_position
	shop._rebuild_merchant_shop_items()
	shop.selected_shop_index = _shop_index(shop, &"forklift_repair")
	flow.progression_state.gold = 4
	check(not shop.purchase_selected() and flow.progression_state.gold == 4 and vehicle.health == 1900, "Unaffordable repair changes neither gold nor durability")
	# Damage can change while the card is displayed; commit uses the new cost.
	vehicle.health = 1899
	flow.progression_state.gold = 100
	check(shop.purchase_selected(), "Purchase repair through shop")
	check(flow.progression_state.gold == 94 and vehicle.health == vehicle.MAX_HEALTH, "Repair charges current damage and restores full durability")
	check(vehicle.cargo == {Items.VEG_ROOT_ID: 3} and vehicle.global_position == original_position, "Repair preserves cargo and position")
	check(_shop_index(shop, &"forklift_repair") == -1 and not vehicle.repair(), "Repaired vehicle cannot be charged again")
	vehicle.health = 0
	check(not vehicle.can_take_item(player), "Broken vehicle cannot be driven")
	shop._rebuild_merchant_shop_items()
	shop.selected_shop_index = _shop_index(shop, &"forklift_repair")
	flow.progression_state.gold = 100
	check(shop.purchase_selected() and flow.progression_state.gold == 0 and vehicle.can_take_item(player), "Completely broken vehicle repairs for 100 and can be driven again")
	# A stale repair card after another repair must not charge anything.
	vehicle.health = 1999
	shop._rebuild_merchant_shop_items()
	shop.selected_shop_index = _shop_index(shop, &"forklift_repair")
	vehicle.repair()
	flow.progression_state.gold = 100
	check(not shop.purchase_selected() and flow.progression_state.gold == 100, "Stale repair card cannot charge a healthy vehicle")
	vehicle.queue_free()
	await process_frame
	shop._rebuild_merchant_shop_items()
	check(_shop_index(shop, &"forklift_repair") == -1, "Removed vehicle leaves no repair item")

func _enemy(scene: String, at: Vector2) -> Node2D:
	var enemy: Node2D = load("res://Scenes/Enemies/%s.tscn" % scene).instantiate()
	main.add_child(enemy)
	enemy.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	enemy.global_position = at
	made.append(enemy)
	return enemy

func _test_controls() -> void:
	var enemy: Node2D = load("res://Scenes/Enemies/pig_enemy.tscn").instantiate()
	main.add_child(enemy)
	made.append(enemy)
	Effects.attach(enemy, 5, 5)
	check(Effects.rooted(enemy) and Effects.damage(enemy, 100) == 150, "Net root and vulnerability")
	var effect: Node = enemy.get_node("FacilityControlEffect")
	effect._process(6)
	check(not Effects.rooted(enemy), "Net root expires")
	Effects.attach(player, 0, 0, 0.25, 6)
	check(Effects.speed(player) < 0.3, "Trap temporary slow")
	player.clear_hostile_control()
	check(is_equal_approx(Effects.speed(player), 1.0), "Immunity clears facility control")

func _test_tools_and_harvest() -> void:
	flow.run_context.state = 7
	player.global_position = Vector2(1850, 0)
	player.aim_direction = Vector2.RIGHT
	var enemy: Node2D = load("res://Scenes/Enemies/pig_enemy.tscn").instantiate()
	main.add_child(enemy)
	enemy.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	enemy.global_position = player.global_position + Vector2(100, 0)
	made.append(enemy)
	hold(&"magic_net")
	check(preload("res://Scripts/Facilities/FacilityToolEffect.gd").use(player), "Magic net use")
	check(not get_nodes_in_group("facility_tool_effects").is_empty(), "Magic net spawned")
	if get_nodes_in_group("facility_tool_effects").is_empty():
		return
	var net: Node2D = get_nodes_in_group("facility_tool_effects").back()
	net._physics_process(0.05)
	check(Effects.rooted(enemy) and Effects.damage(enemy, 20) == 30, "Thrown net actually hits")
	await process_frame
	hold(&"bear_trap")
	check(preload("res://Scripts/Facilities/FacilityToolEffect.gd").use(player), "Trap place")
	check(not get_nodes_in_group("facility_tool_effects").is_empty(), "Trap spawned")
	if get_nodes_in_group("facility_tool_effects").is_empty():
		return
	var trap: Node2D = get_nodes_in_group("facility_tool_effects").back()
	trap.global_position = enemy.global_position
	var before: int = enemy.current_health
	trap._physics_process(0.01)
	check(enemy.current_health < before or enemy.is_dead, "Trap deals real damage")
	check(Effects.speed(enemy) < 1.0, "Trap slows")
	await _test_trap_friendly_fire()
	var point: Node2D = load("res://Scripts/Forage/ForagePoint.gd").new()
	var title := Label.new()
	title.name = "NameLabel"
	point.add_child(title)
	var prompt := Label.new()
	prompt.name = "PromptLabel"
	point.add_child(prompt)
	main.add_child(point)
	made.append(point)
	check(point.harvest_for_vehicle(0).is_empty() and not point.is_queued_for_deletion(), "Full vehicle preserves forage")
	var harvest: Dictionary = point.harvest_for_vehicle(40)
	check(harvest.size() == point.forage_item_ids.size() and point.is_queued_for_deletion(), "Vehicle harvests all point produce")
	await process_frame
	var bolt: Node2D = load("res://Scripts/Facilities/BallistaBolt.gd").new()
	main.add_child(bolt)
	bolt.global_position = Vector2(2400, 0)
	var target: Node2D = load("res://Scenes/Enemies/pig_enemy.tscn").instantiate()
	main.add_child(target)
	target.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	target.global_position = Vector2(2500, 0)
	made.append(target)
	await physics_frame
	await process_frame
	await physics_frame
	before = target.current_health
	bolt._physics_process(0.2)
	check(target.current_health < before, "Ballista straight bolt damages enemy")
	target.global_position = Vector2(14000, 12000)
	player.global_position = Vector2(2500, 0)
	await physics_frame
	await process_frame
	await physics_frame
	var friendly_bolt: Node2D = load("res://Scripts/Facilities/BallistaBolt.gd").new()
	main.add_child(friendly_bolt)
	friendly_bolt.global_position = player.get_node("CollisionShape2D").global_position - Vector2(100, 0)
	before = player.combat_controller.current_health
	friendly_bolt._physics_process(0.2)
	check(player.combat_controller.current_health == maxi(before - 180, 0), "Ballista bolt actually collides with and damages player")
	var ballista := create(&"ballista", Vector2(2700, 0))
	ballista._process(0.1)
	check(ballista.cooldown > 0, "Automatic ballista firing path")

func _test_trap_friendly_fire() -> void:
	var boss := _enemy("sandworm_boss", Vector2(12000, 12000))
	var normal := _enemy("pig_enemy", Vector2(13000, 12000))
	player.global_position = Vector2(11000, 12000)
	for target: Node2D in [normal, boss, player]:
		var before: int = player.combat_controller.current_health if target == player else target.current_health
		var trap: Node2D = preload("res://Scripts/Facilities/FacilityToolEffect.gd").new()
		trap.kind = &"bear_trap"
		trap.source = weakref(player)
		trap.owner_clear = true
		main.add_child(trap)
		trap.global_position = target.global_position
		trap._physics_process(0.01)
		var after: int = player.combat_controller.current_health if target == player else target.current_health
		check(before - after == (60 if target == player else 300), "Trap damage for %s" % target.name)
		check(Effects.rooted(target) == (target == normal), "Trap retains boss/player root exemption")
	await process_frame
	player.clear_hostile_control()
	hold(&"bear_trap")
	var view := preload("res://Scripts/UI/InteractionPromptView.gd").new()
	var actions: Array[Dictionary] = view._parse_actions(player.interaction_controller._get_interaction_button_prompt_text())
	check(actions.any(func(action: Dictionary) -> bool: return action.key == "K"), "Held trap displays deployment key without a nearby target")
	player.clear_held_item()

func _test_shop_selection() -> void:
	var shop: Node = flow.night_shop_controller
	flow.progression_state.gold = 10000
	shop.selected_shop_category_index = 2
	shop._rebuild_merchant_shop_items()
	var index: int = _shop_index(shop, &"facility_prep_table")
	shop.selected_shop_index = index
	check(shop.purchase_selected(), "Repeatable facility purchase")
	check(shop.selected_shop_index == _shop_index(shop, &"facility_prep_table"), "Repeatable purchase retains item cursor")
	# Use a harmless purchase callback to isolate cursor behavior from kitchen
	# floor capacity; the normal purchase placement is covered above.
	shop.set_facility_purchase_callback(func(_data: Dictionary) -> bool: return true)
	flow.progression_state.shop_stat_purchase_counts.erase(&"facility_flyer")
	shop._rebuild_merchant_shop_items()
	index = _shop_index(shop, &"facility_flyer")
	var next_id: StringName = shop.merchant_shop_items[index + 1].id
	shop.selected_shop_index = index
	check(shop.purchase_selected(), "Limited facility purchase")
	check(shop.selected_shop_index >= 0 and shop.merchant_shop_items[shop.selected_shop_index].id == next_id, "Sold-out item selects its successor")
	var indices: Array[int] = shop._get_shop_item_indices_for_category(2)
	shop.selected_shop_index = indices.back()
	shop.move_selection_2d(1, 0)
	check(shop.selected_shop_index == indices.front(), "Last shop item wraps right to first")
	shop.move_selection_2d(-1, 0)
	check(shop.selected_shop_index == indices.back(), "First shop item wraps left to last")
	shop.move_selection_2d(0, 1)
	check(shop.selected_shop_index == indices.front(), "Last shop row wraps down to first item")
	shop.move_selection_2d(0, -1)
	check(shop.selected_shop_index == indices.back(), "First shop row wraps up to last item")
	shop.set_facility_purchase_callback(Callable(flow, "purchase_support_facility"))

func _shop_index(shop: Node, id: StringName) -> int:
	for index in range(shop.merchant_shop_items.size()):
		if shop.merchant_shop_items[index].id == id:
			return index
	return -1

func _test_purchases() -> void:
	for node: Node in made:
		if is_instance_valid(node):
			node.queue_free()
	await process_frame
	await physics_frame
	for entry: Dictionary in Catalog.ENTRIES:
		var id := StringName(entry.id)
		var success: bool = flow.purchase_support_facility({"facility_type": id})
		check(success, "Safe purchase %s" % id)
		if success:
			flow.progression_state.increment_stat_purchase_count(StringName("facility_%s" % id))
		if int(entry.limit) == 1:
			check(not flow.purchase_support_facility({"facility_type": id}), "Unique purchase cap %s" % id)
	check(not Catalog.available(&"culture", 3), "Culture limit three")
	flow.night_shop_controller._rebuild_merchant_shop_items()
	check(flow.night_shop_controller.merchant_shop_items.size() > 15, "Shop lists new facilities")
	await physics_frame
