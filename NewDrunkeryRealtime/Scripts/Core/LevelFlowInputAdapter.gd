extends RefCounted

const LevelContext = preload("res://Scripts/Core/LevelContext.gd")

enum Action { NONE, CONSUME, CANCEL, CONFIRM, LEFT, RIGHT, UP, DOWN, PREVIOUS_CATEGORY, NEXT_CATEGORY, SCROLL_UP, SCROLL_DOWN, TOGGLE_MENU, REFRESH }

## Translates input only. Flow state, selection and transition guards stay with the host.
static func decode(event: InputEvent, state: int, forge_pending: bool = false) -> Action:
	if event.is_echo() or _is_modifier_only_key_event(event):
		return Action.NONE
	match state:
		LevelContext.LevelState.NIGHT_EVENT:
			if _is_cancel_pressed(event):
				return Action.CANCEL
			if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
				return Action.UP
			if event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
				return Action.DOWN
			if event.is_action_pressed("ui_confirm") or _is_key_pressed(event, KEY_J):
				return Action.CONFIRM
			return Action.CONSUME
		LevelContext.LevelState.NIGHT_SHOP:
			if _is_cancel_pressed(event):
				return Action.CANCEL
			if forge_pending:
				if event.is_action_pressed("ui_navigate_left"):
					return Action.LEFT
				if event.is_action_pressed("ui_navigate_right"):
					return Action.RIGHT
				if event.is_action_pressed("ui_confirm"):
					return Action.CONFIRM
				return Action.CONSUME
			if _is_key_pressed(event, KEY_Q):
				return Action.PREVIOUS_CATEGORY
			if _is_key_pressed(event, KEY_E):
				return Action.NEXT_CATEGORY
			if event.is_action_pressed("ui_navigate_left"):
				return Action.LEFT
			if event.is_action_pressed("ui_navigate_right"):
				return Action.RIGHT
			if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
				return Action.UP
			if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
				return Action.DOWN
			if event.is_action_pressed("ui_confirm"):
				return Action.CONFIRM
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					return Action.SCROLL_UP
				if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					return Action.SCROLL_DOWN
		LevelContext.LevelState.NIGHT_PLANNING, LevelContext.LevelState.ORDER_GROUP_SELECT, LevelContext.LevelState.BLESSING_SELECT, LevelContext.LevelState.GLOBAL_MODIFIER_SELECT:
			if _is_cancel_pressed(event) or (state == LevelContext.LevelState.ORDER_GROUP_SELECT and event.is_action_pressed("interact")):
				return Action.CANCEL
			if _is_key_pressed(event, KEY_L):
				if state == LevelContext.LevelState.ORDER_GROUP_SELECT:
					return Action.TOGGLE_MENU
				if state == LevelContext.LevelState.BLESSING_SELECT:
					return Action.REFRESH
			if event.is_action_pressed("ui_navigate_left"):
				return Action.LEFT
			if event.is_action_pressed("ui_navigate_right"):
				return Action.RIGHT
			if event.is_action_pressed("ui_confirm") or _is_key_pressed(event, KEY_J):
				return Action.CONFIRM
		LevelContext.LevelState.MENU_DISH_SELECT:
			if _is_key_pressed(event, KEY_R):
				return Action.REFRESH
			if _is_cancel_pressed(event) or event.is_action_pressed("interact"):
				return Action.CANCEL
			if _is_key_pressed(event, KEY_L):
				return Action.TOGGLE_MENU
			if event.is_action_pressed("ui_navigate_left") or _is_key_pressed(event, KEY_A):
				return Action.LEFT
			if event.is_action_pressed("ui_navigate_right") or _is_key_pressed(event, KEY_D):
				return Action.RIGHT
			if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up") or _is_key_pressed(event, KEY_W):
				return Action.UP
			if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down") or _is_key_pressed(event, KEY_S):
				return Action.DOWN
			if _is_key_pressed(event, KEY_J) or event.is_action_pressed("ui_confirm"):
				return Action.CONFIRM
		LevelContext.LevelState.LEVEL_SUCCESS, LevelContext.LevelState.LEVEL_FAILED:
			if event.is_action_pressed("ui_confirm"):
				return Action.CONFIRM
	return Action.NONE

static func should_suppress_player_interaction(event: InputEvent, state: int) -> bool:
	return not event.is_echo() and not _is_modifier_only_key_event(event) and _is_key_pressed(event, KEY_K) and state in [
		LevelContext.LevelState.NIGHT_SHOP,
		LevelContext.LevelState.NIGHT_PLANNING,
		LevelContext.LevelState.ORDER_GROUP_SELECT,
		LevelContext.LevelState.MENU_DISH_SELECT,
		LevelContext.LevelState.BLESSING_SELECT,
		LevelContext.LevelState.GLOBAL_MODIFIER_SELECT,
		LevelContext.LevelState.NIGHT_EVENT
	]

static func should_toggle_orders(event: InputEvent) -> bool:
	return event != null and not event.is_echo() and event.is_action_pressed("toggle_orders")

static func is_toggle_orders_key_down() -> bool:
	return Input.is_physical_key_pressed(Key.KEY_TAB) or Input.is_key_pressed(Key.KEY_TAB)

static func _is_cancel_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or _is_key_pressed(event, KEY_K)

static func _is_modifier_only_key_event(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed:
		return false
	return key_event.keycode in [KEY_ALT, KEY_SHIFT, KEY_CTRL, KEY_META] or key_event.physical_keycode in [KEY_ALT, KEY_SHIFT, KEY_CTRL, KEY_META]

static func _is_key_pressed(event: InputEvent, keycode: Key) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and (key_event.keycode == keycode or key_event.physical_keycode == keycode)
