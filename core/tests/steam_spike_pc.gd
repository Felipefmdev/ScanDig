## Spike #54: teste em 2 PCs, com 2 contas Steam diferentes (a mesma conta não entra no
## próprio lobby). Roteiro em docs/spikes/STEAM_SPIKE_54.md.
##   PC 1: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --script res://core/tests/steam_spike_pc.gd -- host
##   PC 2: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --script res://core/tests/steam_spike_pc.gd -- join=K7Q-3MX
## O host cria o lobby público (máx. 4), imprime o código, espera alguém entrar (até 5 min),
## faz uma expedição na Praia com o cliente e imprime "HOST RESULT fails=N". O cliente acha o
## lobby pelo código, entra, conecta pelo SteamPeer e imprime "CLIENT RESULT fails=N".
## Funciona com ou sem --headless. Save isolado em user://test_saves/steam_spike_pc_*.
extends SceneTree

const LOBBY_TYPE_PUBLIC: int = 2
const LOBBY_DISTANCE_WORLDWIDE: int = 3
const COMPARISON_EQUAL: int = 0
const MAX_MEMBERS: int = 4
const LOBBY_ENTER_SUCCESS: int = 1
const WAIT_PLAYER_SEC: float = 300.0

var _fails: int = 0
var _steam: Object = null
var _lobby_id: int = 0
var _lobby_list: Array = []
var _joined: Array = []
var _summary: Dictionary = {}


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _w(s: float) -> void:
	await create_timer(s).timeout


## Roda os callbacks da Steam enquanto espera (o peer também roda no _poll).
func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var t: float = 0.0
	while not bool(cond.call()):
		if t >= timeout_s:
			return false
		_steam.call("run_callbacks")
		await _w(0.1)
		t += 0.1
	return true


func _arg(key: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a == key:
			return "1"
		if a.begins_with(key + "="):
			return a.get_slice("=", 1)
	return ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	var role: String = "host" if _arg("host") != "" else ("join" if _arg("join") != "" else "")
	if role == "":
		print("Use -- host ou -- join=CÓDIGO")
		quit(2)
		return
	SaveManager.instance.use_test_save_dir("steam_spike_pc_" + role)
	if not Engine.has_singleton("Steam"):
		print("SKIP steam (sem GodotSteam)")
		_finish(role)
		return
	_steam = Engine.get_singleton("Steam")
	var init: Dictionary = _steam.call("steamInitEx", 480)
	print("%s steamInitEx -> %s" % [role.to_upper(), str(init)])
	if int(init.get("status", -1)) != 0:
		_check(false, "Steam não iniciou (a Steam está aberta e logada?)")
		_finish(role)
		return
	_steam.call("initRelayNetworkAccess")
	# Métodos (não lambdas), desconectados antes do steamShutdown no _finish.
	_steam.connect("lobby_created", _on_lobby_created)
	_steam.connect("lobby_match_list", _on_lobby_match_list)
	_steam.connect("lobby_joined", _on_lobby_joined)
	_steam.connect("join_requested", _on_join_requested)
	SessionManager.instance.expedition_ended.connect(func(s: Dictionary) -> void: _summary = s)
	if role == "host":
		await _run_host()
	else:
		await _run_join(_arg("join"))
	_finish(role)


func _on_lobby_created(connect: int, lobby_id: int) -> void:
	_lobby_id = lobby_id if connect == 1 else -1


func _on_lobby_match_list(lobbies: Array) -> void:
	_lobby_list = lobbies


func _on_lobby_joined(lobby: int, _permissions: int, _locked: bool, response: int) -> void:
	_joined = [lobby, response]


## Convite aceito na lista de amigos / overlay com o jogo aberto.
func _on_join_requested(lobby: int, friend: int) -> void:
	print("join_requested lobby=%d amigo=...%s" % [lobby, str(friend).right(4)])


func _run_host() -> void:
	var gs: GameState = GameState.instance
	var sm: SessionManager = SessionManager.instance
	var net: NetworkManager = NetworkManager.instance
	gs.reset_state()
	_steam.call("createLobby", LOBBY_TYPE_PUBLIC, MAX_MEMBERS)
	_check(await _wait_until(func() -> bool: return _lobby_id != 0, 15.0) and _lobby_id > 0, "lobby criado")
	if _lobby_id <= 0:
		return
	var code: String = ""
	for i in range(RoomCode.LENGTH):
		code += RoomCode.CHARSET[randi() % RoomCode.CHARSET.length()]
	_steam.call("setLobbyData", _lobby_id, "game", "scandig")
	_steam.call("setLobbyData", _lobby_id, "scandig_code", code)
	_steam.call("setLobbyData", _lobby_id, "scandig_ver", str(SteamPeer.PROTOCOL_VERSION))
	var transport: SteamPeer.SteamTransport = SteamPeer.SteamTransport.new(_steam, 0)
	transport.lobby_id = _lobby_id
	var peer: SteamPeer = SteamPeer.new()
	peer.max_clients = MAX_MEMBERS - 1
	peer.create_host(transport)
	net.spike_install_host(peer)
	print("")
	print("HOST ===== CÓDIGO DA SALA: %s =====" % RoomCode.format_for_display(code))
	print("HOST esperando alguém entrar (até %s s)..." % (_arg("wait") if _arg("wait") != "" else str(int(WAIT_PLAYER_SEC))))
	var wait_s: float = float(_arg("wait")) if _arg("wait") != "" else WAIT_PLAYER_SEC
	var joined: bool = await _wait_until(func() -> bool: return net.connected_players.size() >= 2, wait_s)
	_check(joined, "um cliente entrou")
	if not joined:
		return
	var client_id: int = 0
	for peer_id: int in net.connected_players.keys():
		if peer_id != 1:
			client_id = peer_id
	var remote: int = peer.get_remote_for_peer(client_id)
	print("HOST cliente peer_id=%d SteamID=...%s" % [client_id, str(remote).right(4)])
	_print_connection("HOST", remote)
	sm.request_start_expedition("praia")
	var ready: bool = await _wait_until(func() -> bool: return sm.is_peer_scene_ready(client_id), 30.0)
	_check(ready, "cliente carregou a Praia (peer_scene_ready)")
	await _w(5.0)
	gs.request_report_discovery("alianca_ouro", 400)
	await _w(1.0)
	sm.request_end_expedition()
	_check(await _wait_until(func() -> bool: return not _summary.is_empty(), 20.0), "resumo da expedição")
	_check(gs.current_day == 2 and gs.team_money == 300, "dia 2, R$ 300: dia %d R$ %d" % [gs.current_day, gs.team_money])
	_print_connection("HOST", remote)
	await _w(5.0)
	net.disconnect_game()
	_steam.call("leaveLobby", _lobby_id)


func _run_join(raw_code: String) -> void:
	var gs: GameState = GameState.instance
	var net: NetworkManager = NetworkManager.instance
	var code: String = RoomCode.normalize(raw_code)
	_check(RoomCode.is_valid(code), "código válido: %s" % code)
	_steam.call("addRequestLobbyListStringFilter", "game", "scandig", COMPARISON_EQUAL)
	_steam.call("addRequestLobbyListStringFilter", "scandig_code", code, COMPARISON_EQUAL)
	_steam.call("addRequestLobbyListStringFilter", "scandig_ver", str(SteamPeer.PROTOCOL_VERSION), COMPARISON_EQUAL)
	_steam.call("addRequestLobbyListDistanceFilter", LOBBY_DISTANCE_WORLDWIDE)
	_steam.call("addRequestLobbyListResultCountFilter", 2)
	_lobby_list = [-1]
	_steam.call("requestLobbyList")
	await _wait_until(func() -> bool: return _lobby_list != [-1], 15.0)
	_check(_lobby_list.size() == 1, "busca pelo código achou 1 lobby: %s" % str(_lobby_list))
	if _lobby_list.size() != 1:
		return
	var lobby_id: int = int(_lobby_list[0])
	var t0: int = Time.get_ticks_msec()
	_steam.call("joinLobby", lobby_id)
	await _wait_until(func() -> bool: return not _joined.is_empty(), 15.0)
	_check(not _joined.is_empty() and int(_joined[1]) == LOBBY_ENTER_SUCCESS, "entrou no lobby: %s" % str(_joined))
	if _joined.is_empty() or int(_joined[1]) != LOBBY_ENTER_SUCCESS:
		return
	var owner: int = _steam.call("getLobbyOwner", lobby_id)
	var transport: SteamPeer.SteamTransport = SteamPeer.SteamTransport.new(_steam, 0)
	transport.lobby_id = lobby_id
	var peer: SteamPeer = SteamPeer.new()
	peer.create_client(transport, owner)
	var connected: Array[bool] = [false]
	net.connection_succeeded.connect(func() -> void: connected[0] = true)
	net.spike_install_client(peer)
	_check(await _wait_until(func() -> bool: return connected[0], 20.0), "conectou ao host em %d ms" % (Time.get_ticks_msec() - t0))
	print("CLIENT meu peer_id=%d" % get_multiplayer().get_unique_id())
	_print_connection("CLIENT", owner)
	var in_map: bool = await _wait_until(func() -> bool: return current_scene != null and current_scene.name == "MapPraia", 30.0)
	_check(in_map, "entrou na Praia")
	var back: bool = await _wait_until(func() -> bool: return not _summary.is_empty() and current_scene != null and current_scene.name == "LobbyBase", 60.0)
	_check(back, "voltou ao lobby com o resumo")
	_check(gs.current_day == 2 and gs.team_money == 300 and gs.discovered_items.has("alianca_ouro"), "estado do host: dia %d R$ %d %s" % [gs.current_day, gs.team_money, str(gs.discovered_items)])
	_print_connection("CLIENT", owner)
	var lost: bool = await _wait_until(func() -> bool: return net.connected_players.is_empty(), 30.0)
	print("CLIENT host saiu: ", lost)
	_steam.call("leaveLobby", lobby_id)


## Direto (punch) ou pelo relay da Steam (SDR): remote_pop/pop_relay != 0 indicam relay.
func _print_connection(tag: String, remote: int) -> void:
	var info: Dictionary = _steam.call("getSessionConnectionInfo", remote, true, true)
	print("%s conexão: estado=%s ping=%s pop_relay=%s remote_pop=%s descr=%s" % [tag, info.get("connection_state"),
		info.get("ping"), info.get("pop_relay"), info.get("remote_pop"), info.get("debug_description")])


func _finish(role: String) -> void:
	if _steam != null:
		for pair: Array in [["lobby_created", _on_lobby_created], ["lobby_match_list", _on_lobby_match_list],
				["lobby_joined", _on_lobby_joined], ["join_requested", _on_join_requested]]:
			if _steam.is_connected(String(pair[0]), pair[1] as Callable):
				_steam.disconnect(String(pair[0]), pair[1] as Callable)
		NetworkManager.instance.disconnect_game()
		_steam.call("steamShutdown")
	print("%s RESULT fails=%d" % [role.to_upper(), _fails])
	quit(_fails)
