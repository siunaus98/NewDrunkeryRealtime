extends SceneTree

const Geometry = preload("res://Scripts/Core/InteractionGeometry.gd")
var failures: int = 0

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _init() -> void:
	var center := Vector2(10, -6)
	var area := Vector2(40, 20)
	var expected: Array[Vector2] = [Vector2(-10, -16), Vector2(10, -16), Vector2(30, -16), Vector2(-10, 4), Vector2(10, 4), Vector2(30, 4)]
	_check(Geometry.grid_points(Transform2D.IDENTITY, center, area, 3, 2) == expected, "Grid order must remain row-major with edges included.")
	_check(Geometry.grid_points(Transform2D.IDENTITY, center, area, 0, -2) == [center], "Invalid counts must fall back to the center point.")
	_check(Geometry.grid_points(Transform2D.IDENTITY, center, area, 1, 2) == [Vector2(10, -16), Vector2(10, 4)], "Single-column points must stay on the center line.")
	_check(Geometry.grid_points(Transform2D.IDENTITY, center, area, 2, 1) == [Vector2(-10, -6), Vector2(30, -6)], "Single-row points must stay on the center line.")
	var turned := Transform2D(PI / 2.0, Vector2(100, 50))
	_check(Geometry.world_rect(turned, center, area).is_equal_approx(Rect2(96, 40, 20, 40)), "Quarter-turn bounds must exchange width and height around the transformed center.")
	_check(Geometry.world_rect(turned, center, Vector2.ZERO).is_equal_approx(Rect2(turned * center, Vector2.ZERO)), "Zero-sized regions must retain their transformed location.")
	_check(Geometry.closest_point_on_segment(Vector2(5, 4), Vector2.ZERO, Vector2(10, 0)).is_equal_approx(Vector2(5, 0)), "Segment projection must clamp to the segment.")
	_check(Geometry.closest_point_on_segment(Vector2(-4, 2), Vector2.ZERO, Vector2(10, 0)).is_equal_approx(Vector2.ZERO), "Segment projection must clamp to the start.")
	_check(Geometry.closest_point_on_segment(Vector2(14, -2), Vector2.ZERO, Vector2(10, 0)).is_equal_approx(Vector2(10, 0)), "Segment projection must clamp to the end.")
	_check(Geometry.closest_point_on_segment(Vector2(3, 4), Vector2(7, 9), Vector2(7, 9)).is_equal_approx(Vector2(7, 9)), "Degenerate segments must return their endpoint.")
	# Construct scripts outside the tree to test geometry without triggering scene _ready.
	var parent := Node2D.new()
	parent.position = Vector2(113, -71)
	parent.rotation = 0.31
	parent.scale = Vector2(1.7, 0.8)
	for path in ["Kitchen/TestTable", "Kitchen/TestCooker", "Kitchen/AssemblyStation", "Kitchen/IngredientStorageCabinet", "Kitchen/LooseItem", "Restaurant/NightRestInteractable", "Restaurant/FixedBarrelBlocker", "Forage/ForagePoint"]:
		var node: Node2D = load("res://Scripts/%s.gd" % path).new()
		parent.add_child(node)
		node.interaction_area_center = center
		node.interaction_area_size = area
		for angle in [0.0, PI / 2.0, -0.73]:
			node.position = Vector2(25, -40)
			node.rotation = angle
			node.scale = Vector2(-1.2, 0.7)
			if path != "Restaurant/FixedBarrelBlocker":
				var local_corners: Array[Vector2] = [Vector2(-10, -16), Vector2(30, -16), Vector2(-10, 4), Vector2(30, 4)]
				var bounds := Rect2(node.to_global(local_corners[0]), Vector2.ZERO)
				for corner in local_corners:
					bounds = bounds.expand(node.to_global(corner))
				_check(node.get_interaction_rect_global().is_equal_approx(bounds), "%s must include all four corners with nested rotation and reflection." % path)
			if path != "Forage/ForagePoint":
				node.interaction_area_columns = 3
				node.interaction_area_rows = 2
				var points: Array = node.get_pickup_drop_positions()
				_check(points.size() == expected.size(), "%s must keep its grid dimensions." % path)
				for index in range(expected.size()):
					_check(points[index].is_equal_approx(node.to_global(expected[index])), "%s must preserve point order and use the current global transform." % path)
				node.interaction_area_columns = 1
				node.interaction_area_rows = 1
				_check(node.get_pickup_drop_positions()[0].is_equal_approx(node.to_global(center)), "Runtime configuration edits must take effect without a cache refresh.")
		parent.remove_child(node)
		node.free()
	parent.free()
	if failures == 0:
		print("PASS: grid edge cases, bounds, all eight migrated scripts, nested transforms, reflection and live configuration.")
	quit(0 if failures == 0 else 1)
