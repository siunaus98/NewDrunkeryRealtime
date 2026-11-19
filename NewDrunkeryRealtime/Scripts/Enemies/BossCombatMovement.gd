extends RefCounted

## Steering only during normal action. Skill tells, recovery and special
## movement keep their own rules; no navigation rebuilds or per-frame RNG.
var orbit_side := 1.0
var blocked_time := 0.0
var turn_cooldown := 0.0

func _init() -> void:
	orbit_side = -1.0 if randf() < 0.5 else 1.0

func target(boss: CharacterBody2D, player_point: Vector2, delta: float) -> Vector2:
	turn_cooldown = maxf(turn_cooldown - delta, 0.0)
	# Orbit the nearest reachable point when a player hugs the outer walls;
	# circling an out-of-bounds center can clamp both goals to one corner.
	player_point = boss._safe_arena_point(player_point)
	var offset := boss.global_position - player_point
	var spacing: float = boss.combat_spacing
	if offset.length() > spacing + 150.0:
		return boss._safe_arena_point(player_point)
	var radial := offset.normalized() if not offset.is_zero_approx() else Vector2.UP
	var goal: Vector2 = boss._safe_arena_point(player_point + radial.rotated(orbit_side * 0.8) * spacing)
	if goal.distance_to(boss.global_position) < 24.0 or (blocked_time >= 0.3 and turn_cooldown <= 0):
		orbit_side *= -1.0
		blocked_time = 0
		turn_cooldown = 1.0
		goal = boss._safe_arena_point(player_point + radial.rotated(orbit_side * 0.8) * spacing)
	return goal

func report_motion(requested: Vector2, actual: Vector2, delta: float) -> void:
	if requested.length() > 0.01 and actual.length() < requested.length() * 0.2:
		blocked_time += delta
	else:
		blocked_time = 0.0
