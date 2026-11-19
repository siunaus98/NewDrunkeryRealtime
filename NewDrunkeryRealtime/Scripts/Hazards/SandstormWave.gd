extends Node2D

var boss_owner: Node
var direction: Vector2 = Vector2.DOWN
var width: float = 256.0
var thickness: float = 56.0
var speed: float = 288.0
var travel_distance: float = 1500.0
var warning_duration: float = 1.5
var launch_distance: float = 620.0
var crash_damage: int = 35
var crash_stun: float = 2.0
var warning_remaining: float = 0.0
var travelled: float = 0.0
var hit_players: Dictionary = {}

func _ready() -> void:
	add_to_group("boss_storm_hazards")
	process_physics_priority = -30
	warning_remaining = warning_duration

func _physics_process(delta: float) -> void:
	if not is_instance_valid(boss_owner) or boss_owner.is_dead or boss_owner.is_queued_for_deletion():
		queue_free()
		return
	if warning_remaining > 0.0:
		warning_remaining = maxf(warning_remaining - delta, 0.0)
		queue_redraw()
		return
	var step := minf(speed * delta, travel_distance - travelled)
	var previous := global_position
	global_position += direction * step
	travelled += step
	for player in get_tree().get_nodes_in_group("player"):
		if not player is Node2D or not player.has_method("apply_storm_launch") or hit_players.has(player.get_instance_id()):
			continue
		# Sweeping the full front avoids tunnelling at low frame rates.
		var offset: Vector2 = player.global_position - previous
		if absf(offset.dot(direction.orthogonal())) <= width * 0.5 + 18.0 and offset.dot(direction) >= -thickness * 0.5 - 18.0 and offset.dot(direction) <= step + thickness * 0.5 + 18.0:
			hit_players[player.get_instance_id()] = true
			player.apply_storm_launch(direction, launch_distance, crash_damage, crash_stun, boss_owner)
	if travelled >= travel_distance:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var side := direction.orthogonal() * width * 0.5
	var gold := Color("f9db91")
	if warning_remaining > 0.0:
		var end := direction * travel_distance
		draw_colored_polygon(PackedVector2Array([-side, side, end + side, end - side]), Color(0.95, 0.65, 0.2, 0.12))
		draw_line(-side, end - side, gold, 3.0)
		draw_line(side, end + side, gold, 3.0)
		for i in range(1, int(travel_distance / 120.0)):
			var tip := direction * float(i) * 120.0
			draw_polyline(PackedVector2Array([tip - direction * 22.0 - direction.orthogonal() * 20.0, tip, tip - direction * 22.0 + direction.orthogonal() * 20.0]), gold, 4.0, true)
	else:
		var depth := direction * thickness * 0.5
		draw_colored_polygon(PackedVector2Array([-side - depth, side - depth, side + depth, -side + depth]), Color(0.8, 0.53, 0.23, 0.8))
		for i in range(4):
			var offset := direction * (float(i) - 1.5) * thickness / 4.0
			draw_line(-side + offset, side + offset, gold.darkened(float(i) * 0.13), 6.0, true)
		for i in range(7):
			var center := side * lerpf(-0.9, 0.9, float(i) / 6.0)
			draw_arc(center, 14.0, travelled / 40.0, travelled / 40.0 + PI * 1.5, 14, gold, 3.0, true)
