extends SceneTree

const NavigationCache = preload("res://Scripts/Core/ScarabNavigationCache.gd")
var failures: Array[String] = []
var blocked: bool = false
var slow_probe: bool = false
var probes: int = 0
var publications: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _walkable(point: Vector2, _actor: Node2D) -> bool:
	probes += 1
	# Force a slice boundary independently of machine speed.
	if slow_probe:
		OS.delay_usec(2000)
	return not blocked or int(point.x / 64.0) != 1

func _published(_bounds: Rect2, _grid: AStarGrid2D, _cell_size: float, _size: Vector2i) -> void:
	publications += 1

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var navigation := NavigationCache.new()
	var bounds := Rect2(0, 0, 256, 192)
	var size := Vector2i(4, 3)
	_check(navigation.get_grid(bounds, 64.0, size) == null and probes == 0, "Requesting a missing grid must schedule it without synchronous scanning.")
	slow_probe = true
	navigation.tick(0.0, _walkable, _published)
	_check(probes == 1 and publications == 0 and navigation.get_grid(bounds, 64.0, size) == null, "An unfinished first slice must never publish a partial grid.")
	slow_probe = false
	for frame in range(20):
		navigation.tick(0.0, _walkable, _published)
		if publications == 1:
			break
	var first: AStarGrid2D = navigation.get_grid(bounds, 64.0, size)
	_check(first != null and publications == 1, "A completed snapshot must publish once.")
	if first == null:
		quit(1)
		return
	var probe_count: int = probes
	_check(navigation.get_grid(bounds, 64.0, size) == first, "Actors requesting the same bounds must share the grid.")
	navigation.tick(0.99, _walkable, _published)
	_check(probes == probe_count, "Collision snapshots must not rebuild before the one-second refresh interval.")
	var gate := Vector2i(0, 1)
	var start := Vector2i(3, 1)
	navigation.get_gate_path(bounds, start, gate)
	for frame in range(20):
		navigation.tick(0.99, _walkable, _published)
		if not navigation.get_gate_path(bounds, start, gate).is_empty():
			break
	var route: Array[Vector2i] = navigation.get_gate_path(bounds, start, gate)
	_check(not route.is_empty() and route.front() == start and route.back() == gate, "Reverse search must lead each actor to the shared gate.")
	navigation.get_gate_path(bounds, Vector2i(2, 2), gate)
	_check(navigation.caches[bounds].gate_trees.size() == 1, "Different actors must reuse the same gate tree.")
	blocked = true
	slow_probe = true
	navigation.tick(1.0, _walkable, _published)
	_check(navigation.get_grid(bounds, 64.0, size) == first and publications == 1, "Actors must retain the old complete snapshot while its replacement is built.")
	_check(not navigation.get_gate_path(bounds, start, gate).is_empty(), "Existing gate routes must remain available until replacement publication.")
	slow_probe = false
	for frame in range(20):
		navigation.tick(1.0, _walkable, _published)
		if publications == 2:
			break
	var second: AStarGrid2D = navigation.get_grid(bounds, 64.0, size)
	_check(second != first and second.is_point_solid(Vector2i(1, 1)), "Replacement must contain the changed obstacle.")
	_check(navigation.caches[bounds].gate_trees.is_empty(), "Publishing a changed snapshot must invalidate old gate trees.")
	navigation.get_gate_path(bounds, start, gate)
	for frame in range(20):
		navigation.tick(1.1, _walkable, _published)
	_check(navigation.get_gate_path(bounds, start, gate).is_empty(), "Rebuilt gate search must not cross the new wall.")
	var other_bounds := Rect2(512, 0, 256, 192)
	navigation.get_grid(other_bounds, 64.0, size)
	_check(navigation.caches.size() == 2, "Kitchen and cross-region bounds must remain separate snapshots.")
	navigation.clear()
	_check(navigation.caches.is_empty(), "Business cleanup must remove published grids, pending work and gate trees.")
	_check(navigation.get_grid(bounds, 64.0, size) == null, "A new business must start with no old snapshot.")
	# Each slow probe exhausts the entire frame budget. Both regions must
	# still make progress even while the first keeps requesting refreshes.
	navigation.get_grid(other_bounds, 64.0, size)
	slow_probe = true
	navigation.tick(0.0, _walkable, _published)
	navigation.tick(2.0, _walkable, _published)
	_check(navigation.caches[bounds].cursor == 1 and navigation.caches[other_bounds].cursor == 1, "A busy first region must give the second region the next slice.")
	for frame in range(2, 24):
		navigation.tick(float(frame) * 2.0, _walkable, _published)
	_check(navigation.get_grid(bounds, 64.0, size) != null and navigation.get_grid(other_bounds, 64.0, size) != null, "Both first snapshots must complete under sustained slow queries.")
	navigation.clear()
	if failures.is_empty():
		print("PASS: shared grids, fair sliced builds, atomic replacement, refresh interval, shared gate routes, obstacle invalidation and cleanup/restart.")
	quit(0 if failures.is_empty() else 1)
