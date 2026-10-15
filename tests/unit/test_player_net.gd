extends GutTest

## #22 Coop Fase 1: jogador local vs remoto e o PlayersRoot (contrato #5, bloco B).

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")

var _root: Node3D


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _spawn(node_name: String) -> Player:
	var p: Player = PLAYER_SCENE.instantiate() as Player
	p.name = node_name
	_root.add_child(p)
	return p


func test_local_player_owns_camera_hud_and_group() -> void:
	var p: Player = _spawn("1")
	assert_true(p.is_local())
	assert_eq(p.get_multiplayer_authority(), 1)
	assert_true(p.is_in_group(Player.LOCAL_GROUP))
	assert_true(p.is_in_group(Player.ALL_GROUP))
	assert_true(p.camera.current)
	assert_true((p.get_node("HUD") as CanvasLayer).visible)
	assert_false(p.avatar.visible, "o proprio corpo nao aparece em 1.a pessoa")
	assert_true(p.is_physics_processing())


func test_remote_player_is_a_puppet() -> void:
	var local: Player = _spawn("1")
	var remote: Player = _spawn("424242")
	assert_eq(remote.get_multiplayer_authority(), 424242)
	assert_false(remote.is_local())
	assert_false(remote.is_in_group(Player.LOCAL_GROUP), "inimigos/bot so veem o jogador local")
	assert_true(remote.is_in_group(Player.ALL_GROUP))
	assert_false(remote.camera.current, "um remoto nunca rouba a camara")
	assert_true(local.camera.current)
	assert_false((remote.get_node("HUD") as CanvasLayer).visible)
	assert_true(remote.avatar.visible)
	assert_false(remote.is_physics_processing(), "a posicao vem do NetSync")
	assert_eq(get_tree().get_first_node_in_group(Player.LOCAL_GROUP), local)


func test_damage_only_applies_to_owner() -> void:
	var local: Player = _spawn("1")
	var remote: Player = _spawn("424242")
	remote.take_damage(30.0)
	assert_eq(remote.health, remote.max_health, "vida do remoto e do dono dele")
	local.apply_damage(30.0, Vector3.ZERO)
	assert_eq(local.health, local.max_health - 30.0)


func test_held_tool_follows_selected_slot() -> void:
	var p: Player = _spawn("1")
	assert_eq(p.held_tool_id, &"")
	p.inventory.add_item(CarriedItem.create_tool(DetectorSpawn.TOOL_ID, DetectorSpawn.TOOL_NAME))
	p.inventory.select(0)
	assert_eq(p.held_tool_id, &"detector")


func test_players_root_spawns_local_player_outside_expedition() -> void:
	var players: PlayersRoot = PlayersRoot.new()
	_root.add_child(players)
	var me: Player = players.get_player(multiplayer.get_unique_id())
	assert_not_null(me, "fora de uma expedicao o host cria logo o jogador local")
	assert_true(me.is_local())
	assert_eq(players.spawn_player(multiplayer.get_unique_id()), me, "nao duplica")
	var other: Player = players.spawn_player(777)
	assert_ne(other.position, me.position, "nasce ao lado, nao dentro")
