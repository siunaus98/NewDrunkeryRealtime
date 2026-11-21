extends Node

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const LevelFlowInputAdapter = preload("res://Scripts/Core/LevelFlowInputAdapter.gd")
const LevelContext = preload("res://Scripts/Core/LevelContext.gd")
const OrderGroupDefs = preload("res://Scripts/Orders/OrderGroupDefs.gd")
const NightShopController = preload("res://Scripts/Progression/NightShopController.gd")
const OrderGroupSelectController = preload("res://Scripts/UI/OrderGroupSelectController.gd")
const BlessingSelectController = preload("res://Scripts/UI/BlessingSelectController.gd")
const SkillUpgradeSelectController = preload("res://Scripts/UI/SkillUpgradeSelectController.gd")
const RunOverlayController = preload("res://Scripts/UI/RunOverlayController.gd")
const RunSetupController = preload("res://Scripts/Core/RunSetupController.gd")
const MenuDishSelectController = preload("res://Scripts/UI/MenuDishSelectController.gd")
const NightPlanningController = preload("res://Scripts/UI/NightPlanningController.gd")
const GlobalModifierSelectController = preload("res://Scripts/UI/GlobalModifierSelectController.gd")
const NightEventController = preload("res://Scripts/Progression/NightEventController.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
const RunProgressionState = preload("res://Scripts/Core/RunProgressionState.gd")
const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const MenuRequirementsQuery = preload("res://Scripts/Core/MenuRequirementsQuery.gd")
const MapMechanismDefs = preload("res://Scripts/Core/MapMechanismDefs.gd")
const SandSpiritAid = preload("res://Scripts/Enemies/SandSpiritAid.gd")
const SUPPORT_FACILITY_SCENE := preload("res://Scenes/Restaurant/support_facility.tscn")
const TEST_DAY_ARGUMENT_PREFIX: String = "--test-day="
const MONITOR_PLAYTEST_ARGUMENT: String = "--test-monitor"

# Short service window for the current demo verification pass. This only
# changes the runtime copy of a selected order group; authored order data and
# the normal production duration remain unchanged.
const FAST_BUSINESS_TEST: bool = false
const FAST_BUSINESS_PREPARE_DURATION: float = 2.0
const FAST_BUSINESS_SERVICE_DURATION: float = 30.0
const FIRST_DAY_BOSS_DISABLED_PLAYTEST: bool = false
const PATIENCE_SPEED_PLAYTEST: float = 1.0
const SKILL_UPGRADE_PLAYTEST_XP: int = 1000
const SKILL_UPGRADE_PLAYTEST_TAKE_DURATION: float = 30.0

## Give the player a short planning window before the first customers arrive.
## Normal days allow 60s preparation and 260s service; playtest overrides remain explicit.
@export var prepare_phase_duration: float = 60.0
@export var service_phase_duration: float = 260.0
@export var danger_threshold: int = 30
@export var danger_duration: float = 18.0
@export var wave_break_duration_default: float = 4.0
@export var blessing_select_duration: float = 30.0
@export var starting_gold: int = 12
@export var night_starting_stock_per_item: int = 5
@export var magic_max: int = 8
@export var magic_regen_interval: float = 10.8
@export var support_facility_spawn_origin: Vector2 = Vector2(3136, 1664)
@export var support_facility_spawn_search_cells: int = 8
@export var menu_max_size: int = 5
@export var menu_offer_count: int = 3
@export var base_serving_counter_count: int = 3
@export var day_transition_min_duration: float = 0.3

var run_context: LevelContext
var order_groups: Array[Dictionary] = []
var prepare_time_remaining: float = 0.0
var day_time_remaining: float = 0.0
var wave_break_time_remaining: float = 0.0
var magic_current: int = 0
var magic_regen_remaining: float = 0.0
var barrel_serving_bonus: int = 0
var support_facility_aura_multiplier: float = 1.0
var kitchen_processing_speed_multiplier: float = 1.0

const EQUIPMENT_SCENES := {
	&"cut_station": preload("res://Scenes/Restaurant/test_cooker.tscn"),
	&"roast_station": preload("res://Scenes/Restaurant/bake_cooker.tscn"),
	&"grind_station": preload("res://Scenes/Restaurant/grind_cooker.tscn"),
	&"prep_table": preload("res://Scenes/Restaurant/test_table.tscn")
}

var level_refs: LevelRefs
var progression_state: RunProgressionState
var order_hud: CanvasLayer
var run_status_hud: CanvasLayer
var order_manager: Node
var storage_manager: Node
var serving_counter: Node
var battle_manager: Node
var scarab_mechanism_controller: Node
var quicksand_mechanism_controller: Node
var wind_sand_mechanism_controller: Node
var player: Node
var overlay_controller: Node
var run_setup_controller: Node
var night_shop_controller: Node
var night_planning_controller: Node
var order_group_select_controller: Node
var menu_dish_select_controller: Node
var blessing_select_controller: Node
var skill_upgrade_select_controller: Node
var global_modifier_select_controller: Node
var night_event_controller: Node
var sand_spirit_aid: Node
var active_skill_upgrade_kind: StringName = &""
var menu_return_state: int = LevelContext.LevelState.NIGHT_REST
var menu_update_is_mandatory: bool = false
var post_result_menu_update_step: int = -1
var day_transition_active: bool = false
var day_transition_time_remaining: float = 0.0
var input_release_guard_active: bool = false
var test_start_day_index: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_scene_nodes()
	_cache_initial_loot_slots()
	_build_overlay()
	_connect_existing_signals()
	_initialize_persistent_progression()
	night_event_controller = NightEventController.new()
	add_child(night_event_controller)
	night_event_controller.setup(self)
	_refresh_order_groups_for_current_day()
	_enter_night_rest()

func _input(event: InputEvent) -> void:
	if input_release_guard_active or day_transition_active:
		get_viewport().set_input_as_handled()
		return
	var state: int = _get_state()
	var forge_pending: bool = state == LevelContext.LevelState.NIGHT_SHOP and night_shop_controller != null and night_shop_controller.has_method("has_pending_forge") and bool(night_shop_controller.has_pending_forge())
	var action: LevelFlowInputAdapter.Action = LevelFlowInputAdapter.decode(event, state, forge_pending)
	if action == LevelFlowInputAdapter.Action.NONE:
		return
	match action:
		LevelFlowInputAdapter.Action.CONFIRM:
			AudioCue.play_ui(&"ui_confirm")
		LevelFlowInputAdapter.Action.CANCEL:
			AudioCue.play_ui(&"ui_cancel")
		LevelFlowInputAdapter.Action.LEFT, LevelFlowInputAdapter.Action.RIGHT, LevelFlowInputAdapter.Action.UP, LevelFlowInputAdapter.Action.DOWN:
			AudioCue.play_ui(&"ui_move")
		LevelFlowInputAdapter.Action.REFRESH:
			AudioCue.play_ui(&"ui_refresh")
		LevelFlowInputAdapter.Action.PREVIOUS_CATEGORY, LevelFlowInputAdapter.Action.NEXT_CATEGORY, LevelFlowInputAdapter.Action.TOGGLE_MENU:
			AudioCue.play_ui(&"ui_tab")
		_:
			pass
	if LevelFlowInputAdapter.should_suppress_player_interaction(event, state):
		if player != null and player.has_method("suppress_interaction_input_for_current_frame"):
			player.suppress_interaction_input_for_current_frame()
	get_viewport().set_input_as_handled()
	_handle_flow_input_action(action)

func _handle_flow_input_action(action: LevelFlowInputAdapter.Action) -> void:
	if _get_state() == LevelContext.LevelState.NIGHT_EVENT:
		night_event_controller.handle_action(action)
		return
	if _get_state() == LevelContext.LevelState.GLOBAL_MODIFIER_SELECT:
		if action == LevelFlowInputAdapter.Action.LEFT:
			global_modifier_select_controller.move_selection(-1)
		elif action == LevelFlowInputAdapter.Action.RIGHT:
			global_modifier_select_controller.move_selection(1)
		elif action == LevelFlowInputAdapter.Action.CONFIRM:
			_confirm_global_modifier()
		elif action == LevelFlowInputAdapter.Action.CANCEL and global_modifier_select_controller.mode != &"offer":
			_close_global_modifier_overlay()
		return
	if _get_state() == LevelContext.LevelState.NIGHT_SHOP:
		if action == LevelFlowInputAdapter.Action.CANCEL:
			if night_shop_controller != null and night_shop_controller.has_method("has_pending_forge") and bool(night_shop_controller.has_pending_forge()):
				return
			_close_night_shop_overlay()
			return
		if night_shop_controller != null and night_shop_controller.has_method("has_pending_forge") and bool(night_shop_controller.has_pending_forge()):
			if action == LevelFlowInputAdapter.Action.LEFT:
				night_shop_controller.move_forge_selection(-1)
				return
			if action == LevelFlowInputAdapter.Action.RIGHT:
				night_shop_controller.move_forge_selection(1)
				return
			if action == LevelFlowInputAdapter.Action.CONFIRM:
				night_shop_controller.confirm_forge_selection()
				return
			return
		if action == LevelFlowInputAdapter.Action.PREVIOUS_CATEGORY:
			if night_shop_controller != null and night_shop_controller.has_method("move_category_selection"):
				night_shop_controller.move_category_selection(-1)
			return
		if action == LevelFlowInputAdapter.Action.NEXT_CATEGORY:
			if night_shop_controller != null and night_shop_controller.has_method("move_category_selection"):
				night_shop_controller.move_category_selection(1)
			return
		if action == LevelFlowInputAdapter.Action.LEFT:
			if night_shop_controller != null and night_shop_controller.has_method("move_selection_2d"):
				night_shop_controller.move_selection_2d(-1, 0)
			return
		if action == LevelFlowInputAdapter.Action.RIGHT:
			if night_shop_controller != null and night_shop_controller.has_method("move_selection_2d"):
				night_shop_controller.move_selection_2d(1, 0)
			return
		if action == LevelFlowInputAdapter.Action.UP:
			if night_shop_controller != null and night_shop_controller.has_method("move_selection_2d"):
				night_shop_controller.move_selection_2d(0, -1)
			return
		if action == LevelFlowInputAdapter.Action.DOWN:
			if night_shop_controller != null and night_shop_controller.has_method("move_selection_2d"):
				night_shop_controller.move_selection_2d(0, 1)
			return
		if action == LevelFlowInputAdapter.Action.CONFIRM:
			if night_shop_controller != null and night_shop_controller.has_method("purchase_selected"):
				night_shop_controller.purchase_selected()
			return
		if action in [LevelFlowInputAdapter.Action.SCROLL_UP, LevelFlowInputAdapter.Action.SCROLL_DOWN]:
			if night_shop_controller != null and night_shop_controller.has_method("scroll_list"):
				night_shop_controller.scroll_list(-120 if action == LevelFlowInputAdapter.Action.SCROLL_UP else 120)
			return

	if _get_state() == LevelContext.LevelState.NIGHT_PLANNING:
		if action == LevelFlowInputAdapter.Action.CANCEL:
			_enter_night_rest()
			return
		if action == LevelFlowInputAdapter.Action.LEFT:
			if night_planning_controller != null and night_planning_controller.has_method("move_selection"):
				night_planning_controller.move_selection(-1)
			return
		if action == LevelFlowInputAdapter.Action.RIGHT:
			if night_planning_controller != null and night_planning_controller.has_method("move_selection"):
				night_planning_controller.move_selection(1)
			return
		if action == LevelFlowInputAdapter.Action.CONFIRM:
			_confirm_night_planning_action()
			return

	if _get_state() == LevelContext.LevelState.ORDER_GROUP_SELECT:
		if action == LevelFlowInputAdapter.Action.CANCEL:
			_enter_night_rest()
			return
		if action == LevelFlowInputAdapter.Action.TOGGLE_MENU:
			menu_return_state = LevelContext.LevelState.NIGHT_REST
			_open_menu_dish_overlay()
			return
		if action == LevelFlowInputAdapter.Action.LEFT:
			if order_group_select_controller != null and order_group_select_controller.has_method("move_selection"):
				order_group_select_controller.move_selection(-1)
			return
		if action == LevelFlowInputAdapter.Action.RIGHT:
			if order_group_select_controller != null and order_group_select_controller.has_method("move_selection"):
				order_group_select_controller.move_selection(1)
			return
		if action == LevelFlowInputAdapter.Action.CONFIRM:
			_confirm_selected_group()
			return

	if _get_state() == LevelContext.LevelState.MENU_DISH_SELECT:
		if action == LevelFlowInputAdapter.Action.REFRESH:
			if progression_state.refresh_menu_offer(menu_offer_count):
				_open_menu_dish_overlay(menu_update_is_mandatory, menu_dish_select_controller.overlay_title_text, menu_dish_select_controller.offer_header_text)
			return
		if action == LevelFlowInputAdapter.Action.CANCEL:
			if menu_dish_select_controller != null and menu_dish_select_controller.has_method("has_pending_selection") and bool(menu_dish_select_controller.has_pending_selection()):
				menu_dish_select_controller.cancel_pending_selection()
				return
			if menu_update_is_mandatory:
				return
			_skip_menu_dish_offer()
			return
		if action == LevelFlowInputAdapter.Action.TOGGLE_MENU:
			if not menu_update_is_mandatory and (menu_dish_select_controller == null or not menu_dish_select_controller.has_method("has_pending_selection") or not bool(menu_dish_select_controller.has_pending_selection())):
				if progression_state != null and progression_state.has_pending_skill_upgrade():
					_enter_night_rest()
					_show_skill_upgrade_required_notice()
				else:
					_enter_order_group_select()
			return
		if action == LevelFlowInputAdapter.Action.LEFT:
			if menu_dish_select_controller != null and menu_dish_select_controller.has_method("move_selection"):
				menu_dish_select_controller.move_selection(-1)
			return
		if action == LevelFlowInputAdapter.Action.RIGHT:
			if menu_dish_select_controller != null and menu_dish_select_controller.has_method("move_selection"):
				menu_dish_select_controller.move_selection(1)
			return
		if action == LevelFlowInputAdapter.Action.UP:
			if menu_dish_select_controller != null and menu_dish_select_controller.has_method("move_replace_selection"):
				menu_dish_select_controller.move_replace_selection(-1)
			return
		if action == LevelFlowInputAdapter.Action.DOWN:
			if menu_dish_select_controller != null and menu_dish_select_controller.has_method("move_replace_selection"):
				menu_dish_select_controller.move_replace_selection(1)
			return
		if action == LevelFlowInputAdapter.Action.CONFIRM:
			_confirm_selected_menu_dish()
			return

	if _get_state() == LevelContext.LevelState.BLESSING_SELECT:
		if action == LevelFlowInputAdapter.Action.CANCEL:
			_close_blessing_select()
			return
		if action == LevelFlowInputAdapter.Action.REFRESH:
			if active_skill_upgrade_kind != &"" and skill_upgrade_select_controller != null and skill_upgrade_select_controller.has_method("refresh_selected"):
				skill_upgrade_select_controller.refresh_selected()
			elif blessing_select_controller != null and blessing_select_controller.has_method("refresh_selected"):
				blessing_select_controller.refresh_selected()
			return
		if action == LevelFlowInputAdapter.Action.LEFT:
			if active_skill_upgrade_kind != &"" and skill_upgrade_select_controller != null:
				skill_upgrade_select_controller.move_selection(-1)
			elif blessing_select_controller != null and blessing_select_controller.has_method("move_selection"):
				blessing_select_controller.move_selection(-1)
			return
		if action == LevelFlowInputAdapter.Action.RIGHT:
			if active_skill_upgrade_kind != &"" and skill_upgrade_select_controller != null:
				skill_upgrade_select_controller.move_selection(1)
			elif blessing_select_controller != null and blessing_select_controller.has_method("move_selection"):
				blessing_select_controller.move_selection(1)
			return
		if action == LevelFlowInputAdapter.Action.CONFIRM:
			if active_skill_upgrade_kind != &"":
				_confirm_selected_skill_upgrade()
			else:
				_confirm_selected_blessing()
			return

	if _get_state() in [LevelContext.LevelState.LEVEL_SUCCESS, LevelContext.LevelState.LEVEL_FAILED]:
		if action == LevelFlowInputAdapter.Action.CONFIRM:
			if run_context != null and run_context.state == LevelContext.LevelState.LEVEL_SUCCESS:
				if bool(run_context.selected_order_group.get("final_boss", false)):
					_restart_run_after_failure()
				else:
					_begin_post_result_menu_updates()
			else:
				_restart_run_after_failure()

func _process(delta: float) -> void:
	if night_event_controller != null:
		night_event_controller.sync_presence()
	if input_release_guard_active:
		input_release_guard_active = false
		get_tree().paused = false
		if overlay_controller != null and overlay_controller.has_method("set_transition_visible"):
			overlay_controller.set_transition_visible(false)
	if day_transition_active:
		_update_day_transition(delta)
		_update_run_status_hud()
		_update_debug_label()
		return
	if run_context == null:
		_update_run_status_hud()
		_update_debug_label()
		return
	_update_magic(delta)

	match run_context.state:
		LevelContext.LevelState.PREPARE_PHASE:
			prepare_time_remaining = maxf(prepare_time_remaining - delta, 0.0)
			day_time_remaining = maxf(day_time_remaining - delta, 0.0)
			if prepare_time_remaining <= _get_prepare_duration() * 0.5 and battle_manager != null:
				battle_manager.spawn_scheduled_boss()
			if prepare_time_remaining <= 0.0:
				_start_wave_phase()
		LevelContext.LevelState.WAVE_ACTIVE:
			day_time_remaining = maxf(day_time_remaining - delta, 0.0)
			if day_time_remaining <= 0.0:
				if bool(run_context.selected_order_group.get("boss_special_guest", false)):
					_arrive_special_guest()
				else:
					_enter_result(true, "营业时间结束。")
					return
			if run_context.danger_active:
				run_context.danger_time_remaining = maxf(run_context.danger_time_remaining - delta, 0.0)
				if run_context.danger_time_remaining <= 0.0:
					_enter_result(false, "危险倒计时结束，酒馆失守了。")
		LevelContext.LevelState.WAVE_BREAK:
			wave_break_time_remaining = maxf(wave_break_time_remaining - delta, 0.0)
			day_time_remaining = maxf(day_time_remaining - delta, 0.0)
			if day_time_remaining <= 0.0:
				if bool(run_context.selected_order_group.get("boss_special_guest", false)):
					_start_wave_phase()
					_arrive_special_guest()
				else:
					_enter_result(true, "营业时间结束。")
				return
			if order_hud != null and order_hud.has_method("set_intermission"):
				order_hud.set_intermission(wave_break_time_remaining, run_context.current_wave_index + 1)
			if wave_break_time_remaining <= 0.0:
				_start_wave_phase()

	_update_run_status_hud()
	_update_debug_label()

func _resolve_scene_nodes() -> void:
	level_refs = LevelRefs.find_from(self)
	if level_refs == null:
		push_warning("LevelFlowController requires a LevelRefs node in the scene.")
		return
	var scene_root: Node = level_refs.get_scene_root()
	order_hud = level_refs.get_order_hud() as CanvasLayer
	order_manager = level_refs.get_order_manager()
	storage_manager = level_refs.get_storage_manager()
	serving_counter = level_refs.get_serving_counter()
	battle_manager = level_refs.get_battle_manager()
	scarab_mechanism_controller = level_refs.get_scarab_mechanism_controller()
	quicksand_mechanism_controller = level_refs.get_quicksand_mechanism_controller()
	wind_sand_mechanism_controller = level_refs.get_wind_sand_mechanism_controller()
	player = level_refs.get_player()
	run_status_hud = level_refs.get_run_status_hud() as CanvasLayer
	if run_setup_controller == null:
		run_setup_controller = RunSetupController.new()
		add_child(run_setup_controller)
	if run_setup_controller != null and run_setup_controller.has_method("set_scene_refs"):
		var station_nodes: Array[Node] = level_refs.get_station_nodes()
		run_setup_controller.set_scene_refs(scene_root, player, storage_manager, battle_manager, station_nodes)
	_apply_scene_refs_to_runtime_controllers()

func _cache_initial_loot_slots() -> void:
	if run_setup_controller != null and run_setup_controller.has_method("cache_initial_loot_slots"):
		run_setup_controller.cache_initial_loot_slots()

func _connect_existing_signals() -> void:
	if battle_manager != null and not battle_manager.boss_defeated.is_connected(_on_boss_defeated):
		battle_manager.boss_defeated.connect(_on_boss_defeated)
	if order_manager != null:
		if order_manager.has_signal("order_completed") and not order_manager.order_completed.is_connected(_on_order_completed):
			order_manager.order_completed.connect(_on_order_completed)
		if order_manager.has_signal("dessert_served") and not order_manager.dessert_served.is_connected(_on_dessert_served):
			order_manager.dessert_served.connect(_on_dessert_served)
		if order_manager.has_signal("order_expired") and not order_manager.order_expired.is_connected(_on_order_expired):
			order_manager.order_expired.connect(_on_order_expired)
		if order_manager.has_signal("orders_changed") and not order_manager.orders_changed.is_connected(_on_orders_changed):
			order_manager.orders_changed.connect(_on_orders_changed)
		if order_manager.has_signal("waiting_orders_changed") and not order_manager.waiting_orders_changed.is_connected(_on_waiting_orders_changed):
			order_manager.waiting_orders_changed.connect(_on_waiting_orders_changed)
		if order_manager.has_signal("special_guest_penalty_tick") and not order_manager.special_guest_penalty_tick.is_connected(_on_special_guest_penalty_tick):
			order_manager.special_guest_penalty_tick.connect(_on_special_guest_penalty_tick)
		if order_manager.has_signal("special_guest_completed") and not order_manager.special_guest_completed.is_connected(_on_special_guest_completed):
			order_manager.special_guest_completed.connect(_on_special_guest_completed)
	if progression_state != null and progression_state.has_signal("level_up_reached") and not progression_state.level_up_reached.is_connected(_on_level_up_reached):
		progression_state.level_up_reached.connect(_on_level_up_reached)

func _build_overlay() -> void:
	overlay_controller = RunOverlayController.new()
	add_child(overlay_controller)
	overlay_controller.build_overlay(
		Callable(self, "_on_blessing_card_mouse_entered"),
		Callable(self, "_on_blessing_card_mouse_exited"),
		Callable(self, "_on_blessing_card_gui_input"),
		5
	)

	order_group_select_controller = OrderGroupSelectController.new()
	add_child(order_group_select_controller)
	order_group_select_controller.configure_ui(
		overlay_controller.get_title_label(),
		overlay_controller.get_body_label(),
		overlay_controller.get_hint_label(),
		overlay_controller.get_blessing_timer_label(),
		overlay_controller.get_blessing_timer_bar_frame(),
		overlay_controller.get_blessing_cards_root(),
		overlay_controller.get_blessing_card_panels(),
		overlay_controller.cards_scroll
	)
	order_group_select_controller.set_order_groups(order_groups)
	global_modifier_select_controller = GlobalModifierSelectController.new()
	add_child(global_modifier_select_controller)
	global_modifier_select_controller.configure_ui(
		overlay_controller.get_title_label(), overlay_controller.get_body_label(), overlay_controller.get_hint_label(),
		overlay_controller.get_blessing_timer_label(), overlay_controller.get_blessing_timer_bar_frame(),
		overlay_controller.get_blessing_cards_root(), overlay_controller.get_blessing_card_panels(), overlay_controller.cards_scroll)

	menu_dish_select_controller = MenuDishSelectController.new()
	add_child(menu_dish_select_controller)
	menu_dish_select_controller.configure_ui(
		overlay_controller.get_title_label(),
		overlay_controller.get_body_label(),
		overlay_controller.get_hint_label(),
		overlay_controller.get_blessing_timer_label(),
		overlay_controller.get_blessing_timer_bar_frame(),
		overlay_controller.get_blessing_cards_root(),
		overlay_controller.get_blessing_card_panels()
	)

	night_planning_controller = NightPlanningController.new()
	add_child(night_planning_controller)
	night_planning_controller.configure_ui(
		overlay_controller.get_title_label(),
		overlay_controller.get_body_label(),
		overlay_controller.get_hint_label(),
		overlay_controller.get_blessing_timer_label(),
		overlay_controller.get_blessing_timer_bar_frame(),
		overlay_controller.get_blessing_cards_root(),
		overlay_controller.get_blessing_card_panels()
	)

	blessing_select_controller = BlessingSelectController.new()
	add_child(blessing_select_controller)
	blessing_select_controller.configure_ui(
		overlay_controller.get_title_label(),
		overlay_controller.get_body_label(),
		overlay_controller.get_hint_label(),
		overlay_controller.get_blessing_timer_label(),
		overlay_controller.get_blessing_timer_bar_frame(),
		overlay_controller.get_blessing_timer_bar_fill(),
		overlay_controller.get_blessing_cards_root(),
		overlay_controller.get_blessing_card_panels()
	)
	blessing_select_controller.set_duration(blessing_select_duration)
	skill_upgrade_select_controller = SkillUpgradeSelectController.new()
	add_child(skill_upgrade_select_controller)
	skill_upgrade_select_controller.configure_ui(
		overlay_controller.get_title_label(),
		overlay_controller.get_body_label(),
		overlay_controller.get_hint_label(),
		overlay_controller.get_blessing_cards_root(),
		overlay_controller.get_blessing_card_panels()
	)

	night_shop_controller = NightShopController.new()
	add_child(night_shop_controller)
	night_shop_controller.configure_ui(
		overlay_controller.get_title_label(),
		overlay_controller.get_body_label(),
		overlay_controller.get_hint_label(),
		overlay_controller.get_blessing_timer_label(),
		overlay_controller.get_blessing_timer_bar_frame(),
		overlay_controller.get_blessing_cards_root(),
		overlay_controller.get_shop_root(),
		overlay_controller.get_shop_category_tabs(),
		overlay_controller.get_shop_scroll(),
		overlay_controller.get_shop_item_list()
	)
	if night_shop_controller.has_signal("purchase_completed") and not night_shop_controller.purchase_completed.is_connected(_on_night_shop_purchase_completed):
		night_shop_controller.purchase_completed.connect(_on_night_shop_purchase_completed)
	_apply_scene_refs_to_runtime_controllers()

func _apply_scene_refs_to_runtime_controllers() -> void:
	if night_shop_controller != null and night_shop_controller.has_method("set_scene_refs"):
		night_shop_controller.set_scene_refs(player, storage_manager)
	if night_shop_controller != null and night_shop_controller.has_method("set_facility_purchase_callback"):
		night_shop_controller.set_facility_purchase_callback(Callable(self, "purchase_support_facility"))
	if night_shop_controller != null and night_shop_controller.has_method("set_kitchen_upgrade_callback"):
		night_shop_controller.set_kitchen_upgrade_callback(Callable(self, "purchase_kitchen_upgrade"))
	if night_shop_controller != null and night_shop_controller.has_method("set_attribute_forge_callback"):
		night_shop_controller.set_attribute_forge_callback(Callable(self, "apply_attribute_forge"))
	if blessing_select_controller != null and blessing_select_controller.has_method("set_progression_state"):
		blessing_select_controller.set_progression_state(progression_state)
	if skill_upgrade_select_controller != null and skill_upgrade_select_controller.has_method("set_progression_state"):
		skill_upgrade_select_controller.set_progression_state(progression_state)

func _initialize_persistent_progression() -> void:
	if progression_state == null:
		progression_state = RunProgressionState.new()
	test_start_day_index = _read_test_start_day_index()
	progression_state.reset(starting_gold, test_start_day_index if test_start_day_index >= 0 else 0)
	progression_state.set_menu_max_size(menu_max_size)
	if progression_state.has_signal("level_up_reached") and not progression_state.level_up_reached.is_connected(_on_level_up_reached):
		progression_state.level_up_reached.connect(_on_level_up_reached)
	if night_shop_controller != null and night_shop_controller.has_method("reset_persistent_state"):
		night_shop_controller.reset_persistent_state(progression_state)
	if blessing_select_controller != null and blessing_select_controller.has_method("set_progression_state"):
		blessing_select_controller.set_progression_state(progression_state)
	if skill_upgrade_select_controller != null and skill_upgrade_select_controller.has_method("set_progression_state"):
		skill_upgrade_select_controller.set_progression_state(progression_state)
	# Temporary second-batch event test: provide real owned blessings to trade,
	# plus XP-driven level-ups so the normal goddess selection can be tested.
	if progression_state.events.SECOND_NIGHT_PLAYTEST or progression_state.events.ALL_EVENTS_PLAYTEST:
		progression_state.add_blessing(&"blessing_001")
		progression_state.add_blessing(&"blessing_002")
		progression_state.add_xp(120)
	_sync_owned_blessings_to_player()
	_sync_skill_variants_to_player()

func _read_test_start_day_index() -> int:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		arguments = OS.get_cmdline_args()
	for argument in arguments:
		if not String(argument).begins_with(TEST_DAY_ARGUMENT_PREFIX):
			continue
		var value_text := String(argument).trim_prefix(TEST_DAY_ARGUMENT_PREFIX)
		if value_text.is_valid_int():
			# The command-line switch uses the player-facing day number (1-based),
			# while RunProgressionState stores a zero-based day index.
			return clampi(value_text.to_int() - 1, 0, 6)
	return -1

func _enter_night_rest() -> void:
	if run_context == null:
		run_context = LevelContext.new()
	AudioCue.play_music(&"night")
	_refresh_order_groups_for_current_day()
	run_context.state = LevelContext.LevelState.NIGHT_REST
	run_context.selected_order_group.clear()
	run_context.current_wave_index = 0
	run_context.completed_orders = 0
	run_context.failed_orders = 0
	run_context.reputation_max = 100
	run_context.reputation = 100
	run_context.danger_active = false
	run_context.danger_time_remaining = 0.0
	_refill_magic()
	prepare_time_remaining = 0.0
	wave_break_time_remaining = 0.0
	if night_shop_controller != null and night_shop_controller.has_method("clear_runtime_selection"):
		night_shop_controller.clear_runtime_selection()
	menu_return_state = LevelContext.LevelState.NIGHT_REST
	menu_update_is_mandatory = false
	post_result_menu_update_step = -1
	input_release_guard_active = true
	_set_blessing_overlay_visible(false)
	_set_overlay_layout_mode(false)
	_set_overlay_visible(false)
	get_tree().paused = true
	if overlay_controller != null and overlay_controller.has_method("set_transition_visible"):
		overlay_controller.set_transition_visible(true)
	if order_manager != null and order_manager.has_method("clear_orders"):
		order_manager.clear_orders()
	if order_manager != null and order_manager.has_method("reset_day_tracking"):
		order_manager.reset_day_tracking()
	elif order_hud != null and order_hud.has_method("clear_current_order"):
		order_hud.clear_current_order()
	if battle_manager != null and battle_manager.has_method("reset_runtime_state"):
		battle_manager.reset_runtime_state()
	_stop_map_mechanisms()
	if run_setup_controller != null and run_setup_controller.has_method("reset_for_night"):
		var starting_stock: int = 30 if (progression_state.events.SECOND_NIGHT_PLAYTEST or progression_state.events.ALL_EVENTS_PLAYTEST) else night_starting_stock_per_item
		run_setup_controller.reset_for_night(progression_state.day_index, starting_stock)
	_sync_storage_cabinets_to_current_menu()
	_sync_kitchen_unlocks_to_current_menu()
	_sync_barrel_serving_bonus()
	_sync_support_facility_bonuses()
	var map_node := level_refs.get_prototype_map() if level_refs != null else null
	if map_node != null and map_node.has_method("refresh_environment"):
		var map_seed := int(progression_state.modifiers.run_seed) if progression_state != null else 0
		map_node.refresh_environment(map_seed, int(progression_state.day_index) if progression_state != null else 0)
	if night_event_controller != null:
		night_event_controller.refresh_night()
	if run_status_hud != null and run_status_hud.has_method("set_status_visible"):
		run_status_hud.set_status_visible(true)
	_update_debug_label()

func _enter_order_group_select() -> void:
	if night_event_controller != null and night_event_controller.blocks_next_day():
		if progression_state.pending_menu_offer_kind == &"event":
			_open_menu_dish_overlay(true, "刻碑师：选择新菜", "已付款 · 不可刷新")
		else:
			_return_from_menu_overlay()
			overlay_controller.show_toast("游商已在酒馆内等候，请先与他交谈取回本息。", 4.0)
		return
	if progression_state != null and progression_state.has_pending_skill_upgrade():
		_enter_night_rest()
		_show_skill_upgrade_required_notice()
		return
	if progression_state != null and progression_state.modifiers.needs_global_choice(progression_state.day_index):
		_open_global_modifier_overlay()
		return
	if run_context == null:
		run_context = LevelContext.new()
	_refresh_order_groups_for_current_day()
	run_context.state = LevelContext.LevelState.ORDER_GROUP_SELECT
	run_context.selected_order_group.clear()
	run_context.completed_orders = 0
	run_context.failed_orders = 0
	run_context.current_wave_index = 0
	run_context.reputation = run_context.reputation_max
	run_context.danger_active = false
	run_context.danger_time_remaining = 0.0
	prepare_time_remaining = 0.0
	wave_break_time_remaining = 0.0
	if blessing_select_controller != null and blessing_select_controller.has_method("clear_state"):
		blessing_select_controller.clear_state()
	_set_blessing_overlay_visible(false)
	_set_overlay_layout_mode(true)
	get_tree().paused = true
	if order_manager != null and order_manager.has_method("clear_orders"):
		order_manager.clear_orders()
	elif order_hud != null and order_hud.has_method("clear_current_order"):
		order_hud.clear_current_order()
	if battle_manager != null and battle_manager.has_method("reset_runtime_state"):
		battle_manager.reset_runtime_state()
	if run_status_hud != null and run_status_hud.has_method("set_status_visible"):
		run_status_hud.set_status_visible(true)
	_set_overlay_visible(true)
	if order_group_select_controller != null and order_group_select_controller.has_method("prepare_for_open"):
		order_group_select_controller.prepare_for_open()
	_update_debug_label()

func _confirm_selected_group() -> void:
	if order_group_select_controller != null and order_group_select_controller.has_method("mark_confirmed_this_frame"):
		if not bool(order_group_select_controller.mark_confirmed_this_frame()):
			return
	var active_group_index: int = _get_active_order_group_index()
	if order_groups.is_empty() or active_group_index < 0 or active_group_index >= order_groups.size():
		return

	run_context = LevelContext.new()
	progression_state.modifiers.choose_day(active_group_index, progression_state.day_index)
	var menu_group := _build_order_group_for_current_menu(order_groups[active_group_index])
	run_context.initialize(menu_group, 100)
	if run_setup_controller != null and run_setup_controller.has_method("reset_for_selected_group"):
		run_setup_controller.reset_for_selected_group(run_context)
	_sync_storage_cabinets_to_current_menu()
	_sync_kitchen_unlocks_to_current_menu()
	_sync_barrel_serving_bonus()
	_sync_support_facility_bonuses()
	_start_day_transition()

func _start_day_transition() -> void:
	day_transition_active = true
	day_transition_time_remaining = maxf(day_transition_min_duration, 0.0)
	get_tree().paused = true
	_set_blessing_overlay_visible(false)
	_set_overlay_visible(false)
	if overlay_controller != null and overlay_controller.has_method("set_transition_visible"):
		overlay_controller.set_transition_visible(true)

func _update_day_transition(delta: float) -> void:
	day_transition_time_remaining = maxf(day_transition_time_remaining - delta, 0.0)
	if day_transition_time_remaining > 0.0:
		return
	day_transition_active = false
	_enter_prepare_phase()
	if overlay_controller != null and overlay_controller.has_method("set_transition_visible"):
		overlay_controller.set_transition_visible(false)

func _start_map_mechanisms(start_business: bool) -> void:
	_ensure_sand_spirit_aid()
	if start_business and scarab_mechanism_controller != null and scarab_mechanism_controller.has_method("start_business"):
		scarab_mechanism_controller.start_business()
	if quicksand_mechanism_controller != null and quicksand_mechanism_controller.has_method("start_gameplay"):
		quicksand_mechanism_controller.start_gameplay()
	if wind_sand_mechanism_controller != null and wind_sand_mechanism_controller.has_method("start_gameplay"):
		wind_sand_mechanism_controller.start_gameplay()

func _on_boss_defeated(mechanism_id: StringName) -> void:
	# Controllers stay inactive until the next day's configure_for_level().
	# Starting another wave must not undo the reward for defeating this boss.
	match mechanism_id:
		MapMechanismDefs.QUICKSAND:
			if quicksand_mechanism_controller != null:
				quicksand_mechanism_controller.stop_gameplay()
		MapMechanismDefs.SCARAB:
			if scarab_mechanism_controller != null:
				scarab_mechanism_controller.stop_business(true)
		MapMechanismDefs.SANDSTORM:
			if wind_sand_mechanism_controller != null:
				wind_sand_mechanism_controller.stop_gameplay()

func _stop_map_mechanisms() -> void:
	if is_instance_valid(sand_spirit_aid):
		sand_spirit_aid.queue_free()
	sand_spirit_aid = null
	if scarab_mechanism_controller != null and scarab_mechanism_controller.has_method("stop_business"):
		scarab_mechanism_controller.stop_business()
	if quicksand_mechanism_controller != null and quicksand_mechanism_controller.has_method("stop_gameplay"):
		quicksand_mechanism_controller.stop_gameplay()
	if wind_sand_mechanism_controller != null and wind_sand_mechanism_controller.has_method("stop_gameplay"):
		wind_sand_mechanism_controller.stop_gameplay()

func _get_prepare_duration() -> float:
	if run_context != null:
		return float(run_context.selected_order_group.get("prepare_duration", prepare_phase_duration))
	return prepare_phase_duration

func _ensure_sand_spirit_aid() -> void:
	if progression_state == null or not progression_state.events.sand_spirit_aid or not is_instance_valid(player):
		return
	if is_instance_valid(sand_spirit_aid):
		return
	sand_spirit_aid = SandSpiritAid.new()
	var runtime_root: Node = level_refs.get_runtime_root() if level_refs != null else self
	runtime_root.add_child(sand_spirit_aid)
	sand_spirit_aid.setup(player)

func _get_service_duration() -> float:
	if run_context != null:
		return float(run_context.selected_order_group.get("service_duration", service_phase_duration))
	return service_phase_duration

func _enter_prepare_phase() -> void:
	if run_context == null:
		return
	AudioCue.play_music(&"boss" if bool(run_context.selected_order_group.get("final_boss", false)) or StringName(run_context.selected_order_group.get("boss_enhanced_map_mechanism_id", &"")) != &"" else &"day")
	run_context.state = LevelContext.LevelState.PREPARE_PHASE
	run_context.special_guest_arrived = false
	prepare_time_remaining = _get_prepare_duration()
	day_time_remaining = prepare_time_remaining + _get_service_duration()
	if player != null and player.has_method("begin_blessing_day"):
		player.begin_blessing_day()
	wave_break_time_remaining = 0.0
	get_tree().paused = false
	_set_blessing_overlay_visible(false)
	_set_overlay_layout_mode(false)
	_set_overlay_visible(false)
	if order_manager != null and order_manager.has_method("clear_orders"):
		order_manager.clear_orders()
	elif order_hud != null and order_hud.has_method("clear_current_order"):
		order_hud.clear_current_order()
	if battle_manager != null and battle_manager.has_method("enter_prepare_phase"):
		battle_manager.configure_for_order_group(run_context.selected_order_group)
		battle_manager.enter_prepare_phase()
	_start_map_mechanisms(false)
	if run_status_hud != null and run_status_hud.has_method("set_status_visible"):
		run_status_hud.set_status_visible(true)
	_update_day_clock()
	_update_debug_label()

func _start_wave_phase() -> void:
	if run_context == null:
		return
	if not run_context.has_remaining_waves():
		if bool(run_context.selected_order_group.get("boss_special_guest", false)):
			run_context.state = LevelContext.LevelState.WAVE_ACTIVE
			return
		_enter_result(true, "所有波次已完成。")
		return
	run_context.state = LevelContext.LevelState.WAVE_ACTIVE
	_start_map_mechanisms(true)
	var wave_data: Dictionary = run_context.get_current_wave()
	var wave_number: int = int(wave_data.get("wave_number", run_context.current_wave_index + 1))
	var orders: Array = wave_data.get("orders", [])
	if order_manager != null and order_manager.has_method("set_orders"):
		order_manager.set_orders(orders)
	if order_hud != null and order_hud.has_method("set_wave_number"):
		order_hud.set_wave_number(wave_number)
	if battle_manager != null and battle_manager.has_method("start_wave"):
		battle_manager.start_wave(run_context.current_wave_index, wave_data, run_context.selected_order_group)

func _arrive_special_guest() -> void:
	if run_context.special_guest_arrived or order_manager == null:
		return
	var orders: Array = run_context.selected_order_group.get("boss_special_orders", [])
	if orders.is_empty():
		return
	order_manager.add_orders(orders)
	run_context.special_guest_arrived = true
	if order_hud != null:
		order_hud.set_wave_number(run_context.current_wave_index + 1)

func _on_order_completed(order_data: Dictionary) -> void:
	if run_context == null or _get_state() != LevelContext.LevelState.WAVE_ACTIVE:
		return
	_apply_served_dish_rewards(order_data)
	run_context.record_order_completed(order_data)
	_handle_wave_order_resolution()

func _on_dessert_served(dish_data: Dictionary) -> void:
	if run_context == null or _get_state() != LevelContext.LevelState.WAVE_ACTIVE:
		return
	_apply_served_dish_rewards(dish_data)

func _apply_served_dish_rewards(order_data: Dictionary) -> void:
	var rewarded_order := order_data.duplicate(true)
	var blessing_runtime: RefCounted = player.get_blessing_controller() if player != null and player.has_method("get_blessing_controller") else null
	if blessing_runtime != null:
		rewarded_order = blessing_runtime.on_order_completed(rewarded_order)
		if bool(order_data.get("customer_completed", true)):
			blessing_runtime.on_other_customer_completed()
	if progression_state != null:
		for reward_key: StringName in [&"gold", &"xp"]:
			var reward_field := "%s_reward" % reward_key
			rewarded_order[reward_field] = roundi(float(rewarded_order.get(reward_field, 0)) * get_run_modifier_multiplier(reward_key))
		progression_state.apply_order_rewards(rewarded_order)
		progression_state.events.record_income(progression_state.day_index, int(rewarded_order.get("gold_reward", 0)))
		_update_run_status_hud()

func _on_orders_changed(order_list: Array) -> void:
	_update_serving_counter_target_from_orders(order_list, "get_waiting_orders")

func _on_waiting_orders_changed(order_list: Array) -> void:
	_update_serving_counter_target_from_orders(order_list, "get_active_orders")

func _update_serving_counter_target_from_orders(order_list: Array, fallback_method: StringName) -> void:
	var effective_orders: Array = order_list
	if effective_orders.is_empty():
		if order_manager == null or not order_manager.has_method(fallback_method):
			_set_order_target_slot_for_serving_counters(-1)
			return
		effective_orders = order_manager.call(fallback_method)
	if effective_orders.is_empty():
		_set_order_target_slot_for_serving_counters(-1)
		return
	var next_order: Dictionary = effective_orders[0] if effective_orders[0] is Dictionary else {}
	_set_order_target_slot_for_serving_counters(int(next_order.get("target_slot", 1)) - 1)

func _set_order_target_slot_for_serving_counters(slot_index: int) -> void:
	for counter in get_tree().get_nodes_in_group("serving_counters"):
		if counter != null and counter.has_method("set_order_target_slot"):
			counter.set_order_target_slot(slot_index)

func _on_order_expired(order_data: Dictionary) -> void:
	if run_context == null or _get_state() != LevelContext.LevelState.WAVE_ACTIVE:
		return

	var penalized_order := order_data.duplicate(true)
	penalized_order["reputation_penalty"] = ceili(float(order_data.get("reputation_penalty", 0)) * get_run_modifier_multiplier(&"reputation"))
	# Windows are reused by different customers; the visit index distinguishes
	# them while keeping all dishes of a single visit under one protection.
	var customer_key := "%s:%s" % [order_data.get("customer_id", ""), order_data.get("day_customer_index", order_data.get("order_id", ""))]
	if not bool(order_data.get("special_guest", false)) and progression_state.events.on_customer_expired(progression_state.day_index, customer_key):
		penalized_order["reputation_penalty"] = 0
	run_context.record_order_failed(penalized_order)
	if run_context.reputation <= danger_threshold and not run_context.danger_active:
		run_context.danger_active = true
		run_context.danger_time_remaining = danger_duration

	if run_context.reputation <= 0:
		_enter_result(false, "声望已降到 0。")
		return
	if bool(order_data.get("customer_resolved", true)):
		_handle_wave_order_resolution()

func _on_special_guest_penalty_tick(amount: int) -> void:
	if run_context == null or _get_state() != LevelContext.LevelState.WAVE_ACTIVE:
		return
	run_context.reputation = maxi(run_context.reputation - ceili(maxi(amount, 0) * get_run_modifier_multiplier(&"reputation")), 0)
	if run_context.reputation <= 0:
		_enter_result(false, "特殊客人失望，店铺声望归零。")
	else:
		_update_run_status_hud()

func _on_special_guest_completed() -> void:
	if run_context == null or _get_state() != LevelContext.LevelState.WAVE_ACTIVE:
		return
	_enter_result(true, "沙海宴会评审已满足，七日盛宴完成！" if bool(run_context.selected_order_group.get("final_boss", false)) else "特殊客人已满足，Boss 关完成。")

func _handle_wave_order_resolution() -> void:
	# Boss days finish through special_guest_completed, after rewards are applied.
	if bool(run_context.selected_order_group.get("boss_special_guest", false)):
		return
	if order_manager != null and order_manager.has_method("has_active_order") and order_manager.has_active_order():
		return

	run_context.advance_wave()
	if not run_context.has_remaining_waves():
		_enter_result(true, "所有波次已完成。")
		return

	_enter_wave_break()

func _enter_wave_break() -> void:
	if run_context == null:
		return
	run_context.state = LevelContext.LevelState.WAVE_BREAK
	var selected_group: Dictionary = run_context.selected_order_group
	wave_break_time_remaining = float(selected_group.get("wave_break_duration", wave_break_duration_default))
	if battle_manager != null and battle_manager.has_method("end_wave"):
		battle_manager.end_wave()
	if order_hud != null and order_hud.has_method("set_intermission"):
		order_hud.set_intermission(wave_break_time_remaining, run_context.current_wave_index + 1)

func _create_pending_menu_dish_offer() -> void:
	if progression_state == null:
		return
	progression_state.set_menu_max_size(menu_max_size)
	if not progression_state.has_pending_menu_offer():
		progression_state.create_next_non_drink_offer(menu_offer_count)

func _open_menu_dish_overlay(is_mandatory_update: bool = false, title_text: String = "夜间菜单", offer_header_text: String = "可加入的新菜") -> void:
	if run_context == null or progression_state == null:
		return
	menu_update_is_mandatory = is_mandatory_update
	run_context.state = LevelContext.LevelState.MENU_DISH_SELECT
	get_tree().paused = true
	_set_blessing_overlay_visible(false)
	_set_overlay_layout_mode(true)
	_set_overlay_visible(true)
	if menu_dish_select_controller != null and menu_dish_select_controller.has_method("prepare_for_open"):
		var current_menu_ids := progression_state.get_menu_dish_ids()
		var is_event: bool = progression_state.pending_menu_offer_kind == &"event"
		var old_index: int = current_menu_ids.find(progression_state.event_menu_target) if is_event else progression_state.pending_menu_replace_index
		var needs_replacement := bool(progression_state.has_pending_non_drink_offer() and progression_state.is_non_drink_menu_full())
		menu_dish_select_controller.prepare_for_open(
			progression_state.pending_menu_offer_ids.duplicate(),
			current_menu_ids,
			menu_max_size,
			old_index,
			needs_replacement,
			menu_update_is_mandatory,
			title_text,
			offer_header_text
		)
		menu_dish_select_controller.set_refresh_status(progression_state.menu_refreshes, is_event, TestItemDefs.get_item_display_name(progression_state.event_menu_target) if is_event else "")
		overlay_controller.debug_label.visible = not is_event and OS.get_cmdline_user_args().has("--debug-ui")
		if is_event:
			overlay_controller.hide_toast()
	if overlay_controller != null and overlay_controller.has_method("set_debug_text"):
		overlay_controller.set_debug_text("Menu book")

func _open_night_planning_overlay() -> void:
	if run_context == null:
		return
	run_context.state = LevelContext.LevelState.NIGHT_PLANNING
	get_tree().paused = true
	_set_blessing_overlay_visible(false)
	_set_overlay_layout_mode(true)
	_set_overlay_visible(true)
	if night_planning_controller != null and night_planning_controller.has_method("prepare_for_open"):
		var menu_dish_ids: Array[StringName] = progression_state.get_menu_dish_ids() if progression_state != null else [TestItemDefs.DISH_RED_ID]
		night_planning_controller.prepare_for_open(menu_dish_ids)
	_update_debug_label()

func _confirm_night_planning_action() -> void:
	if night_planning_controller == null:
		return
	if night_planning_controller.has_method("mark_confirmed_this_frame"):
		if not bool(night_planning_controller.mark_confirmed_this_frame()):
			return
	var active_action := int(night_planning_controller.get_active_action()) if night_planning_controller.has_method("get_active_action") else 0
	match active_action:
		NightPlanningController.PlanningAction.VIEW_MENU:
			menu_return_state = LevelContext.LevelState.NIGHT_PLANNING
			_open_menu_dish_overlay()
		NightPlanningController.PlanningAction.START_DAY:
			if progression_state != null and progression_state.has_pending_skill_upgrade():
				_enter_night_rest()
				_show_skill_upgrade_required_notice()
				return
			_enter_order_group_select()
		NightPlanningController.PlanningAction.VIEW_MODIFIERS:
			_open_global_modifier_overlay(true)

func _confirm_selected_menu_dish() -> void:
	if progression_state == null or menu_dish_select_controller == null:
		_enter_night_rest()
		return
	if menu_dish_select_controller.has_method("mark_confirmed_this_frame"):
		if not bool(menu_dish_select_controller.mark_confirmed_this_frame()):
			return
	var action_result: Dictionary = {}
	if menu_dish_select_controller.has_method("handle_primary_action"):
		action_result = menu_dish_select_controller.handle_primary_action()
	if not bool(action_result.get("commit", false)):
		return
	var offer_index := int(action_result.get("offer_index", -1))
	var replace_index := int(action_result.get("replace_index", -1))
	if offer_index < 0:
		return
	var event_exchange: bool = progression_state.pending_menu_offer_kind == &"event"
	if not progression_state.choose_menu_offer(offer_index, replace_index):
		return
	_sync_storage_cabinets_to_current_menu()
	_sync_kitchen_unlocks_to_current_menu()
	if event_exchange:
		night_event_controller.finish_menu_exchange()
		return
	if menu_update_is_mandatory:
		if _open_next_post_result_menu_update():
			return
		_enter_night_rest()
		return
	_open_menu_dish_overlay(false)

func _skip_menu_dish_offer() -> void:
	_return_from_menu_overlay()

func _open_global_modifier_overlay(history_only: bool = false) -> void:
	progression_state.modifiers.ensure_offers(progression_state.day_index)
	run_context.state = LevelContext.LevelState.GLOBAL_MODIFIER_SELECT
	get_tree().paused = true
	_set_blessing_overlay_visible(false)
	_set_overlay_layout_mode(true)
	_set_overlay_visible(true)
	if history_only:
		overlay_controller.ensure_card_count(maxi(3, progression_state.modifiers.global_history.size()))
		global_modifier_select_controller.show_history(progression_state.modifiers.global_history)
	else:
		global_modifier_select_controller.open_offers(progression_state.modifiers.global_choices)

func _confirm_global_modifier() -> void:
	if not global_modifier_select_controller.mark_confirmed_this_frame():
		return
	if global_modifier_select_controller.mode != &"offer":
		_close_global_modifier_overlay()
		return
	var index: int = global_modifier_select_controller.get_active_group_index()
	var pair := progression_state.modifiers.choose_global(index, progression_state.day_index)
	if pair.is_empty():
		return
	global_modifier_select_controller.show_reveal(pair)
	global_modifier_select_controller.last_confirm_frame = Engine.get_process_frames()

func _close_global_modifier_overlay() -> void:
	if global_modifier_select_controller.mode == &"history":
		_open_night_planning_overlay()
	else:
		_enter_night_rest()

func get_run_modifier_multiplier(key: StringName) -> float:
	if progression_state == null:
		return 1.0
	var include_day := _get_state() in [LevelContext.LevelState.PREPARE_PHASE, LevelContext.LevelState.WAVE_ACTIVE, LevelContext.LevelState.WAVE_BREAK]
	var result: float = progression_state.modifiers.multiplier(key, progression_state.day_index, include_day)
	result *= progression_state.events.get_event_multiplier(key, progression_state.day_index, include_day)
	return result

func is_patience_speed_playtest_active() -> bool:
	return PATIENCE_SPEED_PLAYTEST > 1.0 and progression_state != null and progression_state.events.INITIAL_NIGHT_PLAYTEST and progression_state.day_index == 0

func get_patience_speed_playtest_multiplier() -> float:
	return PATIENCE_SPEED_PLAYTEST if is_patience_speed_playtest_active() else 1.0

func _return_from_menu_overlay() -> void:
	menu_update_is_mandatory = false
	match menu_return_state:
		LevelContext.LevelState.NIGHT_PLANNING:
			_open_night_planning_overlay()
		_:
			_enter_night_rest()

func _enter_result(success: bool, message: String) -> void:
	AudioCue.play_sfx(&"success" if success else &"failure", -2.0)
	AudioCue.play_music_once(&"success" if success else &"end")
	if run_context != null:
		if success and progression_state != null:
			progression_state.add_gold(progression_state.events.settle_wager(progression_state.day_index))
			progression_state.modifiers.settle_success(progression_state.day_index)
			progression_state.queue_skill_upgrade_for_completed_day(progression_state.day_index)
			progression_state.grant_completed_day_blessing_refresh(progression_state.day_index)
			var blessing_runtime: RefCounted = player.get_blessing_controller() if player != null and player.has_method("get_blessing_controller") else null
			if blessing_runtime != null:
				progression_state.add_gold(blessing_runtime.get_end_of_day_gold(magic_current))
		_sync_progression_from_run_context(success and not bool(run_context.selected_order_group.get("final_boss", false)))
		if storage_manager != null and storage_manager.has_method("halve_all_stock"):
			storage_manager.halve_all_stock()
		run_context.state = LevelContext.LevelState.LEVEL_SUCCESS if success else LevelContext.LevelState.LEVEL_FAILED
	get_tree().paused = true
	if run_status_hud != null and run_status_hud.has_method("set_status_visible"):
		run_status_hud.set_status_visible(false)
	if battle_manager != null and battle_manager.has_method("end_level"):
		battle_manager.end_level()
	_stop_map_mechanisms()
	if overlay_controller != null and overlay_controller.has_method("show_result"):
		overlay_controller.show_result(success, message, run_context, progression_state, progression_state.events.pending_notice)
		progression_state.events.pending_notice = ""
	_update_debug_label()

func _restart_run_after_failure() -> void:
	# A failed run must not leave the player in the previous run's night state.
	# Returning to the title creates a fresh LevelFlowController and therefore
	# clears customers, orders, bosses, map mechanisms, temporary stock and day
	# progression while leaving the successful-run night flow unchanged.
	get_tree().paused = false
	day_transition_active = false
	input_release_guard_active = false
	if overlay_controller != null and overlay_controller.has_method("set_transition_visible"):
		overlay_controller.set_transition_visible(false)
	get_tree().change_scene_to_file("res://Scenes/Main/game_start.tscn")

func _begin_post_result_menu_updates() -> void:
	post_result_menu_update_step = 0
	if _open_next_post_result_menu_update():
		return
	_enter_night_rest()

func _open_next_post_result_menu_update() -> bool:
	if progression_state == null:
		return false
	if progression_state.has_pending_menu_offer():
		_open_menu_dish_overlay(true, _get_pending_menu_update_title(), _get_pending_menu_offer_header())
		return true
	if post_result_menu_update_step == 0:
		post_result_menu_update_step = 1
		if not progression_state.should_offer_drink_menu_update():
			return _open_next_post_result_menu_update()
		progression_state.create_next_drink_offer(menu_offer_count)
		if progression_state.has_pending_menu_offer():
			_open_menu_dish_overlay(true, _get_pending_menu_update_title(), _get_pending_menu_offer_header())
			return true
		return _open_next_post_result_menu_update()
	if post_result_menu_update_step == 1:
		post_result_menu_update_step = 2
		progression_state.create_next_non_drink_offer(menu_offer_count)
		if progression_state.has_pending_menu_offer():
			_open_menu_dish_overlay(true, _get_pending_menu_update_title(), _get_pending_menu_offer_header())
			return true
	post_result_menu_update_step = -1
	if progression_state.modifiers.needs_global_choice(progression_state.day_index):
		_open_global_modifier_overlay()
		return true
	return false

func _get_pending_menu_update_title() -> String:
	if progression_state != null and progression_state.has_pending_drink_offer():
		return "营业结算：新增酒水"
	return "营业结算：新增菜品"

func _get_pending_menu_offer_header() -> String:
	if progression_state != null and progression_state.has_pending_drink_offer():
		return "选择一种新酒水"
	return "选择一道新菜"

func _on_level_up_reached(_new_level: int) -> void:
	if progression_state != null:
		progression_state.add_blessing_points(1)
	_update_run_status_hud()

func _enter_blessing_select() -> void:
	if progression_state != null and progression_state.has_pending_skill_upgrade():
		_enter_skill_upgrade_select(progression_state.get_pending_skill_upgrade_kind())
		return
	if run_context == null or progression_state == null or progression_state.get_blessing_points() <= 0:
		return
	active_skill_upgrade_kind = &""

	run_context.state = LevelContext.LevelState.BLESSING_SELECT
	get_tree().paused = true
	_set_overlay_visible(true)
	_set_blessing_overlay_visible(true)
	_set_overlay_layout_mode(true)
	if blessing_select_controller != null and blessing_select_controller.has_method("enter_selection"):
		blessing_select_controller.enter_selection()
		if blessing_select_controller.has_method("get_selected_blessing") and blessing_select_controller.get_selected_blessing().is_empty():
			_close_blessing_select()
			return
	_update_debug_label()

func _confirm_selected_blessing() -> void:
	var blessing_data: Dictionary = {}
	if blessing_select_controller != null and blessing_select_controller.has_method("confirm_selection"):
		blessing_data = blessing_select_controller.confirm_selection()
	if blessing_data.is_empty():
		return
	var blessing_id: StringName = StringName(blessing_data.get("id", &""))
	var blessing_applied: bool = false
	if player != null and player.has_method("apply_blessing"):
		if player.apply_blessing(blessing_id) and progression_state != null:
			progression_state.add_blessing(blessing_id)
			blessing_applied = progression_state.spend_blessing_point()
	if not blessing_applied:
		return
	AudioCue.play_sfx(&"upgrade", -2.0)

	if blessing_select_controller != null and blessing_select_controller.has_method("clear_state"):
		blessing_select_controller.clear_state()
	_update_run_status_hud()

	if progression_state.get_blessing_points() > 0:
		_enter_blessing_select()
		return

	_close_blessing_select()

func _enter_skill_upgrade_select(upgrade_kind: StringName) -> void:
	if run_context == null or progression_state == null or skill_upgrade_select_controller == null:
		return
	active_skill_upgrade_kind = upgrade_kind
	run_context.state = LevelContext.LevelState.BLESSING_SELECT
	get_tree().paused = true
	_set_overlay_visible(true)
	_set_blessing_overlay_visible(true)
	_set_overlay_layout_mode(true)
	skill_upgrade_select_controller.enter_selection(upgrade_kind)
	_update_debug_label()

func _show_skill_upgrade_required_notice() -> void:
	if overlay_controller != null:
		if overlay_controller.has_method("show_toast"):
			overlay_controller.show_toast("请先前往女神像选择技能升级。")

func _confirm_selected_skill_upgrade() -> void:
	if skill_upgrade_select_controller == null or progression_state == null:
		return
	var data: Dictionary = skill_upgrade_select_controller.confirm_selection()
	if data.is_empty():
		return
	var kind := StringName(data.get("upgrade_kind", active_skill_upgrade_kind))
	var id := StringName(data.get("id", &""))
	if not progression_state.apply_skill_upgrade(kind, id):
		return
	AudioCue.play_sfx(&"upgrade", 0.0)
	if player != null:
		if kind == &"small" and player.has_method("set_small_skill_variant"):
			player.set_small_skill_variant(id)
		elif kind == &"big" and player.has_method("set_big_skill_variant"):
			player.set_big_skill_variant(id)
	active_skill_upgrade_kind = &""
	skill_upgrade_select_controller.clear_state()
	_close_blessing_select()

func _close_blessing_select() -> void:
	if run_context == null:
		return
	_set_blessing_overlay_visible(false)
	_set_overlay_layout_mode(false)
	_set_overlay_visible(false)
	active_skill_upgrade_kind = &""
	run_context.state = LevelContext.LevelState.NIGHT_REST
	get_tree().paused = false
	_update_debug_label()

func _on_blessing_card_mouse_entered(card_index: int) -> void:
	AudioCue.play_ui(&"ui_move")
	if _get_state() == LevelContext.LevelState.GLOBAL_MODIFIER_SELECT:
		global_modifier_select_controller.handle_mouse_enter(card_index)
		return
	if _get_state() == LevelContext.LevelState.BLESSING_SELECT:
		if active_skill_upgrade_kind != &"" and skill_upgrade_select_controller != null:
			skill_upgrade_select_controller.handle_mouse_enter(card_index)
		elif blessing_select_controller != null and blessing_select_controller.has_method("handle_mouse_enter"):
			blessing_select_controller.handle_mouse_enter(card_index)
		return

	if _get_state() == LevelContext.LevelState.MENU_DISH_SELECT:
		if menu_dish_select_controller != null and menu_dish_select_controller.has_method("handle_mouse_enter"):
			menu_dish_select_controller.handle_mouse_enter(card_index)
		return

	if _get_state() == LevelContext.LevelState.NIGHT_PLANNING:
		if night_planning_controller != null and night_planning_controller.has_method("handle_mouse_enter"):
			night_planning_controller.handle_mouse_enter(card_index)
		return

	if _get_state() == LevelContext.LevelState.ORDER_GROUP_SELECT:
		if order_group_select_controller != null and order_group_select_controller.has_method("handle_mouse_enter"):
			order_group_select_controller.handle_mouse_enter(card_index)

func _on_blessing_card_mouse_exited(card_index: int) -> void:
	if _get_state() == LevelContext.LevelState.GLOBAL_MODIFIER_SELECT:
		global_modifier_select_controller.handle_mouse_exit(card_index)
		return
	if _get_state() == LevelContext.LevelState.ORDER_GROUP_SELECT and order_group_select_controller != null and order_group_select_controller.has_method("handle_mouse_exit"):
		order_group_select_controller.handle_mouse_exit(card_index)
		return
	if _get_state() == LevelContext.LevelState.NIGHT_PLANNING and night_planning_controller != null and night_planning_controller.has_method("handle_mouse_exit"):
		night_planning_controller.handle_mouse_exit(card_index)

func _on_blessing_card_gui_input(event: InputEvent, card_index: int) -> void:
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	AudioCue.play_ui()
	if _get_state() == LevelContext.LevelState.GLOBAL_MODIFIER_SELECT:
		if global_modifier_select_controller.handle_click(card_index) >= 0:
			_confirm_global_modifier()
		return

	if _get_state() == LevelContext.LevelState.NIGHT_SHOP and night_shop_controller != null and night_shop_controller.has_method("has_pending_forge") and bool(night_shop_controller.has_pending_forge()):
		night_shop_controller.confirm_forge_selection(card_index)
		return

	if _get_state() == LevelContext.LevelState.BLESSING_SELECT:
		if active_skill_upgrade_kind != &"" and skill_upgrade_select_controller != null:
			if not skill_upgrade_select_controller.handle_click(card_index).is_empty():
				_confirm_selected_skill_upgrade()
		elif blessing_select_controller != null and blessing_select_controller.has_method("handle_click"):
			if not blessing_select_controller.handle_click(card_index).is_empty():
				_confirm_selected_blessing()
		return

	if _get_state() == LevelContext.LevelState.ORDER_GROUP_SELECT:
		if order_group_select_controller != null and order_group_select_controller.has_method("handle_click"):
			if int(order_group_select_controller.handle_click(card_index)) >= 0:
				_confirm_selected_group()
		return

	if _get_state() == LevelContext.LevelState.MENU_DISH_SELECT:
		if menu_dish_select_controller != null and menu_dish_select_controller.has_method("handle_click"):
			if int(menu_dish_select_controller.handle_click(card_index)) >= 0:
				_confirm_selected_menu_dish()
		return

	if _get_state() == LevelContext.LevelState.NIGHT_PLANNING:
		if night_planning_controller != null and night_planning_controller.has_method("handle_click"):
			if int(night_planning_controller.handle_click(card_index)) >= 0:
				_confirm_night_planning_action()

func _set_blessing_overlay_visible(visible: bool) -> void:
	if overlay_controller != null and overlay_controller.has_method("set_blessing_overlay_visible"):
		overlay_controller.set_blessing_overlay_visible(visible)

func _set_overlay_layout_mode(is_blessing_layout: bool) -> void:
	if overlay_controller != null and overlay_controller.has_method("set_layout_mode"):
		overlay_controller.set_layout_mode(is_blessing_layout)

func _set_overlay_visible(visible: bool) -> void:
	if overlay_controller != null and overlay_controller.has_method("set_overlay_visible"):
		overlay_controller.set_overlay_visible(visible)

func handle_night_rest_interaction(interaction_type: StringName) -> void:
	if not is_night_rest_active():
		return

	match interaction_type:
		&"merchant":
			_open_night_shop_overlay()
		&"menu_book":
			menu_return_state = LevelContext.LevelState.NIGHT_REST
			_open_menu_dish_overlay()
		&"task_book":
			menu_return_state = LevelContext.LevelState.NIGHT_REST
			_open_menu_dish_overlay()
		&"blessing_statue":
			# Skill upgrades have priority over ordinary blessing points. This keeps
			# the statue from opening the wrong selection screen when both are ready.
			if progression_state != null and progression_state.has_pending_skill_upgrade():
				_enter_skill_upgrade_select(progression_state.get_pending_skill_upgrade_kind())
			else:
				_enter_blessing_select()

func apply_attribute_forge(option: Dictionary) -> bool:
	if player != null and player.has_method("apply_forged_attribute"):
		player.apply_forged_attribute(option)
		return true
	return false

func get_blessing_points() -> int:
	return progression_state.get_blessing_points() if progression_state != null else 0

func get_owned_blessing_ids() -> Array[StringName]:
	if progression_state == null or not progression_state.has_method("get_owned_blessing_ids"):
		return []
	return progression_state.get_owned_blessing_ids()

func is_night_rest_active() -> bool:
	return run_context != null and run_context.state == LevelContext.LevelState.NIGHT_REST

func should_show_night_rest_objects() -> bool:
	if run_context == null:
		return false
	return run_context.state in [LevelContext.LevelState.NIGHT_REST, LevelContext.LevelState.NIGHT_SHOP]

func _open_night_shop_overlay() -> void:
	if run_context == null:
		return
	run_context.state = LevelContext.LevelState.NIGHT_SHOP
	get_tree().paused = true
	_set_blessing_overlay_visible(false)
	_set_overlay_layout_mode(true)
	_set_overlay_visible(true)
	if night_shop_controller != null and night_shop_controller.has_method("prepare_for_open"):
		night_shop_controller.prepare_for_open(progression_state)
	_update_debug_label()

func _close_night_shop_overlay() -> void:
	if run_context == null:
		return
	run_context.state = LevelContext.LevelState.NIGHT_REST
	get_tree().paused = false
	_set_overlay_visible(false)
	_update_debug_label()

func _on_night_shop_purchase_completed(new_gold: int) -> void:
	if progression_state == null:
		progression_state = RunProgressionState.new()
	progression_state.gold = max(new_gold, 0)
	_update_run_status_hud()
	_update_debug_label()

func _get_active_order_group_index() -> int:
	if order_group_select_controller != null and order_group_select_controller.has_method("get_active_group_index"):
		return int(order_group_select_controller.get_active_group_index())
	return -1

func _refresh_order_groups_for_current_day() -> void:
	var day_index: int = progression_state.day_index if progression_state != null else 0
	var templates := OrderGroupDefs.create_default_order_groups(mini(day_index, 2))
	order_groups.clear()
	progression_state.modifiers.ensure_offers(day_index)
	# A shared base schedule keeps the difficulty choice about risk and reward,
	# rather than silently giving each card a different number of customers.
	var template: Dictionary = templates[0]
	for offer in progression_state.modifiers.day_offers:
		var group := template.duplicate(true)
		group.merge(offer, true)
		group["day_index"] = day_index
		group["detail_text"] = "当前菜单：%s\n\n当日难题不影响特殊客人的独立耐心计时。" % ", ".join(progression_state.get_menu_dish_ids().map(func(id: StringName) -> String: return TestItemDefs.get_item_display_name(id)))
		order_groups.append(group)
	if overlay_controller != null:
		overlay_controller.ensure_card_count(order_groups.size())
	if order_group_select_controller != null and order_group_select_controller.has_method("set_order_groups"):
		order_group_select_controller.set_order_groups(order_groups)
	if order_group_select_controller != null and order_group_select_controller.has_method("set_current_menu_dish_ids") and progression_state != null:
		order_group_select_controller.set_current_menu_dish_ids(progression_state.get_menu_dish_ids())

func _build_order_group_for_current_menu(group_data: Dictionary) -> Dictionary:
	var menu_dish_ids: Array[StringName] = [TestItemDefs.DISH_RED_ID]
	if progression_state != null:
		menu_dish_ids = progression_state.get_menu_dish_ids()
	var monitor_playtest := OS.get_cmdline_user_args().has(MONITOR_PLAYTEST_ARGUMENT)
	var final_boss := monitor_playtest or (progression_state != null and progression_state.day_index == 6)
	# Each confirmed day gets a fresh order sequence. The generator still accepts
	# an explicit seed for deterministic validation, but gameplay should vary
	# between runs instead of replaying the same "random" first day.
	var source_group := group_data.duplicate(true)
	if progression_state != null:
		source_group["day_index"] = progression_state.day_index
	var built_group := OrderGroupDefs.build_group_for_menu(source_group, menu_dish_ids)
	if progression_state != null:
		built_group["run_multipliers"] = {
			&"enemy_move": get_run_modifier_multiplier(&"enemy_move"),
			&"enemy_attack": get_run_modifier_multiplier(&"enemy_attack")}
	if FAST_BUSINESS_TEST:
		built_group["prepare_duration"] = FAST_BUSINESS_PREPARE_DURATION
		built_group["service_duration"] = FAST_BUSINESS_SERVICE_DURATION
		_apply_skill_upgrade_playtest_group(built_group)
	if progression_state != null and progression_state.events.PLAYTEST_BATCH > 0 and progression_state.day_index == 0:
		built_group["prepare_duration"] = 5.0
		built_group["service_duration"] = 90.0
	var event_multiday_test: bool = progression_state != null and (progression_state.events.SECOND_NIGHT_PLAYTEST or progression_state.events.ALL_EVENTS_PLAYTEST) and progression_state.day_index <= 4 and not monitor_playtest
	if event_multiday_test:
		built_group["prepare_duration"] = 5.0
		built_group["service_duration"] = 20.0
		# Every completed order can fund another blessing choice through the
		# normal reward path; keep the random menu, customers and day progression.
		for wave: Dictionary in built_group.get("waves", []):
			for order: Dictionary in wave.get("orders", []):
				order["xp_reward"] = 60
	if progression_state != null:
		built_group["map_mechanism_ids"] = progression_state.get_active_map_mechanism_ids()
		built_group["boss_enhanced_map_mechanism_id"] = progression_state.get_boss_enhanced_map_mechanism_id()
	else:
		built_group["map_mechanism_ids"] = []
		built_group["boss_enhanced_map_mechanism_id"] = &""
	if final_boss:
		built_group["boss_enhanced_map_mechanism_id"] = &"monitor"
		built_group["final_boss"] = true
		built_group["display_name"] = "第七日 · 沙海终宴"
		if monitor_playtest:
			built_group["map_mechanism_ids"] = []
			built_group["prepare_duration"] = 8.0
			built_group["service_duration"] = 20.0
	if FIRST_DAY_BOSS_DISABLED_PLAYTEST and progression_state != null and progression_state.day_index == 0 and not monitor_playtest:
		built_group["boss_enhanced_map_mechanism_id"] = &""
		built_group.erase("boss_special_orders")
		built_group.erase("boss_special_guest")
		built_group.erase("boss_special_guest_id")
	if event_multiday_test:
		built_group["boss_enhanced_map_mechanism_id"] = &""
		built_group.erase("boss_special_orders")
		built_group.erase("boss_special_guest")
		built_group.erase("boss_special_guest_id")
	if built_group.get("boss_enhanced_map_mechanism_id", &"") != &"":
		built_group = OrderGroupDefs.append_boss_special_orders(built_group, StringName(built_group["boss_enhanced_map_mechanism_id"]))
	if scarab_mechanism_controller != null and scarab_mechanism_controller.has_method("configure_for_level"):
		scarab_mechanism_controller.configure_for_level(built_group, progression_state)
	if quicksand_mechanism_controller != null and quicksand_mechanism_controller.has_method("configure_for_level"):
		quicksand_mechanism_controller.configure_for_level(built_group)
	if wind_sand_mechanism_controller != null and wind_sand_mechanism_controller.has_method("configure_for_level"):
		wind_sand_mechanism_controller.configure_for_level(built_group)
	_remap_order_targets_to_unlocked_serving_counters(built_group)
	return built_group

func _apply_skill_upgrade_playtest_group(built_group: Dictionary) -> void:
	# Keep the first two days focused on progression testing: one customer is
	# enough to finish the day, while the large XP reward also creates blessing
	# points before the day-2 skill upgrade checkpoint.
	if progression_state == null or progression_state.day_index > 1:
		return
	var source_waves: Variant = built_group.get("waves", [])
	if not source_waves is Array or source_waves.is_empty():
		return
	var first_wave: Dictionary = source_waves[0].duplicate(true) if source_waves[0] is Dictionary else {}
	var source_orders: Variant = first_wave.get("orders", [])
	if not source_orders is Array or source_orders.is_empty():
		return
	var test_order: Dictionary = source_orders[0].duplicate(true)
	test_order["xp_reward"] = SKILL_UPGRADE_PLAYTEST_XP
	test_order["gold_reward"] = maxi(int(test_order.get("gold_reward", 0)), 100)
	test_order["order_take_patience_duration"] = SKILL_UPGRADE_PLAYTEST_TAKE_DURATION
	test_order["patience_duration"] = 120.0
	first_wave["orders"] = [test_order]
	first_wave["wave_number"] = 1
	built_group["waves"] = [first_wave]
	built_group["wave_break_duration"] = 0.2

func get_active_map_mechanism_ids() -> Array[StringName]:
	if run_context != null and run_context.has_method("get_active_map_mechanism_ids"):
		return run_context.get_active_map_mechanism_ids()
	if progression_state == null or not progression_state.has_method("get_active_map_mechanism_ids"):
		return []
	return progression_state.get_active_map_mechanism_ids()

func get_boss_enhanced_map_mechanism_id() -> StringName:
	if run_context != null and run_context.has_method("get_boss_enhanced_map_mechanism_id"):
		return run_context.get_boss_enhanced_map_mechanism_id()
	if progression_state == null or not progression_state.has_method("get_boss_enhanced_map_mechanism_id"):
		return &""
	return progression_state.get_boss_enhanced_map_mechanism_id()

func get_active_map_mechanism_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mechanism_id in get_active_map_mechanism_ids():
		result.append(MapMechanismDefs.get_definition(mechanism_id))
	return result

func _remap_order_targets_to_unlocked_serving_counters(group_data: Dictionary) -> void:
	var unlocked_count: int = _get_unlocked_serving_counter_count()
	var waves: Variant = group_data.get("waves", [])
	if not (waves is Array):
		return
	var order_index: int = 0
	var special_orders: Array = group_data.get("boss_special_orders", [])
	var has_special_guest := not special_orders.is_empty()
	for order_data: Dictionary in special_orders:
		order_data["target_slot"] = 1
	for wave_data in waves:
		if not (wave_data is Dictionary):
			continue
		for order_data in wave_data.get("orders", []):
			if order_data is Dictionary and bool(order_data.get("special_guest", false)):
				has_special_guest = true
				break
		if has_special_guest:
			break
	var regular_slot_count: int = maxi(unlocked_count - (1 if has_special_guest else 0), 1)
	for wave_data in waves:
		if not (wave_data is Dictionary):
			continue
		var orders: Variant = wave_data.get("orders", [])
		if not (orders is Array):
			continue
		var customer_slots: Dictionary = {}
		for order_data in orders:
			if not (order_data is Dictionary):
				continue
			if bool(order_data.get("special_guest", false)):
				order_data["target_slot"] = 1
				continue
			var batch_id := String(order_data.get("customer_batch_id", order_data.get("order_id", "")))
			if not customer_slots.has(batch_id):
				customer_slots[batch_id] = (order_index % regular_slot_count) + (2 if has_special_guest else 1)
				order_index += 1
			order_data["target_slot"] = customer_slots[batch_id]

func _sync_storage_cabinets_to_current_menu() -> void:
	var ingredient_ids := _collect_current_menu_ingredient_ids()
	for cabinet in get_tree().get_nodes_in_group("storage_facilities"):
		if is_instance_valid(cabinet) and cabinet.has_method("set_menu_allowed_item_ids"):
			cabinet.set_menu_allowed_item_ids(ingredient_ids)

func _sync_kitchen_unlocks_to_current_menu() -> void:
	# The first region gives all three processing stations from the start.
	for facility in get_tree().get_nodes_in_group("cooking_stations"):
		if not is_instance_valid(facility):
			continue
		if not facility.has_method("get_station_process_state"):
			continue
		_set_runtime_facility_visible(facility, true)
	_sync_serving_counters_to_day()

func _sync_serving_counters_to_day() -> void:
	var unlocked_count: int = _get_unlocked_serving_counter_count()
	for counter in get_tree().get_nodes_in_group("serving_counters"):
		if not is_instance_valid(counter):
			continue
		var slot_offset: int = int(counter.get("slot_number_offset"))
		_set_runtime_facility_visible(counter, slot_offset < unlocked_count)

func _get_unlocked_serving_counter_count() -> int:
	var unlocked_count: int = max(base_serving_counter_count, 1)
	if progression_state != null:
		unlocked_count = base_serving_counter_count + progression_state.day_index
	return clampi(unlocked_count, 1, 8)

func _set_runtime_facility_visible(node: Node, is_visible: bool) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = is_visible
	_set_collision_enabled_recursive(node, is_visible)

func _set_collision_enabled_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionShape2D:
		(node as CollisionShape2D).disabled = not enabled
	for child in node.get_children():
		_set_collision_enabled_recursive(child, enabled)

func _collect_current_menu_ingredient_ids() -> Array[StringName]:
	var menu_dish_ids: Array[StringName] = progression_state.get_menu_dish_ids() if progression_state != null else [TestItemDefs.DISH_RED_ID]
	if run_context != null:
		for order: Dictionary in run_context.selected_order_group.get("boss_special_orders", []):
			var dish := StringName(order.dish_item_id)
			if dish not in menu_dish_ids:
				menu_dish_ids.append(dish)
	return MenuRequirementsQuery.collect_ingredient_ids(menu_dish_ids)

func _update_debug_label() -> void:
	if overlay_controller == null:
		return
	var selected_group_name: String = "无"
	if run_context == null:
		var active_group_index: int = _get_active_order_group_index()
		if active_group_index >= 0 and active_group_index < order_groups.size():
			selected_group_name = String(order_groups[active_group_index].get("display_name", ""))
	overlay_controller.update_debug_status(run_context, progression_state, selected_group_name, prepare_time_remaining, wave_break_time_remaining)

func _update_run_status_hud() -> void:
	if run_status_hud == null:
		return
	run_status_hud.update_run_status(run_context, progression_state, player, magic_current, magic_max)
	_update_day_clock()

func _update_day_clock() -> void:
	if run_status_hud != null:
		var special_clock: Dictionary = order_manager.get_special_guest_clock() if order_manager != null else {}
		run_status_hud.update_day_clock(run_context, day_time_remaining, _get_prepare_duration(), _get_service_duration(), special_clock)

func can_spend_magic(amount: int) -> bool:
	return magic_current >= maxi(amount, 0)

func get_current_level_state() -> int:
	return _get_state()

func spend_magic(amount: int) -> bool:
	var cost: int = maxi(amount, 0)
	if cost <= 0:
		return true
	if magic_current < cost:
		return false
	magic_current -= cost
	var blessing_runtime: RefCounted = player.get_blessing_controller() if player != null and player.has_method("get_blessing_controller") else null
	if blessing_runtime != null:
		magic_current = mini(magic_current + blessing_runtime.on_magic_spent(cost), magic_max)
	_update_run_status_hud()
	return true

func add_magic(amount: int) -> void:
	magic_current = mini(magic_current + maxi(amount, 0), maxi(magic_max, 1))
	_update_run_status_hud()

func adjust_skill_magic(amount: int) -> int:
	# Refunds and random fluctuations are not another skill cast or magic-spend event.
	var previous_magic: int = magic_current
	magic_current = clampi(magic_current + amount, 0, maxi(magic_max, 1))
	_update_run_status_hud()
	return magic_current - previous_magic

func add_blessing_gold(amount: int) -> void:
	if progression_state != null:
		progression_state.add_gold(amount)
		_update_run_status_hud()

func get_order_manager_for_blessings() -> Node:
	return order_manager

func get_magic_ratio_for_blessings() -> float:
	return float(magic_current) / float(maxi(magic_max, 1))

func is_service_active_for_blessings() -> bool:
	return _get_state() in [LevelContext.LevelState.WAVE_ACTIVE, LevelContext.LevelState.WAVE_BREAK]

func add_magic_capacity_bonus(amount: int) -> void:
	magic_max = maxi(magic_max + maxi(amount, 0), 1)
	_refill_magic()
	_update_run_status_hud()

func add_magic_regen_multiplier(multiplier: float) -> void:
	var safe_multiplier: float = maxf(multiplier, 0.01)
	magic_regen_interval = maxf(magic_regen_interval / safe_multiplier, 0.5)
	magic_regen_remaining = minf(magic_regen_remaining, magic_regen_interval)
	_update_run_status_hud()

func add_support_facility_aura_multiplier(multiplier: float) -> void:
	support_facility_aura_multiplier *= maxf(multiplier, 0.01)
	_sync_support_facility_bonuses()

func add_barrel_serving_bonus(amount: int) -> void:
	barrel_serving_bonus = maxi(barrel_serving_bonus + maxi(amount, 0), 0)
	_sync_barrel_serving_bonus()

func _sync_barrel_serving_bonus() -> void:
	for barrel in get_tree().get_nodes_in_group("drink_barrels"):
		if is_instance_valid(barrel) and barrel.has_method("set_extra_servings_per_fill"):
			barrel.set_extra_servings_per_fill(barrel_serving_bonus)

func _sync_support_facility_bonuses() -> void:
	for support in get_tree().get_nodes_in_group("support_facilities"):
		if is_instance_valid(support) and support.has_method("set_aura_multiplier"):
			support.set_aura_multiplier(support_facility_aura_multiplier)

func _refill_magic() -> void:
	magic_current = maxi(magic_max, 1)
	magic_regen_remaining = maxf(magic_regen_interval, 0.01)

func _update_magic(delta: float) -> void:
	if _get_state() not in [
		LevelContext.LevelState.PREPARE_PHASE,
		LevelContext.LevelState.WAVE_ACTIVE,
		LevelContext.LevelState.WAVE_BREAK
	]:
		return
	if magic_current >= magic_max:
		magic_regen_remaining = maxf(magic_regen_interval, 0.01)
		return
	magic_regen_remaining = maxf(magic_regen_remaining - delta, 0.0)
	if magic_regen_remaining > 0.0:
		return
	add_magic(1)
	magic_regen_remaining = maxf(magic_regen_interval, 0.01)

func purchase_support_facility(item_data: Dictionary) -> bool:
	var type: StringName = StringName(item_data.get("facility_type", &""))
	if not preload("res://Scripts/Facilities/FacilityCatalog.gd").definition(type).is_empty():
		return preload("res://Scripts/Facilities/FacilityPurchase.gd").purchase(self, type)
	if not EQUIPMENT_SCENES.has(type) and type not in [&"conveyor", &"lamp"]:
		return false
	var equipment_scene: PackedScene = EQUIPMENT_SCENES.get(type, SUPPORT_FACILITY_SCENE)
	var facility: Node2D = equipment_scene.instantiate()
	if EQUIPMENT_SCENES.has(type):
		facility.scale = Vector2.ONE * (0.21 if type == &"prep_table" else 0.17)
	if facility == null:
		return false
	var scene_root: Node = level_refs.get_runtime_root() if level_refs != null else get_tree().current_scene
	if scene_root == null:
		facility.queue_free()
		return false
	scene_root.add_child(facility)
	if EQUIPMENT_SCENES.has(type):
		facility.reset_state()
		if type != &"prep_table":
			facility.set("processing_speed_multiplier", kitchen_processing_speed_multiplier)
	else:
		_configure_support_facility(facility, item_data)
	if facility.has_method("set_aura_multiplier"):
		facility.set_aura_multiplier(support_facility_aura_multiplier)
	var spawn_position := _find_support_facility_spawn_position(facility)
	if spawn_position == Vector2.INF:
		facility.queue_free()
		return false
	facility.global_position = spawn_position
	return true

func can_summon_flyer_customer() -> bool:
	return _get_flyer_slot() > 0 and _get_state() == LevelContext.LevelState.WAVE_ACTIVE

func _get_flyer_slot() -> int:
	if order_manager == null or run_context == null:
		return -1
	var first := 2 if not Array(run_context.selected_order_group.get("boss_special_orders", [])).is_empty() else 1
	for slot in range(first, _get_unlocked_serving_counter_count() + 1):
		if not order_manager.customers.has("slot:%d" % slot):
			return slot
	return -1

func summon_flyer_customer() -> bool:
	if not can_summon_flyer_customer():
		return false
	var menu: Array = progression_state.get_menu_dish_ids() if progression_state != null else [TestItemDefs.DISH_RED_ID]
	menu = menu.filter(func(dish_id: StringName) -> bool: return not TestItemDefs.is_dessert(dish_id))
	if menu.is_empty():
		return false
	var order: Dictionary = OrderGroupDefs._order("flyer_%d" % Time.get_ticks_usec(), _get_flyer_slot(), StringName(menu.pick_random()), 0)
	order["facility_reward_multiplier"] = 1.05
	order_manager.add_orders([order])
	return true

func purchase_kitchen_upgrade(item_data: Dictionary) -> bool:
	match StringName(item_data.get("upgrade_id", &"")):
		&"magic_capacity":
			add_magic_capacity_bonus(1)
			return true
		&"magic_regen":
			add_magic_regen_multiplier(1.12)
			return true
		&"station_speed":
			kitchen_processing_speed_multiplier *= 1.15
			for station: Node in get_tree().get_nodes_in_group("cooking_stations"):
				station.set("processing_speed_multiplier", kitchen_processing_speed_multiplier)
			return true
	return false

func _configure_support_facility(facility: Node2D, item_data: Dictionary) -> void:
	facility.set("facility_type", StringName(item_data.get("facility_type", &"conveyor")))
	facility.set("display_name", String(item_data.get("title", "支援设施")))
	match StringName(item_data.get("facility_type", &"")):
		&"conveyor":
			facility.set("base_color", Color(0.34, 0.30, 0.24, 1.0))
			facility.set("accent_color", Color(0.98, 0.72, 0.24, 1.0))
			facility.set("aura_color", Color(1.0, 0.72, 0.24, 0.14))
			facility.set("movement_speed_multiplier", 1.18)
		&"lamp":
			facility.set("base_color", Color(0.32, 0.28, 0.23, 1.0))
			facility.set("accent_color", Color(1.0, 0.88, 0.46, 1.0))
			facility.set("aura_color", Color(1.0, 0.84, 0.34, 0.16))
			facility.set("cook_speed_multiplier", 1.22)

func _find_support_facility_spawn_position(facility: Node2D) -> Vector2:
	var prototype_map: Node = level_refs.get_prototype_map() if level_refs != null else null
	if prototype_map == null or not prototype_map.has_method("get_cell_for_point"):
		return Vector2.INF
	var origin_cell: Vector2i = prototype_map.get_cell_for_point(support_facility_spawn_origin)
	var footprint: Vector2i = Vector2i(1, 1)
	if facility.has_method("get_layout_footprint"):
		footprint = facility.get_layout_footprint()
	var search_cells: int = maxi(support_facility_spawn_search_cells, 1)
	for ring in range(search_cells + 1):
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if abs(x) != ring and abs(y) != ring:
					continue
				var cell := origin_cell + Vector2i(x, y)
				var tile_size: Vector2 = prototype_map.get_tile_size()
				var position: Vector2 = prototype_map.to_global((Vector2(cell) + Vector2(footprint) * 0.5) * tile_size)
				if _is_support_facility_spawn_clear(facility, prototype_map, cell, footprint, position):
					return position
	return Vector2.INF

func _is_support_facility_spawn_clear(facility: Node2D, prototype_map: Node, top_left_cell: Vector2i, footprint: Vector2i, position: Vector2) -> bool:
	# Newly constructed paired endpoints must reserve their cells immediately,
	# before the physics server has completed its next synchronization step.
	var candidate_rect := Rect2(position - Vector2(footprint) * 64 + Vector2.ONE, Vector2(footprint) * 128 - Vector2.ONE * 2)
	for other: Node2D in get_tree().get_nodes_in_group("new_facilities"):
		if other == facility or not other.active():
			continue
		var other_size: Vector2 = Vector2(other.get_layout_footprint()) * 128
		if candidate_rect.intersects(Rect2(other.global_position - other_size * 0.5, other_size)):
			return false
	if facility.has_method("validate_placement") and not facility.validate_placement(position):
		return false
	if prototype_map.has_method("is_cell_editable_for_facility"):
		for y in range(footprint.y):
			for x in range(footprint.x):
				if not bool(prototype_map.is_cell_editable_for_facility(top_left_cell + Vector2i(x, y), facility)):
					return false
	var query_shape := RectangleShape2D.new()
	query_shape.size = Vector2(104.0, 104.0)
	if facility.has_method("get_layout_footprint"):
		var tile_size: Vector2 = prototype_map.get_tile_size() if prototype_map.has_method("get_tile_size") else Vector2(128, 128)
		query_shape.size = Vector2(footprint) * tile_size * 0.82
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = Transform2D(0.0, position)
	query.collision_mask = 1 | 2 | 4 | 8 | 16
	query.exclude = [facility.get_rid()] if facility is CollisionObject2D else []
	var hits: Array[Dictionary] = facility.get_world_2d().direct_space_state.intersect_shape(query, 24)
	return hits.is_empty()

func _get_state() -> int:
	if run_context == null:
		return LevelContext.LevelState.ORDER_GROUP_SELECT
	return run_context.state

func _sync_progression_from_run_context(advance_day: bool = true) -> void:
	if run_setup_controller == null or not run_setup_controller.has_method("build_progression_snapshot"):
		return
	var snapshot: Dictionary = run_setup_controller.build_progression_snapshot(run_context, progression_state.day_index, progression_state, advance_day)
	if progression_state == null:
		progression_state = RunProgressionState.new()
	progression_state.apply_snapshot(snapshot)
	_sync_owned_blessings_to_player()
	_sync_skill_variants_to_player()

func _sync_owned_blessings_to_player() -> void:
	if player == null or progression_state == null or not player.has_method("set_owned_blessings_for_run"):
		return
	player.set_owned_blessings_for_run(progression_state.get_owned_blessing_ids())
	if player.has_method("set_event_max_health_penalty"):
		player.set_event_max_health_penalty(progression_state.events.max_health_penalty)

func _sync_skill_variants_to_player() -> void:
	if player == null or progression_state == null:
		return
	if player.has_method("set_small_skill_variant"):
		player.set_small_skill_variant(progression_state.small_skill_variant)
	if player.has_method("set_big_skill_variant"):
		player.set_big_skill_variant(progression_state.big_skill_variant)
