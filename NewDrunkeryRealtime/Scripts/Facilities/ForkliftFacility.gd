extends "res://Scripts/Facilities/FacilityBase.gd"

const CAPACITY := 40
const MAX_HEALTH := 2000
const REPAIR_HEALTH_PER_GOLD := 20
const Contacts = preload("res://Scripts/Facilities/ForkliftContactController.gd")
var health := MAX_HEALTH
var cargo: Dictionary = {}
var driver: Node2D
var saved_player_layer := 1
var saved_player_mask := 0
var harvest_tick := 0.0
var input_released := false
var contacts: RefCounted
var driving_prompt: RefCounted

func _ready() -> void:
	super._ready()
	allows_battle_placement = true
	collision_mask = 1 | 2 | 4 | 8 | 16
	add_to_group("damageables")
	add_to_group("forklifts")
	remove_from_group("movable_facilities")
	contacts = Contacts.new()
	contacts.setup(self)
	driving_prompt = preload("res://Scripts/UI/InteractionPromptView.gd").new()
	driving_prompt.setup(self)

func amount() -> int:
	var total := 0
	for value: int in cargo.values():
		total += value
	return total

func get_repair_cost() -> int:
	return ceili(float(maxi(MAX_HEALTH - health, 0)) / REPAIR_HEALTH_PER_GOLD)

func repair() -> bool:
	if health >= MAX_HEALTH:
		return false
	health = MAX_HEALTH
	return true

func can_be_moved_by_player(_player: Node) -> bool:
	return false

func should_prioritize_hold_interaction(_player: Node) -> bool:
	return true

func get_hold_interaction_action() -> StringName:
	return &"interact"

func can_work_now() -> bool:
	return true

func can_take_item(player: Node) -> bool:
	return active() and driver == null and health > 0 and not player.is_holding_item()

func take_item_to_player(player: Node) -> bool:
	return _start_driving(player)

func interact_with_player(player: Node2D) -> bool:
	return process_hold_interaction(player, get_process_delta_time())

func _start_driving(player: Node2D) -> bool:
	if not can_take_item(player):
		return false
	var reference: Node = refs()
	var map: Node = reference.get_prototype_map() if reference != null else null
	if map == null or not map.is_point_in_battle_zone(player.global_position):
		player.show_hint("请从战斗区一侧上车")
		return false
	driver = player
	saved_player_layer = player.collision_layer
	saved_player_mask = player.collision_mask
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_meta("facility_vehicle", self)
	player.hide()
	input_released = false
	return true

func _process(delta: float) -> void:
	super._process(delta)
	status.text = "%d/%d ♥%d" % [amount(), CAPACITY, health]
	body_sprite.modulate = Color("8b8274") if health <= 0 else Color.WHITE
	driving_prompt.update_prompt("J 下车" if is_instance_valid(driver) else "", -130)

func _physics_process(delta: float) -> void:
	contacts.tick(delta)
	if not is_instance_valid(driver):
		return
	if not driver.input_gate.is_pressed(&"pickup_drop"):
		input_released = true
	if health <= 0 or (input_released and driver.input_gate.is_just_pressed(&"pickup_drop")):
		_try_exit()
		return
	var input: Vector2 = driver.input_gate.get_movement() if driver.window_input_focused else Vector2.ZERO
	var motion: Vector2 = input * driver.move_speed * 1.2 * delta
	if work_progress > 0.0:
		motion = Vector2.ZERO
	var reference: Node = refs()
	var map: Node = reference.get_prototype_map() if reference != null else null
	if map == null or not map.is_point_in_battle_zone(global_position + motion, Vector2(50, 50)):
		motion = Vector2.ZERO
	# StaticBody2D's swept movement retains the same collision protection as
	# carried facilities. The seated player is collision-free and follows it.
	if not motion.is_zero_approx():
		# Forage points are harvestable terrain, not walls for this vehicle.
		var exclusions: Array[PhysicsBody2D] = []
		for point: Node in get_tree().get_nodes_in_group("forage_points"):
			if point is PhysicsBody2D:
				add_collision_exception_with(point)
				exclusions.append(point)
		_move_driven(motion)
		for point: PhysicsBody2D in exclusions:
			remove_collision_exception_with(point)
		direction = input.normalized()
		body_sprite.flip_h = direction.x < 0
	driver.global_position = global_position
	contacts.check_contacts()
	if not is_day():
		return
	harvest_tick -= delta
	if harvest_tick <= 0:
		harvest_tick = 0.15
		for point: Node2D in get_tree().get_nodes_in_group("forage_points"):
			if point.global_position.distance_to(global_position) < 100 and point.has_method("harvest_for_vehicle"):
				var harvested: Dictionary = point.harvest_for_vehicle(CAPACITY - amount())
				for id: StringName in harvested:
					cargo[id] = int(cargo.get(id, 0)) + int(harvested[id])

func _try_exit() -> bool:
	if not is_instance_valid(driver):
		return false
	var reference: Node = refs()
	var map: Node = reference.get_prototype_map() if reference != null else null
	for offset in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
		var candidate: Vector2 = global_position + offset * 112
		if map == null or not map.is_point_in_playable_area(candidate, Vector2(28, 28)):
			continue
		var shape := CircleShape2D.new()
		shape.radius = 28
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform.origin = candidate
		query.collision_mask = 1 | 2 | 4 | 8 | 16
		if not get_world_2d().direct_space_state.intersect_shape(query, 8).is_empty():
			continue
		driver.global_position = candidate
		driver.collision_layer = saved_player_layer
		driver.collision_mask = saved_player_mask
		driver.remove_meta("facility_vehicle")
		driver.show()
		driver.suppress_interaction_input_for_current_frame()
		driver = null
		return true
	return false

func receive_hit(damage: int, _direction: Vector2 = Vector2.ZERO) -> void:
	health = maxi(health - damage, 0)
	if damage > 0:
		AudioCue.at(self, &"hurt", -5.0)

func take_damage(damage: int, hit_direction: Vector2 = Vector2.ZERO, damage_type: StringName = &"special") -> bool:
	if health <= 0:
		return false
	if damage_type == &"contact":
		damage = ceili(float(damage) * 0.5)
	receive_hit(damage, hit_direction)
	return true

func _move_driven(motion: Vector2) -> void:
	# Keep tangential movement when brushing an enemy or a wall. There is no
	# hit pause on the driver; enemy displacement is integrated by contacts.
	for step in range(3):
		var hit := move_and_collide(motion)
		if hit == null:
			return
		contacts.touch(hit.get_collider())
		motion = hit.get_remainder().slide(hit.get_normal())
		if motion.is_zero_approx():
			return

func get_hit_position() -> Vector2:
	return global_position

func get_hit_radius() -> float:
	return 54.0

func reset_state() -> void:
	super.reset_state()
	if driver != null:
		_try_exit()

func process_hold_interaction(player: Node, delta: float) -> bool:
	if work_requires_release:
		return false
	if collection_amount <= 0:
		collection_amount = amount()
	if driver != null or collection_amount <= 0 or not work(player, delta, 0.4 * collection_amount):
		return false
	var reference: Node = refs()
	if reference == null:
		return false
	for id: StringName in cargo:
		reference.get_storage_manager().add_stock(id, int(cargo[id]), &"fresh")
	cargo.clear()
	collection_amount = 0
	reward_collection(player)
	return true

func get_interaction_button_prompt(_player: Node) -> String:
	if health <= 0:
		return "K 按住卸货" if amount() > 0 else ""
	return "J 驾驶 / K 按住卸货" if amount() > 0 else "J 驾驶"
