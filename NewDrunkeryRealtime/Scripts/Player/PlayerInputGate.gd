extends RefCounted

var blocked_actions: Dictionary[StringName, int] = {}
var hint_key_blocked: bool = false

func refresh() -> void:
	for action: StringName in blocked_actions.keys():
		is_blocked(action)

func capture_menu_inputs() -> void:
	for action: StringName in InputMap.get_actions():
		if Input.is_action_pressed(action) or Input.is_action_just_pressed(action) or Input.is_action_just_released(action):
			blocked_actions[action] = Engine.get_process_frames()
	hint_key_blocked = hint_key_blocked or Input.is_key_pressed(KEY_L) or Input.is_physical_key_pressed(KEY_L)

func is_blocked(action: StringName) -> bool:
	if not blocked_actions.has(action):
		return false
	# Keep release edges out of gameplay too: releasing a menu attack must
	# not finish an attack charge. Other actions remain immediately usable.
	if not Input.is_action_pressed(action) and not Input.is_action_just_pressed(action) and not Input.is_action_just_released(action) and Engine.get_process_frames() > blocked_actions[action]:
		blocked_actions.erase(action)
		return false
	return true

func is_pressed(action: StringName) -> bool:
	return not is_blocked(action) and Input.is_action_pressed(action)

func is_just_pressed(action: StringName) -> bool:
	return not is_blocked(action) and Input.is_action_just_pressed(action)

func is_just_released(action: StringName) -> bool:
	return not is_blocked(action) and Input.is_action_just_released(action)

func is_source_hint_pressed() -> bool:
	var pressed: bool = Input.is_key_pressed(KEY_L) or Input.is_physical_key_pressed(KEY_L)
	if not pressed:
		hint_key_blocked = false
	return pressed and not hint_key_blocked

func get_movement() -> Vector2:
	var actions: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
	var strengths: Array[float] = []
	var deadzone: float = 0.0
	for action: StringName in actions:
		strengths.append(0.0 if is_blocked(action) else Input.get_action_raw_strength(action))
		deadzone += InputMap.action_get_deadzone(action) * 0.25
	var direction := Vector2(strengths[1] - strengths[0], strengths[3] - strengths[2])
	var length: float = direction.length()
	if length <= deadzone:
		return Vector2.ZERO
	if length > 1.0:
		return direction / length
	return direction * inverse_lerp(deadzone, 1.0, length) / length
