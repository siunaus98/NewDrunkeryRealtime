extends SceneTree

const Cards = preload("res://Scripts/UI/ReadinessCards.gd")
const Defs = preload("res://Scripts/Tutorial/DayBriefingDefs.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func key() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	return event

func run() -> void:
	check(Defs.cards_for_day({"map_mechanism_ids": []}).is_empty(), "Ordinary mechanism-free day needs no briefing")
	var entries: Array[Dictionary] = Defs.cards_for_day({"map_mechanism_ids": [&"scarab", &"sandstorm", &"quicksand"], "boss_enhanced_map_mechanism_id": &"monitor"})
	check(entries.size() == 4, "Three mechanisms and boss receive cards without a special customer repeat")
	var seen := {&"scarab": true, &"sandstorm": true, &"quicksand": true}
	check(Defs.cards_for_day({"map_mechanism_ids": [&"scarab", &"sandstorm", &"quicksand"]}, seen).is_empty(), "Previously read mechanisms are not repeated")
	check(Defs.cards_for_day({"map_mechanism_ids": [&"scarab"], "boss_enhanced_map_mechanism_id": &"scarab"}, seen).size() == 1, "Boss briefing remains even when its mechanism was read")
	for entry: Dictionary in entries:
		check(ResourceLoader.exists(entry.image) and not String(entry.body).is_empty(), "Briefing has real artwork and instruction text")
	var cards := Cards.new()
	root.add_child(cards)
	cards.open(entries)
	cards.set_process(false)
	check(cards.preview.visible and cards.preview.get_child_count() == 2, "Mechanism has two static in-game examples")
	check(get_nodes_in_group("scarab_enemies").is_empty(), "Static samples cannot enter gameplay queries")
	check(paused and cards.visible, "Card freezes gameplay")
	cards._input(key())
	check(cards.index == 0, "Opening key cannot skip first card")
	cards._process(2.99)
	cards._input(key())
	check(cards.index == 0, "Card cannot skip before three seconds")
	cards._process(.02)
	var repeated := key()
	repeated.echo = true
	cards._input(repeated)
	check(cards.index == 0, "Held-key repeat cannot skip")
	cards._input(key())
	check(cards.index == 1 and cards.elapsed == 0, "Fresh key after three seconds advances and restarts lock")
	cards._input(key())
	check(cards.index == 1, "Double press cannot skip next card")
	if OS.get_cmdline_user_args().has("--capture"):
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_artifact_work/tutorial"))
		root.get_texture().get_image().save_png("res://_artifact_work/tutorial/briefing.png")
	var finished: Array[bool] = []
	cards.finished.connect(func() -> void: finished.append(true))
	while cards.index < entries.size():
		cards._process(3.1)
		cards._input(key())
	check(not paused and finished.size() == 1, "Last card restores pause and completes exactly once")
	await process_frame
	# Exercise the real transition rather than only the card widget.
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var flow: Node = main.get_node("LevelFlowController")
	flow.input_release_guard_active = false
	flow.run_context.selected_order_group = {"map_mechanism_ids": [&"scarab"], "prepare_duration": 60, "service_duration": 180}
	flow.day_transition_active = true
	flow.day_transition_time_remaining = 0
	flow._update_day_transition(.1)
	check(flow.day_briefing != null and flow.day_briefing.visible and paused, "Real day transition waits for briefing")
	var time_before: float = flow.day_time_remaining
	flow._process(5)
	check(flow.day_time_remaining == time_before, "Day timer does not advance behind briefing")
	flow.day_briefing.elapsed = 3.1
	Input.action_press("dash")
	flow.day_briefing._input(key())
	check(flow.get_current_level_state() == preload("res://Scripts/Core/LevelContext.gd").LevelState.PREPARE_PHASE and not paused, "Final confirmation begins real preparation")
	check(main.get_node("Player").input_gate.is_blocked(&"dash"), "Confirmation input is isolated from dash")
	check(flow.progression_state.seen_mechanism_briefings.has(&"scarab"), "Reading a real briefing records the mechanism")
	var restored := preload("res://Scripts/Core/RunProgressionState.gd").new()
	restored.apply_snapshot(flow.progression_state.get_snapshot())
	check(restored.seen_mechanism_briefings.has(&"scarab"), "Read state survives day snapshots")
	restored.reset(12)
	check(restored.seen_mechanism_briefings.is_empty(), "A new run introduces mechanisms again")
	Input.action_release("dash")
	main.queue_free()
	paused = false
	await process_frame
	print("READINESS CARDS: %d failures; all mechanisms and bosses, three-second lock, fresh keys, pause and real prepare transition" % failures.size())
	quit(0 if failures.is_empty() else 1)
