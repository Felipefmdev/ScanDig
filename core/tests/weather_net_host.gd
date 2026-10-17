## Teste headless (#99), host do par weather_net_*: o clima do host chega ao cliente na sala e a
## quem entra no meio do evento; os clientes nunca agendam. Ordem:
##   "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/weather_net_host.gd
##   (3 s depois) ... --script res://core/tests/weather_net_client.gd
##   (quando o host imprimir "HOST weather_active") ... --script res://core/tests/weather_net_client.gd -- --late
extends SceneTree
const PORT: int = 7813
var _joins: int = 0
var _fails: int = 0
func _w(s: float) -> void:
	await create_timer(s).timeout
func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("HOST FAIL ", msg)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("weather_net_host")
	print("HOST host_game=", NetworkManager.instance.host_game(PORT))
	root.multiplayer.peer_connected.connect(func(_id: int) -> void: _joins += 1)
	SessionManager.instance.request_start_expedition("praia")
	var t: float = 0.0
	while _joins < 1 and t < 15.0:
		await _w(0.5); t += 0.5
	var client_id: int = 0
	t = 0.0
	while client_id == 0 and t < 10.0:
		for peer_id: int in root.multiplayer.get_peers():
			if SessionManager.instance.is_peer_scene_ready(peer_id):
				client_id = peer_id
		await _w(0.25); t += 0.25
	_check(client_id != 0, "cliente não carregou a Praia")
	var weather: WeatherManager = WeatherManager.instance
	_check(weather.get_state()["map_id"] == "praia", "ciclo começou na expedição: %s" % weather.get_state())
	weather.force_weather()
	print("HOST weather_warning kind=", weather.current_kind(), " phase=", weather.phase())
	await _w(WeatherManager.FORCE_WARNING_S + 1.0)
	print("HOST weather_active kind=", weather.current_kind(), " phase=", weather.phase())
	_check(weather.is_active(), "evento ativo no host")
	t = 0.0
	while _joins < 2 and t < 30.0:
		await _w(0.5); t += 0.5
	print("HOST joins=", _joins)
	_check(_joins == 2, "cliente atrasado não entrou")
	await _w(6.0)
	_check(weather.is_active(), "evento ainda ativo no fim (duração 60+ s)")
	print("HOST RESULT fails=%d" % _fails)
	quit(_fails)
