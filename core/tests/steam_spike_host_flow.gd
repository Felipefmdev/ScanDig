## Spike #54: o que dá para validar numa conta só. Init da Steam (App ID 480), lobby
## público com scandig_code, SteamPeer de host sobre a Steam (Networking Messages) como
## peer da árvore e uma expedição solo inteira com ele ativo (RPCs do GameState e da
## SessionManager sem mudança). "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/steam_spike_host_flow.gd
## Sem Steam: "SKIP steam". Save isolado em user://test_saves/steam_spike_host_flow.
extends SceneTree

const LOBBY_TYPE_PUBLIC: int = 2
const MAX_MEMBERS: int = 4

var _fails: int = 0
var _steam: Object = null
var _lobby_id: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _w(s: float) -> void:
	await create_timer(s).timeout


func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var t: float = 0.0
	while not bool(cond.call()):
		if t >= timeout_s:
			return false
		_steam.call("run_callbacks")
		await _w(0.1)
		t += 0.1
	return true


func _initialize() -> void:
	_run.call_deferred()


func _on_lobby_created(connect: int, lobby_id: int) -> void:
	_lobby_id = lobby_id if connect == 1 else -1


func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	SaveManager.instance.use_test_save_dir("steam_spike_host_flow")
	if not Engine.has_singleton("Steam"):
		print("SKIP steam (sem GodotSteam)")
		_finish()
		return
	_steam = Engine.get_singleton("Steam")
	var init: Dictionary = _steam.call("steamInitEx", 480)
	if int(init.get("status", -1)) != 0:
		print("SKIP steam: ", init)
		_finish()
		return
	_steam.call("initRelayNetworkAccess")
	_steam.connect("lobby_created", _on_lobby_created)
	_steam.call("createLobby", LOBBY_TYPE_PUBLIC, MAX_MEMBERS)
	_check(await _wait_until(func() -> bool: return _lobby_id != 0, 10.0) and _lobby_id > 0, "lobby criado")
	var code: String = ""
	for i in range(RoomCode.LENGTH):
		code += RoomCode.CHARSET[randi() % RoomCode.CHARSET.length()]
	_steam.call("setLobbyData", _lobby_id, "game", "scandig")
	_steam.call("setLobbyData", _lobby_id, "scandig_code", code)
	_steam.call("setLobbyData", _lobby_id, "scandig_ver", str(SteamPeer.PROTOCOL_VERSION))
	print("FLOW lobby code=", RoomCode.format_for_display(code))

	var peer: SteamPeer = SteamPeer.new()
	var transport: SteamPeer.SteamTransport = SteamPeer.SteamTransport.new(_steam, 0)
	_check(peer.create_host(transport) == OK, "SteamPeer host")
	get_multiplayer().multiplayer_peer = peer
	_check(get_multiplayer().get_unique_id() == 1 and get_multiplayer().is_server(), "get_unique_id()=1 e is_server() com o peer da Steam")
	_check(GameState.instance.is_authority(), "GameState é autoridade")

	# Expedição solo inteira com o peer da Steam ativo (os RPCs saem para ninguém).
	var gs: GameState = GameState.instance
	var sm: SessionManager = SessionManager.instance
	gs.reset_state()
	var summary: Array[Dictionary] = []
	sm.expedition_ended.connect(func(s: Dictionary) -> void: summary.append(s))
	sm.request_start_expedition("praia")
	_check(await _wait_until(func() -> bool: return current_scene != null and current_scene.name == "MapPraia" and sm.is_in_expedition(), 10.0), "entrou na Praia")
	# Deixa o mapa terminar o _ready (o SpotSpawner espera 2 physics_frame).
	await _w(2.0)
	gs.request_report_discovery("alianca_ouro", 400)
	sm.request_end_expedition()
	_check(await _wait_until(func() -> bool: return not summary.is_empty() and current_scene != null and current_scene.name == "LobbyBase", 15.0), "voltou ao lobby com resumo")
	_check(gs.current_day == 2 and gs.discovered_items.has("alianca_ouro") and gs.team_money == 300, "dia 2, R$ 300, aliança no museu: dia %d R$ %d" % [gs.current_day, gs.team_money])

	peer.close()
	get_multiplayer().multiplayer_peer = OfflineMultiplayerPeer.new()
	_steam.call("leaveLobby", _lobby_id)
	_steam.disconnect("lobby_created", _on_lobby_created)
	_steam.call("run_callbacks")
	_steam.call("steamShutdown")
	gs.reset_state()
	_finish()


func _finish() -> void:
	print("RESULT fails=%d" % _fails)
	quit(_fails)
