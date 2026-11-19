extends StaticBody2D

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")

var sink: Node
var highlighted: bool = false
var status_label: Label
var plate_sprites: Array[Sprite2D] = []

func _ready() -> void:
	sink = get_parent()
	add_to_group("pickup_drop_targets")
	collision_layer = 4 | 16
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(120, 112)
	collision.shape = shape
	add_child(collision)
	for i in range(3):
		var plate := Sprite2D.new()
		plate.name = "CleanPlate%d" % i
		plate.texture = Items.get_item_texture(Items.PLATE_ID)
		plate.position = Vector2(0, -17 - i * 6)
		plate.scale = Vector2.ONE * 0.68
		add_child(plate)
		plate_sprites.append(plate)
	status_label = Label.new()
	status_label.position = Vector2(-62, 54)
	status_label.size = Vector2(124, 54)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_size_override("font_size", 32)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_color_override("font_outline_color", Color("302217"))
	status_label.add_theme_constant_override("outline_size", 8)
	add_child(status_label)
	refresh()

func can_take_item(player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(sink):
		return false
	return is_visible_in_tree() and not sink.is_carried and sink.clean_plates > 0 and player.can_pick_up_item(Items.PLATE_ID)

func take_item_to_player(player: Node) -> bool:
	if not can_take_item(player) or not player.pick_up_item(Items.PLATE_ID, Items.get_item_texture(Items.PLATE_ID)):
		return false
	sink.clean_plates -= 1
	refresh()
	return true

func can_receive_item(player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(sink):
		return false
	return is_visible_in_tree() and not sink.is_carried and player.get_held_item_id() == Items.PLATE_ID and Array(player.get_held_item_payload().get("items", [])).is_empty()

func receive_item_from_player(player: Node) -> bool:
	if not can_receive_item(player):
		return false
	player.clear_held_item()
	sink.clean_plates += 1
	refresh()
	return true

func is_pickup_drop_focusable(_player: Node) -> bool:
	# A rejected rack interaction must not fall back to dropping the held item.
	return is_visible_in_tree() and not sink.is_carried

func get_interaction_button_prompt(player: Node) -> String:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(sink):
		return ""
	if can_receive_item(player):
		return "J 归还净盘"
	var prompts: Array[String] = []
	if can_take_item(player):
		prompts.append("J 取净盘")
	if not player.is_holding_item():
		prompts.append("K 搬起整套设施")
	return " / ".join(prompts)

func get_pickup_drop_radius() -> float:
	return 150.0

func get_interaction_rect_global() -> Rect2:
	return Rect2(global_position - Vector2(60, 56), Vector2(120, 112))

func set_pickup_drop_highlight(active: bool) -> void:
	highlighted = active
	sink.refresh_highlight()

func refresh() -> void:
	if status_label != null:
		status_label.text = str(sink.clean_plates)
	for i in range(plate_sprites.size()):
		plate_sprites[i].visible = i < sink.clean_plates
