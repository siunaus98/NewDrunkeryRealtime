extends StaticBody2D

func _ready() -> void:
	add_to_group("pickup_drop_targets")
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(96, 72)
	shape.shape = rectangle
	add_child(shape)
	var label := Label.new()
	label.text = "菜谱书 · K"
	label.position = Vector2(-90, 45)
	label.size = Vector2(180, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	add_child(label)
	queue_redraw()

func _draw() -> void:
	draw_style_box(_page_style(Color("795034")), Rect2(-62, -43, 124, 87))
	draw_style_box(_page_style(Color("f7e5ae")), Rect2(-56, -49, 112, 80))
	draw_line(Vector2(0, -47), Vector2(0, 29), Color("b38b54"), 3)
	for side in [-1, 1]:
		for row in range(4):
			draw_line(Vector2(side * 10, -29 + row * 14), Vector2(side * 44, -29 + row * 14), Color("a47c4c"), 3)

func _page_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("573f2e")
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	return style

func is_pickup_drop_focusable(_player: Node) -> bool:
	return true

func get_pickup_drop_positions() -> Array[Vector2]:
	return [global_position]

func get_pickup_drop_radius() -> float:
	return 180.0

func get_interaction_rect_global() -> Rect2:
	return Rect2(global_position - Vector2(62, 49), Vector2(124, 96))

func get_interaction_button_prompt(_player: Node) -> String:
	return "K 查看菜品"

func interact_with_player(_player: Node) -> bool:
	var codex: Node = get_tree().current_scene.codex_controller
	codex.open_codex(&"dishes")
	return true
