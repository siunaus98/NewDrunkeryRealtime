extends CanvasLayer

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")

@export var card_size: Vector2 = Vector2(360.0, 218.0)
@export var card_spacing: float = 14.0
@export var card_row_spacing: float = 12.0
@export var screen_margin: Vector2 = Vector2(24.0, 18.0)
@export var relayout_animation_duration: float = 0.18
@export var wave_status_height: float = 34.0

@onready var container: MarginContainer = $MarginContainer
@onready var order_panel: Panel = $MarginContainer/OrderCard

var order_cards: Dictionary = {}
var order_customer_ids: Dictionary = {}
var cards_root: Control
var wave_status_label: Label
var order_manager: Node
var is_expanded: bool = true
var is_transitioning_visibility: bool = false
var relayout_tween: Tween
var current_wave_number: int = 0

func _ready() -> void:
	layer = 30
	container.visible = false
	cards_root = Control.new()
	cards_root.name = "CustomerCards"
	cards_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cards_root)
	wave_status_label = Label.new()
	wave_status_label.position = screen_margin
	wave_status_label.add_theme_font_size_override("font_size", 24)
	add_child(wave_status_label)
	var refs := LevelRefs.find_from(self)
	order_manager = refs.get_order_manager() if refs != null else null
	if order_manager != null:
		if not order_manager.orders_changed.is_connected(_on_orders_changed):
			order_manager.orders_changed.connect(_on_orders_changed)
		if not order_manager.waiting_orders_changed.is_connected(_on_waiting_orders_changed):
			order_manager.waiting_orders_changed.connect(_on_waiting_orders_changed)
		if not order_manager.waiting_order_progress_changed.is_connected(_on_order_progress_changed):
			order_manager.waiting_order_progress_changed.connect(_on_order_progress_changed)
		if not order_manager.order_progress_changed.is_connected(_on_order_progress_changed):
			order_manager.order_progress_changed.connect(_on_order_progress_changed)
	clear_orders()

func clear_current_order() -> void:
	clear_orders()

func clear_orders() -> void:
	_stop_relayout_tween()
	for card: Panel in order_cards.values():
		card.queue_free()
	order_cards.clear()
	order_customer_ids.clear()
	_update_wave_status("", false)

func set_orders(order_list: Array, wave_number: int = 0) -> void:
	_sync_orders(order_list)
	if wave_number > 0 and not order_list.is_empty():
		set_wave_number(wave_number)

func set_intermission(time_remaining: float, next_wave_number: int) -> void:
	clear_orders()
	_update_wave_status("间歇 %.1f 秒 → 第%d波" % [time_remaining, next_wave_number], true)

func clear_wave_status() -> void:
	_update_wave_status("", false)

func set_wave_number(wave_number: int) -> void:
	current_wave_number = maxi(wave_number, 0)
	_update_wave_status("第%d波" % current_wave_number, current_wave_number > 0)

func has_active_order() -> bool:
	return not order_cards.is_empty()

func can_toggle_visibility_mode() -> bool:
	return not is_transitioning_visibility

func toggle_visibility_mode() -> void:
	if can_toggle_visibility_mode():
		set_visibility_mode(not is_expanded)

func set_visibility_mode(expanded: bool, immediate: bool = false) -> void:
	is_expanded = expanded
	_relayout_cards(immediate)

func _on_orders_changed(order_list: Array) -> void:
	_sync_orders(order_list)

func _on_waiting_orders_changed(_order_list: Array) -> void:
	_sync_orders(order_manager.get_active_orders())

func _sync_orders(order_list: Array) -> void:
	var grouped: Dictionary = {}
	order_customer_ids.clear()
	var visible_orders: Array = order_list.duplicate()
	if order_manager != null:
		for waiting: Dictionary in order_manager.get_waiting_orders():
			if bool(waiting.get("special_guest", false)) or bool(waiting.get("elite_customer", false)):
				var pending := waiting.duplicate(true)
				pending["awaiting_acceptance"] = true
				visible_orders.append(pending)
	var active_customers: Dictionary = {}
	for order: Variant in order_list:
		if order is Dictionary:
			active_customers[String(order.get("customer_id", ""))] = true
	var filtered: Array = []
	var waiting_customers: Dictionary = {}
	for order: Variant in visible_orders:
		if not order is Dictionary:
			continue
		var customer_id := String(order.get("customer_id", ""))
		var sequential := bool(order.get("special_guest", false)) or bool(order.get("elite_customer", false))
		if bool(order.get("awaiting_acceptance", false)) and sequential:
			if active_customers.has(customer_id) or waiting_customers.has(customer_id):
				continue
			waiting_customers[customer_id] = true
		if not bool(order.get("awaiting_acceptance", false)) or not sequential:
			filtered.append(order)
	visible_orders = filtered
	for order: Variant in visible_orders:
		if not order is Dictionary:
			continue
		var order_id := String(order.get("order_id", ""))
		if order_id.is_empty():
			continue
		var customer_id := String(order.get("customer_id", order_id))
		order_customer_ids[order_id] = customer_id
		if not grouped.has(customer_id):
			grouped[customer_id] = []
		grouped[customer_id].append(order)
	for customer_id: String in order_cards.keys():
		if not grouped.has(customer_id):
			order_cards[customer_id].queue_free()
			order_cards.erase(customer_id)
	for customer_id: String in grouped:
		if order_cards.has(customer_id):
			# Rebuild only on acceptance, serving, or a structural change,
			# never on countdown ticks.
			order_cards[customer_id].free()
		order_cards[customer_id] = _create_customer_card(grouped[customer_id])
	_relayout_cards(true)

func _create_customer_card(orders: Array) -> Panel:
	var first: Dictionary = orders[0]
	var special := bool(first.get("special_guest", false))
	var elite := bool(first.get("elite_customer", false))
	var waiting := bool(first.get("awaiting_acceptance", false))
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_meta("special_guest", special)
	var sequential := special or elite
	card.set_meta("sequential", sequential)
	card.set_meta("expanded_height", 122.0 if waiting else (card_size.y + 32 if sequential else card_size.y + float(orders.size() - 1) * 138.0))
	_style_panel(card, Color(0.24, 0.065, 0.07, 0.96) if special else Color(0.12, 0.14, 0.18, 0.94), Color(1.0, 0.25, 0.28) if special else Color(0.95, 0.75, 0.30) if elite else Color(0.65, 0.69, 0.75), 3)
	cards_root.add_child(card)
	_add_label(card, "CustomerName", ("精英 · " if elite else "") + String(first.get("customer_name", "客人")), Vector2(14, 8), Vector2(card_size.x - 28 if sequential else card_size.x - 130, 28), 21)
	var order_index := maxi(int(first.get("customer_order_index", first.get("special_guest_index", 0))), 0)
	var order_total := maxi(int(first.get("customer_order_total", first.get("special_guest_total", orders.size()))), 1)
	var orders_remaining := maxi(int(first.get("customer_orders_remaining", order_total - order_index)), 0)
	var count_text := "第%d道 · 剩%d道" % [order_index + 1, orders_remaining] if sequential else "%d道" % orders.size()
	_add_label(card, "Window", "%d号 · %s" % [int(first.get("target_slot", 1)), count_text], Vector2(14, 38) if sequential else Vector2(card_size.x - 125, 8), Vector2(card_size.x - 28, 30) if sequential else Vector2(115, 30), 24 if sequential else 20)
	if special:
		card.get_node("CustomerName").modulate = Color(1.0, 0.4, 0.4)
	if waiting:
		_add_label(card, "AcceptPrompt", "K 接单 · 超时持续扣声望" if special else "按住 K 接单", Vector2(14, 71), Vector2(card_size.x - 28, 26), 18)
	var dishes := Control.new()
	dishes.name = "Dishes"
	dishes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(dishes)
	for index in range(orders.size()):
		if waiting:
			break
		var order: Dictionary = orders[index]
		var dish_id := StringName(order.get("dish_item_id", &""))
		var row := Control.new()
		row.name = "Dish_%s" % String(order.get("order_id", ""))
		row.position = Vector2(12, (74 if sequential else 42) + index * 138)
		row.size = Vector2(card_size.x - 24, 140)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dishes.add_child(row)
		_add_icon(row, "DishIcon", TestItemDefs.get_item_texture(dish_id), Vector2.ZERO, Vector2(54, 54))
		_add_label(row, "DishName", String(order.get("dish_name", TestItemDefs.get_item_display_name(dish_id))), Vector2(66, 6), Vector2(row.size.x - 66, 42), 23)
		var recipe_row := Control.new()
		recipe_row.name = "RecipeIconsRow"
		recipe_row.position = Vector2(0, 58)
		recipe_row.size = Vector2(row.size.x, 78)
		recipe_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(recipe_row)
		_rebuild_recipe_icons(recipe_row, order.get("recipe_items", []))
	var frame := ColorRect.new()
	frame.name = "PatienceBarFrame"
	frame.color = Color(0.04, 0.05, 0.07)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	var fill := ColorRect.new()
	fill.name = "PatienceBarFill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(fill)
	var remaining: float = float(first.get("order_take_time_remaining" if waiting else "time_remaining", 1.0))
	var duration: float = float(first.get("order_take_patience_duration" if waiting else "patience_duration", 1.0))
	card.set_meta("patience_ratio", clampf(remaining / maxf(duration, 0.001), 0.0, 1.0))
	return card

func _rebuild_recipe_icons(row: Control, recipe_items: Array) -> void:
	var portions: Array[Dictionary] = []
	for entry: Variant in recipe_items:
		if entry is Dictionary:
			for _index in range(maxi(int(entry.get("count", 1)), 1)):
				portions.append(entry)
	if portions.is_empty():
		return
	var width := row.size.x / float(portions.size())
	var icon_size := minf(width - 8.0, 44.0)
	for index in range(portions.size()):
		var entry: Dictionary = portions[index]
		var panel := Panel.new()
		panel.position = Vector2(index * width, 0)
		panel.size = Vector2(width - 4, row.size.y)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_panel(panel, Color(0.07, 0.08, 0.11, 0.9), Color(0.32, 0.36, 0.42), 1)
		row.add_child(panel)
		var item_id := StringName(entry.get("item_id", &""))
		var icon := _add_icon(panel, "IngredientIcon", TestItemDefs.get_item_texture(item_id), Vector2((panel.size.x - icon_size) * 0.5, 3), Vector2.ONE * icon_size)
		icon.tooltip_text = TestItemDefs.get_item_display_name(item_id)
		var state := StringName(entry.get("process_state", &""))
		var texture := TestItemDefs.get_process_icon_texture(state)
		if texture != null:
			var process_icon := _add_icon(panel, "ProcessIcon", texture, Vector2((panel.size.x - 26) * 0.5, 49), Vector2(26, 26))
			process_icon.tooltip_text = TestItemDefs.get_process_display_name(state)
			process_icon.set_meta("process_state", state)

func _add_icon(parent: Node, node_name: String, texture: Texture2D, position: Vector2, size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = texture
	icon.position = position
	icon.size = size
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(icon)
	return icon

func _add_label(parent: Node, node_name: String, text: String, position: Vector2, size: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = position
	label.size = size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

func _on_order_progress_changed(order_id: String, remaining: float, duration: float) -> void:
	var customer_id := String(order_customer_ids.get(order_id, ""))
	var card: Panel = order_cards.get(customer_id)
	if card != null:
		card.set_meta("patience_ratio", clampf(remaining / maxf(duration, 0.001), 0.0, 1.0))
		_update_card_progress(card)

func _update_card_progress(card: Panel) -> void:
	var ratio: float = float(card.get_meta("patience_ratio", 1.0))
	var frame: ColorRect = card.get_node("PatienceBarFrame")
	var fill: ColorRect = frame.get_node("PatienceBarFill")
	fill.size = Vector2(frame.size.x * ratio, frame.size.y)
	fill.color = Color(1.0, 0.25, 0.28) if bool(card.get_meta("special_guest", false)) else Color(0.48, 0.86, 0.42) if ratio > 0.75 else Color(0.96, 0.76, 0.28) if ratio > 0.25 else Color(0.92, 0.34, 0.3)

func _relayout_cards(immediate: bool = true) -> void:
	_stop_relayout_tween()
	var animate := not immediate and relayout_animation_duration > 0.0
	if animate:
		is_transitioning_visibility = true
		relayout_tween = create_tween().set_parallel(true)
	cards_root.position = Vector2(screen_margin.x, screen_margin.y + wave_status_height + 6)
	var available_width := maxf(get_viewport().get_visible_rect().size.x - screen_margin.x * 2, card_size.x)
	var columns := maxi(int(floor((available_width + card_spacing) / (card_size.x + card_spacing))), 1)
	var index: int = 0
	var y: float = 0.0
	var row_height: float = 0.0
	for card: Panel in order_cards.values():
		if index > 0 and index % columns == 0:
			y += row_height + card_row_spacing
			row_height = 0.0
		var height: float = float(card.get_meta("expanded_height")) if is_expanded else (86.0 if bool(card.get_meta("sequential", false)) else 46.0)
		card.size = Vector2(card_size.x, height)
		card.get_node("Dishes").visible = is_expanded
		var frame: ColorRect = card.get_node("PatienceBarFrame")
		frame.position = Vector2(12, height - 16) if is_expanded else Vector2(card_size.x - 62, height - 13)
		frame.size = Vector2(card_size.x - 24, 10) if is_expanded else Vector2(50, 5)
		_update_card_progress(card)
		var target := Vector2((index % columns) * (card_size.x + card_spacing), y)
		if animate:
			relayout_tween.tween_property(card, "position", target, relayout_animation_duration)
		else:
			card.position = target
		row_height = maxf(row_height, height)
		index += 1
	if animate:
		relayout_tween.finished.connect(_on_relayout_finished, CONNECT_ONE_SHOT)

func _on_relayout_finished() -> void:
	relayout_tween = null
	is_transitioning_visibility = false

func _stop_relayout_tween() -> void:
	if relayout_tween != null:
		relayout_tween.kill()
		relayout_tween = null
	is_transitioning_visibility = false

func _update_wave_status(text: String, visible: bool) -> void:
	if wave_status_label != null:
		wave_status_label.text = text
		wave_status_label.visible = visible

func _style_panel(panel: Panel, background: Color, border: Color, border_width: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	preload("res://Scripts/UI/AtelierStyle.gd").finish(style)
	# Red Boss orders and gold elite orders retain their semantic identity.
	if background.r > background.g * 2.0:
		style.bg_color = Color("572c32f5")
		style.border_color = border
	elif border.r > 0.9 and border.b < 0.5:
		style.border_color = Color("f1cf85")
	if border_width == 1:
		style.bg_color = Color("20322ff0")
		style.border_color = Color("66756b")
		style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
