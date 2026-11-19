extends Node2D

var boss_owner: Node
var target: Node2D
var movement_bounds: Rect2
var radius: float = 150.0
var move_speed: float = 80.0
var lifetime: float = 8.0
var warning_remaining: float = 1.2
var damage: int = 8
var damage_interval: float = 0.75
var slow_multiplier: float = 0.65
var elapsed: float = 0.0
var damage_cooldowns: Dictionary = {}

func _ready() -> void:
	add_to_group("boss_storm_hazards")
	add_to_group("tracking_sandstorms")
	process_physics_priority = -30

func _physics_process(delta: float) -> void:
	if not is_instance_valid(boss_owner) or boss_owner.is_dead or boss_owner.is_queued_for_deletion():
		queue_free()
		return
	if warning_remaining > 0.0:
		warning_remaining = maxf(warning_remaining - delta, 0.0)
		queue_redraw()
		return
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	if is_instance_valid(target) and movement_bounds.has_point(target.global_position):
		var destination := target.global_position.clamp(movement_bounds.position, movement_bounds.end)
		global_position = global_position.move_toward(destination, move_speed * delta)
	for key: int in damage_cooldowns.keys():
		damage_cooldowns[key] = maxf(float(damage_cooldowns[key]) - delta, 0.0)
	for player in get_tree().get_nodes_in_group("player"):
		if not player is Node2D or not movement_bounds.has_point(player.global_position) or global_position.distance_to(player.global_position) > radius:
			continue
		if player.has_method("apply_storm_slow"):
			player.apply_storm_slow(self, slow_multiplier)
		var key := player.get_instance_id()
		if float(damage_cooldowns.get(key, 0.0)) <= 0.0 and player.has_method("take_damage"):
			player.take_damage(damage, Vector2.ZERO, &"sandstorm")
			damage_cooldowns[key] = damage_interval
	queue_redraw()

func _draw() -> void:
	var warning := warning_remaining > 0.0
	draw_circle(Vector2.ZERO, radius, Color(0.74, 0.48, 0.21, 0.12 if warning else 0.3))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color("f9db91"), 4.0, true)
	for i in range(5):
		var angle := elapsed * 2.0 + float(i) * 1.1
		var ring := radius * (0.2 + float(i) * 0.16)
		draw_arc(Vector2.ZERO, ring, angle, angle + PI * 1.5, 32, Color(0.96, 0.76, 0.42, 0.4 if warning else 0.8), 6.0, true)
		var at := Vector2.RIGHT.rotated(angle + 0.7) * ring
		draw_circle(at, 2.5, Color("fff0c3"))
		draw_arc(Vector2(0, -3), ring * 0.92, angle + 0.4, angle + PI, 24, Color(1, 0.91, 0.66, 0.3), 2, true)
