extends Control

const Context = preload("res://Scripts/Core/LevelContext.gd")
const GOLD := Color("edce89")
const MUTED := Color("bdb8ad")

var panel: PanelContainer
var heading: Label
var title: Label
var stats: GridContainer
var summary_scroll: ScrollContainer
var summary: VBoxContainer
var hint: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("283b39"), Color("bfa271"), 2, 16))
	# Wrapped text needs its final width before its minimum height is valid.
	panel.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)
	add_child(panel)
	var margin := MarginContainer.new()
	for edge: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	heading = _label("", 18, GOLD)
	column.add_child(heading)
	title = _label("", 40, Color("faf0d9"))
	column.add_child(title)
	column.add_child(HSeparator.new())
	stats = GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 14)
	stats.add_theme_constant_override("v_separation", 14)
	column.add_child(stats)
	summary_scroll = ScrollContainer.new()
	summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(summary_scroll)
	summary = VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("separation", 14)
	summary_scroll.add_child(summary)
	column.add_child(HSeparator.new())
	hint = _label("", 20, GOLD)
	column.add_child(hint)
	resized.connect(_layout)
	_layout()

func present(success: bool, message: String, context: Context, progression: Object, notice: String) -> void:
	var final_victory: bool = success and context != null and bool(context.selected_order_group.get("final_boss", false))
	var day: int = int(context.selected_order_group.get("day_index", 1)) if context != null else 1
	heading.text = "第 %d 天  /  营业结算" % day
	title.text = "七日盛宴 · 通关" if final_victory else ("今日营业完成" if success else "营业未能完成")
	title.modulate = Color.WHITE if success else Color("f0b3a1")
	for child: Node in stats.get_children():
		stats.remove_child(child)
		child.queue_free()
	_add_stat("完成订单", str(context.completed_orders if context != null else 0), GOLD)
	_add_stat("失败订单", str(context.failed_orders if context != null else 0), Color("dcaa98"))
	_add_stat("剩余声望", "%d / %d" % [context.reputation, context.reputation_max] if context != null else "0", Color("9ac8b1"))
	_add_stat("持有金币", str(int(progression.gold) if progression != null else 0), GOLD)
	_add_stat("当前经验", "%d / %d" % [progression.xp, progression.xp_for_next_level] if progression != null else "0", Color("a5bfe3"))
	_add_stat("当前等级", str(int(progression.level) if progression != null else 1), Color("a5bfe3"))
	for child: Node in summary.get_children():
		summary.remove_child(child)
		child.queue_free()
	summary.add_child(_label("营业纪要", 20, GOLD))
	if not message.is_empty():
		summary.add_child(_label(message, 22, Color("e4e0d5")))
	if success and context != null and StringName(context.selected_order_group.get("reward", &"")) == &"forge":
		var tier: int = clampi(int(context.selected_order_group.get("tier", 1)), 1, 3)
		summary.add_child(_label("关卡奖励 · 1 个%s属性锻造器，夜间找商人免费领取。" % ["白银", "黄金", "钻石"][tier - 1], 22, GOLD))
	if not notice.is_empty():
		summary.add_child(_label(notice, 22, Color("e4e0d5")))
	summary_scroll.scroll_vertical = 0
	hint.text = "Space  返回标题" if final_victory else ("Space  继续 · 进入夜间备战" if success else "Space  返回标题 · 重新开始")
	visible = true
	_layout()
	_layout.call_deferred()

func _add_stat(caption: String, value: String, color: Color) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(Color("344a44"), Color("6f7b69"), 1, 8))
	stats.add_child(card)
	var margin := MarginContainer.new()
	for edge: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_child(_label(caption, 18, MUTED))
	column.add_child(_label(value, 32, color))
	margin.add_child(column)

func _layout() -> void:
	if panel == null:
		return
	panel.size = Vector2(minf(size.x - 64.0, 1040.0), minf(size.y - 64.0, 820.0))
	panel.position = (size - panel.size) * 0.5

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.08, 0.07, 0.06, 0.25)
	style.shadow_size = 6
	return style
