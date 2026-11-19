extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	paused = false
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var player: Node2D = main.get_node("Player")
	var assembly: Node = main.get_node("AssemblyStation")
	var table: Node = main.get_node("PrepTableA")
	for id: StringName in [Items.DISH_CRISP_PLATE_ID, Items.DISH_FOWL_POT_ID, Items.DISH_SCORPION_SUNPLATE_ID, Items.TRASH_ID]:
		player.clear_held_item()
		table.reset_state()
		assembly.reset_state()
		assembly.stored_items.assign([{"item_id": id, "texture": Items.get_item_texture(id), "recipe_signature": "preserved-signature"}])
		assembly._update_item_visual()
		await process_frame
		var unplated: Texture2D = (assembly.item_sprites.get_child(0) as Sprite2D).texture
		_check(unplated != null and not assembly.can_take_item(player), "Unplated food is visible and cannot be collected empty-handed.")
		_check("DishPlated" not in unplated.resource_path, "The assembly output never invents a serving plate.")
		if id == Items.DISH_FOWL_POT_ID:
			_check("DishPrepared" in unplated.resource_path, "Soup waits in a preparation vessel while its UI icon stays food-only.")
			_check(Items.get_item_texture(id) != unplated, "UI soup artwork does not reuse the preparation pot.")
		_check(player.pick_up_item(Items.PLATE_ID, Items.get_item_texture(Items.PLATE_ID)), "A clean plate enters hand.")
		_check(assembly.take_item_to_player(player), "A plate collects the finished food.")
		var plated: Texture2D = player.get_held_item_texture()
		_check(plated != unplated and "DishPlated" in plated.resource_path, "Actual collection switches the held food to its plated presentation.")
		_check(player.get_held_item_payload().get("uses_plate", false), "Visible tableware corresponds to the real carried plate.")
		_check(table.receive_item_from_player(player), "Plated food can be staged on a table.")
		_check(table.meat_sprite.texture == plated and table.item_payload.get("uses_plate", false), "Table staging keeps both visible and owned tableware.")
		_check(table.take_item_to_player(player), "A staged dish is recovered without spending another plate.")
		if id != Items.TRASH_ID:
			_check(assembly.receive_item_from_player(player), "An existing plated dish returns to the assembly counter.")
			await process_frame
			_check((assembly.item_sprites.get_child(0) as Sprite2D).texture == plated, "Returning to assembly does not remove an existing plate.")
			_check(assembly.take_item_to_player(player), "Plated food returns to hand.")
		var loose: Node = load("res://Scenes/Restaurant/loose_item.tscn").instantiate()
		main.add_child(loose)
		loose.setup_item(player.get_held_item_id(), player.get_held_item_texture(), &"", player.get_held_item_recipe_signature(), player.get_held_item_payload())
		player.clear_held_item()
		_check(loose.sprite.texture == plated and loose.can_take_item(player), "Ground presentation keeps the plate and allows empty-handed recovery.")
		_check(loose.take_item_to_player(player) and player.get_held_item_texture() == plated, "Ground recovery keeps the same plated food.")
		_check(player.get_held_item_recipe_signature() == "preserved-signature", "Visual changes preserve the actual dish signature.")
		player.clear_held_item()
	for id: StringName in Items.ASSEMBLY_COMPONENT_IDS:
		_check(Items.get_world_item_texture(id, {"uses_plate": true}) == Items.get_item_texture(id), "Drinks keep their own glass and do not acquire a serving plate.")
	for id: StringName in Items.DISH_IDS:
		_check(Items.get_item_texture(id).get_size() == Vector2(128, 128), "UI food and drink canvases retain their normal dimensions.")
		if not Items.is_drink(id):
			_check("DishPlated" in Items.get_world_item_texture(id, {"uses_plate": true}).resource_path, "Every non-drink recipe has a plated presentation.")
	main.queue_free()
	await process_frame
	print("Dish presentation: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
