extends RefCounted

## Owns all shared snapshots and gate searches. Scene queries are used only
## during tick, without retaining the host or duplicating its gameplay clock.
const BUILD_BUDGET_USEC: int = 1500
const REFRESH_INTERVAL: float = 1.0

var caches: Dictionary = {}
var next_cache_index: int = 0

func clear() -> void:
	caches.clear()
	next_cache_index = 0

func request_refresh() -> void:
	# Keep the last complete snapshot usable while the replacement is built.
	# This avoids the old clear-and-restart stall when a facility is carried.
	for bounds in caches:
		var cache: Dictionary = caches[bounds]
		cache.updated = -10.0

func get_grid(bounds: Rect2, cell_size: float, grid_size: Vector2i) -> AStarGrid2D:
	if not caches.has(bounds):
		caches[bounds] = {"grid": null, "building": null, "cursor": 0, "size": grid_size, "cell_size": cell_size, "updated": -10.0, "gate_trees": {}}
	return caches[bounds].grid as AStarGrid2D

func get_gate_path(bounds: Rect2, start: Vector2i, gate: Vector2i) -> Array[Vector2i]:
	var cache: Dictionary = caches[bounds]
	if not cache.gate_trees.has(gate):
		# Reverse breadth-first search: every reachable cell points one step
		# closer to this gate. All incoming scarabs share the same search.
		cache.gate_trees[gate] = {"queue": [gate], "cursor": 0, "next": {gate: gate}, "complete": false}
	var tree: Dictionary = cache.gate_trees[gate]
	if not tree.next.has(start):
		return []
	var path: Array[Vector2i] = [start]
	var cell := start
	while cell != gate:
		cell = tree.next[cell]
		path.append(cell)
	return path

func _tick_gate_searches(cache: Dictionary, deadline: int) -> void:
	var grid := cache.grid as AStarGrid2D
	if grid == null:
		return
	for gate: Vector2i in cache.gate_trees:
		var tree: Dictionary = cache.gate_trees[gate]
		while tree.cursor < tree.queue.size() and Time.get_ticks_usec() < deadline:
			var cell: Vector2i = tree.queue[tree.cursor]
			tree.cursor += 1
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor := cell + direction
				if grid.region.has_point(neighbor) and not grid.is_point_solid(neighbor) and not tree.next.has(neighbor):
					tree.next[neighbor] = cell
					tree.queue.append(neighbor)
		if tree.cursor == tree.queue.size():
			tree.complete = true
		if Time.get_ticks_usec() >= deadline:
			return

func tick(navigation_clock: float, is_walkable: Callable, snapshot_ready: Callable) -> void:
	# Share collision snapshots across all scarabs and all target approaches.
	# Build in small slices instead of scanning thousands of cells in one frame.
	var deadline := Time.get_ticks_usec() + BUILD_BUDGET_USEC
	var bounds_list: Array = caches.keys()
	var first_index := next_cache_index
	for offset in range(bounds_list.size()):
		var index := (first_index + offset) % bounds_list.size()
		var bounds: Rect2 = bounds_list[index]
		# Resume with the next region when this one exhausts the shared budget.
		# Kitchen refreshes must not starve the first cross-region snapshot.
		next_cache_index = (index + 1) % bounds_list.size()
		var cache: Dictionary = caches[bounds]
		_tick_gate_searches(cache, deadline)
		if Time.get_ticks_usec() >= deadline:
			break
		if cache.building == null:
			if navigation_clock - float(cache.updated) < REFRESH_INTERVAL:
				continue
			var grid := AStarGrid2D.new()
			grid.region = Rect2i(Vector2i.ZERO, cache.size)
			grid.cell_size = Vector2.ONE * float(cache.cell_size)
			grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
			grid.update()
			cache.building = grid
			cache.cursor = 0
		var count: int = cache.size.x * cache.size.y
		while cache.cursor < count and Time.get_ticks_usec() < deadline:
			var cell := Vector2i(int(cache.cursor) % cache.size.x, int(cache.cursor) / cache.size.x)
			var point := bounds.position + (Vector2(cell) + Vector2(0.5, 0.5)) * float(cache.cell_size)
			cache.building.set_point_solid(cell, not bool(is_walkable.call(point, null)))
			cache.cursor += 1
		if cache.cursor == count:
			cache.grid = cache.building
			cache.building = null
			cache.updated = navigation_clock
			# Rebuild gate routes against the new obstacle snapshot, not stale
			# walls or forage points. Actors keep moving on their current routes.
			cache.gate_trees.clear()
			snapshot_ready.call(bounds, cache.grid, cache.cell_size, cache.size)
		if Time.get_ticks_usec() >= deadline:
			break

