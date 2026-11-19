extends SceneTree

const Cue = preload("res://Scripts/Audio/AudioCue.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
var failures: Array[String] = []
var heard: Array[StringName] = []
var audio: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func reset_cues() -> void:
	for voice: AudioStreamPlayer in audio.sfx_players:
		voice.stop()
	audio.last_played.clear()
	heard.clear()

func stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		stop_ticks(child)

func run() -> void:
	audio = Cue.manager()
	check(audio != null, "Audio autoload must exist in standalone tests.")
	if audio == null:
		quit(1)
		return
	audio.cue_played.connect(func(id: StringName) -> void: heard.append(id))
	check(audio.music_streams.size() == 6 and audio.sfx_streams.size() == 46, "All six tracks and 46 effects must load.")
	for id: StringName in audio.MUSIC_IDS:
		var stream: AudioStreamWAV = audio.music_streams[id]
		var minimum_length := 40.0 if id in audio.LOOPING_MUSIC_IDS else 10.0
		check(stream.stereo and stream.get_length() > minimum_length, "Music must be a full stereo phrase: %s" % id)
		if id in audio.LOOPING_MUSIC_IDS:
			check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > stream.mix_rate * 40, "Music must loop over its complete sample range: %s" % id)
		else:
			check(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Settlement music must be one-shot: %s" % id)
	for id: StringName in audio.SFX_IDS:
		check(audio.sfx_streams[id].get_length() > 0.02, "Effect must contain audio: %s" % id)
		reset_cues()
		Cue.play_sfx(id)
		check(heard == [id], "Effect must reach a pooled player: %s" % id)
	reset_cues()
	for count in range(100):
		Cue.play_sfx(&"hit")
	check(heard.size() == 1, "Same-frame hits must be coalesced.")
	check(audio.sfx_players.size() == 20, "Voice pool must remain bounded.")
	var title: Node = load("res://Scenes/Main/game_start.tscn").instantiate()
	root.add_child(title)
	check(audio.current_music == &"title", "Title must select its track.")
	title._show_prepare()
	check(audio.current_music == &"title", "Character selection must share title music.")
	title.queue_free()
	await process_frame
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	stop_ticks(main)
	paused = false
	var flow: Node = main.get_node("LevelFlowController")
	check(audio.current_music == &"night", "Night must select its track.")
	flow.run_context.selected_order_group = flow.order_groups[0].duplicate(true)
	flow.run_context.selected_order_group.erase("boss_enhanced_map_mechanism_id")
	flow.run_context.selected_order_group["final_boss"] = false
	flow._enter_prepare_phase()
	check(audio.current_music == &"day", "Ordinary day must select day music.")
	flow.run_context.selected_order_group["boss_enhanced_map_mechanism_id"] = &"scarab"
	flow._enter_prepare_phase()
	check(audio.current_music == &"boss", "Small boss day must select boss music.")
	flow.run_context.selected_order_group["boss_enhanced_map_mechanism_id"] = &""
	flow.run_context.selected_order_group["final_boss"] = true
	flow._enter_prepare_phase()
	check(audio.current_music == &"boss", "Final boss must select boss music.")
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	var player: Node2D = main.get_node("Player")
	var interaction: RefCounted = player.interaction_controller
	var rack: Node = get_first_node_in_group("plate_sinks").rack
	interaction._set_current_interaction_target(rack)
	player.clear_held_item()
	player.pick_up_item(Items.DISH_CRISP_PLATE_ID, null, &"", "", {"uses_plate": true})
	reset_cues()
	interaction.handle_pickup_drop(Vector2.RIGHT)
	check(heard.is_empty() and player.get_held_item_id() == Items.DISH_CRISP_PLATE_ID, "Rejected plate pickup must be silent and preserve held food.")
	player.clear_held_item()
	reset_cues()
	interaction.handle_pickup_drop(Vector2.RIGHT)
	check(&"pickup" in heard and player.get_held_item_id() == Items.PLATE_ID, "Successful pickup must have sound.")
	reset_cues()
	Cue.work(player, &"cut")
	Cue.work(player, &"cut")
	check(heard.count(&"cut") == 1, "Held work must have a cadence rather than frame-rate sounds.")
	reset_cues()
	player.take_damage(5, Vector2.LEFT, &"test_audio")
	check(&"hurt" in heard, "Actual player damage must have sound.")
	var button := Button.new()
	main.add_child(button)
	button.hide()
	reset_cues()
	button.pressed.emit()
	check(&"ui_confirm" in heard, "Confirmation must still sound when its earlier callback has hidden a menu.")
	reset_cues()
	flow._enter_result(false, "Audio regression fixture")
	check(audio.current_music == &"end" and &"failure" in heard, "Settlement must play one-shot end music and sound its result.")
	paused = false
	for bus: StringName in [&"Music", &"SFX"]:
		var previous: float = audio.volume_controls[bus]
		audio.set_volume(bus, 0.0, false)
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)), "Zero volume must mute the correct bus.")
		audio.set_volume(bus, previous, false)
	# Complete a rapid crossfade before checking that no old track remains.
	await create_timer(0.8).timeout
	var playing := 0
	for voice: AudioStreamPlayer in audio.music_players:
		playing += int(voice.playing)
	check(playing == 1, "Rapid phase changes must leave only one music stream after the fade.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: 4 looping tracks, 46 effects, title/night/day/boss/result routing, actual/failed interactions, work cadence, damage, mouse UI, bounded voices and independent mute.")
	quit(0 if failures.is_empty() else 1)
