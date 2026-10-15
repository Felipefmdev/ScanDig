## Spike #54: init da Steam na Godot 4.3 com o GodotSteam 4.15 (GDExtension).
## "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/steam_spike_init.gd [-- appid=480|skip|fake]
## appid=<n>: App ID do init (padrão 480). skip: não chama o init. fake: finge que a classe não existe.
## Também testa se uma mensagem para o próprio SteamID volta (loopback).
extends SceneTree

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _arg(key: String, default: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a == key:
			return "1"
		if a.begins_with(key + "="):
			return a.get_slice("=", 1)
	return default


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var has_class: bool = Engine.has_singleton("Steam") and _arg("fake", "") == ""
	print("INIT has_steam_class=", has_class)
	if not has_class:
		print("INIT steam indisponível: segue sem Steam")
		_finish()
		return
	var steam: Object = Engine.get_singleton("Steam")
	if _arg("skip", "") != "":
		print("INIT skip: isSteamRunning=", steam.call("isSteamRunning"), " getSteamID=", steam.call("getSteamID"))
		_finish()
		return
	var app_id: int = int(_arg("appid", "480"))
	var t0: int = Time.get_ticks_msec()
	var result: Dictionary = steam.call("steamInitEx", app_id)
	print("INIT steamInitEx(%d) -> %s em %d ms" % [app_id, str(result), Time.get_ticks_msec() - t0])
	var ok: bool = int(result.get("status", -1)) == 0
	print("INIT ok=", ok, " isSteamRunning=", steam.call("isSteamRunning"), " getAppID=", steam.call("getAppID"))
	if not ok:
		_finish()
		return
	var my_id: int = steam.call("getSteamID")
	print("INIT steam_id_suffix=...%s persona_len=%d" % [str(my_id).right(4), String(steam.call("getPersonaName")).length()])
	_check(my_id != 0, "SteamID válido")
	steam.call("initRelayNetworkAccess")
	# Loopback: mensagem para o próprio SteamID.
	var sent: int = steam.call("sendMessageToUser", my_id, "ping".to_utf8_buffer(), 8, 0)
	print("INIT sendMessageToUser(self) -> ", sent)
	var got: Array = []
	for i in range(60):
		steam.call("run_callbacks")
		got = steam.call("receiveMessagesOnChannel", 0, 16)
		if not got.is_empty():
			break
		await create_timer(0.1).timeout
	print("INIT loopback recebidas=", got.size(), " exemplo=", (str(got[0].keys()) if not got.is_empty() else "-"))
	for i in range(30):
		steam.call("run_callbacks")
		await create_timer(0.1).timeout
	print("INIT relay_status=", steam.call("getRelayNetworkStatus"))
	steam.call("steamShutdown")
	_finish()


func _finish() -> void:
	print("RESULT fails=%d" % _fails)
	quit(_fails)
