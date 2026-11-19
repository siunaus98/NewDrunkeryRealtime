extends RefCounted

## Statues travel to a collision-checked arena entrance, never to the boss's
## body. A crowded entrance fails without moving the player or carried items.
static func current_boss(statue: Node) -> Node2D:
	var flow: Node = statue.level_flow_controller
	if flow == null or flow.get_current_level_state() not in [6, 7, 8]:
		return null
	for boss: Node2D in statue.get_tree().get_nodes_in_group("bosses"):
		if not boss.is_dead:
			return boss
	return null

static func travel(statue: Node, player: CharacterBody2D) -> bool:
	var boss := current_boss(statue)
	if boss == null:
		return false
	if player.is_carrying_facility():
		player.show_hint("放下设施后再传送")
		return false
	var bounds: Rect2 = boss.get_movement_bounds()
	var body: CollisionShape2D = player.get_node("CollisionShape2D")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body.shape
	query.collision_mask = 1 | 2 | 4 | 8 | 16
	query.exclude = [player.get_rid()]
	var landing := Vector2.INF
	for row in range(6):
		for column in [0, -1, 1, -2, 2, -3, 3]:
			var candidate := Vector2(bounds.get_center().x + column * 72.0, bounds.end.y - 190.0 - row * 64.0)
			query.transform = body.global_transform
			query.transform.origin += candidate - player.global_position
			if bounds.grow(-130).has_point(candidate) and player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				landing = candidate
				break
		if landing != Vector2.INF:
			break
	if landing == Vector2.INF:
		player.show_hint("战斗区入口被占据，暂时无法传送")
		return false
	player.clear_hostile_control()
	player.combat_controller.dash_time_remaining = 0
	player.velocity = Vector2.ZERO
	player.global_position = landing
	player.push_controller.last_playable_position = landing
	player.show_hint("已抵达BOSS战斗区")
	return true
