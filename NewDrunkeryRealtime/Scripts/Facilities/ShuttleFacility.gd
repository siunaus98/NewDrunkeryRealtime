extends "res://Scripts/Facilities/FacilityBase.gd"

var partner: Node2D
var cargo: Array[Dictionary] = []
var destination: Node2D
var departure: Node2D
var cart: Sprite2D
var progress := 0.0
var journey_seconds := 1.0
var cart_here := true
var cargo_icons: Array[Sprite2D] = []

func _ready() -> void:
	super._ready()
	add_to_group("shuttle_endpoints")
	cart = Sprite2D.new()
	cart.texture = load("res://ArtResource/Facilities/shuttle_cart.svg")
	cart.position.y = -20
	cart.z_index = 10
	add_child(cart)
	cart.hide()
	for index in range(3):
		var icon := Sprite2D.new()
		icon.position = Vector2((index - 1) * 30, -32)
		icon.scale = Vector2.ONE * 0.3
		add_child(icon)
		cargo_icons.append(icon)

func owner_endpoint() -> Node2D:
	return self if not cargo.is_empty() or not is_instance_valid(partner) else partner

func can_be_moved_by_player(player: Node) -> bool:
	return destination == null and (not is_instance_valid(partner) or partner.destination == null) and super.can_be_moved_by_player(player)

func can_receive_item(player: Node) -> bool:
	if not active() or not is_instance_valid(partner) or not partner.active() or not is_day():
		return false
	var owner: Node2D = owner_endpoint()
	return cart_here and destination == null and partner.destination == null and (owner == self or partner.cargo.is_empty()) and cargo.size() < 3 and Cargo.transportable(Cargo.held(player))

func receive_item_from_player(player: Node) -> bool:
	if not can_receive_item(player):
		return false
	cargo.append(Cargo.held(player))
	player.clear_held_item()
	return true

func can_take_item(player: Node) -> bool:
	if not active() or destination != null or cargo.is_empty():
		return false
	var item: Dictionary = cargo.back()
	return player.can_pick_up_item(StringName(item.item_id), StringName(item.get("process_state", &"")), item.get("payload", {}))

func take_item_to_player(player: Node) -> bool:
	if not can_take_item(player) or not Cargo.give(player, cargo.back()):
		return false
	var item: Dictionary = cargo.back()
	if Cargo.Carry.take_leaves_box(player, StringName(item.item_id), item.get("payload", {})):
		item.payload.servings = int(item.payload.servings) - 1
	else:
		cargo.pop_back()
	return true

func should_prioritize_hold_interaction(_player: Node) -> bool:
	return is_day() and destination == null and is_instance_valid(partner) and (not cargo.is_empty() or not cart_here)

func interact_with_player(player: Node) -> bool:
	if not cart_here and is_instance_valid(partner) and partner.cart_here:
		return partner.interact_with_player(player)
	if not cart_here or destination != null or not is_instance_valid(partner) or not partner.active() or not is_day():
		return false
	var reference: Node = refs()
	var map: Node = reference.get_prototype_map() if reference != null else null
	if map == null or map.is_segment_blocked_by_dune_wall(global_position, partner.global_position):
		player.show_hint("轨道不能穿越沙丘，请重新摆放端点")
		return false
	# Fixed departure sample: moving the lamp mid-journey cannot change speed.
	journey_seconds = maxf(global_position.distance_to(partner.global_position) / (900.0 * efficiency()), 0.3)
	destination = partner
	cart_here = false
	partner.cart_here = false
	departure = self
	progress = 0.0
	cart.show()
	return true

func _process(delta: float) -> void:
	super._process(delta)
	status.text = "%d/3" % cargo.size()
	if destination == null:
		cart.visible = cart_here
		cart.position = Vector2(0, -20)
	for index in range(cargo_icons.size()):
		cargo_icons[index].visible = index < cargo.size() and destination == null
		if index < cargo.size():
			cargo_icons[index].texture = Cargo.Items.get_world_item_texture(StringName(cargo[index].item_id), cargo[index].get("payload", {}))
	if destination != null and is_instance_valid(destination) and is_day():
		progress = minf(progress + delta / journey_seconds, 1)
		cart.global_position = global_position.lerp(destination.global_position, progress) + Vector2(0, -20)
		if progress >= 1:
			destination.cargo.assign(cargo)
			destination.cart_here = true
			cargo.clear()
			destination = null
			cart.hide()
	queue_redraw()

func _draw() -> void:
	super._draw()
	if active() and is_instance_valid(partner) and partner.active():
		var endpoint := to_local(partner.global_position)
		draw_line(Vector2.ZERO, endpoint, Color("513420"), 9)
		draw_line(Vector2.ZERO, endpoint, Color("c9ac77"), 4)

func get_interaction_button_prompt(_player: Node) -> String:
	return "J 装卸 · 最多3件 / K 发车（空车K搬起）"
