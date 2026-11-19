extends SceneTree

var failures: int = 0

class CounterProbe extends Node:
	var target: int = -99
	func set_order_target_slot(value: int) -> void:
		target = value
	func get_order_target_slot() -> int:
		return target

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_stop_ticks(child)

func _get_counter_targets(main: Node) -> Array[int]:
	var result: Array[int] = []
	for counter in main.get_tree().get_nodes_in_group("serving_counters"):
		if counter is CounterProbe:
			result.append(int(counter.get_order_target_slot()))
	if result.is_empty():
		push_error("No serving counters were found for target synchronization test.")
	return result

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	_stop_ticks(main)
	paused = false
	var flow: Node = main.get_node("LevelFlowController")
	var order_manager: Node = main.get_node("OrderManager")
	flow.order_manager = order_manager
	for index in range(3):
		var counter := CounterProbe.new()
		counter.add_to_group("serving_counters")
		main.add_child(counter)
	order_manager.active_orders.clear()
	order_manager.waiting_orders.clear()
	flow._on_orders_changed([])
	_check(_get_counter_targets(main).all(func(value: int) -> bool: return value == -1), "Empty order lists must clear serving targets.")
	order_manager.waiting_orders.append({"target_slot": 2, "order_id": "waiting-target"})
	flow._on_orders_changed([])
	_check(_get_counter_targets(main).all(func(value: int) -> bool: return value == 1), "Order changes must fall back to waiting orders when active list is empty.")
	flow._on_orders_changed([{"target_slot": 3, "order_id": "active-target"}])
	_check(_get_counter_targets(main).all(func(value: int) -> bool: return value == 2), "Non-empty active changes must use the first active order.")
	order_manager.active_orders.append({"target_slot": 1, "order_id": "active-fallback"})
	flow._on_waiting_orders_changed([])
	_check(_get_counter_targets(main).all(func(value: int) -> bool: return value == 0), "Waiting changes must fall back to active orders when waiting list is empty.")
	flow._on_waiting_orders_changed([{"target_slot": 4, "order_id": "waiting-first"}, {"target_slot": 1, "order_id": "waiting-second"}])
	_check(_get_counter_targets(main).all(func(value: int) -> bool: return value == 3), "Non-empty waiting changes must use the first waiting order.")
	main.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: serving target clear, active/waiting fallback, first-order priority and zero-based slot mapping.")
	quit(0 if failures == 0 else 1)
