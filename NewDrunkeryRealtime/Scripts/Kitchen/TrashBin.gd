extends StaticBody2D

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Carry = preload("res://Scripts/Kitchen/CarryItemRules.gd")
const BIN_TEXTURE = preload("res://ArtResource/Kitchen/trash_bin.svg")
var is_carried: bool = false
var body_sprite: Sprite2D

func _ready() -> void:
	for group: String in ["pickup_drop_targets", "movable_facilities", "table_facilities", "facility_layout_blockers"]:
		add_to_group(group)
	collision_layer = 4 | 16
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(104, 112)
	shape.shape = rectangle
	add_child(shape)
	body_sprite = Sprite2D.new()
	body_sprite.name = "BinSprite"
	body_sprite.texture = BIN_TEXTURE
	body_sprite.position = Vector2(0, -12)
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(body_sprite)
	var label := Label.new()
	label.text = "垃圾桶"
	label.position = Vector2(-64, -110)
	label.size = Vector2(128, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)

func is_pickup_drop_focusable(_player: Node) -> bool:
	return not is_carried and is_visible_in_tree()

func can_receive_item(player: Node) -> bool:
	if not is_pickup_drop_focusable(player) or not player.is_holding_item():
		return false
	var item_id: StringName = player.get_held_item_id()
	if item_id == Items.DIRTY_PLATE_ID:
		return false
	if item_id == Items.PLATE_ID:
		return not Array(Carry.payload_from(player).get("items", [])).is_empty()
	return Items.is_supported_item(item_id)

func receive_item_from_player(player: Node) -> bool:
	if not can_receive_item(player):
		return false
	var item_id: StringName = player.get_held_item_id()
	var payload: Dictionary = Carry.payload_from(player)
	if item_id == Items.PLATE_ID:
		# Prepared portions have not yet used the plate for a finished dish.
		payload["items"] = []
		player.set_held_item_payload(payload)
	else:
		var returns_plate: bool = bool(payload.get("uses_plate", false))
		player.clear_held_item()
		if returns_plate:
			player.pick_up_item(Items.DIRTY_PLATE_ID, Items.get_item_texture(Items.DIRTY_PLATE_ID))
	return true

func get_interaction_button_prompt(player: Node) -> String:
	if can_receive_item(player):
		if player.get_held_item_id() == Items.PLATE_ID:
			return "J 倒掉盘内半成品（保留净盘）"
		if bool(Carry.payload_from(player).get("uses_plate", false)):
			return "J 丢弃食物（保留脏盘）"
		return "J 丢弃手中物品"
	return "K 搬起" if not player.is_holding_item() else ""

func can_be_moved_by_player(_player: Node) -> bool:
	return not is_carried and is_visible_in_tree()

func set_facility_carried(carried: bool) -> void:
	is_carried = carried

func set_pickup_drop_highlight(active: bool) -> void:
	body_sprite.modulate = Color(1.18, 1.14, 1.04) if active else Color.WHITE

func get_layout_footprint() -> Vector2i:
	return Vector2i.ONE

func get_pickup_drop_radius() -> float:
	return 150.0

func get_interaction_rect_global() -> Rect2:
	return Rect2(global_position - Vector2(52, 56), Vector2(104, 112))
