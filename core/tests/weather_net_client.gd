## Teste headless (#99), cliente do par weather_net_* (ver weather_net_host.gd). Sem argumento:
## está na Praia quando o host força a chuva (recebe aviso e depois ativo). Com "-- --late": entra
## com o evento já ativo (recebe o estado atual ao carregar o mapa). Nenhum dos dois agenda. Os
## dois recebem a noite (#109): pelo RPC de entrada ou, o atrasado, pelo sync da cena.
extends SceneTree
const PORT: int = 7813
var _late: bool = false
var _phases: Array[String] = []
var _fails: int = 0
func _w(s: float) -> void:
	await create_timer(s).timeout
func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var t: float = 0.0
	while not bool(cond.call()):
		if t >= timeout_s:
			return false
		await _w(0.25)
		t += 0.25
	return true
func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("CLIENT FAIL ", msg)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	_late = OS.get_cmdline_user_args().has("--late")
	var tag: String = "CLIENT late" if _late else "CLIENT"
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	SaveManager.instance.use_test_save_dir("weather_net_late" if _late else "weather_net_client")
	var weather: WeatherManager = WeatherManager.instance
	weather.weather_changed.connect(func(kind: String, phase: String) -> void: _phases.append("%s:%s" % [kind, phase]))
	print(tag, " join=", NetworkManager.instance.join_game("127.0.0.1", PORT))
	var active: bool = await _wait_until(func() -> bool: return weather.is_active(), 25.0)
	_check(active, "não recebeu a chuva ativa em 25 s")
	await _w(2.0)
	print(tag, " kind=", weather.current_kind(), " phase=", weather.phase(), " phases=", _phases,
		" running=", weather._running, " dig=", weather.dig_speed_mult(), " noise=", weather.detector_noise())
	_check(weather.current_kind() == WeatherManager.KIND_RAIN, "tipo=%s" % weather.current_kind())
	_check(not weather._running, "cliente agendando")
	_check(weather.dig_speed_mult() > 1.0 and weather.detector_noise() > 0.0, "modificadores da chuva no cliente")
	print(tag, " night=", SessionManager.is_night(), " night_fx=", NightFx.instance.is_active())
	_check(SessionManager.is_night(), "cliente recebeu a noite")
	_check(NightFx.instance.is_active(), "ambiente noturno no cliente")
	var env: Environment = WeatherFx.instance.current_environment_copy()
	_check(env != null and env.fog_density <= NightMode.MAX_FOG_DENSITY, "névoa noite + chuva com teto")
	if _late:
		_check(not _phases.has("rain:warning"), "atrasado viu o aviso")
		_check(_phases.has("rain:active"), "atrasado não recebeu o estado ativo")
	else:
		_check(_phases.has("rain:warning") and _phases.has("rain:active"), "faltou aviso ou ativo: %s" % [_phases])
		_check(_phases.find("rain:warning") < _phases.find("rain:active"), "ordem aviso → ativo")
	print(tag, " RESULT fails=%d" % _fails)
	quit(_fails)
