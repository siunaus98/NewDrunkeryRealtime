extends SceneTree

const HealthBar = preload("res://Scripts/UI/HealthBar.gd")
const Defs = preload("res://Scripts/Core/MapMechanismDefs.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	paused = false
	main.get_node("LevelFlowController").set_process(false)
	for controller_name in ["ScarabMechanismController", "QuicksandMechanismController", "WindSandMechanismController"]:
		main.get_node(controller_name).set_process(false)
	var manager: Node = main.get_node("BattleManager")
	manager.set_process(false)
	manager.reset_runtime_state()
	var player: Node2D = main.get_node("Player")
	# Event playtests grant a starting strength blessing. Isolate the base
	# 65-point damage fixture from those optional resources.
	var no_blessings: Array[StringName] = []
	player.set_owned_blessings_for_run(no_blessings)
	player.set_process(false)
	player.set_physics_process(false)
	var player_bar := player.get_node("OverheadHealthBar") as ActorHealthBar
	_check(not player.health_label.visible and player_bar.health_ratio == 1.0, "Player must have a full overhead bar instead of numeric HP.")
	player.take_damage(50, Vector2.ZERO, &"quicksand")
	_check(player_bar.health_ratio == 0.5, "Player bar must track damage.")
	player.combat_controller.reset_temporary_state()
	_check(player_bar.health_ratio == 1.0, "Player bar must track recovery/reset.")
	var map: Node2D = main.get_node("PrototypeMap")
	var center: Vector2 = map.get_region_bounds(&"top").get_center()
	player.position = center + Vector2(-400, 160)
	var enemies: Array[Node2D] = []
	var index := 0
	for id in [&"chaser", &"sprinter", &"slammer", &"ranged", &"bullet_fan", &"bruiser", &"sniper", &"orbiter", &"splitter"]:
		var enemy: Node2D = manager._get_enemy_scene_for_id(id).instantiate()
		main.add_child(enemy)
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemy.position = center + Vector2(-460 + index % 5 * 230, 60 + floori(index / 5.0) * 230)
		var bar := enemy.get_node("OverheadHealthBar") as ActorHealthBar
		_check(bar != null and not enemy.health_label.visible, "Every ordinary and elite enemy must use an overhead bar: %s" % id)
		var ratio: float = [1.0, 0.65, 0.35, 0.1][index % 4]
		enemy.receive_hit(int(enemy.max_health * (1.0 - ratio)))
		_check(absf(bar.health_ratio - ratio) < 0.01, "Enemy bar must update on damage: %s" % id)
		enemies.append(enemy)
		index += 1
	_check(HealthBar.color_for_ratio(1.0).is_equal_approx(Color("65d67b")) and HealthBar.color_for_ratio(0.65).is_equal_approx(Color("efdc4f")) and HealthBar.color_for_ratio(0.35).is_equal_approx(Color("f39436")) and HealthBar.color_for_ratio(0.0).is_equal_approx(Color("ed4949")), "Health colors must run green, yellow, orange, red.")
	manager.configure_for_order_group({"boss_enhanced_map_mechanism_id": Defs.QUICKSAND})
	manager.spawn_scheduled_boss()
	var boss: Node2D = get_first_node_in_group("sandworm_bosses")
	boss.set_physics_process(false)
	boss.position = center + Vector2(0, -220)
	var hud: Node = main.get_node("RunStatusHud")
	hud.set_status_visible(true)
	hud._process(0.0)
	_check(hud.boss_panel.visible and not boss.health_label.visible, "Boss must use the public HUD instead of overhead numbers.")
	# Place the attack beyond the old 108px radius but within the visible body edge.
	player.position = boss.position - Vector2(290, 0) - player.attack_origin_offset
	var hp: int = boss.current_health
	player.combat_controller._apply_attack_hit({"direction": Vector2.RIGHT}, func(_point: Vector2) -> bool: return true)
	_check(boss.current_health == hp - 65, "Light attack at the enlarged visual edge must hit for the existing 65 damage.")
	player.position = center + Vector2(-620, 280)
	hud._process(0.0)
	_check(is_equal_approx(hud.boss_health_bar.health_ratio, float(boss.current_health) / boss.max_health), "Public boss bar must follow actual damage.")
	boss.receive_scarab_escape(1)
	boss.current_health = boss.max_health / 2
	hud._process(0.0)
	_check(hud.boss_health_bar.health_ratio == 0.5, "Public boss bar must reflect updated health.")
	var camera: Camera2D = main.get_node("Camera2D")
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.position = center
	camera.reset_smoothing()
	hud.set_day_clock(180, 230, 50, "营业")
	await create_timer(0.2).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output := OS.get_environment("TEMP").path_join("health-bars-review.png")
		root.get_texture().get_image().save_png(output)
		print("Health bar screenshot: " + output)
	boss.receive_hit(boss.max_health)
	hud._process(0.0)
	_check(not hud.boss_panel.visible, "Public boss bar must disappear after defeat.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: player and nine enemy bars, health colors, public boss HUD lifecycle, enlarged hit radius and actual 65-point light attack.")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
