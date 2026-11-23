extends Control

const Lessons = preload("res://Scripts/Tutorial/TutorialController.gd")
const Style = preload("res://Scripts/UI/AtelierStyle.gd")
const DESCRIPTIONS = [
	"取料、切配、组合第一道冷盘", "先接单，再取盘装菜、上菜洗盘", "熟成度、烤糊与备料桌", "酿一杯不需要盘子的酒", "额外招待，恢复耐心不抵原单", "逐道上菜、剩余道数与耐心",
	"金币经验与商店四个分类", "四方向选收获，中断不消失", "攻击、冲刺与触碰收集掉落", "小技能、大招与切配前后对比", "了解菜单，体验祝福与共享刷新", "强大敌人、专属食材和特殊客人"
]
const ICONS = [
	"res://ArtResource/Cooker/cut_station.svg", "res://ArtResource/Kitchen/plate_wash_station.svg",
	"res://ArtResource/Cooker/roast_station.svg", "res://ArtResource/Kitchen/drink_barrel.svg",
	"res://ArtResource/Generated/Dish/dish_qingmei_sweet_bowl.svg", "res://ArtResource/Restaurant/serving_counter.svg",
	"res://ArtResource/Restaurant/salesperson.svg", "res://ArtResource/Tutorial/quicksand.svg",
	"res://ArtResource/Generated/Enemy/desert_bird_enemy.svg", "res://ArtResource/Cooker/cut_station.svg",
	"res://ArtResource/Restaurant/goddess_statue.svg", "res://ArtResource/Generated/Enemy/sandworm_boss.svg"
]
var cards: Array[Button] = []
var selected := 0

func _ready() -> void:
	preload("res://Scripts/Audio/AudioCue.gd").play_music(&"title")
	var shade := ColorRect.new()
	shade.color = Color("172c2d")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, 72)
	for edge in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 36)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	column.add_child(_label("小沙的料理课堂 · 选择教学小关", 38))
	column.add_child(_label("十二张独立地图，全部开放。点击卡片开始，退出后可随时回来补课。", 23))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	column.add_child(grid)
	for index in range(Lessons.TITLES.size()):
		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(420, 240)
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_stylebox_override("normal", Style.panel())
		card.pressed.connect(start_lesson.bind(index))
		card.mouse_entered.connect(_select.bind(index))
		grid.add_child(card)
		cards.append(card)
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 20
		inner.offset_right = -20
		inner.offset_top = 12
		inner.offset_bottom = -12
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inner)
		var icon := TextureRect.new()
		icon.texture = load(ICONS[index])
		icon.custom_minimum_size.y = 110
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon)
		inner.add_child(_label("%02d · %s" % [index + 1, Lessons.TITLES[index]], 24))
		inner.add_child(_label(DESCRIPTIONS[index], 20))
	var back := Button.new()
	back.text = "返回标题 · Esc / K        方向键 / WASD 选择 · Enter / 空格确认"
	back.custom_minimum_size.y = 48
	back.pressed.connect(_back)
	back.focus_mode = Control.FOCUS_NONE
	column.add_child(back)
	_select(0)

func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Style.LIGHT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _select(index: int) -> void:
	selected = wrapi(index, 0, cards.size())
	for i in range(cards.size()): cards[i].add_theme_stylebox_override("normal", Style.panel(i == selected))

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_W, KEY_UP: _select(selected - 4)
		KEY_S, KEY_DOWN: _select(selected + 4)
		KEY_A, KEY_LEFT: _select(selected - 1)
		KEY_D, KEY_RIGHT: _select(selected + 1)
		KEY_ENTER, KEY_SPACE: start_lesson(selected)
		KEY_ESCAPE, KEY_K: _back()
		_: return
	get_viewport().set_input_as_handled()

func start_lesson(index: int) -> void:
	get_tree().set_meta("run_setup", {"tutorial": true, "tutorial_step": clampi(index, 0, Lessons.BOSS), "small_skill_variant": &"rush_order", "big_skill_variant": &"steady_pot"})
	get_tree().change_scene_to_file("res://Scenes/Main/main.tscn")

func _back() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main/game_start.tscn")
