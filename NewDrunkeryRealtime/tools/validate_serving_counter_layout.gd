extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_stop_ticks(child)

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	_stop_ticks(main)
	var map: Node = main.get_node("PrototypeMap")
	var kitchen: Rect2 = map.get_kitchen_zone_bounds()
	var left: Array[Vector2] = [main.get_node("TestServingCounter").global_position, main.get_node("TestServingCounter2").global_position]
	var bottom: Array[Vector2] = [main.get_node("TestServingCounter3").global_position, main.get_node("TestServingCounter4").global_position, main.get_node("TestServingCounter5").global_position]
	var right: Vector2 = main.get_node("TestServingCounter6").global_position
	for point: Vector2 in left:
		_check(is_equal_approx(point.x, kitchen.position.x - 64.0), "Left customer table must sit outside the kitchen's left boundary.")
	_check(is_equal_approx(right.x, kitchen.end.x + 64.0), "Right customer table must sit outside the kitchen's right boundary.")
	for point: Vector2 in bottom:
		_check(is_equal_approx(point.y, kitchen.end.y + 64.0), "Bottom customer table must sit outside the kitchen's bottom boundary.")
	_check(left[0].y < left[1].y and bottom[0].x < bottom[1].x and bottom[1].x < bottom[2].x, "Customer table numbering order must remain stable.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: customer serving tables occupy the expanded restaurant's outer grid edges with stable numbering.")
	quit(0 if failures.is_empty() else 1)
