extends RefCounted

const Defs = preload("res://Scripts/Enemies/BossGeometryDefs.gd")

var boss: CharacterBody2D
var data: Dictionary
var body_shapes: Array[CollisionShape2D] = []
var debug_view: Node2D
var debug_visible: bool = false
var debug_layers: Array[StringName] = [&"body", &"hurt", &"contact"]

func setup(host: CharacterBody2D) -> void:
	boss = host
	data = Defs.profile(boss.boss_kind)
	if data.is_empty():
		return
	boss.collision_layer |= 32  # Grounded boss mass, separate from ordinary enemies.
	# Replace the legacy single circle with overlapping silhouette components.
	var old: CollisionShape2D = boss.get_node_or_null("CollisionShape2D")
	if old != null:
		old.disabled = true
	for region: Vector3 in data.body:
		var node := CollisionShape2D.new()
		node.name = "GroundBody%d" % body_shapes.size()
		var circle := CircleShape2D.new()
		circle.radius = _radius(region.z, false)
		node.shape = circle
		boss.add_child(node)
		body_shapes.append(node)
	debug_view = Node2D.new()
	debug_view.name = "BossGeometryOverlay"
	debug_view.z_index = 30
	boss.add_child(debug_view)
	debug_view.draw.connect(_draw_debug)
	debug_visible = bool(boss.get_tree().get_meta("boss_geometry_debug", OS.get_cmdline_user_args().has("--boss-hitboxes")))
	sync_ground()

func _pixel(region: Vector3) -> Vector2:
	var view: Vector2 = data.view
	# SVG's default xMidYMid meet keeps the viewBox aspect and letterboxes.
	var fit: Vector2 = boss.sprite.texture.get_size() / view
	return (Vector2(region.x, region.y) - view * 0.5) * minf(fit.x, fit.y)

func _radius(radius: float, animated: bool) -> float:
	var factor: Vector2 = boss.sprite.texture.get_size() / Vector2(data.view)
	factor = Vector2.ONE * minf(factor.x, factor.y)
	var scale: Vector2 = boss.sprite.global_scale.abs() if animated else boss.global_scale.abs() * boss.base_sprite_scale.abs()
	# Static base scale for blocking; animated scale for visible hurt regions.
	factor *= scale
	return radius * (maxf(factor.x, factor.y) if animated else minf(factor.x, factor.y))

func ground_transform() -> Transform2D:
	var angle: float = boss.sprite.rotation if boss.boss_kind == &"monitor" else 0.0
	return boss.global_transform * Transform2D(angle, boss.base_sprite_scale, 0.0, boss.base_sprite_position)

func sync_ground() -> void:
	if data.is_empty():
		return
	var transform := boss.global_transform.affine_inverse() * ground_transform()
	for i in body_shapes.size():
		body_shapes[i].position = transform * _pixel(data.body[i])
	if debug_view != null:
		debug_view.queue_redraw()

func regions(layer: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if data.is_empty():
		return result
	var animated := layer == &"hurt"
	var transform: Transform2D = boss.sprite.global_transform if animated else ground_transform()
	for circle: Vector3 in data.get(layer, []):
		result.append({"position": transform * _pixel(circle), "radius": _radius(circle.z, animated)})
	return result

func ground_extent() -> Vector2:
	var extent := Vector2.ZERO
	if boss.boss_kind == &"monitor":
		# Reserve the same turning space at every heading. A changing AABB
		# otherwise moves the arena edge underneath the boss while it turns.
		for circle: Vector3 in data.body:
			var center: Vector2 = _pixel(circle) * boss.base_sprite_scale
			var reach := center.length() + _radius(circle.z, false)
			extent = extent.max(Vector2.ONE * reach)
		return extent
	for circle: Dictionary in regions(&"body"):
		var offset: Vector2 = circle.position - boss.global_position
		extent = extent.max(offset.abs() + Vector2.ONE * float(circle.radius))
	return extent

func point_in_contact(point: Vector2, player_radius: float = 0.0) -> bool:
	if not contact_active():
		return false
	for circle: Dictionary in regions(&"contact"):
		var reach: float = float(circle.radius) + player_radius
		if point.distance_squared_to(circle.position) <= reach * reach:
			return true
	return false

func contact_active() -> bool:
	# Animated airborne bodies remain hittable, but cannot damage a player from
	# an invisible old footprint on the ground. Landing skills own their AoE.
	if boss.state != boss.AttackState.WINDUP:
		return true
	if boss.attack == boss.Attack.LEAP or (boss.boss_kind == &"monitor" and boss.attack == boss.Attack.STING):
		return false
	return boss.sprite.position.y >= boss.base_sprite_position.y - 40.0

func swept_contact(point: Vector2, motion: Vector2, player_radius: float = 0.0) -> bool:
	# Sweep each grounded component; never fill empty gaps with one large circle.
	for circle: Dictionary in regions(&"contact"):
		var end: Vector2 = circle.position
		var closest := Geometry2D.get_closest_point_to_segment(point, end - motion, end)
		if point.distance_to(closest) <= float(circle.radius) + player_radius:
			return true
	return false

func motion_clear(from: Vector2, motion: Vector2) -> bool:
	var shift := from - boss.global_position
	for circle: Dictionary in regions(&"body"):
		var shape := CircleShape2D.new()
		shape.radius = float(circle.radius)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.collision_mask = boss.collision_mask
		query.exclude = [boss.get_rid()]
		query.transform = Transform2D(0.0, Vector2(circle.position) + shift)
		query.motion = motion
		var space := boss.get_world_2d().direct_space_state
		if not space.intersect_shape(query, 1).is_empty():
			return false
		if not motion.is_zero_approx() and space.cast_motion(query)[0] < 0.999:
			return false
	return true

func toggle_debug() -> void:
	debug_visible = not debug_visible
	boss.get_tree().set_meta("boss_geometry_debug", debug_visible)
	debug_view.queue_redraw()

func _draw_circles(layer: StringName, color: Color) -> void:
	var circles: Array[Dictionary] = regions(layer)
	for circle: Dictionary in circles:
		var center := debug_view.to_local(circle.position)
		var radius := float(circle.radius) / maxf(debug_view.global_scale.abs().x, 0.001)
		debug_view.draw_circle(center, radius, Color(color, 0.035))
		# Draw only the union boundary, so overlapping components do not hide art.
		for step in range(64):
			var a := TAU * float(step) / 64.0
			var b := TAU * float(step + 1) / 64.0
			var middle: Vector2 = circle.position + Vector2.RIGHT.rotated((a + b) * 0.5) * float(circle.radius)
			var interior := false
			for other: Dictionary in circles:
				if other == circle:
					continue
				if middle.distance_squared_to(other.position) < pow(float(other.radius) - 0.05, 2):
					interior = true
					break
			if not interior:
				debug_view.draw_line(center + Vector2.RIGHT.rotated(a) * radius, center + Vector2.RIGHT.rotated(b) * radius, color, 2.0, true)

func _draw_debug() -> void:
	if not debug_visible:
		return
	if debug_layers.has(&"body"):
		_draw_circles(&"body", Color("54aaff"))
	if debug_layers.has(&"hurt"):
		_draw_circles(&"hurt", Color("72e88c"))
	if debug_layers.has(&"contact") and boss.contact_damage > 0 and contact_active() and boss.contact_cooldown_remaining <= 0:
		_draw_circles(&"contact", Color("ff6d65"))
	# Existing orange skill warnings remain the source of truth for skill AoEs.
