extends StaticBody2D

var controller: Node
var event_id: StringName = &""
var highlighted: bool = false
var portrait_sprite: Sprite2D
var idle_time: float = 0.0

func _ready() -> void:
	collision_layer = 4 | 16
	collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 34.0
	shape.shape = circle
	shape.position = Vector2(0, 8)
	add_child(shape)
	add_to_group("pickup_drop_targets")
	var sprite := Sprite2D.new()
	portrait_sprite = sprite
	sprite.texture = load("res://ArtResource/Events/%s.svg" % event_id)
	sprite.position = Vector2(0, -48)
	add_child(sprite)
	var bubble := Label.new()
	bubble.text = "!"
	bubble.position = Vector2(-18, -150)
	bubble.size = Vector2(36, 46)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_theme_font_size_override("font_size", 36)
	bubble.add_theme_color_override("font_color", Color("ffe07e"))
	bubble.add_theme_color_override("font_outline_color", Color("4c3326"))
	bubble.add_theme_constant_override("outline_size", 7)
	add_child(bubble)
	z_index = 8

func _process(delta: float) -> void:
	if not visible or portrait_sprite == null:
		return
	idle_time += delta
	var spirit: bool = event_id in [&"sand_spirit", &"furnace", &"prankster"]
	portrait_sprite.position.y = -48 + sin(idle_time * (2.1 if spirit else 1.6)) * (3.5 if spirit else 0.8)

func set_presence(active: bool) -> void:
	visible = active
	collision_layer = (4 | 16) if active else 0

func is_pickup_drop_focusable(_player: Node) -> bool:
	return visible and controller != null and controller.flow.is_night_rest_active()

func can_take_item(player: Node) -> bool:
	return is_pickup_drop_focusable(player)

func can_receive_item(player: Node) -> bool:
	return is_pickup_drop_focusable(player)

func take_item_to_player(player: Node) -> bool:
	return interact_with_player(player)

func receive_item_from_player(player: Node) -> bool:
	return interact_with_player(player)

func interact_with_player(_player: Node) -> bool:
	if not visible:
		return false
	controller.open_dialogue(event_id)
	return true

func get_interaction_button_prompt(_player: Node) -> String:
	return "J 交谈"

func get_pickup_drop_radius() -> float:
	return 170.0

func get_interaction_rect_global() -> Rect2:
	return Rect2(global_position - Vector2(48, 48), Vector2(96, 96))

func set_pickup_drop_highlight(active: bool) -> void:
	highlighted = active
	modulate = Color(1.2, 1.15, 1.05) if active else Color.WHITE
