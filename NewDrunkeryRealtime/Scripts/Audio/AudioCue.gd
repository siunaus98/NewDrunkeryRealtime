extends RefCounted

## Safe in editor tools and standalone SceneTree tests, before autoloads exist.
static func manager() -> Node:
	if Engine.is_editor_hint():
		return null
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("AudioManager") if tree != null and tree.root != null else null

static func play_music(track: StringName, restart: bool = false) -> void:
	var audio := manager()
	if audio != null:
		audio.play_music(track, restart)

static func play_music_once(track: StringName, restart: bool = true) -> void:
	var audio := manager()
	if audio != null:
		audio.play_music_once(track, restart)

static func npc(id: StringName) -> void:
	var effect: StringName = StringName("npc_%s" % String(id))
	play_sfx(effect, 1.0)

static func play_sfx(effect: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var audio := manager()
	if audio != null:
		audio.play_sfx(effect, volume_db, pitch_scale)

static func play_ui(effect: StringName = &"ui_confirm") -> void:
	play_sfx(effect, -1.0)

## Continuous work emits small ticks, never a new voice every frame.
static func work(source: Node2D, effect: StringName = &"work_tick") -> void:
	if not is_instance_valid(source) or manager() == null:
		return
	var now := Time.get_ticks_msec()
	var gap := 1800 if effect == &"roast" else 550
	if now - int(source.get_meta(&"audio_work_time", -10000)) < gap:
		return
	source.set_meta(&"audio_work_time", now)
	var gain := 0.0 if effect in [&"roast", &"grind", &"brew"] else (-1.0 if effect == &"cut" else (-5.0 if effect != &"wash" else -4.0))
	at(source, effect, gain)

static func at(source: Node2D, effect: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not is_instance_valid(source) or not source.is_inside_tree():
		return
	var screen_point := source.get_global_transform_with_canvas().origin
	var view := source.get_viewport_rect()
	if not view.grow(160.0).has_point(screen_point):
		return
	play_sfx(effect, volume_db, pitch_scale)
