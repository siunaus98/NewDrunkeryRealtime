extends Node

## Only this catalog owns asset paths. AudioCue safely dispatches from tests,
## editor tools and gameplay. Voices, duplicate suppression and mix live here.
const MUSIC_IDS: Array[StringName] = [&"title", &"night", &"day", &"boss", &"success", &"end"]
const LOOPING_MUSIC_IDS: Array[StringName] = [&"title", &"night", &"day", &"boss"]
const SFX_IDS: Array[StringName] = [
	&"ui_confirm", &"ui_cancel", &"ui_move", &"ui_refresh", &"ui_tab",
	&"interaction", &"pickup", &"drop", &"work_tick", &"attack_light",
	&"attack_heavy", &"hit", &"hurt", &"dash", &"skill", &"ultimate",
	&"forage", &"order", &"brew", &"upgrade", &"forge",
	&"event", &"warning", &"serve", &"success", &"failure", &"purchase",
	&"cut", &"grind", &"wash", &"roast", &"complete", &"enemy_shoot",
	&"impact", &"enemy_down", &"boss_alert", &"spit",
	&"npc_merchant", &"npc_devil", &"npc_furnace", &"npc_porcelain", &"npc_sand_spirit", &"npc_prankster", &"npc_engraver", &"npc_gambler", &"npc_repayment"
]
const EXTERNAL_NPC_SFX: Dictionary = {
	&"npc_merchant": "res://Audio/ref_npc_merchant.wav",
	&"npc_repayment": "res://Audio/ref_npc_repayment.wav",
	&"npc_devil": "res://Audio/ref_npc_devil.wav",
	&"npc_furnace": "res://Audio/ref_npc_furnace.wav",
	&"npc_porcelain": "res://Audio/ref_npc_porcelain.wav",
	&"npc_sand_spirit": "res://Audio/ref_npc_sand_spirit.wav",
	&"npc_prankster": "res://Audio/ref_npc_prankster.wav",
	&"npc_engraver": "res://Audio/ref_npc_engraver.wav",
	&"npc_gambler": "res://Audio/ref_npc_gambler.wav",
}
const EXTERNAL_NPC_LICENSES: Dictionary = {
	&"npc_merchant": "Coin Shower by Qvantor (CC0)",
	&"npc_repayment": "Coin Shower by Qvantor (CC0)",
	&"npc_devil": "Evil_chuckle.wav by remarknl (CC0)",
	&"npc_furnace": "fire-whoosh.wav by hnhnh (CC0)",
	&"npc_porcelain": "3_GLASS_BELL_TAPPING... by PaperMacheToothPicksSeaAnenome (CC0)",
	&"npc_sand_spirit": "Joyful - Wouhouh by Sadiquecat (CC0)",
	&"npc_prankster": "dark_ambient-010.wav by ilmari_freesound (CC0)",
	&"npc_engraver": "ROCK_IMPACT_GALETS_OUTDOORS_260128 50 by kevinklang (CC0)",
	&"npc_gambler": "Dice Rolling on Table by Flem0527 (CC0)",
}
const MUSIC_DB := -3.0
const SFX_DB := -7.0
const FADE_SECONDS := 0.65
const VOICE_COUNT := 20
signal cue_played(effect: StringName)

var music_streams: Dictionary = {}
var sfx_streams: Dictionary = {}
var music_players: Array[AudioStreamPlayer] = []
var sfx_players: Array[AudioStreamPlayer] = []
var current_music: StringName = &""
var music_slot := 0
var fade: Tween
var last_played: Dictionary = {}
var volume_controls: Dictionary = {&"Master": 1.0, &"Music": 0.8, &"SFX": 0.8}
const SETTINGS_PATH := "user://audio_settings.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name: StringName in [&"Music", &"SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var bus_index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus_index, bus_name)
			AudioServer.set_bus_send(bus_index, &"Master")
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	for bus_name: StringName in volume_controls:
		set_volume(bus_name, float(settings.get_value("volume", String(bus_name), volume_controls[bus_name])), false)
	for track: StringName in MUSIC_IDS:
		var stream := load("res://Audio/music_%s.wav" % track) as AudioStreamWAV
		if stream != null:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if track in LOOPING_MUSIC_IDS else AudioStreamWAV.LOOP_DISABLED
			stream.loop_begin = 0
			stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
			music_streams[track] = stream
	for effect: StringName in SFX_IDS:
		var stream_path: String = String(EXTERNAL_NPC_SFX.get(effect, "res://Audio/%s.wav" % effect))
		var stream := load(stream_path) as AudioStream
		if stream != null:
			sfx_streams[effect] = stream
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % index
		player.bus = &"Music"
		player.volume_db = -60.0
		add_child(player)
		music_players.append(player)
	for index in range(VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "Effect%d" % index
		player.bus = &"SFX"
		add_child(player)
		sfx_players.append(player)
	get_tree().node_added.connect(_watch_button)

func play_music(track: StringName, restart: bool = false, looping: bool = true) -> void:
	if not music_streams.has(track) or music_players.is_empty():
		return
	if current_music == track and not restart and music_players[music_slot].playing:
		return
	if fade != null and fade.is_valid():
		fade.kill()
	var outgoing := music_players[music_slot]
	music_slot = 1 - music_slot
	var incoming := music_players[music_slot]
	current_music = track
	incoming.stop()
	incoming.stream = music_streams[track]
	var music_stream := incoming.stream as AudioStreamWAV
	if music_stream != null:
		music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
	incoming.volume_db = -60.0
	incoming.play()
	fade = create_tween().set_parallel(true)
	fade.tween_property(incoming, "volume_db", MUSIC_DB, FADE_SECONDS)
	fade.tween_property(outgoing, "volume_db", -60.0, FADE_SECONDS)
	fade.chain().tween_callback(outgoing.stop)

func play_music_once(track: StringName, restart: bool = true) -> void:
	play_music(track, restart, false)

func stop_music() -> void:
	current_music = &""
	if fade != null and fade.is_valid():
		fade.kill()
	for player in music_players:
		player.stop()

func set_volume(bus_name: StringName, value: float, persist: bool = true) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	value = clampf(value, 0.0, 1.0)
	volume_controls[bus_name] = value
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))
	if persist:
		var settings := ConfigFile.new()
		for key: StringName in volume_controls:
			settings.set_value("volume", String(key), volume_controls[key])
		settings.save(SETTINGS_PATH)

func play_sfx(effect: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sfx_streams.has(effect) or sfx_players.is_empty():
		return
	var now := Time.get_ticks_msec()
	var cooldown := 65 if String(effect).begins_with("ui_") else 90
	if effect in [&"warning", &"boss_alert", &"event"]:
		cooldown = 450
	if now - int(last_played.get(effect, -10000)) < cooldown:
		return
	last_played[effect] = now
	# Never replace another playing cue: projectile fans and multi-hits may
	# exceed the budget, in which case discard extra sounds, not gameplay.
	for player in sfx_players:
		if not player.playing:
			player.stream = sfx_streams[effect]
			player.volume_db = SFX_DB + volume_db
			player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
			player.play()
			cue_played.emit(effect)
			return

func _watch_button(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(_button_pressed.bind(weakref(node)))
		node.mouse_entered.connect(_button_hovered.bind(node))

func _button_pressed(button_ref: WeakRef) -> void:
	# An earlier pressed callback may have hidden or rebuilt its entire menu.
	var button := button_ref.get_ref() as BaseButton
	if is_instance_valid(button) and button.disabled:
		return
	var effect: StringName = StringName(button.get_meta("audio_cue", &"ui_confirm")) if is_instance_valid(button) else &"ui_confirm"
	play_sfx(effect, -1.0)

func _button_hovered(button: BaseButton) -> void:
	if not button.disabled and button.is_visible_in_tree():
		play_sfx(&"ui_move", -1.0)
