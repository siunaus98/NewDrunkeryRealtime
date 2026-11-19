extends RefCounted

const Wave = preload("res://Scripts/Hazards/SandstormWave.gd")
const Cyclone = preload("res://Scripts/Hazards/TrackingSandstorm.gd")
const PRESSURE_DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

var boss: CharacterBody2D
var pressure_remaining: float = 7.0
var pressure_interval: float = 20.0
var rng := RandomNumberGenerator.new()

func setup(host: CharacterBody2D) -> void:
	boss = host
	rng.randomize()

func tick_pressure(delta: float) -> void:
	if boss.level_refs == null or not is_instance_valid(boss.prototype_map):
		return
	var controller: Node = boss.level_refs.get_wind_sand_mechanism_controller()
	if controller == null or not controller.active:
		return
	pressure_remaining = maxf(pressure_remaining - delta, 0.0)
	if pressure_remaining > 0.0:
		return
	var kitchen: Rect2 = boss.prototype_map.get_kitchen_zone_bounds()
	var tile: Vector2 = boss.prototype_map.get_tile_size()
	# Use the actual canvas transform, including camera offset and zoom. The
	# entire front must begin beyond both playable land and the current view.
	var visible_bounds: Rect2 = boss.get_canvas_transform().affine_inverse() * boss.get_viewport_rect()
	var outer_bounds: Rect2 = boss.prototype_map.get_world_bounds().merge(visible_bounds)
	for _index in range(2):
		_spawn_pressure_wave(kitchen, outer_bounds, tile)
	pressure_remaining = pressure_interval

func _spawn_pressure_wave(kitchen: Rect2, outer_bounds: Rect2, tile: Vector2) -> void:
	var heading: Vector2 = PRESSURE_DIRECTIONS[rng.randi_range(0, PRESSURE_DIRECTIONS.size() - 1)]
	var vertical := heading.y != 0.0
	var width := (tile.x if vertical else tile.y) * 2.0
	var lane_min := kitchen.position.x if vertical else kitchen.position.y
	var lane_size := kitchen.size.x if vertical else kitchen.size.y
	var inset := minf(width * 0.5, lane_size * 0.5)
	var lane := rng.randf_range(lane_min + inset, lane_min + lane_size - inset)
	var outside := outer_bounds.grow(rng.randf_range(256.0, 512.0))
	var start: Vector2
	if vertical:
		start = Vector2(lane, outside.position.y if heading.y > 0.0 else outside.end.y)
	else:
		start = Vector2(outside.position.x if heading.x > 0.0 else outside.end.x, lane)
	# Approach travel replaces the ground warning. Keep travelling past the
	# far map/view edge so the front never vanishes inside the playable area.
	spawn_wave(start, heading, width, outside.size.y if vertical else outside.size.x, 0.0)

func prepare() -> void:
	match boss.attack:
		boss.Attack.GUST:
			boss.windup_total = 1.2
		boss.Attack.DIVE:
			boss.attack_target = boss._leap_target(boss.attack_direction, boss.attack_origin.distance_to(boss.attack_target), 600.0)
			boss.windup_total = 1.2
		boss.Attack.CYCLONE:
			boss.windup_total = 1.2

func resolve() -> void:
	match boss.attack:
		boss.Attack.GUST:
			var tile: Vector2 = boss.prototype_map.get_tile_size() if is_instance_valid(boss.prototype_map) else Vector2(128, 128)
			spawn_wave(boss.attack_origin, boss.attack_direction, tile.x, 1400.0, 0.0)
		boss.Attack.DIVE:
			boss.global_position = boss.attack_target
			if boss._player_in_arena() and boss._player_point().distance_to(boss.attack_target) <= boss.leap_radius:
				var outward: Vector2 = boss._player_point() - boss.attack_target
				if outward.is_zero_approx():
					outward = boss.attack_direction
				if boss._damage_player(boss.skill_damage, outward.normalized()) and boss.player.has_method("apply_contact_push"):
					boss.player.apply_contact_push(outward, 160.0)
			boss.impact_remaining = 0.5
		boss.Attack.CYCLONE:
			for existing in boss.get_tree().get_nodes_in_group("tracking_sandstorms"):
				if existing.boss_owner == boss:
					existing.queue_free()
			var storm := Cyclone.new()
			storm.boss_owner = boss
			storm.target = boss.player
			storm.movement_bounds = boss.movement_bounds
			# The boss's locked ground warning already covered the full delay.
			storm.warning_remaining = 0.0
			storm.position = boss.get_parent().to_local(boss.attack_target)
			boss.get_parent().add_child(storm)

func spawn_wave(point: Vector2, heading: Vector2, width: float, distance: float, warning: float) -> Node2D:
	var wave := Wave.new()
	wave.boss_owner = boss
	wave.direction = heading.normalized()
	wave.width = width
	wave.travel_distance = distance
	wave.warning_duration = warning
	wave.position = boss.get_parent().to_local(point)
	boss.get_parent().add_child(wave)
	return wave

func update_visuals() -> void:
	if boss.state != boss.AttackState.WINDUP:
		return
	var progress := clampf(1.0 - boss.state_remaining / boss.windup_total, 0.0, 1.0)
	if boss.attack == boss.Attack.DIVE:
		boss.sprite.position += (boss.attack_target - boss.global_position) * progress + Vector2.UP * sin(progress * PI) * 150.0
		boss.sprite.rotation = sin(progress * PI) * boss.attack_direction.x * 0.3
	else:
		boss.sprite.scale *= Vector2(1.0 + sin(progress * PI) * 0.22, 1.0 - sin(progress * PI) * 0.12)
		boss.sprite.position.y -= sin(progress * PI) * 30.0

func draw_warning() -> void:
	var winding: bool = boss.state == boss.AttackState.WINDUP
	if not winding and boss.impact_remaining <= 0.0:
		return
	var gold := Color("f9db91")
	var target: Vector2 = boss.to_local(boss.attack_target)
	if boss.attack == boss.Attack.GUST and winding:
		var origin: Vector2 = boss.to_local(boss.attack_origin)
		var tile: Vector2 = boss.prototype_map.get_tile_size() if is_instance_valid(boss.prototype_map) else Vector2(128, 128)
		var side: Vector2 = boss.attack_direction.orthogonal() * tile.x * 0.5
		var end: Vector2 = origin + boss.attack_direction * 1400.0
		boss.draw_colored_polygon(PackedVector2Array([origin - side, origin + side, end + side, end - side]), Color(0.95, 0.65, 0.2, 0.15))
		boss.draw_line(origin - side, end - side, gold, 3.0)
		boss.draw_line(origin + side, end + side, gold, 3.0)
		for i in range(1, 10):
			var tip: Vector2 = origin + boss.attack_direction * i * 140.0
			boss.draw_polyline(PackedVector2Array([tip - boss.attack_direction * 22.0 - side * 0.3, tip, tip - boss.attack_direction * 22.0 + side * 0.3]), gold, 4.0)
	elif boss.attack in [boss.Attack.DIVE, boss.Attack.CYCLONE]:
		var radius: float = boss.leap_radius if boss.attack == boss.Attack.DIVE else 150.0
		boss.draw_circle(target, radius, Color(0.95, 0.65, 0.2, 0.18))
		boss.draw_arc(target, radius, 0.0, TAU, 48, gold, 4.0, true)
		if winding:
			var progress: float = 1.0 - boss.state_remaining / boss.windup_total
			boss.draw_arc(target, radius * (1.0 - 0.8 * progress), 0.0, TAU, 48, gold, 4.0, true)
		else:
			boss.draw_arc(target, radius * (1.0 - boss.impact_remaining / 0.5), 0.0, TAU, 48, gold, 12.0, true)
