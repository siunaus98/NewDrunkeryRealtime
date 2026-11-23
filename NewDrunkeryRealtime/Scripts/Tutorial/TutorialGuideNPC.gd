extends Node2D

var tutorial: Node
var speech_label: Label
var halo_time := 0.0
var highlighted := false

func _ready() -> void:
	add_to_group("pickup_drop_targets")
	z_index = 14
	scale = Vector2.ONE * 0.48
	speech_label = Label.new()
	speech_label.text = "小沙：看这里～"
	speech_label.position = Vector2(-80, -86)
	speech_label.size = Vector2(160, 30)
	speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_label.add_theme_font_size_override("font_size", 14)
	speech_label.add_theme_color_override("font_color", Color("fff0b6"))
	speech_label.add_theme_color_override("font_outline_color", Color("4b3425"))
	speech_label.add_theme_constant_override("outline_size", 5)
	add_child(speech_label)
	queue_redraw()

func _process(delta: float) -> void:
	halo_time += delta
	queue_redraw()

func _draw() -> void:
	var bob := sin(halo_time * 2.2) * 1.5
	# halo
	draw_arc(Vector2(0, -34 + bob), 12.0, 0, TAU, 32, Color("f4d879"), 5, true)
	draw_circle(Vector2(0, -34 + bob), 15.0, Color(1.0, 0.88, 0.42, 0.10))
	# wings
	draw_colored_polygon(PackedVector2Array([Vector2(-15, -55 + bob), Vector2(-78, -82 + bob), Vector2(-94, -35 + bob), Vector2(-54, -8 + bob), Vector2(-17, -22 + bob)]), Color("dce9d5"))
	draw_polyline(PackedVector2Array([Vector2(-15, -55 + bob), Vector2(-78, -82 + bob), Vector2(-94, -35 + bob), Vector2(-54, -8 + bob), Vector2(-17, -22 + bob)]), Color("6d735f"), 3, true)
	draw_colored_polygon(PackedVector2Array([Vector2(15, -55 + bob), Vector2(78, -82 + bob), Vector2(94, -35 + bob), Vector2(54, -8 + bob), Vector2(17, -22 + bob)]), Color("dce9d5"))
	draw_polyline(PackedVector2Array([Vector2(15, -55 + bob), Vector2(78, -82 + bob), Vector2(94, -35 + bob), Vector2(54, -8 + bob), Vector2(17, -22 + bob)]), Color("6d735f"), 3, true)
	# robe and collar
	draw_colored_polygon(PackedVector2Array([Vector2(-28, -49 + bob), Vector2(28, -49 + bob), Vector2(45, 35 + bob), Vector2(-45, 35 + bob)]), Color("91b9b0"))
	draw_polyline(PackedVector2Array([Vector2(-28, -49 + bob), Vector2(28, -49 + bob), Vector2(45, 35 + bob), Vector2(-45, 35 + bob), Vector2(-28, -49 + bob)]), Color("59473f"), 3, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-22, -47 + bob), Vector2(0, -29 + bob), Vector2(22, -47 + bob), Vector2(15, -60 + bob), Vector2(-15, -60 + bob)]), Color("f1dfad"))
	# face and hair
	draw_circle(Vector2(0, -78 + bob), 27.0, Color("f3d2a7"))
	draw_arc(Vector2(0, -78 + bob), 27.0, PI, TAU, 24, Color("718878"), 7, true)
	draw_circle(Vector2(-9, -79 + bob), 3.0, Color("4f5048"))
	draw_circle(Vector2(9, -79 + bob), 3.0, Color("4f5048"))
	draw_arc(Vector2(0, -68 + bob), 8.0, 0.15, PI - 0.15, 14, Color("8d5e58"), 2, true)
	# small staff
	draw_line(Vector2(40, 30 + bob), Vector2(48, -74 + bob), Color("bd8d50"), 4, true)
	draw_circle(Vector2(48, -82 + bob), 8.0, Color("f0cf78"))
	if highlighted:
		draw_arc(Vector2.ZERO, 62.0 + sin(halo_time * 4.0) * 4.0, 0, TAU, 36, Color("ffe18b"), 3, true)

func is_pickup_drop_focusable(_player: Node) -> bool:
	return true

func get_pickup_drop_radius() -> float:
	return 180.0

func get_interaction_rect_global() -> Rect2:
	return Rect2(global_position - Vector2(54, 100), Vector2(108, 140))

func get_pickup_drop_positions() -> Array[Vector2]:
	return [global_position]

func get_interaction_button_prompt(_player: Node) -> String:
	return ""

func interact_with_player(_player: Node) -> bool:
	return false

func set_pickup_drop_highlight(active: bool) -> void:
	highlighted = active
	queue_redraw()

func set_current_hint(_text: String) -> void:
	if speech_label != null:
		speech_label.text = "小沙：看这里～"
