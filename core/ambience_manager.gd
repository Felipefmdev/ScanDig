class_name AmbienceManager
extends Node

## Ambiente sonoro em loop por mapa (#123) e o loop do clima (#99) por cima dele, no bus "Ambient"
## (filho do SFX em default_bus_layout.tres: o volume de efeitos dos ajustes também o controla).
## Fade-in ao carregar o mapa (scene_loaded) e fade-out no scene_changing; de noite (#109) Praia e
## Campo trocam de loop (sem gaivotas / grilos). O clima entra com fade no aviso (baixo, ao longe),
## sobe no "active" e sai com fade no fim. Só local: cada peer toca o seu, a partir do mapa e do
## clima que já recebeu. Loops: tools/gen_audio.py (import com loop=true).
## Autoload CoreAmbience.

const BUS: StringName = &"Ambient"
const _GEN: String = "res://assets/audio/generated/"
## Por mapa (MapData.id): loop de dia, de noite (opcional) e volume em dB (fundo: bem abaixo dos
## passos, que tocam a -16 dB + o offset da superfície).
const AMBIENT_BY_MAP: Dictionary = {
	"praia": {"day": _GEN + "amb_praia_day.ogg", "night": _GEN + "amb_praia_night.ogg", "db": -18.0},
	"campo": {"day": _GEN + "amb_campo_day.ogg", "night": _GEN + "amb_campo_night.ogg", "db": -19.0},
	"ruinas": {"day": _GEN + "amb_ruinas.ogg", "db": -17.0},
	"geleira": {"day": _GEN + "amb_geleira.ogg", "db": -18.0},
	"cratera": {"day": _GEN + "amb_cratera.ogg", "db": -15.0},
	"ilha_tesouro": {"day": _GEN + "amb_ilha.ogg", "db": -18.0},
}
## Por tipo de clima (WeatherManager.KIND_*): loop e volume no auge, nunca acima do passo no chão
## dos mapas onde cai (chuva: areia/grama; nevasca: neve -3; cinzas: cristal -2).
const WEATHER_LOOPS: Dictionary = {
	"rain": {"path": _GEN + "weather_rain.ogg", "db": -17.0},
	"blizzard": {"path": _GEN + "weather_blizzard.ogg", "db": -19.0},
	"ashstorm": {"path": _GEN + "weather_ashstorm.ogg", "db": -18.0},
}
## No aviso o clima já se ouve, mais baixo (vem chegando).
const WARNING_DB_OFFSET: float = -12.0
const SILENT_DB: float = -60.0
const MAP_SCENE_PREFIX: String = "res://world/map_"

var fade_in_s: float = 2.5
var fade_out_s: float = 0.8
var weather_fade_s: float = 3.0

var _map_player: AudioStreamPlayer = null
var _weather_player: AudioStreamPlayer = null
var _map_path: String = ""
var _weather_kind: String = ""
var _tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_map_player = _make_player(&"MapAmbience")
	_weather_player = _make_player(&"WeatherAmbience")
	var sm: SessionManager = SessionManager.instance
	if sm != null:
		sm.scene_loaded.connect(_on_scene_loaded)
		sm.scene_changing.connect(func(_target: String) -> void: stop_all())
	var wm: WeatherManager = WeatherManager.instance
	if wm != null:
		wm.weather_changed.connect(set_weather)
	# Cena de mapa aberta direto (bot, editor): toca o ambiente dela também.
	_play_initial_scene.call_deferred()


func _make_player(node_name: StringName) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = node_name
	p.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else SFX.BUS
	p.volume_db = SILENT_DB
	add_child(p)
	return p


## Loop do mapa (`night`: a variante noturna, se houver). Mapa sem ambiente: silencia.
static func ambient_path(map_id: String, night: bool) -> String:
	var cfg: Dictionary = AMBIENT_BY_MAP.get(map_id, {}) as Dictionary
	if night and cfg.has("night"):
		return str(cfg["night"])
	return str(cfg.get("day", ""))


## map_praia.tscn -> "praia"; fora de mapa (lobby, título) -> "".
static func map_id_from_scene(scene_path: String) -> String:
	if not scene_path.begins_with(MAP_SCENE_PREFIX):
		return ""
	return scene_path.trim_prefix(MAP_SCENE_PREFIX).trim_suffix(".tscn")


func _play_initial_scene() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null and map_id_from_scene(scene.scene_file_path) != "" and _map_path == "":
		_on_scene_loaded(scene.scene_file_path)


func _on_scene_loaded(scene_path: String) -> void:
	var map_id: String = map_id_from_scene(scene_path)
	if map_id == "":
		stop_all()
		return
	play_map(map_id, SessionManager.is_night())
	var wm: WeatherManager = WeatherManager.instance
	if wm != null:
		set_weather(wm.current_kind(), wm.phase())


func play_map(map_id: String, night: bool = false) -> void:
	var path: String = ambient_path(map_id, night)
	if path == "" or not ResourceLoader.exists(path):
		_fade(_map_player, SILENT_DB, fade_out_s, true)
		_map_path = ""
		return
	var db: float = float((AMBIENT_BY_MAP[map_id] as Dictionary).get("db", -12.0))
	if path != _map_path or not _map_player.playing:
		_map_path = path
		_start(_map_player, load(path) as AudioStream)
	_fade(_map_player, db, fade_in_s)


## Liga o loop do clima: aviso = baixo, active = cheio, none (ou tipo sem loop) = sai com fade.
func set_weather(kind: String, phase: String) -> void:
	var cfg: Dictionary = WEATHER_LOOPS.get(kind, {}) as Dictionary
	if cfg.is_empty() or phase == WeatherManager.PHASE_NONE or _map_path == "":
		_weather_kind = ""
		_fade(_weather_player, SILENT_DB, weather_fade_s, true)
		return
	if kind != _weather_kind or not _weather_player.playing:
		_weather_kind = kind
		_start(_weather_player, load(str(cfg["path"])) as AudioStream)
	var db: float = float(cfg["db"]) + (WARNING_DB_OFFSET if phase == WeatherManager.PHASE_WARNING else 0.0)
	_fade(_weather_player, db, weather_fade_s)


func stop_all() -> void:
	_map_path = ""
	_weather_kind = ""
	_fade(_map_player, SILENT_DB, fade_out_s, true)
	_fade(_weather_player, SILENT_DB, fade_out_s, true)


func is_map_playing() -> bool:
	return _map_player.playing and _map_path != ""


func map_player() -> AudioStreamPlayer:
	return _map_player


func weather_player() -> AudioStreamPlayer:
	return _weather_player


func _start(p: AudioStreamPlayer, stream: AudioStream) -> void:
	p.stop()
	p.stream = stream
	p.volume_db = SILENT_DB
	# começa num ponto qualquer do loop: dois mapas seguidos não soam iguais
	var length: float = stream.get_length() if stream != null else 0.0
	p.play(randf() * length * 0.9 if length > 0.0 else 0.0)


func _fade(p: AudioStreamPlayer, to_db: float, secs: float, stop_after: bool = false) -> void:
	var old: Tween = _tweens.get(p) as Tween
	if old != null and old.is_valid():
		old.kill()
	if p.stream == null:
		return
	var t: Tween = create_tween()
	# em amplitude linear: em dB o fade-in passaria quase todo calado e subiria de uma vez
	t.tween_method(func(v: float) -> void: p.volume_db = maxf(linear_to_db(maxf(v, 0.0001)), SILENT_DB),
		db_to_linear(p.volume_db), db_to_linear(to_db), maxf(secs, 0.01))
	if stop_after:
		t.tween_callback(p.stop)
	_tweens[p] = t
