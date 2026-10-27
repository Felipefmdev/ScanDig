extends GutTest

## #186 UI contract only. CounterFake is a real Node3D, not gameplay range proof.
## No purchase button is pressed before the commerce API is coordinated.
const SOURCE: String = "res://ui/world_upgrade_shop.gd"
const PLAYER: PackedScene = preload("res://gameplay/player/player.tscn")
const UPGRADE_IDS: Array[String] = ["detector", "pinpointer", "shovel", "backpack"]


class CounterFake extends Node3D:
	var radius: float = 3.0


	func _ready() -> void:
		add_to_group("upgrade_counters")


	func is_actor_in_range(actor: Player) -> bool:
		return is_instance_valid(actor) and is_inside_tree() and actor.is_inside_tree() and global_position.distance_to(actor.global_position) <= radius


var _snapshot: Dictionary = {}
var _original_scene: Node = null
var _original_mouse: int = Input.MOUSE_MODE_VISIBLE
var _original_paused: bool = false
var _original_focus: Control = null
var _world: Node3D = null
var _replacement: Node3D = null
var _shop: CanvasLayer = null
var _actor: Player = null
var _counter: CounterFake = null


func before_each() -> void:
	_snapshot = GameState.instance.get_snapshot().duplicate(true)
	_original_scene = get_tree().current_scene
	_original_mouse = Input.mouse_mode
	_original_paused = get_tree().paused
	_original_focus = get_viewport().gui_get_focus_owner()
	GameState.instance.reset_state()
	GameState.instance.team_money = 1000000


func after_each() -> void:
	if is_instance_valid(_shop) and _shop.has_method("close"):
		_shop.call("close")
	get_tree().current_scene = _original_scene
	if is_instance_valid(_replacement):
		_replacement.free()
	if is_instance_valid(_world):
		_world.free()
	# The script instance can exist before _world if a fixture guard fails.
	if is_instance_valid(_shop):
		_shop.free()
	GameState.instance.load_snapshot(_snapshot)
	get_tree().paused = _original_paused
	Input.mouse_mode = _original_mouse
	if is_instance_valid(_original_focus) and _original_focus.is_inside_tree():
		_original_focus.grab_focus()
	_world = null
	_replacement = null
	_shop = null
	_actor = null
	_counter = null


func _fixture() -> bool:
	var exists: bool = ResourceLoader.exists(SOURCE)
	assert_true(exists, "production world_upgrade_shop.gd must exist (RED without parse dependency)")
	if not exists:
		return false
	var source: Script = load(SOURCE) as Script
	assert_not_null(source)
	if source == null:
		return false
	var instance: Node = source.new() as Node
	assert_true(instance is CanvasLayer, "world shop is a CanvasLayer")
	if not (instance is CanvasLayer):
		if instance != null:
			instance.free()
		return false
	_shop = instance as CanvasLayer
	for method: String in ["open_for", "close", "is_open", "get_upgrade_button"]:
		assert_true(_shop.has_method(method), "required shop API: " + method)
		if not _shop.has_method(method):
			_shop.free()
			_shop = null
			return false
	_world = Node3D.new()
	_world.name = "WorldUpgradeShopTest"
	get_tree().root.add_child(_world)
	assert_true(_world.get_parent() == get_tree().root, "current_scene requires a direct root child")
	get_tree().current_scene = _world
	assert_true(get_tree().current_scene == _world, "world is the active scene before opening UI")
	_actor = PLAYER.instantiate() as Player
	_actor.name = "1"
	_actor.process_mode = Node.PROCESS_MODE_DISABLED
	_world.add_child(_actor)
	_counter = CounterFake.new()
	_world.add_child(_counter)
	_world.add_child(_shop)
	assert_true(_counter.is_in_group("upgrade_counters"))
	assert_false(_actor.is_settings_open(), "isolated test starts with no modal")
	return true


func _open() -> bool:
	var result: Variant = _shop.call("open_for", _counter, _actor)
	assert_eq(typeof(result), TYPE_BOOL, "open_for returns bool")
	return result is bool and bool(result)


func _is_open() -> bool:
	return bool(_shop.call("is_open"))


func _button(id: String) -> Button:
	var result: Variant = _shop.call("get_upgrade_button", id)
	assert_true(result is Button, "consultable upgrade button: " + id)
	return result as Button if result is Button else null


func test_gamepad_down_wraps_from_close_to_first_purchase() -> void:
	if not _fixture():
		return
	assert_true(_open())
	await wait_frames(3)
	var close: Control = get_viewport().gui_get_focus_owner()
	assert_not_null(close)
	if close == null:
		return
	# Usa a resolução de vizinhos da GUI; eventos reais ficam no runner com janela.
	assert_same(close.find_valid_focus_neighbor(SIDE_BOTTOM), _button("detector"), "O direcional sai de Fechar e alcança a primeira compra")
	assert_same(_button("detector").find_valid_focus_neighbor(SIDE_TOP), close, "A navegação inversa também fecha o anel")

func test_four_upgrade_buttons_without_museum_or_expedition_navigation() -> void:
	if not _fixture():
		return
	var before: Dictionary = GameState.instance.get_snapshot().duplicate(true)
	assert_true(_open())
	for id: String in UPGRADE_IDS:
		assert_not_null(_button(id))
	for node: Node in _shop.find_children("*", "", true, false):
		if node is Button or node is Label:
			var text: String = str(node.get("text")).strip_edges().to_lower()
			for forbidden: String in ["museu", "expedições", "museum", "expeditions"]:
				assert_false(text.contains(forbidden), "world shop has no hub navigation: " + text)
	assert_eq(GameState.instance.get_snapshot(), before, "rendering/opening cannot purchase or unlock anything")


func test_open_blocks_player_input_without_pausing_and_close_releases_it() -> void:
	if not _fixture():
		return
	assert_true(_open())
	assert_true(_is_open())
	assert_true(_actor.is_settings_open(), "Player real must recognize world-shop modal")
	assert_false(get_tree().paused, "world simulation continues")
	_shop.call("close")
	assert_false(_is_open())
	assert_false(_actor.is_settings_open())
	assert_false(get_tree().paused)
	_shop.call("close")
	assert_false(_is_open(), "close is idempotent")


func test_open_shop_does_not_make_real_player_invulnerable() -> void:
	if not _fixture():
		return
	assert_true(_open())
	var before: float = _actor.health
	_actor.take_damage(10.0)
	assert_almost_eq(_actor.health, before - 10.0, 0.001, "real damage while browsing")
	assert_false(get_tree().paused)


func test_real_lethal_damage_downed_closes_shop() -> void:
	if not _fixture():
		return
	_actor.allow_downed = true
	assert_true(_open())
	_actor.take_damage(_actor.max_health)
	await wait_frames(3)
	assert_true(_actor.is_downed, "real lethal damage control")
	assert_false(_is_open())
	assert_false(_actor.is_settings_open())
	assert_false(get_tree().paused)


func test_dead_actor_cannot_open_and_death_while_open_closes() -> void:
	if not _fixture():
		return
	_actor.health = 0.0
	assert_false(_open(), "dead actor rejected before showing UI")
	assert_false(_is_open())
	_actor.health = _actor.max_health
	assert_true(_open())
	# Represent dead-but-not-downed lifecycle separately from solo auto-respawn.
	_actor.health = 0.0
	_actor.health_changed.emit(0.0, _actor.max_health)
	await wait_frames(3)
	assert_false(_is_open())
	assert_false(_actor.is_settings_open())


func test_range_loss_closes_and_out_of_range_open_is_rejected() -> void:
	if not _fixture():
		return
	_actor.position = Vector3(100, 0, 0)
	assert_false(_counter.is_actor_in_range(_actor))
	assert_false(_open())
	_actor.position = Vector3.ZERO
	assert_true(_open())
	_actor.position = Vector3(100, 0, 0)
	await wait_frames(3)
	assert_false(_is_open())
	assert_false(_actor.is_settings_open())


func test_counter_free_closes_without_retaining_invalid_reference() -> void:
	if not _fixture():
		return
	assert_true(_open())
	_counter.free()
	await wait_frames(3)
	assert_false(_is_open())
	assert_false(_actor.is_settings_open())


func test_current_scene_change_closes_even_if_old_counter_still_exists() -> void:
	if not _fixture():
		return
	assert_true(_open())
	_replacement = Node3D.new()
	get_tree().root.add_child(_replacement)
	assert_true(_replacement.get_parent() == get_tree().root, "replacement is a direct root child")
	get_tree().current_scene = _replacement
	assert_true(get_tree().current_scene == _replacement, "scene change precondition")
	await wait_frames(3)
	assert_true(is_instance_valid(_counter), "scene-change guard independent of counter free")
	assert_false(_is_open())
	assert_false(_actor.is_settings_open())


func test_close_restores_prior_focus_and_mouse_mode() -> void:
	if not _fixture():
		return
	var prior: Button = Button.new()
	prior.text = "Prior focus"
	_world.add_child(prior)
	prior.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var before_mode: int = Input.mouse_mode
	if DisplayServer.get_name() != "headless":
		assert_eq(before_mode, Input.MOUSE_MODE_CAPTURED, "real renderer must capture mouse before opening")
	assert_true(get_viewport().gui_get_focus_owner() == prior)
	assert_true(_open())
	await wait_frames(2)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	var focus: Control = get_viewport().gui_get_focus_owner()
	assert_not_null(focus, "keyboard/controller focus enters shop")
	if focus != null:
		assert_true(_shop.is_ancestor_of(focus))
	_shop.call("close")
	await wait_frames(2)
	assert_eq(Input.mouse_mode, before_mode, "restore actual pre-open mode, including headless display")
	assert_true(get_viewport().gui_get_focus_owner() == prior)


func test_buttons_follow_money_max_level_and_required_map_snapshot_changes() -> void:
	if not _fixture():
		return
	assert_true(_open())
	for id: String in UPGRADE_IDS:
		var button: Button = _button(id)
		if button == null:
			return
		assert_false(button.disabled, "initial affordable upgrade: " + id)
	GameState.instance.load_snapshot({"team_money": 0})
	await wait_frames(2)
	for id: String in UPGRADE_IDS:
		var button: Button = _button(id)
		if button != null:
			assert_true(button.disabled, "no money: " + id)
	GameState.instance.load_snapshot({"team_money": 1000000, "upgrade_levels": {"detector": 3}, "unlocked_maps": []})
	assert_eq(GameState.instance.get_next_upgrade_required_map("detector"), "ruinas")
	await wait_frames(2)
	var detector: Button = _button("detector")
	if detector == null:
		return
	assert_true(detector.disabled, "money cannot replace required route")
	GameState.instance.load_snapshot({"unlocked_maps": ["ruinas"]})
	await wait_frames(2)
	assert_false(detector.disabled, "permanent route enables next upgrade")
	var maximums: Dictionary = {}
	for id: String in UPGRADE_IDS:
		maximums[id] = GameState.instance.get_upgrade_max_level(id)
	GameState.instance.load_snapshot({"upgrade_levels": maximums})
	await wait_frames(2)
	for id: String in UPGRADE_IDS:
		var button: Button = _button(id)
		if button != null:
			assert_true(button.disabled, "max level: " + id)
	assert_eq(GameState.instance.team_money, 1000000, "UI refresh never buys")


func test_pressed_before_process_after_counter_or_actor_free_closes_without_purchase() -> void:
	if not _fixture():
		return
	watch_signals(_shop)
	var before: Dictionary = GameState.instance.get_snapshot().duplicate(true)
	assert_true(_open())
	var button: Button = _button("detector")
	if button == null:
		return
	assert_false(button.disabled, "exercise enabled button, not disabled early return")
	_counter.free()
	# Deliberately no await: press before _process can notice the freed reference.
	button.pressed.emit()
	assert_false(_is_open(), "invalid counter must synchronously close on press")
	assert_false(_actor.is_settings_open(), "surviving real Player loses shop modal gate")
	assert_eq(int(_shop.get("_pending_request")), 0, "no pending purchase after invalid counter")
	assert_signal_not_emitted(_shop, "purchase_requested")
	assert_eq(GameState.instance.get_snapshot(), before, "no charge or upgrade")
	# Same lifecycle window for a freed actor; the UI and button remain alive.
	_counter = CounterFake.new()
	_world.add_child(_counter)
	assert_true(_open())
	assert_false(button.disabled)
	_actor.free()
	button.pressed.emit()
	assert_false(_is_open(), "invalid actor must synchronously close on press")
	assert_eq(int(_shop.get("_pending_request")), 0, "no pending purchase after invalid actor")
	assert_signal_not_emitted(_shop, "purchase_requested")
	assert_eq(GameState.instance.get_snapshot(), before)
	_actor = null


func test_real_victory_modal_keeps_focus_mouse_and_restores_pre_shop_mode() -> void:
	# Preserve any pre-existing modal by refusing to disturb it. This test only
	# opens/closes the real VictoryScreen when both original modals are closed.
	var victory: VictoryScreen = VictoryScreen.instance
	assert_not_null(victory)
	if victory == null:
		return
	assert_false(PauseMenu.is_open(), "modal fixture precondition")
	assert_false(VictoryScreen.is_open(), "modal fixture precondition")
	if PauseMenu.is_open() or VictoryScreen.is_open():
		return
	if not _fixture():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var before_mode: int = Input.mouse_mode
	if DisplayServer.get_name() != "headless":
		assert_eq(before_mode, Input.MOUSE_MODE_CAPTURED)
	assert_true(_open())
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	# Real API, no game_victory emission, completion mutation, fake flag or pause.
	victory.open()
	assert_true(VictoryScreen.is_open())
	assert_false(get_tree().paused, "VictoryScreen does not pause world processing")
	await wait_frames(3)
	assert_false(_is_open(), "higher modal takes ownership and closes shop")
	assert_true(_actor.is_settings_open(), "real Player remains gated by VictoryScreen")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "shop close cannot recapture mouse over victory")
	var focus: Control = get_viewport().gui_get_focus_owner()
	assert_not_null(focus, "higher modal retains keyboard/controller focus")
	if focus != null:
		assert_true(victory.root_control.is_ancestor_of(focus), "focus remains inside real VictoryScreen")
	victory.close()
	await wait_frames(2)
	assert_false(VictoryScreen.is_open(), "restore original closed modal state")
	assert_false(PauseMenu.is_open())
	assert_false(_actor.is_settings_open(), "both modals released")
	assert_eq(Input.mouse_mode, before_mode, "final close restores original pre-shop mouse ownership")


func test_real_timeout_retries_same_intent_id_and_late_reply_allows_new_intent() -> void:
	if not _fixture():
		return
	var requests: Array[Dictionary] = []
	# Capture real UI emissions as held transport. No commerce handler or host
	# purchase is faked; this test proves correlation/intent lifecycle only.
	var hold: Callable = func(upgrade_id: String, request_id: int) -> void:
		requests.append({"upgrade_id": upgrade_id, "request_id": request_id})
	_shop.connect("purchase_requested", hold)
	assert_true(_open())
	var button: Button = _button("detector")
	if button == null:
		return
	assert_false(button.disabled)
	var state: Dictionary = GameState.instance.get_snapshot().duplicate(true)
	button.pressed.emit()
	assert_eq(requests.size(), 1)
	if requests.size() != 1:
		return
	var first_id: int = int(requests[0]["request_id"])
	assert_gt(first_id, 0)
	assert_true(button.disabled, "pending intent prevents another purchase")
	# Production timeout uses wall-clock ticks. Wait real frames past its 8s
	# threshold without changing time_scale, timeout constant or pending timestamp.
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 8250:
		await get_tree().process_frame
	assert_gte(Time.get_ticks_msec() - started, 8000, "real timeout elapsed")
	assert_true(_is_open())
	assert_false(button.disabled, "same intent can be retried after no reply")
	button.pressed.emit()
	assert_eq(requests.size(), 2)
	if requests.size() != 2:
		return
	assert_eq(str(requests[1]["upgrade_id"]), "detector")
	assert_eq(int(requests[1]["request_id"]), first_id, "timeout retry must reuse original intent ID")
	assert_true(button.disabled)
	# Deliver the held original response while retry is pending. It must still
	# correlate and finish that intent, rather than be dropped as an old ID.
	_shop.call("complete_purchase", first_id, true, "Compra concluida")
	assert_false(button.disabled, "late original reply resolves the retried intent")
	assert_eq(int(_shop.get("_pending_request")), 0)
	button.pressed.emit()
	assert_eq(requests.size(), 3)
	if requests.size() == 3:
		assert_gt(int(requests[2]["request_id"]), first_id, "explicit purchase after completion is a new intent")
	assert_eq(GameState.instance.get_snapshot(), state, "held UI transport does not claim host purchase/debit")


func test_contextual_modal_suppresses_generic_world_interactable_focus() -> void:
	if not _fixture():
		return
	var target: Interactable = Interactable.new()
	target.focus_offset = Vector3(0, 1.6, 0)
	_world.add_child(target)
	target.global_position = _actor.global_position + Vector3(0, 0, -1.2)
	_actor.camera.look_at(target.get_focus_point())
	Interactable._update_focus(get_tree())
	assert_same(Interactable.get_focused(), target, "real target is usable before modal")
	assert_true(_open())
	Interactable._update_focus(get_tree())
	assert_null(Interactable.get_focused(), "E in shop cannot reach another world interaction")
	_shop.call("close")
	Interactable._update_focus(get_tree())
	assert_same(Interactable.get_focused(), target, "closing returns world focus")
	Interactable.reset_focus()
