class_name LevelRefs
extends Node

@export var scene_root_path: NodePath = NodePath("..")
@export var runtime_root_path: NodePath = NodePath("..")
@export var prototype_map_path: NodePath = NodePath("../PrototypeMap")
@export var player_path: NodePath = NodePath("../Player")
@export var order_hud_path: NodePath = NodePath("../OrderHud")
@export var order_manager_path: NodePath = NodePath("../OrderManager")
@export var storage_manager_path: NodePath = NodePath("../StorageManager")
@export var battle_manager_path: NodePath = NodePath("../BattleManager")
@export var scarab_mechanism_controller_path: NodePath = NodePath("../ScarabMechanismController")
@export var quicksand_mechanism_controller_path: NodePath = NodePath("../QuicksandMechanismController")
@export var wind_sand_mechanism_controller_path: NodePath = NodePath("../WindSandMechanismController")
@export var level_flow_controller_path: NodePath = NodePath("../LevelFlowController")
@export var serving_counter_path: NodePath = NodePath("../TestServingCounter")
@export var run_status_hud_path: NodePath = NodePath("../RunStatusHud")
@export var battle_spawn_point_paths: Array[NodePath] = [
	NodePath("../FrontlineSpawnA"),
	NodePath("../FrontlineSpawnB"),
	NodePath("../FrontlineSpawnC"),
	NodePath("../FrontlineSpawnD"),
	NodePath("../FrontlineSpawnE")
]
@export var station_paths: Array[NodePath] = [
	NodePath("../TestTable"),
	NodePath("../TestCooker"),
	NodePath("../BakeCooker"),
	NodePath("../GrindCooker"),
	NodePath("../AssemblyStation"),
	NodePath("../FixedBarrelLeftA"),
	NodePath("../FixedBarrelLeftB"),
	NodePath("../FixedBarrelLeftC"),
	NodePath("../FixedBarrelLeftD"),
	NodePath("../FixedBarrelCenterA"),
	NodePath("../FixedBarrelRightA"),
	NodePath("../TestServingCounter"),
	NodePath("../TestServingCounter2"),
	NodePath("../TestServingCounter3"),
	NodePath("../TestServingCounter4"),
	NodePath("../TestServingCounter5"),
	NodePath("../TestServingCounter6")
]

func get_scene_root() -> Node:
	var scene_root: Node = get_node_or_null(scene_root_path)
	return scene_root if scene_root != null else get_parent()

func get_runtime_root() -> Node:
	var runtime_root: Node = get_node_or_null(runtime_root_path)
	return runtime_root if runtime_root != null else get_scene_root()

func get_prototype_map() -> Node:
	return get_node_or_null(prototype_map_path)

func get_player() -> Node:
	return get_node_or_null(player_path)

func get_order_hud() -> Node:
	return get_node_or_null(order_hud_path)

func get_order_manager() -> Node:
	return get_node_or_null(order_manager_path)

func get_storage_manager() -> Node:
	return get_node_or_null(storage_manager_path)

func get_battle_manager() -> Node:
	return get_node_or_null(battle_manager_path)

func get_scarab_mechanism_controller() -> Node:
	return get_node_or_null(scarab_mechanism_controller_path)

func get_quicksand_mechanism_controller() -> Node:
	return get_node_or_null(quicksand_mechanism_controller_path)

func get_wind_sand_mechanism_controller() -> Node:
	return get_node_or_null(wind_sand_mechanism_controller_path)

func get_level_flow_controller() -> Node:
	return get_node_or_null(level_flow_controller_path)

func get_serving_counter() -> Node:
	return get_node_or_null(serving_counter_path)

func get_run_status_hud() -> Node:
	return get_node_or_null(run_status_hud_path)

func get_station_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	for path in station_paths:
		var node: Node = get_node_or_null(path)
		if node != null:
			nodes.append(node)
	return nodes

func get_battle_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for path in battle_spawn_point_paths:
		var marker: Node = get_node_or_null(path)
		if marker is Node2D:
			points.append(marker.global_position)
	return points

static func find_from(node: Node) -> LevelRefs:
	if node == null:
		return null
	var scene_root: Node = node.get_tree().current_scene if node.get_tree() != null else null
	if scene_root != null:
		var refs_from_scene: LevelRefs = scene_root.get_node_or_null("LevelRefs") as LevelRefs
		if refs_from_scene != null:
			return refs_from_scene
	var parent: Node = node
	while parent != null:
		if parent is LevelRefs:
			return parent as LevelRefs
		var candidate: LevelRefs = parent.get_node_or_null("LevelRefs") as LevelRefs
		if candidate != null:
			return candidate
		parent = parent.get_parent()
	return null
