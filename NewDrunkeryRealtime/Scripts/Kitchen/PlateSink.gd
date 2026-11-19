extends StaticBody2D

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const PlateRack = preload("res://Scripts/Kitchen/PlateRack.gd")
const UltimateBoost = preload("res://Scripts/Player/UltimateFacilityBoost.gd")
const STATION_TEXTURE = preload("res://ArtResource/Kitchen/plate_wash_station.svg")
const WASH_DURATION: float = 5.0
const STARTING_PLATES: int = 3
const WASH_OFFSET: Vector2 = Vector2(64, 0)

var clean_plates: int = STARTING_PLATES
var event_plate_bonus: int = 0
var dirty_plates: int = 0
var wash_progress: float = 0.0
var last_wash_frame: int = -1
var highlighted: bool = false
var is_carried: bool = false
var status_label: Label
var rack: StaticBody2D
var body_sprite: Sprite2D
var dirty_plate_sprite: Sprite2D
var splash_time: float = 0.0
var splash_visible: bool = false

func _process(delta: float) -> void:
	splash_time += delta
	var active: bool = not is_carried and Engine.get_process_frames() - last_wash_frame <= 2 and last_wash_frame >= 0
	if active or splash_visible:
		splash_visible = active
		queue_redraw()

func _draw() -> void:
	if not splash_visible:
		return
	for index in range(6):
		var t: float = fposmod(splash_time * 1.5 + float(index) / 6.0, 1.0)
		var at: Vector2 = WASH_OFFSET + Vector2((float(index) - 2.5) * 10, -24 - sin(t * PI) * 25)
		draw_circle(at, 2.2, Color(0.77, 0.94, 0.91, sin(t * PI) * 0.85))

func _ready() -> void:
	add_to_group("pickup_drop_targets")
	add_to_group("kitchen_resettable")
	add_to_group("facility_layout_blockers")
	add_to_group("movable_facilities")
	add_to_group("table_facilities")
	add_to_group("plate_sinks")
	collision_layer = 4 | 16
	collision_mask = 0
	body_sprite = Sprite2D.new()
	body_sprite.name = "StationSprite"
	body_sprite.texture = STATION_TEXTURE
	body_sprite.position = Vector2(0, -16)
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(body_sprite)
	dirty_plate_sprite = Sprite2D.new()
	dirty_plate_sprite.name = "DirtyPlateSprite"
	dirty_plate_sprite.texture = Items.get_item_texture(Items.DIRTY_PLATE_ID)
	dirty_plate_sprite.position = WASH_OFFSET + Vector2(-12, -26)
	dirty_plate_sprite.scale = Vector2.ONE * 0.68
	add_child(dirty_plate_sprite)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(120, 112)
	shape.shape = rectangle
	shape.position = WASH_OFFSET
	add_child(shape)
	status_label = Label.new()
	status_label.position = WASH_OFFSET + Vector2(-62, 54)
	status_label.size = Vector2(124, 54)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_size_override("font_size", 32)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_color_override("font_outline_color", Color("302217"))
	status_label.add_theme_constant_override("outline_size", 8)
	add_child(status_label)
	rack = PlateRack.new()
	rack.name = "CleanPlateRack"
	rack.position = -WASH_OFFSET
	add_child(rack)
	_refresh()

func can_receive_item(player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return false
	return not is_carried and is_visible_in_tree() and player.get_held_item_id() == Items.DIRTY_PLATE_ID

func receive_item_from_player(player: Node) -> bool:
	if not can_receive_item(player):
		return false
	player.clear_held_item()
	dirty_plates += 1
	_refresh()
	return true

func _can_wash(player: Node) -> bool:
	if is_carried or not is_visible_in_tree() or dirty_plates <= 0 or player.is_holding_item() or not (player is Node2D):
		return false
	if to_local(player.global_position).distance_to(WASH_OFFSET) > 170.0:
		return false
	return not (player.has_method("is_quicksand_processing_blocked") and player.is_quicksand_processing_blocked())

func process_hold_interaction(player: Node, delta: float) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return false
	if not _can_wash(player):
		return false
	# A shared sink cannot advance twice in one frame with two players.
	var frame: int = Engine.get_process_frames()
	if last_wash_frame == frame:
		return false
	last_wash_frame = frame
	var speed: float = float(player.get_work_progress_multiplier()) if player.has_method("get_work_progress_multiplier") else 1.0
	speed *= preload("res://Scripts/Core/SupportFacilityAuraQuery.gd").get_cook_multiplier(get_tree(), global_position)
	speed *= UltimateBoost.get_multiplier(self)
	speed *= preload("res://Scripts/Progression/NightEventEffects.gd").multiplier(self, &"wash")
	if wash_progress <= 0.001 and player.has_method("consume_instant_work") and player.consume_instant_work(&"wash"):
		wash_progress = WASH_DURATION
	else:
		wash_progress = minf(wash_progress + maxf(delta, 0.0) * speed, WASH_DURATION)
	if wash_progress >= WASH_DURATION:
		dirty_plates -= 1
		# Both cells share the finite inventory; the rack renders the restored
		# plate immediately instead of spawning a loose item on the floor.
		clean_plates += 1
		preload("res://Scripts/Player/UltimateEnergyRules.gd").award(player, &"wash")
		preload("res://Scripts/Player/PlayerWorkEvents.gd").completed(player, &"wash")
		wash_progress = 0.0
	_refresh()
	return true

func interact_with_player(player: Node) -> bool:
	return false

func get_hold_interaction_action() -> StringName:
	return &"pickup_drop"

func get_interaction_progress_data(player: Node) -> Dictionary:
	return {"visible": _can_wash(player), "progress": wash_progress / WASH_DURATION}

func is_pickup_drop_focusable(player: Node) -> bool:
	# Unsupported held items still focus the basin so J cannot become a drop.
	return not is_carried and is_visible_in_tree()

func get_interaction_button_prompt(player: Node) -> String:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return ""
	if can_receive_item(player):
		return "J 放入脏盘"
	if not player.is_holding_item() and dirty_plates > 0:
		return "J 按住净化 / K 搬起整套设施"
	return "K 搬起整套设施" if not player.is_holding_item() else ""

func get_pickup_drop_radius() -> float:
	return 150.0

func get_interaction_rect_global() -> Rect2:
	return Rect2(to_global(WASH_OFFSET - Vector2(60, 56)), Vector2(120, 112))

func get_layout_footprint() -> Vector2i:
	return Vector2i(2, 1)

func get_facility_carry_rect_global() -> Rect2:
	return Rect2(global_position - Vector2(124, 56), Vector2(248, 112))

func can_be_moved_by_player(_player: Node) -> bool:
	return not is_carried and is_visible_in_tree() and not preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self)

func set_facility_carried(carried: bool) -> void:
	is_carried = carried
	if rack != null:
		rack.set_pickup_drop_highlight(false)

func get_facility_preview_data() -> Dictionary:
	return {"body_size": Vector2(248, 116), "base_color": Color("b49569"), "accent_color": Color("3d7881"), "outline_color": Color("57432e")}

func set_pickup_drop_highlight(active: bool) -> void:
	highlighted = active
	refresh_highlight()

func refresh_highlight() -> void:
	if body_sprite != null:
		var active: bool = highlighted or (rack != null and rack.highlighted)
		body_sprite.modulate = Color(1.18, 1.14, 1.04) if active else Color.WHITE

func reset_state() -> void:
	clean_plates = STARTING_PLATES + event_plate_bonus
	dirty_plates = 0
	wash_progress = 0.0
	last_wash_frame = -1
	_refresh()

func set_event_plate_bonus(value: int) -> void:
	# Change only the actual plate delta. Moving or reopening cannot mint plates.
	clean_plates += value - event_plate_bonus
	event_plate_bonus = value
	_refresh()

func _refresh() -> void:
	if status_label != null:
		status_label.text = str(dirty_plates)
	if rack != null:
		rack.refresh()
	if dirty_plate_sprite != null:
		dirty_plate_sprite.visible = dirty_plates > 0
