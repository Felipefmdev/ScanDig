## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_host.gd
extends SceneTree
var scene_ready_pairs: Array[String] = []
func _w(s: float) -> void:
	await create_timer(s).timeout
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("net_host")
	SessionManager.instance.peer_scene_ready.connect(func(peer_id: int, map_id: String) -> void: scene_ready_pairs.append("%d:%s" % [peer_id, map_id]))
	print("HOST host_game=", NetworkManager.instance.host_game(7790))
	SessionManager.instance.request_start_expedition("praia")
	await _w(1.0)
	print("HOST scene=", current_scene.name)
	var t: float = 0.0
	while NetworkManager.instance.connected_players.size() < 2 and t < 15.0:
		await _w(0.5); t += 0.5
	print("HOST players=", NetworkManager.instance.connected_players.size())
	# O ENet sorteia o id do cliente: pega o que não é o host.
	var client_id: int = 0
	for peer_id: int in NetworkManager.instance.connected_players.keys():
		if peer_id != 1:
			client_id = peer_id
	t = 0.0
	while not SessionManager.instance.is_peer_scene_ready(client_id) and t < 8.0:
		await _w(0.25); t += 0.25
	var ready_peers: Array[int] = SessionManager.instance.get_ready_peers()
	print("HOST scene_ready=", ready_peers, " client_id=", client_id, " ok=", ready_peers == [1, client_id], " signals=", scene_ready_pairs)
	await _w(4.0)
	GameState.instance.request_report_discovery("alianca_ouro", 400)
	await _w(1.0)
	SessionManager.instance.request_end_expedition()
	await _w(4.0)
	print("HOST ready_after_end=", SessionManager.instance.get_ready_peers())
	print("HOST day=", GameState.instance.current_day, " money=", GameState.instance.team_money)
	quit(0)
