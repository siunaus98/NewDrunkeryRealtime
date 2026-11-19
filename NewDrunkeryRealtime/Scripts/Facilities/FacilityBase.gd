extends StaticBody2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const Refs = preload("res://Scripts/Core/LevelRefs.gd")
const Cargo = preload("res://Scripts/Facilities/FacilityItems.gd")
const Aura = preload("res://Scripts/Core/SupportFacilityAuraQuery.gd")
const Boost = preload("res://Scripts/Player/UltimateFacilityBoost.gd")
var facility_type: StringName
var display_name := "设施"
var footprint := Vector2i.ONE
var allows_battle_placement := false
var is_carried := false
var direction := Vector2.RIGHT
var stored: Dictionary = {}
var body_sprite: Sprite2D
var item_sprite: Sprite2D
var status: Label
var work_progress := 0.0
var work_duration := 1.0
var work_frame := -10
var work_player: WeakRef
var collection_amount := 0
var aura_multiplier := 1.0
var work_requires_release := false

func configure(id: StringName, title: String) -> void:
	facility_type = id
	display_name = title

func _ready() -> void:
	for group in ["new_facilities", "movable_facilities", "pickup_drop_targets", "table_facilities", "facility_layout_blockers"]:
		add_to_group(group)
	collision_layer = 4 | 16
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(footprint) * 128.0 - Vector2(16, 16)
	shape.shape = rectangle
	add_child(shape)
	body_sprite = Sprite2D.new()
	body_sprite.texture = load("res://ArtResource/Facilities/%s.svg" % facility_type)
	body_sprite.position.y = -14
	add_child(body_sprite)
	item_sprite = Sprite2D.new()
	item_sprite.position = Vector2(0, -32)
	item_sprite.z_index = 3
	item_sprite.scale = Vector2.ONE * 0.65
	add_child(item_sprite)
	status = Label.new()
	status.position = Vector2(-100, 45)
	status.size.x = 200
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_outline_color", Color("513420"))
	status.add_theme_constant_override("outline_size", 5)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)

func _process(_delta: float) -> void:
	if Engine.get_process_frames() - work_frame > 1 and not preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		work_progress = 0.0
		collection_amount = 0
	if not Input.is_action_pressed(get_hold_interaction_action()):
		work_requires_release = false
	if item_sprite != null:
		item_sprite.visible = not stored.is_empty()
		if not stored.is_empty():
			item_sprite.texture = Cargo.Items.get_world_item_texture(StringName(stored.item_id), stored.get("payload", {}))
			item_sprite.modulate = Cargo.Items.get_item_modulate(StringName(stored.get("process_state", &"")))
	queue_redraw()

func refs() -> Node:
	return Refs.find_from(self)

func is_day() -> bool:
	var reference: Node = refs()
	var flow: Node = reference.get_level_flow_controller() if reference != null else null
	return flow != null and flow.get_current_level_state() in [6, 7, 8]

func active() -> bool:
	return not is_carried and is_visible_in_tree()

func efficiency() -> float:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return 0.0
	return Aura.get_cook_multiplier(get_tree(), global_position) * Boost.get_multiplier(self)

func set_aura_multiplier(multiplier: float) -> void:
	aura_multiplier = maxf(multiplier, 0.01)

func pay(player: Node, amount: int) -> bool:
	if not is_day():
		player.show_hint("营业与备菜期间才能使用")
		return false
	if not player.try_spend_magic(amount):
		player.show_hint("魔力不足 · 需要 %d" % amount)
		return false
	return true

func can_receive_item(_player: Node) -> bool:
	return false

func can_take_item(player: Node) -> bool:
	return not preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self) and active() and not stored.is_empty() and player.can_pick_up_item(StringName(stored.item_id), StringName(stored.get("process_state", &"")), stored.get("payload", {}))

func take_item_to_player(player: Node) -> bool:
	if not can_take_item(player) or not Cargo.give(player, stored):
		return false
	if Cargo.Carry.take_leaves_box(player, StringName(stored.item_id), stored.get("payload", {})):
		stored.payload.servings = int(stored.payload.servings) - 1
	else:
		stored = {}
	return true

func is_pickup_drop_focusable(_player: Node) -> bool:
	return active()

func can_be_moved_by_player(_player: Node) -> bool:
	return active() and work_progress <= 0.0 and not preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self)

func destroy_surface_food() -> void:
	stored = {"item_id": Cargo.Items.DIRTY_PLATE_ID, "payload": {}} if bool(stored.get("payload", {}).get("uses_plate", false)) else {}
	work_progress = 0
	collection_amount = 0

func set_facility_carried(value: bool) -> void:
	is_carried = value
	work_progress = 0.0

func rotate_carried_facility() -> void:
	if facility_type not in [&"portal", &"ballista"]:
		return
	direction = direction.rotated(PI * 0.5).round()
	if facility_type == &"ballista":
		refresh_direction_art()
	else:
		queue_redraw()

func refresh_direction_art() -> void:
	# Bake only on rotation. Both hand and floor previews consume the same
	# Sprite2D texture, including dimensions after a quarter turn.
	var texture: Texture2D = load("res://ArtResource/Facilities/%s.svg" % facility_type)
	var image: Image = texture.get_image()
	var turns := (roundi((direction.angle() + PI * 0.5) / (PI * 0.5)) + 4) % 4
	for index in range(turns):
		image.rotate_90(CLOCKWISE)
	body_sprite.texture = ImageTexture.create_from_image(image)

func get_layout_footprint() -> Vector2i:
	return footprint

func get_pickup_drop_radius() -> float:
	return 150.0

func get_interaction_rect_global() -> Rect2:
	return Rect2(global_position - Vector2(footprint) * 56, Vector2(footprint) * 112)

func set_pickup_drop_highlight(value: bool) -> void:
	body_sprite.modulate = Color(1.2, 1.15, 1.03) if value else Color.WHITE

func get_hold_interaction_action() -> StringName:
	return &"pickup_drop"

func get_interaction_button_prompt(_player: Node) -> String:
	return "J 使用 / K 搬起 / 搬运时 L 转向"

func get_interaction_progress_data(_player: Node) -> Dictionary:
	return {"visible": work_progress > 0.0, "progress": work_progress / maxf(work_duration, 0.01)}

func should_lock_player_movement(_player: Node) -> bool:
	return work_progress > 0.0 and Engine.get_process_frames() - work_frame <= 1

func work(player: Node, delta: float, seconds: float) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		# Retain the attendance marker through this forced pause, so resuming
		# the same task does not discard its accumulated collection progress.
		work_frame = Engine.get_process_frames()
		return false
	if not active() or not can_work_now() or player.is_holding_item():
		return false
	if preload("res://Scripts/Facilities/FacilityControlEffect.gd").rooted(player):
		work_progress = 0.0
		return false
	if player.has_method("is_quicksand_processing_blocked") and player.is_quicksand_processing_blocked():
		work_progress = 0.0
		return false
	var frame := Engine.get_process_frames()
	if frame == work_frame:
		return false
	if work_player == null or work_player.get_ref() != player or frame - work_frame > 1:
		work_progress = 0.0
		work_player = weakref(player)
	work_frame = frame
	work_duration = seconds
	AudioCue.work(self)
	if work_progress <= 0.0 and player.consume_instant_work(&"collect"):
		work_progress = seconds
	else:
		work_progress += delta * player.get_work_progress_multiplier() * efficiency()
	if work_progress < seconds:
		return false
	work_progress = 0.0
	work_requires_release = true
	return true

func can_work_now() -> bool:
	return is_day()

func should_block_player_action(_player: Node) -> bool:
	return work_progress > 0.0 and Engine.get_process_frames() - work_frame <= 1

func reward_collection(player: Node) -> void:
	preload("res://Scripts/Player/UltimateEnergyRules.gd").award(player, &"forage")
	preload("res://Scripts/Player/PlayerWorkEvents.gd").completed(player, &"collect")

func reset_state() -> void:
	# New facilities retain their inventories between days. Only temporary
	# interaction ownership resets; vehicle durability and cargo are persistent.
	work_progress = 0.0
	collection_amount = 0
	work_frame = -10
	work_player = null
	work_requires_release = false

func _draw() -> void:
	if active() and work_progress > 0.0:
		draw_rect(Rect2(-48, -88, 96, 10), Color("513420"))
		draw_rect(Rect2(-46, -86, 92 * clampf(work_progress / maxf(work_duration, 0.01), 0, 1), 6), Color("78d0c4"))
