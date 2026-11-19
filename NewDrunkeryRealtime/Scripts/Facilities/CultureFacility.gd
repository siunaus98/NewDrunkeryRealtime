extends "res://Scripts/Facilities/FacilityBase.gd"

const CAPACITY := 12
const GROW_SECONDS := 25.0
var seed: StringName = &""
var stock := 0
var growth := 0.0

func _ready() -> void:
	super._ready()
	add_to_group("production_facilities")

func _process(delta: float) -> void:
	super._process(delta)
	if active() and is_day() and seed != &"" and stock < CAPACITY:
		growth += delta * efficiency()
		while growth >= GROW_SECONDS and stock < CAPACITY:
			growth -= GROW_SECONDS
			stock += 1
	status.text = "%d/%d" % [stock, CAPACITY]

func can_receive_item(player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return false
	var id: StringName = player.get_held_item_id()
	return active() and seed == &"" and Cargo.Items.is_ingredient(id) and not Cargo.Items.is_boss_ingredient(id) and id not in [&"meat_red", &"meat_white", &"sand_hare", &"camel_meat"] and Cargo.Items.is_raw_state(player.get_held_item_process_state())

func receive_item_from_player(player: Node) -> bool:
	if not can_receive_item(player):
		return false
	seed = player.get_held_item_id()
	stored = Cargo.held(player)
	player.clear_held_item()
	return true

func can_take_item(_player: Node) -> bool:
	return false

func destroy_surface_food() -> void:
	# The planted seed stays inside the machine; only the harvest is spoiled.
	stock = 0
	work_progress = 0
	collection_amount = 0

func process_hold_interaction(player: Node, delta: float) -> bool:
	if work_requires_release:
		return false
	if collection_amount <= 0:
		collection_amount = stock
	if collection_amount <= 0 or not work(player, delta, 0.6 * collection_amount):
		return false
	var reference: Node = refs()
	if reference == null:
		return false
	reference.get_storage_manager().add_stock(seed, collection_amount, &"fresh")
	stock -= collection_amount
	collection_amount = 0
	reward_collection(player)
	return true

func get_interaction_button_prompt(player: Node) -> String:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return ""
	if seed == &"":
		return "J 放入种子 / K 搬起"
	if stock > 0 and not player.is_holding_item():
		return "J 按住收集 / K 搬起"
	return "K 搬起"

func get_growth_progress() -> float:
	return clampf(growth / GROW_SECONDS, 0.0, 1.0)

func _draw() -> void:
	super._draw()
	if not active() or seed == &"" or stock >= CAPACITY:
		return
	# Production is visible even when nobody is interacting; collection keeps
	# its own separate bar above the facility.
	draw_rect(Rect2(-48, 76, 96, 12), Color("513420"))
	draw_rect(Rect2(-46, 78, 92 * get_growth_progress(), 8), Color("78d0c4"))
