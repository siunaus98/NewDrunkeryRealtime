extends SceneTree

const Catalog = preload("res://Scripts/Facilities/FacilityCatalog.gd")
const Aura = preload("res://Scripts/Core/SupportFacilityAuraQuery.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
var failures: Array[String] = []
var main: Node
var flow: Node
var map: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in range(4): await process_frame
	await physics_frame

func run() -> void:
	main = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await settle()
	flow = main.get_node("LevelFlowController")
	map = main.get_node("PrototypeMap")
	flow.set_process(false)
	flow.input_release_guard_active = false
	flow.overlay_controller.set_transition_visible(false)
	paused = false
	var initial_tables := 0
	for child: Node in main.get_children():
		if child.get_script() == load("res://Scripts/Kitchen/TestTable.gd"): initial_tables += 1
	check(initial_tables == 3, "Initial kitchen contains exactly three prep tables")
	var shop: Node = flow.night_shop_controller
	check(shop._facility_shop_limit(&"prep_table") == 3 and shop._facility_shop_limit(&"conveyor") == 10 and shop._facility_shop_limit(&"lamp") == 2, "Requested manual purchase caps")
	check(Catalog.definition(&"stack_table").limit == 3 and Catalog.definition(&"ballista").limit == 10, "Requested catalog purchase caps")

	# Work gain sums the bonuses, not the multipliers: 1 + .22 + .22 = 1.44.
	var station: Node2D = main.get_node("TestCooker")
	var lamps: Array[Node2D] = []
	for index in range(2):
		var lamp: Node2D = load("res://Scenes/Restaurant/support_facility.tscn").instantiate()
		lamp.facility_type = &"lamp"
		lamp.cook_speed_multiplier = 1.22
		main.add_child(lamp)
		lamp.global_position = station.global_position + Vector2(index * 60, 80)
		lamps.append(lamp)
	check(is_equal_approx(station._get_nearby_support_cook_multiplier(), 1.44), "Two lamps add to 44 percent work gain")
	lamps[1].set_facility_carried(true)
	check(is_equal_approx(station._get_nearby_support_cook_multiplier(), 1.22), "Carried lamps grant no work gain")
	lamps[1].set_facility_carried(false)
	var barrel: Node2D = main.get_node("FixedBarrelLeftA")
	for lamp: Node2D in lamps: lamp.global_position = barrel.global_position
	check(is_equal_approx(barrel._get_nearby_support_fill_multiplier(), 1.44), "Barrels share additive lamp rule")
	lamps[1].global_position += Vector2(1000, 0)
	check(is_equal_approx(barrel._get_nearby_support_fill_multiplier(), 1.22), "Leaving one lamp aura removes only that bonus")
	lamps[0].hide()
	check(is_equal_approx(barrel._get_nearby_support_fill_multiplier(), 1.0), "Hidden lamps grant no work gain")
	for lamp: Node2D in lamps: lamp.free()

	# Reserve the full authored ingredient-cabinet set, even when not on today's menu.
	var kitchen: Rect2 = map.get_kitchen_zone_bounds()
	var cell_size: Vector2 = map.get_tile_size()
	var total_cells := roundi(kitchen.size.x / cell_size.x) * roundi(kitchen.size.y / cell_size.y)
	var initial_cells := 0
	var initial_detail: Array[Dictionary] = []
	for child: Node in main.get_children():
		if not child is Node2D or not child.has_method("get_layout_footprint"): continue
		var footprint: Vector2i = child.get_layout_footprint()
		var rect := Rect2(child.global_position - Vector2(footprint) * cell_size * .5, Vector2(footprint) * cell_size)
		if not kitchen.encloses(rect): continue
		var area := footprint.x * footprint.y
		initial_cells += area
		initial_detail.append({"name": child.name, "cells": area})
	var purchased_cells := 0
	var purchased_detail: Array[Dictionary] = []
	for id: StringName in shop.SHOP_FACILITY_LIMITS:
		var cells: int = shop.SHOP_FACILITY_LIMITS[id] * (2 if id == &"conveyor" else 1)
		purchased_cells += cells
		purchased_detail.append({"id": id, "cells": cells})
	for entry: Dictionary in Catalog.ENTRIES:
		check(int(entry.limit) > 0, "Every facility has finite cap: " + String(entry.id))
		if entry.id in [&"forklift", &"ballista", &"trap_rack"]: continue
		var facility: Node2D = Catalog.create(entry.id)
		var footprint: Vector2i = facility.get_layout_footprint()
		var cells: int = footprint.x * footprint.y * int(entry.limit) * (2 if entry.get("pair", false) else 1)
		purchased_cells += cells
		purchased_detail.append({"id": entry.id, "cells": cells})
		facility.free()
	var empty := total_cells - initial_cells - purchased_cells
	var summary := {"total": total_cells, "initial_including_all_cabinets": initial_cells, "full_purchase": purchased_cells, "empty": empty, "empty_percent": 100.0 * empty / total_cells, "portal_exit_reserved": 2, "placeable_empty_after_exits": empty - 2, "initial_detail": initial_detail, "purchase_detail": purchased_detail}
	print("KITCHEN CAPACITY: ", JSON.stringify(summary))
	check(empty > 0, "Full purchase preserves space after all cabinets are included")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_artifact_work"))
	var report := FileAccess.open("res://_artifact_work/kitchen_capacity.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(summary, "\t"))
	report.close()

	# Exercise the real shop transaction to every cap, including both-endpoint purchases.
	for cabinet: Node2D in get_nodes_in_group("storage_facilities"):
		cabinet.show()
		cabinet.clear_menu_filter()
	await settle()
	flow.progression_state.gold = 1000000
	flow.run_context.state = preload("res://Scripts/Core/LevelContext.gd").LevelState.NIGHT_REST
	shop.prepare_for_open(flow.progression_state)
	var ids: Array[StringName] = []
	for item: Dictionary in shop.merchant_shop_items:
		if item.type == &"facility": ids.append(item.id)
	for shop_id: StringName in ids:
		var id := StringName(String(shop_id).trim_prefix("facility_"))
		var limit: int = shop._facility_shop_limit(id)
		var stale: Dictionary = {}
		for count in range(limit):
			shop._rebuild_merchant_shop_items()
			var index := find_item(shop, shop_id)
			check(index >= 0, "Facility still purchasable below cap: " + String(id))
			if index < 0: break
			shop.selected_shop_index = index
			stale = shop.merchant_shop_items[index].duplicate(true)
			check(shop.purchase_selected(), "Real shop purchase %s %d/%d" % [id, count + 1, limit])
			await settle()
		check(flow.progression_state.get_stat_purchase_count(shop_id) == limit, "Purchase count reaches cap: " + String(id))
		check(find_item(shop, shop_id) < 0, "Sold-out item leaves shop: " + String(id))
		if not stale.is_empty(): check(not shop._purchase_facility(stale), "Stale card cannot bypass limit: " + String(id))
	for facility: Node2D in get_nodes_in_group("new_facilities"):
		if facility.facility_type in [&"ballista", &"forklift"]:
			check(map.is_point_in_battle_zone(facility.global_position), "Combat equipment is delivered outside kitchen")
	for item: Node2D in get_nodes_in_group("loose_items"):
		if item.item_id == &"bear_trap": check(map.is_point_in_battle_zone(item.global_position), "Trap purchase is delivered outside kitchen")
	main.free()
	paused = false
	print("FACILITY CAPACITY: %d failures; initial tables, purchase caps, real max purchases, lamp overlap and kitchen budget" % failures.size())
	quit(0 if failures.is_empty() else 1)

func find_item(shop: Node, id: StringName) -> int:
	for index in range(shop.merchant_shop_items.size()):
		if shop.merchant_shop_items[index].id == id: return index
	return -1
