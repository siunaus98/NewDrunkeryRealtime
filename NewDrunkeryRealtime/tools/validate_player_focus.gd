extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_stop_ticks(child)

func _key(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_D
	event.physical_keycode = KEY_D
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	paused = false
	_stop_ticks(main)
	var player: CharacterBody2D = main.get_node("Player")
	var combat: RefCounted = player.combat_controller
	player.global_position = Vector2(3600, 1000)
	player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_key(true)
	await physics_frame
	player._physics_process(1.0 / 60.0)
	_check(player.movement_input_direction == Vector2.RIGHT and player.velocity.x > 0.0, "A physical movement key must move the player before focus loss.")
	combat.begin_attack_hold(Vector2.RIGHT)
	Input.action_press("interact")
	Input.action_press("pickup_drop")
	player.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(not player.window_input_focused and player.velocity == Vector2.ZERO and player.movement_input_direction == Vector2.ZERO, "Focus loss immediately clears cached movement and velocity.")
	_check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("interact") and not Input.is_action_pressed("pickup_drop") and not combat.is_attack_button_held, "Focus loss releases actions and cancels a held attack without firing it.")
	var position: Vector2 = player.global_position
	# Simulate a delayed event arriving after focus was already lost.
	_key(true, true)
	await physics_frame
	player._physics_process(1.0 / 60.0)
	_check(player.global_position == position and player.movement_input_direction == Vector2.ZERO, "Input arriving in the background cannot move the player.")
	player.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await physics_frame
	player._physics_process(1.0 / 60.0)
	_check(player.global_position == position and not Input.is_action_pressed("move_right"), "Returning without a new movement press must not resume stale input.")
	_key(false)
	_key(true)
	await physics_frame
	player._physics_process(1.0 / 60.0)
	_check(player.global_position.x > position.x, "A new physical key press after returning must work normally.")
	combat.dash_cooldown_remaining = 0.0
	combat.try_dash(Vector2.RIGHT, Vector2.RIGHT)
	var cooldown: float = combat.dash_cooldown_remaining
	player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not combat.is_dash_active() and combat.dash_cooldown_remaining == cooldown, "Focus loss cancels an input-driven dash while preserving its cooldown.")
	player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_key(false)
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: physical-key movement, window/application focus loss, background input rejection, clean refocus, fresh-key movement and attack/dash cancellation.")
	quit(0 if failures.is_empty() else 1)
