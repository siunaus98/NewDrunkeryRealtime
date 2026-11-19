extends Node

signal boss_defeated(mechanism_id: StringName)

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const IngredientSourceDefs = preload("res://Scripts/Core/IngredientSourceDefs.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
const MapMechanismDefs = preload("res://Scripts/Core/MapMechanismDefs.gd")
const CHICKEN_ENEMY_SCENE := preload("res://Scenes/Enemies/chicken_enemy.tscn")
const PIG_ENEMY_SCENE := preload("res://Scenes/Enemies/pig_enemy.tscn")
const SLAM_ENEMY_SCENE := preload("res://Scenes/Enemies/slam_enemy.tscn")
const RANGED_ENEMY_SCENE := preload("res://Scenes/Enemies/ranged_enemy.tscn")
const BULLET_HELL_ENEMY_SCENE := preload("res://Scenes/Enemies/bullet_hell_enemy.tscn")
const BRUISER_ENEMY_SCENE := preload("res://Scenes/Enemies/bruiser_enemy.tscn")
const SNIPER_ENEMY_SCENE := preload("res://Scenes/Enemies/sniper_enemy.tscn")
const ORBITER_ENEMY_SCENE := preload("res://Scenes/Enemies/orbiter_enemy.tscn")
const SPLITTER_ENEMY_SCENE := preload("res://Scenes/Enemies/splitter_enemy.tscn")
const SANDWORM_BOSS_SCENE := preload("res://Scenes/Enemies/sandworm_boss.tscn")
const SCORPION_BOSS_SCENE := preload("res://Scenes/Enemies/scorpion_boss.tscn")
const VULTURE_BOSS_SCENE := preload("res://Scenes/Enemies/vulture_boss.tscn")
const MONITOR_BOSS_SCENE := preload("res://Scenes/Enemies/monitor_boss.tscn")
const BATTLE_DROP_SCENE := preload("res://Scenes/Battle/battle_drop.tscn")
const LOOSE_ITEM_SCENE := preload("res://Scenes/Restaurant/loose_item.tscn")

@export var base_enemies_per_wave: int = 4
@export var extra_enemies_per_order: int = 1
@export var max_concurrent_enemies: int = 6
@export var maintained_enemies_per_region: int = 1
@export var spawn_interval: float = 1.4
@export var drop_speed_min: float = 180.0
@export var drop_speed_max: float = 340.0
@export var enemy_speed_wave_bonus: float = 14.4
@export var enemy_health_wave_bonus: int = 10
@export_range(0.0, 1.0, 0.01) var non_meat_drop_chance: float = 0.28

var prototype_map: Node2D
var level_refs: LevelRefs
var spawn_points: Array[Vector2] = []
var spawn_points_by_region: Dictionary = {}
var battle_bounds: Rect2 = Rect2()
var allowed_meats: Array[StringName] = []
var allowed_drop_items: Array[StringName] = []
var allowed_non_meat_drops: Array[StringName] = []
var enemy_pool: Array[StringName] = []
var boss_mechanism_id: StringName = &""
var boss_health_override: int = 0
var run_multipliers: Dictionary = {}
var boss_spawned: bool = false
var current_wave_index: int = -1
var target_spawn_count: int = 0
var spawned_count: int = 0
var spawn_cooldown_remaining: float = 0.0
var wave_active: bool = false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_resolve_scene_nodes()
	_refresh_battle_bounds()
	_refresh_spawn_points()

func _process(delta: float) -> void:
	if not wave_active:
		return

	spawn_cooldown_remaining = maxf(spawn_cooldown_remaining - delta, 0.0)
	if _get_active_enemy_count() >= max_concurrent_enemies:
		return
	if spawn_cooldown_remaining > 0.0:
		return

	_spawn_enemy(_get_region_needing_enemy())
	spawn_cooldown_remaining = spawn_interval

func configure_for_order_group(group_data: Dictionary) -> void:
	run_multipliers = Dictionary(group_data.get("run_multipliers", {})).duplicate(true)
	allowed_meats.clear()
	allowed_drop_items.clear()
	allowed_non_meat_drops.clear()
	var raw_allowed_meats: Variant = group_data.get("allowed_meats", [])
	if raw_allowed_meats is Array:
		for item_id in raw_allowed_meats:
			var ingredient_id := StringName(item_id)
			allowed_meats.append(ingredient_id)
			if TestItemDefs.can_drop_ingredient_from_battle(ingredient_id):
				allowed_drop_items.append(ingredient_id)
				if not _is_meat_item(ingredient_id):
					allowed_non_meat_drops.append(ingredient_id)
	var raw_allowed_veggies: Variant = group_data.get("allowed_veggies", [])
	if raw_allowed_veggies is Array:
		for item_id in raw_allowed_veggies:
			var ingredient_id := StringName(item_id)
			if TestItemDefs.can_drop_ingredient_from_battle(ingredient_id) and ingredient_id not in allowed_drop_items:
				allowed_drop_items.append(ingredient_id)
				if not _is_meat_item(ingredient_id):
					allowed_non_meat_drops.append(ingredient_id)
	enemy_pool.clear()
	boss_mechanism_id = StringName(group_data.get("boss_enhanced_map_mechanism_id", &""))
	boss_health_override = maxi(int(group_data.get("boss_health_override", 0)), 0)
	var raw_enemy_pool: Variant = group_data.get("enemy_pool", [])
	if raw_enemy_pool is Array:
		for enemy_id in raw_enemy_pool:
			enemy_pool.append(StringName(enemy_id))

func reset_runtime_state() -> void:
	wave_active = false
	current_wave_index = -1
	target_spawn_count = 0
	spawned_count = 0
	boss_mechanism_id = &""
	boss_health_override = 0
	boss_spawned = false
	spawn_cooldown_remaining = 0.0
	_clear_spawned_enemies()
	_clear_battle_drops()

func enter_prepare_phase() -> void:
	_resolve_scene_nodes()
	_refresh_battle_bounds()
	_refresh_spawn_points()
	current_wave_index = -1
	target_spawn_count = max(base_enemies_per_wave, 1)
	spawned_count = _get_active_enemy_count()
	spawn_cooldown_remaining = 0.0
	wave_active = true

func start_wave(wave_index: int, wave_data: Dictionary, group_data: Dictionary) -> void:
	_resolve_scene_nodes()
	_refresh_battle_bounds()
	_refresh_spawn_points()
	configure_for_order_group(group_data)
	if wave_index == 0:
		_spawn_boss_if_needed()

	current_wave_index = wave_index
	target_spawn_count = _calculate_target_spawn_count(wave_data)
	spawned_count = _get_active_enemy_count()
	spawn_cooldown_remaining = 0.0
	wave_active = true

func end_wave() -> void:
	wave_active = false
	current_wave_index = -1
	target_spawn_count = 0
	spawned_count = _get_active_enemy_count()
	spawn_cooldown_remaining = 0.0

func end_level() -> void:
	reset_runtime_state()

func _resolve_scene_nodes() -> void:
	level_refs = LevelRefs.find_from(self)
	if level_refs == null:
		push_warning("BattleManager requires a LevelRefs node in the scene.")
		return
	prototype_map = level_refs.get_prototype_map() as Node2D

func _refresh_battle_bounds() -> void:
	if prototype_map != null and prototype_map.has_method("get_battle_zone_bounds"):
		battle_bounds = prototype_map.get_battle_zone_bounds()

func _refresh_spawn_points() -> void:
	spawn_points.clear()
	spawn_points_by_region.clear()
	if level_refs != null:
		spawn_points = level_refs.get_battle_spawn_points()

	if spawn_points.is_empty() and prototype_map != null and prototype_map.has_method("get_frontline_spawn_points"):
		var fallback_points: Array = prototype_map.get_frontline_spawn_points()
		for point in fallback_points:
			if point is Vector2:
				spawn_points.append(point)

	if prototype_map != null and prototype_map.has_method("get_battle_region_for_point"):
		for point in spawn_points:
			var region_id: StringName = prototype_map.get_battle_region_for_point(point)
			if region_id == &"":
				continue
			if not spawn_points_by_region.has(region_id):
				spawn_points_by_region[region_id] = []
			var region_points: Array = spawn_points_by_region[region_id]
			region_points.append(point)
			spawn_points_by_region[region_id] = region_points

func _calculate_target_spawn_count(wave_data: Dictionary) -> int:
	var order_count: int = 0
	var orders: Variant = wave_data.get("orders", [])
	if orders is Array:
		order_count = orders.size()
	return max(base_enemies_per_wave + order_count * extra_enemies_per_order + max(current_wave_index, 0), 1)

func _spawn_enemy(preferred_region_id: StringName = &"") -> void:
	var scene_root: Node = level_refs.get_runtime_root() if level_refs != null else get_parent()
	if scene_root == null or spawn_points.is_empty():
		return

	var enemy_id: StringName = _pick_enemy_id(preferred_region_id)
	var home_region_id: StringName = preferred_region_id if preferred_region_id != &"" else _get_home_region_for_enemy(enemy_id)
	var enemy_bounds: Rect2 = _get_bounds_for_region(home_region_id)
	var enemy_scene: PackedScene = _get_enemy_scene_for_id(enemy_id)
	var enemy: CharacterBody2D = enemy_scene.instantiate()
	scene_root.add_child(enemy)
	enemy.add_to_group("battle_spawned_enemies")
	enemy.set_meta("enemy_type", enemy_id)
	enemy.set_meta("spawn_region", home_region_id)
	enemy.global_position = _pick_spawn_point_for_region(home_region_id, enemy_id)

	var drop_item_id: StringName = _get_drop_item_for_enemy(enemy_id)
	if enemy.has_method("setup_for_battle"):
		enemy.setup_for_battle(drop_item_id, enemy_bounds, current_wave_index, enemy_speed_wave_bonus, enemy_health_wave_bonus)
	else:
		if enemy.has_method("set_movement_bounds"):
			enemy.set_movement_bounds(enemy_bounds)
		enemy.set("drop_item_id", drop_item_id)
	preload("res://Scripts/Progression/RunModifierDefs.gd").apply_enemy(enemy, run_multipliers)

	if enemy.has_signal("defeated") and not enemy.defeated.is_connected(_on_enemy_defeated):
		enemy.defeated.connect(_on_enemy_defeated)

	spawned_count += 1

func spawn_scheduled_boss() -> void:
	_spawn_boss_if_needed()

func _spawn_boss_if_needed() -> void:
	if boss_spawned or boss_mechanism_id == &"":
		return
	var scene_root: Node = level_refs.get_runtime_root() if level_refs != null else get_parent()
	if scene_root == null or prototype_map == null:
		return
	var boss_scene: PackedScene
	match boss_mechanism_id:
		MapMechanismDefs.QUICKSAND:
			boss_scene = SANDWORM_BOSS_SCENE
		MapMechanismDefs.SCARAB:
			boss_scene = SCORPION_BOSS_SCENE
		MapMechanismDefs.SANDSTORM:
			boss_scene = VULTURE_BOSS_SCENE
		&"monitor":
			boss_scene = MONITOR_BOSS_SCENE
		_:
			return
	var boss: CharacterBody2D = boss_scene.instantiate()
	if boss_health_override > 0:
		boss.set("max_health", boss_health_override)
	scene_root.add_child(boss)
	boss.add_to_group("battle_spawned_enemies")
	boss.set_meta("enemy_type", &"map_mechanism_boss")
	boss.set_meta("spawn_region", &"top")
	var boss_bounds := _get_bounds_for_region(&"top")
	boss.global_position = _pick_spawn_point_for_region(&"top")
	if boss.has_method("setup_for_battle"):
		boss.setup_for_battle(_get_boss_drop_item(boss_mechanism_id), boss_bounds)
	preload("res://Scripts/Progression/RunModifierDefs.gd").apply_enemy(boss, run_multipliers)
	if boss.has_method("set"):
		boss.set("drop_count", 3)
	if boss.has_signal("defeated") and not boss.defeated.is_connected(_on_enemy_defeated):
		boss.defeated.connect(_on_enemy_defeated)
	boss_spawned = true
	preload("res://Scripts/Audio/AudioCue.gd").play_sfx(&"boss_alert", -2.0)
	spawned_count += 1

func has_active_boss() -> bool:
	for boss in get_tree().get_nodes_in_group("map_mechanism_bosses"):
		if is_instance_valid(boss) and not boss.is_dead and not boss.is_queued_for_deletion():
			return true
	return false

func _pick_enemy_id(preferred_region_id: StringName = &"") -> StringName:
	if not enemy_pool.is_empty():
		var candidates: Array[StringName] = []
		for enemy_id in enemy_pool:
			if preferred_region_id == &"" or _get_home_region_for_enemy(enemy_id) == preferred_region_id:
				candidates.append(enemy_id)
		if not candidates.is_empty():
			return candidates[rng.randi_range(0, candidates.size() - 1)]
		if preferred_region_id != &"":
			match preferred_region_id:
				&"left":
					return &"ranged"
				&"right":
					return &"slammer"
				&"near":
					return &"chaser"
	if current_wave_index >= 0 and rng.randf() < 0.14:
		return &"bullet_fan"
	if current_wave_index >= 0 and rng.randf() < 0.2:
		return &"ranged"
	if current_wave_index >= 0 and rng.randf() < 0.22:
		return &"slammer"
	if current_wave_index >= 0 and rng.randf() < 0.35:
		return &"sprinter"
	match preferred_region_id:
		&"left":
			return &"ranged"
		&"right":
			return &"slammer"
		&"near":
			return &"chaser"
		_:
			return &"chaser"

func _get_region_needing_enemy() -> StringName:
	var maintained_regions: Array[StringName] = [&"near", &"left", &"right"]
	var best_region: StringName = &""
	var lowest_count := maintained_enemies_per_region
	for region_id in maintained_regions:
		var region_count := _get_active_enemy_count_for_region(region_id)
		if region_count < lowest_count:
			lowest_count = region_count
			best_region = region_id
	if best_region != &"":
		return best_region
	return maintained_regions[rng.randi_range(0, maintained_regions.size() - 1)]

func _get_active_enemy_count_for_region(region_id: StringName) -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("battle_spawned_enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var enemy_region := StringName(enemy.get_meta("spawn_region", &""))
		if enemy_region == region_id:
			count += 1
	return count

func _pick_spawn_point_for_region(region_id: StringName, enemy_id: StringName = &"") -> Vector2:
	# The map owns deterministic environmental landmarks. Prefer its placement
	# hint so oasis ecology changes the visual entry point without changing the
	# enemy pool or spawn budget.
	if enemy_id != &"" and prototype_map != null and prototype_map.has_method("get_spawn_point_for_enemy"):
		var hinted: Variant = prototype_map.get_spawn_point_for_enemy(region_id, enemy_id)
		if hinted is Vector2 and hinted != Vector2.INF:
			return hinted
	if spawn_points_by_region.has(region_id):
		var region_points: Array = spawn_points_by_region[region_id]
		if not region_points.is_empty():
			return region_points[rng.randi_range(0, region_points.size() - 1)]
	if prototype_map != null and prototype_map.has_method("get_random_point_in_region"):
		var random_point: Variant = prototype_map.get_random_point_in_region(region_id, Vector2(128, 128))
		if random_point is Vector2:
			return random_point
	return spawn_points[rng.randi_range(0, spawn_points.size() - 1)]

func _get_home_region_for_enemy(enemy_id: StringName) -> StringName:
	return IngredientSourceDefs.get_enemy_home_region(enemy_id)

func _get_bounds_for_region(region_id: StringName) -> Rect2:
	if prototype_map != null and prototype_map.has_method("get_region_bounds"):
		var region_bounds: Variant = prototype_map.get_region_bounds(region_id)
		if region_bounds is Rect2 and region_bounds.size.x > 0.0 and region_bounds.size.y > 0.0:
			return region_bounds
	return battle_bounds

func _get_enemy_scene_for_id(enemy_id: StringName) -> PackedScene:
	match enemy_id:
		&"chaser":
			return CHICKEN_ENEMY_SCENE
		&"sprinter":
			return PIG_ENEMY_SCENE
		&"slammer":
			return SLAM_ENEMY_SCENE
		&"ranged":
			return RANGED_ENEMY_SCENE
		&"bullet_fan":
			return BULLET_HELL_ENEMY_SCENE
		&"bruiser":
			return BRUISER_ENEMY_SCENE
		&"sniper":
			return SNIPER_ENEMY_SCENE
		&"orbiter":
			return ORBITER_ENEMY_SCENE
		&"splitter":
			return SPLITTER_ENEMY_SCENE
		_:
			return CHICKEN_ENEMY_SCENE

func _pick_drop_item_id() -> StringName:
	if allowed_drop_items.is_empty():
		return TestItemDefs.MEAT_RED_ID
	if not allowed_non_meat_drops.is_empty() and rng.randf() < non_meat_drop_chance:
		return allowed_non_meat_drops[rng.randi_range(0, allowed_non_meat_drops.size() - 1)]
	if not allowed_meats.is_empty():
		return allowed_meats[rng.randi_range(0, allowed_meats.size() - 1)]
	return allowed_drop_items[rng.randi_range(0, allowed_drop_items.size() - 1)]

func _get_drop_item_for_enemy(enemy_id: StringName) -> StringName:
	var defined_drop := IngredientSourceDefs.get_enemy_drop_item(enemy_id)
	return defined_drop if defined_drop != &"" else _pick_drop_item_id()

func _get_boss_drop_item(mechanism_id: StringName) -> StringName:
	match mechanism_id:
		MapMechanismDefs.QUICKSAND:
			return TestItemDefs.SANDWORM_CORE_ID
		MapMechanismDefs.SCARAB:
			return TestItemDefs.SCORPION_CLAW_ID
		MapMechanismDefs.SANDSTORM:
			return TestItemDefs.VULTURE_FEATHERHEART_ID
		&"monitor":
			return TestItemDefs.MONITOR_TENDERLOIN_ID
		_:
			return TestItemDefs.MEAT_RED_ID

func _is_meat_item(item_id: StringName) -> bool:
	return item_id in [
		TestItemDefs.MEAT_RED_ID,
		TestItemDefs.MEAT_WHITE_ID,
		TestItemDefs.SHRIMP_ID,
		TestItemDefs.CAMEL_MEAT_ID
	]

func _on_enemy_defeated(enemy: Node2D, drop_item_id: StringName, drop_count: int, defeat_position: Vector2) -> void:
	if enemy.is_in_group("map_mechanism_bosses"):
		boss_defeated.emit(enemy.boss_kind)
	var blessing_runtime := _get_blessing_runtime()
	var blessed_drop_count: int = int(blessing_runtime.on_unit_killed(enemy, drop_count)) if blessing_runtime != null else drop_count
	if drop_item_id == &"" or blessed_drop_count <= 0:
		return
	var attract_range_multiplier: float = float(blessing_runtime.get_drop_attract_range_multiplier(defeat_position)) if blessing_runtime != null else 1.0
	var actual_drop_count := TestItemDefs.get_battle_drop_quantity(drop_item_id, blessed_drop_count)
	if TestItemDefs.is_boss_ingredient(drop_item_id):
		_spawn_boss_ingredient_drops(drop_item_id, actual_drop_count, defeat_position)
		return
	var flow: Node = level_refs.get_level_flow_controller() if level_refs != null else null
	var drop_multiplier: float = float(flow.get_run_modifier_multiplier(&"ordinary_drop")) if flow != null else 1.0
	actual_drop_count = _ordinary_drop_count(actual_drop_count, drop_multiplier)
	for _i in range(actual_drop_count):
		var drop: Area2D = BATTLE_DROP_SCENE.instantiate()
		var runtime_root: Node = level_refs.get_runtime_root() if level_refs != null else get_parent()
		if runtime_root == null:
			return
		runtime_root.add_child(drop)
		drop.global_position = defeat_position
		var angle: float = rng.randf_range(0.0, TAU)
		var speed: float = rng.randf_range(drop_speed_min, drop_speed_max)
		var burst_velocity := Vector2.RIGHT.rotated(angle) * speed
		if drop.has_method("setup_drop"):
			var drop_bounds := battle_bounds
			if enemy != null and enemy.has_method("get_movement_bounds"):
				var enemy_bounds: Variant = enemy.get_movement_bounds()
				if enemy_bounds is Rect2:
					drop_bounds = enemy_bounds
			drop.setup_drop(drop_item_id, burst_velocity, drop_bounds, attract_range_multiplier)

func _ordinary_drop_count(base_count: int, multiplier: float) -> int:
	# Fractional bonuses roll once per original portion. Fixed base drops stay
	# intact; e.g. +40% means each portion has a 40% chance to add one more.
	var extra: float = maxf(multiplier - 1.0, 0.0)
	var result: int = base_count * (1 + floori(extra))
	var chance: float = extra - floorf(extra)
	if chance > 0.0:
		for index in range(base_count):
			if rng.randf() < chance:
				result += 1
	return result

func _spawn_boss_ingredient_drops(item_id: StringName, count: int, origin: Vector2) -> void:
	var runtime_root: Node = level_refs.get_runtime_root() if level_refs != null else get_parent()
	if runtime_root == null:
		return
	var drop_bounds := battle_bounds
	for index in range(maxi(count, 0)):
		var loose_item: CharacterBody2D = LOOSE_ITEM_SCENE.instantiate()
		runtime_root.add_child(loose_item)
		loose_item.setup_item(item_id, TestItemDefs.get_item_texture(item_id), TestItemDefs.PROCESS_STATE_NONE)
		var angle := (TAU * float(index) / float(maxi(count, 1))) + rng.randf_range(-0.18, 0.18)
		var radius := 34.0 + float(index % 2) * 18.0
		var drop_position := origin + Vector2.RIGHT.rotated(angle) * radius
		if drop_bounds.size.x > 0.0 and drop_bounds.size.y > 0.0:
			drop_position = drop_position.clamp(drop_bounds.position + Vector2(32.0, 32.0), drop_bounds.end - Vector2(32.0, 32.0))
		loose_item.global_position = drop_position
		loose_item.velocity = Vector2.RIGHT.rotated(angle) * rng.randf_range(90.0, 170.0)

func _get_blessing_runtime() -> RefCounted:
	var player := get_tree().get_first_node_in_group("player")
	return player.get_blessing_controller() if player != null and player.has_method("get_blessing_controller") else null

func _get_active_enemy_count() -> int:
	var count: int = 0
	for enemy in get_tree().get_nodes_in_group("battle_spawned_enemies"):
		if is_instance_valid(enemy):
			count += 1
	return count

func _clear_spawned_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("battle_spawned_enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

func _clear_battle_drops() -> void:
	for drop in get_tree().get_nodes_in_group("battle_drops"):
		if is_instance_valid(drop):
			drop.queue_free()
