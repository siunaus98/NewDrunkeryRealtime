extends SceneTree

const Context = preload("res://Scripts/Core/LevelContext.gd")
var failures: Array[String] = []

class CostPlayer extends Node:
	var cost: int = 0
	func get_carried_facility_magic_cost() -> int:
		return cost

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_stop_ticks(child)

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	_stop_ticks(main)
	var flow: Node = main.get_node("LevelFlowController")
	var hud: Node = flow.run_status_hud
	var overlay: Node = flow.overlay_controller
	var context: Context = flow.run_context
	var progression: RefCounted = flow.progression_state
	progression.gold = 321
	progression.level = 4
	progression.xp = 25
	progression.xp_for_next_level = 100
	progression.blessing_points = 2
	context.reputation = 23
	context.reputation_max = 100
	context.danger_active = true
	context.danger_time_remaining = 7.5
	flow.prepare_time_remaining = 12.5
	flow.wave_break_time_remaining = 3.5
	flow.day_time_remaining = 142.5
	flow.magic_current = 2
	flow.magic_max = 8
	var cost_player := CostPlayer.new()
	main.add_child(cost_player)
	cost_player.cost = 3
	flow.player = cost_player
	var hidden_states: Array[int] = [Context.LevelState.ORDER_GROUP_SELECT, Context.LevelState.NIGHT_SHOP, Context.LevelState.MENU_DISH_SELECT, Context.LevelState.BLESSING_SELECT, Context.LevelState.GLOBAL_MODIFIER_SELECT, Context.LevelState.LEVEL_SUCCESS, Context.LevelState.LEVEL_FAILED]
	var daytime_states: Array[int] = [Context.LevelState.PREPARE_PHASE, Context.LevelState.WAVE_ACTIVE, Context.LevelState.WAVE_BREAK]
	var before: Dictionary = progression.get_snapshot().duplicate(true)
	for state in Context.LevelState.values():
		context.state = state
		flow._update_run_status_hud()
		flow._update_debug_label()
		_check(hud.visible == (state not in hidden_states), "HUD visibility changed for state %d." % state)
		_check(hud.day_clock.visible == (state in daytime_states), "Clock visibility changed for state %d." % state)
		_check(hud.gold_value_label.text == "321" and hud.xp_value_label.text == "25 / 100", "Gold and XP must reflect progression.")
		_check(hud.xp_level_label.text == "等级 4   祝福点 2", "Level and blessing points must use the current progression.")
		_check(is_equal_approx(hud.xp_fill.size.x, 126.0), "XP bar must show 25 percent.")
		_check(hud.reputation_state_label.text == "危险" and hud.reputation_value_label.text == "23 / 100", "Danger display must follow the context.")
		_check(hud.magic_preview_cost == 3 and not hud.magic_preview_can_afford, "Unaffordable facility cost must remain a warning.")
		_check(flow.magic_current == 2 and context.reputation == 23, "Refreshing displays must not mutate gameplay values.")
		_check(overlay.debug_label.text.contains("危险倒计时：7.5 秒"), "Debug danger text must be preserved.")
		if state == Context.LevelState.PREPARE_PHASE:
			_check(hud.day_clock.progress_layer.phase_text == "备菜" and overlay.debug_label.text.contains("准备时间：12.5 秒"), "Preparation display must retain its phase and timer.")
		if state == Context.LevelState.WAVE_BREAK:
			_check(hud.day_clock.progress_layer.phase_text == "营业" and overlay.debug_label.text.contains("波间休整：3.5 秒"), "Wave break must keep the service clock and debug timer.")
		_check(is_equal_approx(hud.day_clock.progress_layer.remaining, 142.5), "Clock must receive the current remaining duration.")
	_check(before == progression.get_snapshot(), "Rendering must not alter progression.")
	context.state = Context.LevelState.PREPARE_PHASE
	flow.magic_current = 5
	flow._update_run_status_hud()
	_check(hud.magic_preview_can_afford and hud.magic_value_label.text == "5 / 8  -3", "Affordable preview must show its pending cost without spending it.")
	cost_player.cost = -1
	progression.xp_for_next_level = 0
	flow._update_run_status_hud()
	_check(hud.magic_preview_cost == 0 and is_zero_approx(hud.xp_fill.size.x), "Invalid preview cost and zero XP threshold must remain safe.")
	flow.run_context = null
	flow._update_run_status_hud()
	flow._update_debug_label()
	_check(not hud.visible and not hud.day_clock.visible and hud.gold_value_label.text == "0", "Missing context must clear and hide status.")
	_check(overlay.debug_label.text.begins_with("状态：ORDER_GROUP_SELECT\n已选订单组："), "Missing context must retain order selection debug text.")
	flow.run_context = context
	flow._update_run_status_hud()
	_check(hud.visible and hud.gold_value_label.text == "321", "A replacement context must refresh from live data.")
	main.queue_free()
	paused = false
	await process_frame
	if failures.is_empty():
		print("PASS: all-state HUD/clock visibility, progression, danger, magic preview without charge, debug text, zero thresholds and context replacement.")
	quit(0 if failures.is_empty() else 1)
