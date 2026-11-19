extends SceneTree

const Defs = preload("res://Scripts/Core/MapMechanismDefs.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Scarab = preload("res://Scripts/Enemies/ScarabEnemy.gd")
const Sand = preload("res://Scripts/Hazards/QuicksandHazard.gd")
const Tail = preload("res://Scripts/Enemies/SandwormTailStrike.gd")
const Wave = preload("res://Scripts/Hazards/SandstormWave.gd")
const Cyclone = preload("res://Scripts/Hazards/TrackingSandstorm.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_stop_ticks(child)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _add_fixture(main: Node, node: Node2D) -> Node2D:
	main.add_child(node)
	_stop_ticks(node)
	return node

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	_stop_ticks(main)
	paused = false
	var flow: Node = main.get_node("LevelFlowController")
	var battle: Node = main.get_node("BattleManager")
	var scarabs: Node = main.get_node("ScarabMechanismController")
	var sand_controller: Node = main.get_node("QuicksandMechanismController")
	var wind: Node = main.get_node("WindSandMechanismController")
	var storage: Node = main.get_node("StorageManager")
	var player: Node = main.get_node("Player")
	var controllers: Dictionary = {Defs.QUICKSAND: sand_controller, Defs.SCARAB: scarabs, Defs.SANDSTORM: wind}
	var ids: Array[StringName] = [Defs.QUICKSAND, Defs.SCARAB, Defs.SANDSTORM]
	for kind: StringName in ids:
		flow._stop_map_mechanisms()
		battle.reset_runtime_state()
		await physics_frame
		var group := {"map_mechanism_ids": ids, "boss_enhanced_map_mechanism_id": kind, "boss_health_override": 300}
		for controller: Node in controllers.values():
			controller.configure_for_level(group)
		flow._start_map_mechanisms(true)
		battle.configure_for_order_group(group)
		battle.spawn_scheduled_boss()
		var boss: Node2D = get_first_node_in_group("map_mechanism_bosses")
		_check(boss != null and boss.boss_kind == kind, "Each shutdown must be triggered by its actual managed Boss.")
		if boss == null:
			quit(1)
			return
		_stop_ticks(boss)
		var sand := _add_fixture(main, Sand.new())
		var tail := Tail.new()
		tail.boss_owner = boss
		_add_fixture(main, tail)
		var pad := _add_fixture(main, load("res://Scenes/Hazards/wind_sand_pad.tscn").instantiate())
		var wave := Wave.new()
		wave.boss_owner = boss if kind == Defs.SANDSTORM else null
		_add_fixture(main, wave)
		var cyclone := Cyclone.new()
		cyclone.boss_owner = wave.boss_owner
		_add_fixture(main, cyclone)
		var scarab := Scarab.new()
		_add_fixture(main, scarab)
		scarab.stolen_items.assign([Items.VEG_LEAF_ID, Items.VEG_LEAF_ID])
		storage.add_stock(Items.VEG_LEAF_ID, 1)
		_check(storage.reserve_stock(scarab, Items.VEG_LEAF_ID, func() -> bool: return true), "Shutdown fixture must hold a stock reservation.")
		if kind == Defs.SCARAB:
			_check(scarabs.begin_boss_burst(boss), "Shutdown must cancel an active summon wave.")
		if kind == Defs.SANDSTORM:
			player.storm_controller.distance_remaining = 200.0
			player.storm_controller.stun_remaining = 1.0
		var loose_before: int = get_nodes_in_group("loose_items").size()
		boss.receive_hit(300)
		for other_kind: StringName in ids:
			_check(controllers[other_kind].active == (other_kind != kind), "Only the defeated Boss's corresponding controller must stop.")
		_check(sand.is_queued_for_deletion() == (kind == Defs.QUICKSAND), "Existing quicksand must disappear only after worm defeat.")
		_check(pad.is_queued_for_deletion() == (kind == Defs.SANDSTORM), "Existing launch pads must disappear only after vulture defeat.")
		_check(scarab.is_queued_for_deletion() == (kind == Defs.SCARAB), "Existing scarabs must disappear only after scorpion defeat.")
		if kind == Defs.QUICKSAND:
			_check(tail.is_queued_for_deletion(), "Delayed tail pools must be cancelled on worm defeat.")
		if kind == Defs.SANDSTORM:
			_check(wave.is_queued_for_deletion() and cyclone.is_queued_for_deletion(), "Both travelling and tracking storms must be removed.")
			_check(player.storm_controller.distance_remaining == 0.0 and player.storm_controller.stun_remaining == 0.0, "Storm launch and stun must end with the mechanism.")
		if kind == Defs.SCARAB:
			_check(not storage.stock_reservations.has(scarab.get_instance_id()), "Removed scarabs must release stock reservations.")
			_check(scarabs.burst_remaining == 0 and scarabs.burst_owner == null, "Pending summons must be cancelled.")
			_check(get_nodes_in_group("loose_items").size() == loose_before + 5, "Scorpion defeat must drop three Boss ingredients and return both stolen portions.")
			flow._on_boss_defeated(kind)
			_check(get_nodes_in_group("loose_items").size() == loose_before + 5, "Repeated cleanup must not duplicate stolen food.")
		flow._start_map_mechanisms(true)
		controllers[kind]._process(120.0)
		_check(not controllers[kind].active, "Later wave starts and elapsed time must not restart the suspended mechanism.")
		battle.spawn_scheduled_boss()
		_check(not battle.has_active_boss(), "The defeated Boss must not respawn during the same day.")
		await physics_frame
		var removed_groups: Array = ["quicksand_hazards", "sandworm_tail_strikes"] if kind == Defs.QUICKSAND else (["scarab_enemies"] if kind == Defs.SCARAB else ["wind_sand_pads", "boss_storm_hazards"])
		for group_name: String in removed_groups:
			_check(get_nodes_in_group(group_name).is_empty(), "The suspended mechanism must leave no active entities.")
		flow._stop_map_mechanisms()
		await physics_frame
		var next_day := {"map_mechanism_ids": ids}
		for controller: Node in controllers.values():
			controller.configure_for_level(next_day)
		flow._start_map_mechanisms(true)
		_check(scarabs.active and scarabs.business_running and sand_controller.active and wind.active, "Next-day configuration must restore every enabled mechanism.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: all three Boss deaths selectively clear and suspend mechanisms, return stolen food, cancel summons, preserve other mechanisms and restore next day.")
	quit(0 if failures.is_empty() else 1)
