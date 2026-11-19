extends RefCounted

## Held contents are presented at a readable size, independent of sprite scale.
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Carry = preload("res://Scripts/Kitchen/CarryItemRules.gd")
const SLOT_WIDTH: float = 52.0
var panel: Panel
var tail: Polygon2D
var slots: Array[Control] = []
var dish_icon: TextureRect

func setup(host: Node2D) -> void:
	panel = Panel.new()
	panel.name = "ProcessStatusBubble"
	panel.z_index = 24
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("30271ff2")
	style.set_border_width_all(2)
	style.border_color = Color("edc97e")
	style.set_corner_radius_all(8)
	preload("res://Scripts/UI/AtelierStyle.gd").finish(style)
	panel.add_theme_stylebox_override("panel", style)
	dish_icon = _icon(Vector2(7, 8), Vector2(44, 44))
	dish_icon.name = "Dish"
	panel.add_child(dish_icon)
	for index in range(Carry.PLATE_CAPACITY):
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var food := _icon(Vector2(4, 3), Vector2(44, 44))
		food.name = "Ingredient"
		slot.add_child(food)
		var badge := _icon(Vector2(27, 30), Vector2(24, 24))
		badge.name = "Process"
		slot.add_child(badge)
		panel.add_child(slot)
		slots.append(slot)
	tail = Polygon2D.new()
	tail.name = "SpeechTail"
	tail.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(0, 9)])
	tail.color = style.bg_color
	panel.add_child(tail)
	host.add_child(panel)
	panel.hide()

func update(item_id: StringName, state: StringName, signature: String, payload: Dictionary) -> void:
	var entries: Array[Dictionary] = contents(item_id, state, signature, payload)
	var is_dish: bool = Items.is_dish(item_id) or Items.is_drink(item_id)
	dish_icon.texture = Items.get_item_texture(item_id) if is_dish else null
	dish_icon.visible = is_dish
	panel.visible = is_dish or not entries.is_empty()
	var header_width: float = SLOT_WIDTH if is_dish else 0.0
	var width: float = entries.size() * SLOT_WIDTH + header_width + 12.0
	panel.size = Vector2(width, 62)
	panel.position = Vector2(-width * 0.5, -188)
	tail.position = Vector2(width * 0.5, 62)
	for index in range(slots.size()):
		var slot: Control = slots[index]
		slot.visible = index < entries.size()
		if not slot.visible:
			continue
		slot.position = Vector2(6 + header_width + index * SLOT_WIDTH, 3)
		var entry: Dictionary = entries[index]
		var food: TextureRect = slot.get_node("Ingredient")
		var badge: TextureRect = slot.get_node("Process")
		food.texture = Items.get_item_texture(StringName(entry.item_id))
		food.visible = entry.item_id != &""
		badge.texture = Items.get_process_icon_texture(StringName(entry.process_state))
		badge.visible = badge.texture != null
		badge.position = Vector2(27, 30) if food.visible else Vector2(7, 7)
		badge.size = Vector2(24, 24) if food.visible else Vector2(38, 38)

static func contents(item_id: StringName, state: StringName, signature: String, payload: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if item_id == Items.PLATE_ID:
		for entry: Dictionary in payload.get("items", []):
			if entries.size() >= Carry.PLATE_CAPACITY:
				break
			entries.append({"item_id": StringName(entry.get("item_id", &"")), "process_state": Items.normalize_process_state(StringName(entry.get("process_state", &"")))})
	elif Items.is_dish(item_id) or Items.is_drink(item_id):
		# Use the actual recipe, never a default that could hide a wrong maturity.
		for token: String in signature.split("|"):
			var parts: PackedStringArray = token.split(":")
			if parts.size() != 3 or not parts[2].is_valid_int():
				continue
			var ingredient: StringName = StringName(parts[0])
			var maturity: StringName = Items.normalize_process_state(StringName(parts[1]))
			for portion in range(clampi(int(parts[2]), 0, Carry.PLATE_CAPACITY - entries.size())):
				entries.append({"item_id": ingredient, "process_state": maturity})
	elif item_id == Items.SEASONING_BOX_ID:
		entries.append({"item_id": StringName(payload.get("item_id", &"")), "process_state": StringName(payload.get("process_state", &""))})
	elif item_id != &"" and Items.get_process_icon_texture(state) != null:
		entries.append({"item_id": &"", "process_state": state})
	return entries

func _icon(at: Vector2, dimensions: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.position = at
	icon.size = dimensions
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon
