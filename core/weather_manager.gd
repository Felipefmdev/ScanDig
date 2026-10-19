class_name WeatherManager
extends Node

## Clima por mapa (#99): chuva (Praia, Campo), nevasca (Geleira) e tempestade de cinzas
## (Cratera); Ruínas não tem evento. Um evento por vez, em três fases: "warning" (aviso, ainda
## sem efeito), "active" (modificadores valem) e "none". O host decide (RNG próprio) e difunde
## cada mudança de fase pelo HostSync; quem entra no meio recebe o estado ao carregar o mapa.
## Os clientes só aplicam o que recebem, nunca agendam. Fora de expedição tudo fica neutro.
## Visual e aviso: ui/weather_hud.gd (autoload CoreWeatherUI) escuta weather_changed.
## Autoload CoreWeather (mesmo caminho em todos os peers: /root/CoreWeather).

signal weather_changed(kind: String, phase: String)
## Atalho de debug (F3; o F8 para o jogo rodando pelo editor): aviso curto para a tela local (WeatherHud mostra).
signal debug_toast(text: String)

const PHASE_NONE: String = "none"
const PHASE_WARNING: String = "warning"
const PHASE_ACTIVE: String = "active"
const KIND_RAIN: String = "rain"
const KIND_BLIZZARD: String = "blizzard"
const KIND_ASHSTORM: String = "ashstorm"

## Tempos por mapa (segundos). Tudo aqui (e não em campos do MapData) para afinar o ritmo dos
## cinco mapas num lugar só, sem regravar .tres; Ruínas fica de fora (sem evento).
## intensity escala o efeito do tipo (EFFECTS_BY_KIND): 1 = valor cheio.
const WEATHER_BY_MAP: Dictionary = {
	"praia": {"kind": KIND_RAIN, "warning_s": 12.0, "duration_min": 60.0, "duration_max": 80.0,
		"interval_min": 150.0, "interval_max": 240.0, "intensity": 1.0},
	"campo": {"kind": KIND_RAIN, "warning_s": 12.0, "duration_min": 60.0, "duration_max": 90.0,
		"interval_min": 180.0, "interval_max": 270.0, "intensity": 0.85},
	"geleira": {"kind": KIND_BLIZZARD, "warning_s": 15.0, "duration_min": 70.0, "duration_max": 90.0,
		"interval_min": 180.0, "interval_max": 260.0, "intensity": 1.0},
	"cratera": {"kind": KIND_ASHSTORM, "warning_s": 12.0, "duration_min": 60.0, "duration_max": 80.0,
		"interval_min": 170.0, "interval_max": 250.0, "intensity": 1.0},
}
## Modificadores de jogo no auge (intensity 1) de cada tipo; o que falta é neutro.
## dig_speed: × velocidade de cavar · detector_noise: 0..1 de tremor/blips falsos no visor ·
## radar_scale: × alcance do detector · hunger: × gasto de fome.
const EFFECTS_BY_KIND: Dictionary = {
	KIND_RAIN: {"dig_speed": 1.3, "detector_noise": 0.35},
	KIND_BLIZZARD: {"hunger": 1.6},
	KIND_ASHSTORM: {"radar_scale": 0.6},
}
## Aviso curto do force_weather (bot/teste).
const FORCE_WARNING_S: float = 3.0
## Variação sorteada da intensidade a cada evento (× a do mapa).
const INTENSITY_JITTER: Vector2 = Vector2(0.85, 1.0)
## F3 (só build de debug): lido direto do teclado, fora do InputMap e da aba Controles.
const DEBUG_KEY: Key = KEY_F3
const DEBUG_FORCED_TEXT: String = "Clima forçado (F3)"
const DEBUG_ENDED_TEXT: String = "Clima encerrado (F3)"
const DEBUG_HOST_ONLY_TEXT: String = "Só o host (F3)"
const DEBUG_NO_WEATHER_TEXT: String = "Sem clima neste mapa (F3)"

static var instance: WeatherManager = null

var _kind: String = ""
var _phase: String = PHASE_NONE
var _time_left: float = 0.0
var _intensity: float = 1.0
var _map_id: String = ""
## Host com o ciclo correndo (num mapa com clima).
var _running: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Atalho F3 ligado (os testes trocam; no export release fica desligado e nem lê o teclado).
var debug_shortcuts: bool = OS.is_debug_build()


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	_rng.randomize()
	set_process_unhandled_input(debug_shortcuts)
	var sm: SessionManager = SessionManager.instance
	if sm != null:
		sm.expedition_started.connect(_on_expedition_started)
		sm.expedition_ending.connect(func(_map: String) -> void: stop())
		sm.scene_changing.connect(func(_target: String) -> void: stop())
	HostSync.on_peer_ready(self, func(peer_id: int) -> void:
		HostSync.send_to(self, peer_id, &"_rpc_sync", [get_state()]))


func _process(delta: float) -> void:
	if _running:
		tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not debug_shortcuts:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != DEBUG_KEY:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	debug_toast.emit(debug_toggle())


## F3: sem evento, força o do mapa; em aviso/ativo, encerra com o fim normal. Devolve o aviso.
func debug_toggle() -> String:
	if not _is_host():
		return DEBUG_HOST_ONLY_TEXT
	if _phase == PHASE_NONE:
		force_weather()
		return DEBUG_FORCED_TEXT if _phase != PHASE_NONE else DEBUG_NO_WEATHER_TEXT
	force_end()
	return DEBUG_ENDED_TEXT


# --- Consultas (neutras sem evento ativo) ------------------------------------------

func current_kind() -> String:
	return _kind


func phase() -> String:
	return _phase


func is_active() -> bool:
	return _phase == PHASE_ACTIVE


func time_left() -> float:
	return _time_left


func intensity() -> float:
	return _intensity


func dig_speed_mult() -> float:
	return _effect_mult("dig_speed")


func detector_noise() -> float:
	if not is_active():
		return 0.0
	return float((EFFECTS_BY_KIND.get(_kind, {}) as Dictionary).get("detector_noise", 0.0)) * _intensity


func radar_scale() -> float:
	return _effect_mult("radar_scale")


func hunger_mult() -> float:
	return _effect_mult("hunger")


## Multiplicador do tipo atual, puxado para 1 pela intensidade (1 sem evento ou no aviso).
func _effect_mult(key: String) -> float:
	if not is_active():
		return 1.0
	var full: float = float((EFFECTS_BY_KIND.get(_kind, {}) as Dictionary).get(key, 1.0))
	return lerpf(1.0, full, _intensity)


## Atalhos para o gameplay: neutros sem o CoreWeather (testes, bots, cena aberta direto).
static func now_dig_speed_mult() -> float:
	return instance.dig_speed_mult() if instance != null else 1.0


static func now_detector_noise() -> float:
	return instance.detector_noise() if instance != null else 0.0


static func now_radar_scale() -> float:
	return instance.radar_scale() if instance != null else 1.0


static func now_hunger_mult() -> float:
	return instance.hunger_mult() if instance != null else 1.0


static func config_for(map_id: String) -> Dictionary:
	return WEATHER_BY_MAP.get(map_id, {}) as Dictionary


# --- Ciclo (host) ------------------------------------------------------------------

## Host: começa o ciclo do mapa (sem evento no mapa: fica neutro e parado).
func start_cycle(map_id: String) -> void:
	stop()
	_map_id = map_id
	if not _is_host() or config_for(map_id).is_empty():
		return
	_running = true
	_time_left = _roll_interval()


## Para tudo e volta ao neutro (fim da expedição, troca de cena, lobby). Cada peer para sozinho.
func stop() -> void:
	_running = false
	_time_left = 0.0
	_set_state("", PHASE_NONE, 0.0, 1.0, false)


## Avança o relógio do host (o _process chama; os testes chamam direto, sem tempo real).
func tick(delta: float) -> void:
	if not _running or not _is_host():
		return
	_time_left -= delta
	while _running and _time_left <= 0.0:
		_advance_phase()


func _advance_phase() -> void:
	var config: Dictionary = config_for(_map_id)
	match _phase:
		PHASE_NONE:
			if config.is_empty():
				_running = false
				return
			var level: float = float(config.get("intensity", 1.0)) * _rng.randf_range(INTENSITY_JITTER.x, INTENSITY_JITTER.y)
			_set_state(str(config["kind"]), PHASE_WARNING, _time_left + float(config.get("warning_s", 12.0)), level, true)
		PHASE_WARNING:
			_set_state(_kind, PHASE_ACTIVE, _time_left + _roll_duration(), _intensity, true)
		_:
			_end_event(_time_left + _roll_interval())


## Fim do evento: avisa com o tipo que acabou ("O tempo abriu") e volta ao intervalo.
func _end_event(next_interval: float) -> void:
	_set_state(_kind, PHASE_NONE, next_interval, 1.0, true)
	_kind = ""


func _roll_interval() -> float:
	var config: Dictionary = config_for(_map_id)
	return _rng.randf_range(float(config.get("interval_min", 180.0)), float(config.get("interval_max", 240.0)))


func _roll_duration() -> float:
	var config: Dictionary = config_for(_map_id)
	return _rng.randf_range(float(config.get("duration_min", 60.0)), float(config.get("duration_max", 90.0)))


## Host (bot/testes): dispara já o evento do mapa atual, com um aviso curto.
func force_weather() -> void:
	if not _is_host():
		return
	var map_id: String = _current_map_id()
	var config: Dictionary = config_for(map_id)
	if config.is_empty():
		push_warning("WeatherManager: o mapa '%s' não tem clima." % map_id)
		return
	_map_id = map_id
	_running = true
	_set_state(str(config["kind"]), PHASE_WARNING, FORCE_WARNING_S, float(config.get("intensity", 1.0)), true)


## Host (F3/testes): encerra já o evento em aviso ou ativo, com o mesmo fim natural (fase
## "none" difundida e próximo intervalo sorteado). Sem evento, não faz nada.
func force_end() -> void:
	if not _is_host() or _phase == PHASE_NONE:
		return
	_running = not config_for(_map_id).is_empty()
	_end_event(_roll_interval())


## Host (testes): evento `kind` já ativo por `duration` s, com intensidade cheia.
func force_event(kind: String, duration: float) -> void:
	if not _is_host() or not EFFECTS_BY_KIND.has(kind):
		return
	_running = true
	_set_state(kind, PHASE_ACTIVE, duration, 1.0, true)


## Testes: sorteios repetíveis.
func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## Mapa atual: o da expedição; sem SessionManager (bot que abre a cena direto), o nome da cena.
func _current_map_id() -> String:
	var sm: SessionManager = SessionManager.instance
	if sm != null and sm.get_current_map() != null:
		return sm.get_current_map().id
	if is_inside_tree() and get_tree().current_scene != null:
		var file: String = get_tree().current_scene.scene_file_path.get_file().get_basename()
		if file.begins_with("map_"):
			return file.trim_prefix("map_")
	return _map_id


## Verdadeiro onde o clima se decide (solo, fora da árvore nos testes, ou host).
func _is_host() -> bool:
	return HostSync.is_host(self)


func _on_expedition_started(map_id: String) -> void:
	if _is_host():
		start_cycle(map_id)


# --- Estado e sincronização -----------------------------------------------------------

func get_state() -> Dictionary:
	return {"kind": _kind, "phase": _phase, "time_left": _time_left, "intensity": _intensity, "map_id": _map_id}


## Aplica e avisa (sinal) se o tipo ou a fase mudou; com `broadcast`, o host manda aos peers.
func _set_state(kind: String, new_phase: String, time_left_s: float, level: float, broadcast: bool) -> void:
	var changed: bool = kind != _kind or new_phase != _phase
	_kind = kind
	_phase = new_phase
	_time_left = time_left_s
	_intensity = level
	if changed:
		weather_changed.emit(_kind, _phase)
	if broadcast:
		_broadcast_state()


func _broadcast_state() -> void:
	HostSync.broadcast(self, &"_rpc_sync", [get_state()])


## Clientes: estado do host (mudança de fase ou entrada no meio). Nunca agenda.
@rpc("authority", "call_remote", "reliable")
func _rpc_sync(state: Dictionary) -> void:
	_running = false
	_map_id = str(state.get("map_id", _map_id))
	var new_phase: String = str(state.get("phase", PHASE_NONE))
	if not [PHASE_NONE, PHASE_WARNING, PHASE_ACTIVE].has(new_phase):
		return
	_set_state(str(state.get("kind", "")), new_phase, float(state.get("time_left", 0.0)), clampf(float(state.get("intensity", 1.0)), 0.0, 1.0), false)
	if _phase == PHASE_NONE:
		_kind = ""
