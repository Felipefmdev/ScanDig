extends GutTest

## #83: criatura morta pelo convidado entra no Diário. No host, EnemyBase._die roda dentro da RPC
## do golpe do convidado (sender = convidado); report_creature adia e o _is_host_sender vê sender 0.
## O par em rede usa dois SceneMultiplayer locais (ENet na porta 7812), cada um com um GameState
## próprio: o CoreGameState autoload e o multiplayer da raiz não são tocados.

const PORT: int = 7812


## Lado host: recebe o "golpe" do convidado e reporta a criatura ainda dentro da RPC.
class HitRelay extends Node:
	var game_state: GameState = null
	var calls: int = 0
	var sender_in_rpc: int = -1
	var seen_inside_rpc: bool = false

	@rpc("any_peer", "call_remote", "reliable")
	func hit_creature(kind: String) -> void:
		calls += 1
		sender_in_rpc = multiplayer.get_remote_sender_id()
		game_state.report_creature(kind)
		seen_inside_rpc = game_state.seen_creatures.has(kind)


var _orig_seen: Array[String] = []


func before_each() -> void:
	_orig_seen = GameState.instance.seen_creatures.duplicate()


func after_each() -> void:
	GameState.instance.seen_creatures = _orig_seen


func test_inside_remote_rpc() -> void:
	assert_true(GameState._inside_remote_rpc(2))
	assert_true(GameState._inside_remote_rpc(3))
	assert_true(GameState._inside_remote_rpc(398206712), "id sorteado pelo ENet")
	assert_false(GameState._inside_remote_rpc(0), "chamada local")
	assert_false(GameState._inside_remote_rpc(GameState.HOST_PEER_ID), "o próprio host")


func test_offline_report_is_synchronous() -> void:
	var gs: GameState = GameState.instance
	var empty: Array[String] = []
	gs.seen_creatures = empty
	watch_signals(gs)
	gs.report_creature("crab")
	assert_true(gs.seen_creatures.has("crab"), "offline: entra na hora")
	assert_signal_emit_count(gs, "creature_discovered", 1)
	gs.report_creature("crab")
	assert_signal_emit_count(gs, "creature_discovered", 1, "segunda morte do mesmo tipo não repete")


## Monta um lado do par: nó com SceneMultiplayer próprio, um GameState e o relay.
func _side(side_name: String, peer: ENetMultiplayerPeer) -> Node:
	var side: Node = Node.new()
	side.name = side_name
	add_child_autofree(side)
	var mp: SceneMultiplayer = SceneMultiplayer.new()
	get_tree().set_multiplayer(mp, side.get_path())
	mp.multiplayer_peer = peer
	var gs: GameState = GameState.new()
	gs.name = "CoreGameState"
	side.add_child(gs)
	var relay: HitRelay = HitRelay.new()
	relay.name = "Relay"
	relay.game_state = gs
	side.add_child(relay)
	return side


func test_guest_kill_enters_journal_after_a_frame() -> void:
	var server: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server.create_server(PORT, 2), OK, "servidor na porta %d" % PORT)
	var client: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client.create_client("127.0.0.1", PORT), OK)
	var host_side: Node = _side("HostSide", server)
	var client_side: Node = _side("ClientSide", client)
	var host_gs: GameState = host_side.get_node(^"CoreGameState") as GameState
	var host_relay: HitRelay = host_side.get_node(^"Relay") as HitRelay
	var client_relay: HitRelay = client_side.get_node(^"Relay") as HitRelay
	assert_true(host_gs.is_authority(), "lado host é a autoridade")

	var frames: int = 0
	while client.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED and frames < 300:
		await get_tree().process_frame
		frames += 1
	assert_eq(client.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED, "convidado conectou")

	watch_signals(host_gs)
	client_relay.hit_creature.rpc_id(GameState.HOST_PEER_ID, "snake")
	frames = 0
	while host_relay.calls == 0 and frames < 300:
		await get_tree().process_frame
		frames += 1
	assert_eq(host_relay.calls, 1, "o golpe do convidado chegou ao host")
	assert_true(GameState._inside_remote_rpc(host_relay.sender_in_rpc), "dentro da RPC o sender é o convidado (%d)" % host_relay.sender_in_rpc)
	assert_false(host_relay.seen_inside_rpc, "adiado: ainda não entrou dentro da RPC")
	await get_tree().process_frame
	assert_true(host_gs.seen_creatures.has("snake"), "depois de um frame a criatura está no Diário")
	assert_signal_emit_count(host_gs, "creature_discovered", 1)

	for side: Node in [client_side, host_side]:
		get_tree().set_multiplayer(null, side.get_path())
	client.close()
	server.close()
