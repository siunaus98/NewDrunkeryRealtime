extends "res://Scripts/Facilities/FacilityBase.gd"

var partner: Node2D
var transit: Dictionary = {}
var travel_time := 0.0
var remaining := 0.0
var pushed := false
var orb: Sprite2D

func _ready() -> void:
	super._ready()
	add_to_group("item_portals")
	orb = Sprite2D.new()
	orb.texture = load("res://ArtResource/Facilities/transit_orb.svg")
	orb.z_as_relative = false
	orb.z_index = 150
	add_child(orb)
	orb.hide()
	status.text = "出口 →"

func output_at(at: Vector2) -> Vector2:
	return at + direction * 128.0

func output_rect(at: Vector2) -> Rect2:
	return Rect2(output_at(at) - Vector2(63, 63), Vector2(126, 126))

func validate_placement(at: Vector2) -> bool:
	var reference: Node = refs()
	if reference == null:
		return false
	var map: Node = reference.get_prototype_map()
	var output := output_at(at)
	if not map.is_point_in_kitchen_zone(output):
		return false
	var cell: Vector2i = map.get_cell_for_point(output)
	if map.is_cell_reserved_for_fixed_layout(cell, self):
		return false
	return _exit_clear(output, false)

func _exit_clear(at: Vector2, include_units: bool) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(112, 112)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform.origin = at
	query.collision_mask = (1 | 2 | 4 | 8 | 16) if include_units else (4 | 16)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 8).is_empty()

func is_busy() -> bool:
	return not transit.is_empty() or (is_instance_valid(partner) and not partner.transit.is_empty())

func can_be_moved_by_player(player: Node) -> bool:
	return not is_busy() and super.can_be_moved_by_player(player)

func can_receive_item(player: Node) -> bool:
	return active() and is_day() and is_instance_valid(partner) and partner.active() and not is_busy() and player.is_holding_item() and _is_input_side(player)

func _is_input_side(player: Node2D) -> bool:
	return (player.global_position - global_position).normalized().dot(direction) < 0.6

func receive_item_from_player(player: Node) -> bool:
	if not can_receive_item(player) or not pay(player, 1):
		return false
	transit = Cargo.held(player)
	player.clear_held_item()
	travel_time = maxf(1.0, global_position.distance_to(partner.global_position) / 650.0)
	remaining = travel_time
	pushed = false
	orb.show()
	return true

func can_take_item(_player: Node) -> bool:
	return false

func _process(delta: float) -> void:
	super._process(delta)
	if transit.is_empty() or not is_instance_valid(partner):
		return
	if not is_day() or not active() or not partner.active():
		return
	remaining = maxf(remaining - delta, 0.0)
	orb.global_position = global_position.lerp(partner.global_position, clampf(1.0 - remaining / travel_time, 0, 1))
	var exit: Vector2 = partner.output_at(partner.global_position)
	if remaining <= 0.2 and not pushed:
		pushed = true
		for group in ["player", "enemies", "scarab_enemies"]:
			for unit: Node2D in get_tree().get_nodes_in_group(group):
				if unit.global_position.distance_to(exit) > 128:
					continue
				var away := (unit.global_position - exit).normalized()
				if away.is_zero_approx():
					away = partner.direction.orthogonal()
				if unit.has_method("apply_contact_push"):
					unit.apply_contact_push(away, 140)
				elif unit is CharacterBody2D:
					unit.move_and_collide(away * 140)
	if remaining <= 0 and partner._exit_clear(exit, true):
		Cargo.drop(get_parent(), exit, transit)
		AudioCue.at(partner, &"skill", -8.0)
		transit = {}
		orb.hide()
	status.text = "出口受阻" if remaining <= 0 and not transit.is_empty() else "传送中" if not transit.is_empty() else ""

func reset_state() -> void:
	super.reset_state()
	# Transit remains owned by this portal across phase changes; it resumes
	# next day instead of spawning a loose item that setup would delete.

func get_interaction_button_prompt(_player: Node) -> String:
	return "J 从非出口侧传送整件物品 · 1魔力 / K 搬起 / L 转出口"

func _draw() -> void:
	super._draw()
	if active():
		draw_rect(Rect2(direction * 128 - Vector2(60, 60), Vector2(120, 120)), Color(0.35, 0.8, 0.86, 0.3), false, 3)
		draw_line(direction * 28, direction * 86, Color("ffdc76"), 9)
		draw_colored_polygon(PackedVector2Array([direction * 102, direction * 76 + direction.orthogonal() * 14, direction * 76 - direction.orthogonal() * 14]), Color("ffdc76"))
