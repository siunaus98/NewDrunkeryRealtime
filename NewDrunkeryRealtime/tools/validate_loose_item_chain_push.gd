extends SceneTree

const LOOSE_ITEM_SCENE := preload("res://Scenes/Restaurant/loose_item.tscn")

var failures: Array[String] = []
var spawned_items: Array[Node] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	_stop_ticks(main)
	for existing in get_nodes_in_group("loose_items"):
		if is_instance_valid(existing):
			existing.queue_free()
	await physics_frame

	var first := _spawn_item(main, Vector2(620, 620))
	var chain: Array[Node] = [first]
	for i in range(1, 18):
		chain.append(_spawn_item(main, Vector2(620 + float(i) * 31.0, 620)))
	await physics_frame
	_stop_ticks(main)
	for item in chain:
		item.chain_push_max_depth = 3
		item.chain_push_hard_limit = 6
		item.chain_push_warning_depth = 3
		item.enable_chain_push_diagnostics = false

	first.apply_player_push(Vector2.RIGHT, 420.0, Vector2.RIGHT * 520.0, Vector2.RIGHT * 28.0)
	_check_all_positions_finite(chain, "Long linear chain")

	var cycle_a := _spawn_item(main, Vector2(1080, 780))
	var cycle_b := _spawn_item(main, Vector2(1110, 780))
	var cycle_c := _spawn_item(main, Vector2(1095, 806))
	await physics_frame
	_stop_ticks(main)
	for item in [cycle_a, cycle_b, cycle_c]:
		item.chain_push_max_depth = 3
		item.chain_push_hard_limit = 4
		item.chain_push_warning_depth = 2
		item.enable_chain_push_diagnostics = false

	cycle_a.apply_player_push(Vector2.RIGHT, 360.0, Vector2.RIGHT * 480.0, Vector2.RIGHT * 24.0)
	_check_all_positions_finite([cycle_a, cycle_b, cycle_c], "Cyclic overlap")

	for item in spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: loose-item chain push terminates for long linear and cyclic overlap cases with finite positions.")
	quit(0 if failures.is_empty() else 1)

func _spawn_item(parent: Node, position: Vector2) -> Node:
	var item: Node = LOOSE_ITEM_SCENE.instantiate()
	item.position = position
	parent.add_child(item)
	spawned_items.append(item)
	return item

func _check_all_positions_finite(items: Array, label: String) -> void:
	for item in items:
		_check(is_instance_valid(item) and item.global_position.is_finite(), "%s chain produced an invalid item position." % label)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	if not failures.has(message):
		failures.append(message)
	push_error(message)

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_stop_ticks(child)
