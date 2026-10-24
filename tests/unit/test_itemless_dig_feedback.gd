extends GutTest

## Production regression: itemless activation must not advertise a collectible.
## Observe actual Player message_stack, not a replacement HUD/formatting mock.
var saved_state: Dictionary = {}
var saved_map: MapData = null
var saved_ready: Array[int] = []
var fixture_root: Node3D = null

func before_each() -> void:
	saved_state = GameState.instance.get_snapshot()
	saved_map = SessionManager.instance._current_map
	saved_ready = SessionManager.instance.get_ready_peers()
	SessionManager.instance._current_map = load("res://items/maps/lua.tres") as MapData
	SessionManager.instance._ready_peers.clear()
	SessionManager.instance._ready_peers.append(1)
	GameState.instance.defeated_bosses.erase("lunar_warden")
	fixture_root = Node3D.new()
	add_child_autoqfree(fixture_root)

func after_each() -> void:
	if is_instance_valid(fixture_root): fixture_root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	SessionManager.instance._current_map = saved_map
	SessionManager.instance._ready_peers.assign(saved_ready)
	GameState.instance.apply_snapshot(saved_state)

func _player() -> Player:
	var player: Player = load("res://gameplay/player/player.tscn").instantiate() as Player
	player.name = "1"
	fixture_root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.position = Vector3(0,0,1.5)
	player.held_tool_id = &""
	player.carrying_loot = false
	player.clear_messages()
	return player

func _spawner() -> EnemySpawner:
	var spawner: EnemySpawner = EnemySpawner.new()
	spawner.primary_kind = &""
	spawner.secondary_kind = &""
	spawner.ambient_enabled = false
	spawner.spawns_per_level = [0,0,0]
	spawner.hermits_per_level = [0,0,0]
	spawner.seagulls_per_level = [0,0,0]
	fixture_root.add_child(spawner)
	spawner.enemy_spawned.connect(func(enemy: Node3D) -> void: enemy.set_physics_process(false))
	return spawner

func _altar() -> BuriedSpot:
	var path: String = "res://gameplay/environment/lunar_altar.gd"
	assert_true(ResourceLoader.exists(path),"Production/selected LunarAltar absent")
	if not ResourceLoader.exists(path): return null
	var altar: BuriedSpot = (load(path) as Script).new() as BuriedSpot
	fixture_root.add_child(altar)
	return altar

func _text(player: Player) -> String:
	var text: String = ""
	for node: Node in player.message_stack.get_children():
		var label: Label = node as Label
		if label != null and not label.is_queued_for_deletion(): text += label.text+"\n"
	return text

func _labels(player: Player) -> Array[Label]:
	var labels: Array[Label] = []
	for node: Node in player.message_stack.get_children():
		if node is Label and not node.is_queued_for_deletion(): labels.append(node as Label)
	return labels

func _assert_no_false_find(player: Player) -> void:
	var text: String = _text(player)
	assert_false(text.contains(tr("Artefato Misterioso")),"Itemless altar is not a mysterious artifact")
	assert_false(text.contains(InputDevice.fill_key_prompts(tr("[E] pegar"))),"No pickup instruction when there is no ItemData")
	assert_false(text.contains(MoneyFormat.money(0)),"No fabricated zero-value find")

func test_real_lunar_reveal_active_never_announces_a_collectible() -> void:
	var player: Player = _player()
	if player == null: return
	_spawner()
	var altar: BuriedSpot = _altar()
	if altar == null: return
	for index: int in 3:
		var result: Dictionary = altar.dig(true,1.0,false,player)
		assert_true(bool(result.get("dug",false)))
		player._show_dig_feedback(result,true)
	assert_null(altar.item)
	assert_eq(StringName(altar.call("get_activation_state")),&"ACTIVE")
	assert_eq(altar.dirt_layers,0)
	_assert_no_false_find(player)
	player._update_interaction_target()
	assert_false(player.interact_prompt.text.contains(tr("Artefato Misterioso")),"No independent item pickup target either")

func test_active_transition_retires_previous_layer_toasts_but_preserves_other_notice() -> void:
	var player: Player = _player()
	if player == null: return
	_spawner()
	var altar: BuriedSpot = _altar()
	if altar == null: return
	player._show_temporary_message("HUD_SENTINEL_UNRELATED",Color.WHITE,10)
	for index: int in 2: player._show_dig_feedback(altar.dig(true,1.0,false,player),true)
	var prior: Array[Label] = []
	for label: Label in _labels(player):
		if label.text != "HUD_SENTINEL_UNRELATED": prior.append(label)
	assert_gt(prior.size(),0,"Real partial excavation emitted progress feedback")
	player._show_dig_feedback(altar.dig(true,1.0,false,player),true)
	for label: Label in prior:
		assert_true(not is_instance_valid(label) or label.is_queued_for_deletion(),"Completed altar must retire its stale layer feedback immediately")
	assert_true(_text(player).contains("HUD_SENTINEL_UNRELATED"),"Do not clear every HUD message to hide the defect")

func test_remote_result_roundtrip_does_not_fabricate_itemless_find() -> void:
	var player: Player = _player()
	if player == null: return
	_spawner()
	var altar: BuriedSpot = _altar()
	if altar == null: return
	for index: int in 3:
		var result: Dictionary = altar.dig(true,1.0,false,player)
		var decoded: Dictionary = BuriedSpot.result_from_net(BuriedSpot.result_to_net(result))
		player._on_remote_dig_result(decoded,true,altar.global_position)
	_assert_no_false_find(player)

func test_real_item_keeps_name_value_pickup_and_perfect_feedback() -> void:
	var player: Player = _player()
	if player == null: return
	var spot: BuriedSpot = BuriedSpot.new()
	spot.item = load("res://items/catalog/engrenagem_alienigena.tres") as ItemData
	spot.rare_decided = true
	spot.free_on_reveal = false
	fixture_root.add_child(spot)
	var result: Dictionary = {}
	for index: int in 3: result = spot.dig(true,1.0,false,player)
	assert_not_null(result.get("item"))
	assert_true(bool(result.get("is_perfect",false)))
	player._show_dig_feedback(result,true)
	var text: String = _text(player)
	assert_true(text.contains(tr(spot.item.display_name)))
	assert_true(text.contains(MoneyFormat.money(int(result.final_value))))
	assert_true(text.contains(InputDevice.fill_key_prompts(tr("[E] pegar"))))
	assert_true(text.contains(tr("✔ ESCAVAÇÃO PERFEITA! (+25%)")))

func test_legacy_boss_altar_rearm_and_world_flags_survive_feedback() -> void:
	var player: Player = _player()
	if player == null: return
	_spawner()
	var flags: WorldFlags = WorldFlags.new()
	fixture_root.add_child(flags)
	flags.set_flag(&"hud_preserved",true)
	var before: Dictionary = flags.get_all()
	var altar: BossAltar = BossAltar.new()
	fixture_root.add_child(altar)
	for index: int in 3: player._show_dig_feedback(altar.dig(true,1.0,false,player),true)
	assert_true(altar._woken)
	assert_eq(altar.dirt_layers,0)
	assert_eq(flags.get_all(),before)
	altar.rearm()
	assert_false(altar._woken)
	assert_eq(altar.dirt_layers,3)
	assert_true(altar.is_in_group(&"buried_spots"))
	_assert_no_false_find(player)
