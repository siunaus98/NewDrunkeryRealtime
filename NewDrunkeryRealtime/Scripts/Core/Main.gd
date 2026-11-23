extends Node2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
const LevelContext = preload("res://Scripts/Core/LevelContext.gd")
const CodexController = preload("res://Scripts/UI/CodexController.gd")
const LevelFlowInputAdapter = preload("res://Scripts/Core/LevelFlowInputAdapter.gd")
const PauseMenu = preload("res://Scripts/UI/PauseMenuController.gd")

var level_refs: LevelRefs
var prototype_map: Node2D
var player: CharacterBody2D
var order_hud: CanvasLayer
var run_setup: Dictionary = {}
var _toggle_orders_tab_was_down: bool = false
var _toggle_orders_last_frame: int = -1
var codex_controller: CodexController
var pause_menu: CanvasLayer
var pause_menu_visible: bool = false
var level_flow_controller: Node

func _ready() -> void:
	print("NewDrunkeryRealtime prototype booted.")
	_resolve_scene_refs()
	_build_pause_and_codex_ui()
	if level_flow_controller != null and level_flow_controller.progression_state != null:
		level_flow_controller.progression_state.blessings_changed.connect(_sync_codex_blessings)
		_sync_codex_blessings()
	_consume_run_setup()
	if prototype_map.has_method("get_world_bounds"):
		var world_bounds: Rect2 = prototype_map.get_world_bounds()
		player.movement_bounds = world_bounds
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.has_method("set_movement_bounds"):
				enemy.set_movement_bounds(world_bounds)
	if bool(run_setup.get("tutorial", false)):
		var tutorial := preload("res://Scripts/Tutorial/TutorialController.gd").new()
		tutorial.name = "TutorialController"
		add_child(tutorial)
		tutorial.call_deferred("setup", self)

func _input(event: InputEvent) -> void:
	if level_flow_controller != null and is_instance_valid(level_flow_controller.day_briefing) and level_flow_controller.day_briefing.visible:
		return
	if pause_menu_visible and _is_key_pressed(event, Key.KEY_K):
		_hide_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if codex_controller != null and codex_controller.is_open():
			return
		if _can_open_pause_menu():
			_toggle_pause_menu()
			get_viewport().set_input_as_handled()
			return
	if LevelFlowInputAdapter.should_toggle_orders(event):
		_trigger_toggle_orders()

func _is_key_pressed(event: InputEvent, keycode: Key) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode

func _process(_delta: float) -> void:
	# Tab is also used by Godot's UI focus system, so keep a narrow fallback for
	# the prototype when the action mapping does not surface as a normal press.
	var tab_is_down: bool = LevelFlowInputAdapter.is_toggle_orders_key_down()
	if tab_is_down and not _toggle_orders_tab_was_down:
		_trigger_toggle_orders()
	_toggle_orders_tab_was_down = tab_is_down

func _trigger_toggle_orders() -> void:
	var current_frame: int = Engine.get_process_frames()
	if _toggle_orders_last_frame == current_frame:
		return
	_toggle_orders_last_frame = current_frame
	_try_toggle_orders()

func _try_toggle_orders() -> void:
	if player != null and player.input_gate.is_blocked(&"toggle_orders"):
		return
	if is_instance_valid(order_hud) and order_hud.has_method("can_toggle_visibility_mode") and not order_hud.can_toggle_visibility_mode():
		return
	if is_instance_valid(order_hud) and order_hud.has_method("toggle_visibility_mode"):
		order_hud.toggle_visibility_mode()
		AudioCue.play_ui(&"ui_tab")

func _resolve_scene_refs() -> void:
	level_refs = LevelRefs.find_from(self)
	if level_refs == null:
		push_warning("Main requires a LevelRefs node in the scene.")
		return
	prototype_map = level_refs.get_prototype_map() as Node2D
	player = level_refs.get_player() as CharacterBody2D
	order_hud = level_refs.get_order_hud() as CanvasLayer
	level_flow_controller = level_refs.get_level_flow_controller()

func _build_pause_and_codex_ui() -> void:
	codex_controller = CodexController.new()
	add_child(codex_controller)

	pause_menu = PauseMenu.new()
	pause_menu.layer = 80
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.visible = false
	add_child(pause_menu)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.add_child(root)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.025, 0.72)
	root.add_child(shade)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(460, 560)
	panel.position = Vector2(-230, -280)
	panel.add_theme_stylebox_override("panel", preload("res://Scripts/UI/AtelierStyle.gd").panel())
	root.add_child(panel)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 28
	column.offset_top = 26
	column.offset_right = -28
	column.offset_bottom = -26
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)

	var title := Label.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	column.add_child(title)

	var resume_button := Button.new()
	resume_button.text = "继续"
	resume_button.custom_minimum_size = Vector2(220, 52)
	resume_button.pressed.connect(_hide_pause_menu)
	column.add_child(resume_button)

	var codex_button := Button.new()
	codex_button.text = "图鉴"
	codex_button.custom_minimum_size = Vector2(220, 52)
	codex_button.pressed.connect(_open_codex_from_pause)
	column.add_child(codex_button)

	var blessing_button := Button.new()
	blessing_button.text = "已拥有祝福"
	blessing_button.custom_minimum_size = Vector2(220, 52)
	blessing_button.pressed.connect(_open_blessings_from_pause)
	column.add_child(blessing_button)
	var buttons: Array[Button] = [resume_button, codex_button, blessing_button]
	for bus_name: StringName in [&"Music", &"SFX"]:
		var volume_button := Button.new()
		volume_button.custom_minimum_size = Vector2(220, 44)
		column.add_child(volume_button)
		_update_volume_button(volume_button, bus_name)
		volume_button.pressed.connect(_cycle_audio_volume.bind(volume_button, bus_name))
		buttons.append(volume_button)
	pause_menu.setup(buttons)
	pause_menu.cancelled.connect(_hide_pause_menu)
	var hint := Label.new()
	hint.text = "WASD / 方向键：选择　空格 / J：确认\nESC / K：返回"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	column.add_child(hint)

func _update_volume_button(button: Button, bus_name: StringName) -> void:
	var audio := AudioCue.manager()
	var value: float = float(audio.volume_controls.get(bus_name, 0.8)) if audio != null else 0.8
	button.text = "%s音量：%d%%" % ["音乐" if bus_name == &"Music" else "音效", roundi(value * 100.0)]
	button.tooltip_text = "确认或点击：依次切换音量，0%为静音"

func _cycle_audio_volume(button: Button, bus_name: StringName) -> void:
	var audio := AudioCue.manager()
	if audio != null:
		var current: int = roundi(float(audio.volume_controls.get(bus_name, 0.8)) * 5.0)
		audio.set_volume(bus_name, float(wrapi(current + 1, 0, 6)) / 5.0)
	_update_volume_button(button, bus_name)

func _can_open_pause_menu() -> bool:
	if pause_menu_visible:
		return true
	if level_flow_controller == null or not level_flow_controller.has_method("get_current_level_state"):
		return true
	var state_value: int = int(level_flow_controller.get_current_level_state())
	return state_value in [
		LevelContext.LevelState.NIGHT_REST,
		LevelContext.LevelState.PREPARE_PHASE,
		LevelContext.LevelState.WAVE_ACTIVE,
		LevelContext.LevelState.WAVE_BREAK
	]

func _toggle_pause_menu() -> void:
	if pause_menu_visible:
		_hide_pause_menu()
	else:
		_show_pause_menu()

func _show_pause_menu() -> void:
	AudioCue.play_ui()
	pause_menu_visible = true
	if pause_menu != null:
		pause_menu.visible = true
		pause_menu.select(0)
	get_tree().paused = true

func _hide_pause_menu() -> void:
	AudioCue.play_ui(&"ui_cancel")
	pause_menu_visible = false
	if pause_menu != null:
		pause_menu.visible = false
	get_tree().paused = false

func _open_codex_from_pause() -> void:
	pause_menu_visible = false
	if pause_menu != null:
		pause_menu.visible = false
	get_tree().paused = false
	if codex_controller != null:
		_sync_codex_blessings()
		codex_controller.open_codex()

func _open_blessings_from_pause() -> void:
	pause_menu_visible = false
	if pause_menu != null:
		pause_menu.visible = false
	get_tree().paused = false
	if codex_controller != null:
		_sync_codex_blessings()
		codex_controller.open_codex(CodexController.CATEGORY_BLESSINGS)

func _sync_codex_blessings() -> void:
	if codex_controller == null:
		return
	if level_flow_controller != null and level_flow_controller.has_method("get_owned_blessing_ids"):
		codex_controller.set_owned_blessings(level_flow_controller.get_owned_blessing_ids())
	else:
		codex_controller.set_owned_blessings([])

func _consume_run_setup() -> void:
	if get_tree() == null or not get_tree().has_meta("run_setup"):
		return
	var setup_meta: Variant = get_tree().get_meta("run_setup", {})
	get_tree().remove_meta("run_setup")
	run_setup = setup_meta if setup_meta is Dictionary else {}
	if player == null or run_setup.is_empty():
		return
	player.set_meta("run_setup", run_setup.duplicate(true))
	if run_setup.has("small_skill_variant"):
		player.set_small_skill_variant(StringName(run_setup.small_skill_variant))
	if run_setup.has("big_skill_variant"):
		player.set_big_skill_variant(StringName(run_setup.big_skill_variant))
	if bool(run_setup.get("start_ultimate_full", false)) and player.has_method("fill_ultimate_energy"):
		player.fill_ultimate_energy()
	if run_setup.has("character_id"):
		player.set_meta("selected_character_id", StringName(run_setup.get("character_id", &"")))
	if run_setup.has("innate_passive_id"):
		player.set_meta("innate_passive_id", StringName(run_setup.get("innate_passive_id", &"")))
