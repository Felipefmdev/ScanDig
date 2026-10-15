## Spike #54: lobby público (máx. 4) com scandig_code e busca pelo código no App ID 480.
## "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/steam_spike_lobby.gd
## Precisa da Steam aberta; sem ela: "SKIP steam".
extends SceneTree

const LOBBY_TYPE_PUBLIC: int = 2
const LOBBY_DISTANCE_WORLDWIDE: int = 3
const COMPARISON_EQUAL: int = 0
const GAME_KEY: String = "game"
const GAME_VALUE: String = "scandig"
const PROTOCOL_VERSION: String = "1"

var _fails: int = 0
var _steam: Object = null
var _created: Array = []
var _lists: Array = []


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _pump(seconds: float, cond: Callable) -> bool:
	var t: float = 0.0
	while t < seconds:
		_steam.call("run_callbacks")
		if bool(cond.call()):
			return true
		await create_timer(0.1).timeout
		t += 0.1
	return false


func _search(filters: Dictionary, max_results: int) -> Array:
	for key: String in filters:
		_steam.call("addRequestLobbyListStringFilter", key, String(filters[key]), COMPARISON_EQUAL)
	_steam.call("addRequestLobbyListDistanceFilter", LOBBY_DISTANCE_WORLDWIDE)
	_steam.call("addRequestLobbyListResultCountFilter", max_results)
	_lists.clear()
	var t0: int = Time.get_ticks_msec()
	_steam.call("requestLobbyList")
	var ok: bool = await _pump(10.0, func() -> bool: return not _lists.is_empty())
	var lobbies: Array = _lists[0] if ok else []
	print("LOBBY busca %s -> %d lobbies em %d ms" % [str(filters), lobbies.size(), Time.get_ticks_msec() - t0])
	return lobbies


func _run() -> void:
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
	_steam.connect("lobby_created", func(connect: int, lobby_id: int) -> void: _created.append([connect, lobby_id]))
	_steam.connect("lobby_match_list", func(lobbies: Array) -> void: _lists.append(lobbies))

	# Ruído do App ID 480: quantos lobbies públicos existem sem filtro.
	var noise: Array = await _search({}, 50)
	var sample_keys: Array[String] = []
	for lobby_id: int in noise.slice(0, 5):
		sample_keys.append("%s|%s" % [_steam.call("getLobbyData", lobby_id, "name"), _steam.call("getLobbyData", lobby_id, GAME_KEY)])
	print("LOBBY ruído 480: ", noise.size(), " (amostra name|game: ", sample_keys, ")")

	var code: String = ""
	var charset: String = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
	for i in range(6):
		code += charset[randi() % charset.length()]
	var t0: int = Time.get_ticks_msec()
	_steam.call("createLobby", LOBBY_TYPE_PUBLIC, 4)
	var created: bool = await _pump(10.0, func() -> bool: return not _created.is_empty())
	_check(created and int(_created[0][0]) == 1, "lobby_created connect=1: %s em %d ms" % [str(_created), Time.get_ticks_msec() - t0])
	if not created or int(_created[0][0]) != 1:
		_finish()
		return
	var lobby_id: int = int(_created[0][1])
	var my_id: int = _steam.call("getSteamID")
	_check(_steam.call("setLobbyData", lobby_id, GAME_KEY, GAME_VALUE), "setLobbyData game")
	_check(_steam.call("setLobbyData", lobby_id, "scandig_code", code), "setLobbyData scandig_code=%s" % code)
	_check(_steam.call("setLobbyData", lobby_id, "scandig_ver", PROTOCOL_VERSION), "setLobbyData scandig_ver")
	_check(int(_steam.call("getLobbyOwner", lobby_id)) == my_id, "dono do lobby é o host")
	_check(int(_steam.call("getNumLobbyMembers", lobby_id)) == 1, "1 membro (o host)")
	_check(_steam.call("getLobbyData", lobby_id, "scandig_code") == code, "getLobbyData devolve o código")

	# A busca vem do servidor da Steam: dá um tempo para os dados do lobby propagarem.
	await _pump(1.0, func() -> bool: return false)
	var found: Array = await _search({GAME_KEY: GAME_VALUE, "scandig_code": code}, 5)
	_check(found.size() == 1 and int(found[0]) == lobby_id, "busca pelo código acha o lobby: %s" % str(found))
	var wrong: Array = await _search({GAME_KEY: GAME_VALUE, "scandig_code": "ZZZZZZ"}, 5)
	_check(wrong.is_empty(), "código inexistente não acha nada: %s" % str(wrong))
	var ours: Array = await _search({GAME_KEY: GAME_VALUE}, 50)
	print("LOBBY lobbies com game=scandig agora: ", ours.size())
	var other_ver: Array = await _search({GAME_KEY: GAME_VALUE, "scandig_code": code, "scandig_ver": "999"}, 5)
	_check(other_ver.is_empty(), "versão de protocolo diferente filtra: %s" % str(other_ver))

	_steam.call("leaveLobby", lobby_id)
	await _pump(1.5, func() -> bool: return false)
	var after: Array = await _search({GAME_KEY: GAME_VALUE, "scandig_code": code}, 5)
	_check(after.is_empty(), "lobby some da busca depois do leaveLobby: %s" % str(after))
	_steam.call("steamShutdown")
	_finish()


func _finish() -> void:
	print("RESULT fails=%d" % _fails)
	quit(_fails)
