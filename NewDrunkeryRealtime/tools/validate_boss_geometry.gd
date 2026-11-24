extends SceneTree

const Query = preload("res://Scripts/Player/PlayerAttackTargetQuery.gd")
const Defs = preload("res://Scripts/Enemies/BossGeometryDefs.gd")
var failures: Array[String] = []

class MultiTarget extends Node2D:
	var hits: int = 0
	var centres: Array[Vector2] = []
	func receive_hit(_damage: int, _direction: Vector2) -> void:
		hits += 1
	func get_hurt_regions() -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for centre in centres:
			result.append({"position": global_position + centre, "radius": 25.0})
		return result

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		stop_ticks(child)

func circles_equal(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	for i in a.size():
		if not Vector2(a[i].position).is_equal_approx(b[i].position):
			return false
	return true

func check_art_coverage(boss: CharacterBody2D, kind: String) -> void:
	var texture_image: Image = boss.sprite.texture.get_image()
	texture_image.convert(Image.FORMAT_RGBA8)
	for layer: StringName in [&"body", &"hurt", &"contact"]:
		var regions: Array[Dictionary] = boss.geometry.regions(layer)
		var total := 0
		var covered := 0
		for y in range(0, texture_image.get_height(), 2):
			for x in range(0, texture_image.get_width(), 2):
				if texture_image.get_pixel(x, y).a < 0.5:
					continue
				total += 1
				var local := Vector2(x + .5, y + .5) - Vector2(texture_image.get_size()) * .5
				var point: Vector2 = boss.sprite.to_global(local)
				for region: Dictionary in regions:
					if point.distance_squared_to(region.position) <= float(region.radius) * float(region.radius):
						covered += 1
						break
		var ratio := float(covered) / maxi(total, 1)
		print("ART COVERAGE %s %s: %.1f%%" % [kind, layer, ratio * 100])
		if layer != &"body" or kind == "sandworm":
			check(ratio >= (0.97 if layer == &"hurt" else 0.94), "%s %s must cover the actual opaque silhouette, ratio %.3f" % [kind, layer, ratio])

func check_continuity(boss: CharacterBody2D, kind: String) -> void:
	for layer: StringName in [&"body", &"hurt", &"contact"]:
		var regions: Array[Dictionary] = boss.geometry.regions(layer)
		var reached: Array[int] = [0]
		var cursor := 0
		while cursor < reached.size():
			var a: Dictionary = regions[reached[cursor]]
			for i in regions.size():
				if reached.has(i):
					continue
				var b: Dictionary = regions[i]
				if Vector2(a.position).distance_to(b.position) < float(a.radius) + float(b.radius):
					reached.append(i)
			cursor += 1
		check(reached.size() == regions.size(), "%s %s is one connected individual" % [kind, layer])

func run() -> void:
	var target := MultiTarget.new()
	root.add_child(target)
	target.centres = [Vector2(-60, 0), Vector2(60, 0)]
	var gap := Query.get_target_geometry(target, Vector2.ZERO)
	check(not Query.is_in_attack_geometry(gap, 0, 8, Vector2.RIGHT, PI), "Empty gap between hurt components is not a hit")
	var edge := Query.get_target_geometry(target, Vector2(100, 0))
	check(Query.is_in_attack_geometry(edge, 0, 20, Vector2.LEFT, 0.3), "Outer edge of one component is reachable without reaching the old centre")
	check(Query.circle_intersects_sector(Vector2(48, 18), 10, 0, 80, Vector2.RIGHT, 0.2), "A hurt circle crossing a sector edge can be hit")
	check(not Query.circle_intersects_sector(Vector2(48, 40), 5, 0, 80, Vector2.RIGHT, 0.2), "A circle beyond the sector edge is rejected")
	var visible_part := Query.get_target_geometry(target, Vector2.ZERO)
	check(Query.is_in_attack_geometry(visible_part, 0, 100, Vector2.RIGHT, PI, func(p: Vector2) -> bool: return p.x > 0) and visible_part.position.x > 0, "A reachable body part is selected when another part is across a zone boundary")
	target.queue_free()
	await process_frame
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	stop_ticks(main)
	paused = false
	var actor: Node2D = main.get_node("Player")
	# Exercise real melee dispatch without prototype starting blessings.
	actor.combat_controller.blessing_controller = null
	actor.global_position = Vector2(2400, 1400)
	var multi := MultiTarget.new()
	main.add_child(multi)
	multi.global_position = actor.global_position + actor.combat_controller.attack_origin_offset + Vector2(85, 0)
	multi.centres = [Vector2(-12, 0), Vector2(12, 0)]
	multi.add_to_group("damageables")
	actor.combat_controller._apply_attack_hit({"direction": Vector2.RIGHT, "inner_radius": 0, "outer_radius": 150, "angle_degrees": 100}, func(_point: Vector2) -> bool: return true)
	check(multi.hits == 1, "Real melee hits two overlapping regions only once per target")
	multi.queue_free()
	var exported: Array[Dictionary] = []
	for kind: String in ["sandworm", "scorpion", "vulture", "monitor"]:
		var boss: CharacterBody2D = load("res://Scenes/Enemies/%s_boss.tscn" % kind).instantiate()
		main.add_child(boss)
		stop_ticks(boss)
		boss.global_position = Vector2(8000, 8000)
		boss.state = boss.AttackState.ACTIVE
		boss.impact_remaining = 0
		boss._update_visuals()
		boss.geometry.sync_ground()
		await physics_frame
		boss.movement_bounds = Rect2(7000, 7000, 2000, 2000)
		check_art_coverage(boss, kind)
		check_continuity(boss, kind)
		check(boss.get_node("CollisionShape2D").disabled, "%s legacy circle disabled" % kind)
		check(boss.geometry.body_shapes.size() == Defs.profile(boss.boss_kind).body.size(), "%s uses individual ground components" % kind)
		var hurt: Array[Dictionary] = boss.get_hurt_regions()
		check(hurt.size() > 1, "%s has multiple hurt regions" % kind)
		# Actual physics sweep into a wall at the first component, not only a math test.
		var bodies: Array[Dictionary] = boss.geometry.regions(&"body")
		# Real player collision, including the foot offset and the new mask bit.
		var player_radius: float = boss._player_contact_radius()
		var right_edge := -INF
		var player_foot := Vector2.ZERO
		for circle: Dictionary in bodies:
			var edge_x: float = circle.position.x + circle.radius
			if edge_x > right_edge:
				right_edge = edge_x
				player_foot = circle.position + Vector2(float(circle.radius) + player_radius + 2, 0)
		actor.global_position = player_foot - Vector2(0, 14)
		await physics_frame
		check(actor.test_move(actor.global_transform, Vector2(-12, 0)), "%s ground body blocks actual player movement" % kind)
		check(boss.geometry.point_in_contact(actor.get_sort_origin(), player_radius), "%s touching the solid body can trigger contact damage" % kind)
		var health_before: int = actor.combat_controller.current_health
		actor.combat_controller.contact_immunity_remaining = 0
		boss.contact_cooldown_remaining = 0
		boss._try_contact_damage()
		check(actor.combat_controller.current_health < health_before, "%s real contact damage applies at the player body edge" % kind)
		var after_contact: int = actor.combat_controller.current_health
		boss._try_contact_damage()
		check(actor.combat_controller.current_health == after_contact, "%s contact cooldown prevents repeated same-frame damage" % kind)
		actor.global_position = Vector2(2400, 1400)
		boss.geometry.toggle_debug()
		var debug_on: bool = boss.geometry.debug_visible
		boss.geometry.toggle_debug()
		check(debug_on != boss.geometry.debug_visible, "%s debug overlay toggles" % kind)
		var obstacle := StaticBody2D.new()
		obstacle.collision_layer = 4
		var collider := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(10, 10)
		collider.shape = rect
		obstacle.add_child(collider)
		main.add_child(obstacle)
		obstacle.global_position = bodies[0].position + Vector2(float(bodies[0].radius) + 22, 0)
		await physics_frame
		check(not boss.geometry.motion_clear(boss.global_position, Vector2(50, 0)), "%s landing/path checks see obstacles beside any body component" % kind)
		check(boss.test_move(boss.global_transform, Vector2(50, 0)), "%s actual physics body blocks placed obstacle" % kind)
		obstacle.queue_free()
		await physics_frame
		# Damage and blocking follow the pose; an airborne body has no floor mass.
		var ground_before: Array[Dictionary] = boss.geometry.regions(&"body")
		var hurt_before: Array[Dictionary] = boss.get_hurt_regions()
		boss.sprite.position += Vector2(0, -120)
		boss.state = boss.AttackState.WINDUP
		boss.sprite.scale *= Vector2(1.05, .95)
		boss.geometry.sync_ground()
		check(not circles_equal(ground_before, boss.geometry.regions(&"body")), "%s body collision follows visible displacement" % kind)
		check(not circles_equal(hurt_before, boss.get_hurt_regions()), "%s hurt regions follow visible animation" % kind)
		check(not circles_equal(ground_before, boss.geometry.regions(&"contact")), "%s contact regions follow visible animation" % kind)
		check(not boss.geometry.contact_active(), "%s airborne windup disables old floor contact damage" % kind)
		await process_frame
		check(boss.geometry.body_shapes.all(func(shape: CollisionShape2D) -> bool: return shape.disabled), "%s airborne blocking is disabled" % kind)
		boss.state = boss.AttackState.ACTIVE
		boss.sprite.position = boss.base_sprite_position
		boss.sprite.scale = boss.base_sprite_scale
		boss.geometry.sync_ground()
		await process_frame
		check(boss.geometry.body_shapes.all(func(shape: CollisionShape2D) -> bool: return not shape.disabled), "%s landing restores body blocking" % kind)
		# Exercise the actual displacement animation close to landing, where the
		# old height-only guard could reactivate invisible contact at the origin.
		var displacement: int = boss.Attack.LEAP
		if kind == "vulture":
			displacement = boss.Attack.DIVE
		elif kind == "monitor":
			displacement = boss.Attack.STING
		boss.attack = displacement
		boss.state = boss.AttackState.WINDUP
		boss.attack_target = boss.global_position + Vector2(650, 0)
		boss.windup_total = 1.0
		boss.state_remaining = 0.02
		boss._update_visuals()
		check(not boss.geometry.contact_active(), "%s remains harmless at the old floor position just before landing" % kind)
		var contact_now: Dictionary = boss.geometry.regions(&"contact")[0]
		var expected_center: Vector2 = boss.sprite.to_global(boss.geometry._pixel(boss.geometry.data.contact[0]))
		check(Vector2(contact_now.position).is_equal_approx(expected_center), "%s real displacement contact follows rendered body" % kind)
		await process_frame
		check(boss.geometry.body_shapes.all(func(shape: CollisionShape2D) -> bool: return shape.disabled), "%s real displacement releases starting floor footprint" % kind)
		boss.state = boss.AttackState.ACTIVE
		boss._update_visuals()
		await process_frame
		# A grounded visual offset must damage only the new visible location.
		boss.sprite.position += Vector2(900, 0)
		boss.geometry.sync_ground()
		check(not boss.geometry.point_in_contact(ground_before[0].position, player_radius), "%s old ground location cannot deal ghost contact damage" % kind)
		check(boss.geometry.point_in_contact(boss.geometry.regions(&"contact")[0].position), "%s visible displaced body retains contact damage" % kind)
		boss._update_visuals()
		# The actual player attack must reach heads/claws, outside the floor mass.
		var exposed: Dictionary = boss.get_hurt_regions()[boss.get_hurt_regions().size() - 1]
		if kind == "monitor":
			exposed = boss.get_hurt_regions()[3]
		actor.global_position = exposed.position + Vector2(float(exposed.radius) + 75, 0) - actor.combat_controller.attack_origin_offset
		var boss_health: int = boss.current_health
		var light_damage: int = roundi(actor.combat_controller.get_current_attack_damage() * actor.combat_controller.light_attack_damage_multiplier)
		var multiplier: float = boss.rear_damage_multiplier if kind == "monitor" and boss.is_rear_hit(actor.global_position) else 1.0
		actor.combat_controller._apply_attack_hit({"direction": Vector2.LEFT, "inner_radius": 0, "outer_radius": 145, "angle_degrees": 82}, func(_point: Vector2) -> bool: return true)
		check(boss.current_health == boss_health - roundi(light_damage * multiplier), "%s real melee hits an exposed component exactly once" % kind)
		actor.global_position = Vector2(2400, 1400)
		if kind == "monitor":
			var old_ground: Array[Dictionary] = boss.geometry.regions(&"body")
			boss.facing = Vector2.RIGHT
			boss._update_visuals()
			check(not circles_equal(old_ground, boss.geometry.regions(&"body")), "Monitor grounded footprint rotates with facing")
			var rear: Vector2 = boss.get_hit_position() - boss.facing * 180
			check(boss.is_rear_hit(rear), "Monitor rear weakness stays behind the new pose")
			actor.global_position = boss.get_hit_position() - boss.facing * 165
			boss_health = boss.current_health
			actor.combat_controller._apply_attack_hit({"direction": (boss.get_hit_position() - actor.global_position).normalized(), "inner_radius": 0, "outer_radius": 145, "angle_degrees": 100}, func(_point: Vector2) -> bool: return true)
			check(boss.current_health == boss_health - light_damage * 2, "Monitor actual rear melee still earns exactly one doubled hit")
			actor.global_position = Vector2(2400, 1400)
		if kind == "sandworm":
			# This is the open centre of the authored curved worm, not body.
			var empty: Vector2 = boss.sprite.to_global(boss.geometry._pixel(Vector3(65, 62, 0)))
			check(not boss.geometry.point_in_contact(empty), "Worm curve's empty centre causes no contact damage")
			check(not boss.geometry.swept_contact(empty, Vector2.ZERO, player_radius), "Worm empty centre remains harmless to the player's footprint")
		if kind == "vulture":
			var tip: Vector2 = boss.sprite.to_global(boss.geometry._pixel(Vector3(12, 64, 0)))
			check(boss.geometry.point_in_contact(tip), "Vulture outer wing is included in contact damage")
			actor.global_position = tip - Vector2(0, 14)
			await physics_frame
			check(actor.test_move(actor.global_transform, Vector2(12, 0)), "Vulture outer wing blocks the player")
			check(boss.geometry.point_in_contact(tip, player_radius), "Vulture outer wing contact includes player radius")
		# A fast rush must catch an intermediate point even if neither end overlaps.
		var contact: Dictionary = boss.geometry.regions(&"contact")[0]
		var swept_point: Vector2 = contact.position - Vector2(300, 0)
		check(boss.geometry.swept_contact(swept_point, Vector2(600, 0), player_radius), "%s fast rush sweeps individual contact regions without tunnelling" % kind)
		var json_regions: Dictionary = {}
		for layer: StringName in [&"body", &"hurt", &"contact"]:
			var circles: Array[Dictionary] = []
			for region: Dictionary in boss.geometry.regions(layer):
				var offset: Vector2 = region.position - boss.global_position
				circles.append({"x": offset.x, "y": offset.y, "radius": region.radius})
			json_regions[String(layer)] = circles
		exported.append({"kind": kind, "regions": json_regions, "sprite_transform": [boss.sprite.transform.x.x, boss.sprite.transform.x.y, boss.sprite.transform.y.x, boss.sprite.transform.y.y, boss.sprite.position.x, boss.sprite.position.y]})
		boss.queue_free()
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_artifact_work/boss_geometry"))
	var file := FileAccess.open("res://_artifact_work/boss_geometry/regions.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(exported))
	main.queue_free()
	await process_frame
	print("BOSS GEOMETRY: %d failures; gaps, sector edges, real melee deduplication, physics obstacles, animation, facing and contact" % failures.size())
	quit(0 if failures.is_empty() else 1)
