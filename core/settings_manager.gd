class_name SettingsManager
extends Node

## Configurações do jogo (vídeo, áudio; depois controles e jogabilidade, #77). Único dono do
## user://scandig_settings.cfg: lê, aplica e grava. Preserva as seções que não são dele
## ([player] do nome e das opções do Esc, [online] do NetworkManager). A UI só fala com ele.
## Autoload CoreSettings.

signal settings_changed(section: String, values: Dictionary)
## Fim do teste de vídeo (resolução / modo de janela): kept = confirmado a tempo.
signal video_trial_finished(kept: bool)

const DEFAULT_PATH: String = "user://scandig_settings.cfg"
const VIDEO: String = "video"
const AUDIO: String = "audio"

const WINDOW_MODES: Array[String] = ["windowed", "fullscreen", "borderless"]
const FPS_LIMITS: Array[int] = [30, 60, 120, 144, 0]
const QUALITIES: Array[String] = ["low", "medium", "high"]
const UI_SCALE_RANGE: Vector2 = Vector2(0.9, 1.3)
## Resoluções comuns; a UI mostra só as que cabem no monitor.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1366, 768),
	Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]
## Buses de áudio controlados (o Music existe no default_bus_layout.tres mesmo sem música).
const AUDIO_BUSES: Dictionary = {"master": &"Master", "music": &"Music", "sfx": &"SFX"}
const VIDEO_TRIAL_SECONDS: float = 10.0

const DEFAULTS: Dictionary = {
	VIDEO: {
		"window_mode": "windowed",
		"resolution": Vector2i(1280, 720),
		"vsync": true,
		"max_fps": 0,
		"ui_scale": 1.0,
		"quality": "high",
	},
	AUDIO: {
		"master": 1.0,
		"music": 1.0,
		"sfx": 1.0,
	},
}

## Por qualidade: MSAA 3D, escala do render 3D e tamanho dos atlas de sombra.
const QUALITY_PRESETS: Dictionary = {
	"low": {"msaa": Viewport.MSAA_DISABLED, "scale_3d": 0.75, "shadow_size": 1024},
	"medium": {"msaa": Viewport.MSAA_2X, "scale_3d": 0.9, "shadow_size": 2048},
	"high": {"msaa": Viewport.MSAA_2X, "scale_3d": 1.0, "shadow_size": 4096},
}

static var instance: SettingsManager = null

var settings_path: String = DEFAULT_PATH
var _values: Dictionary = {}
var _trial_previous: Dictionary = {}
var _trial_token: int = 0
## O arquivo tinha [video]: só então o início do jogo mexe na janela (sem escolha salva, vale o
## tamanho do projeto ou o --resolution da linha de comando).
var _video_saved: bool = false


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	# Testes e capturas (--script) usam os padrões: as escolhas do jogador (escala da UI,
	# janela) mudariam layouts e PNGs. Os testes trocam settings_path e chamam load_settings().
	if OS.get_cmdline_args().has("--script"):
		_values = DEFAULTS.duplicate(true)
	else:
		load_settings()
	apply_all()


# --- Leitura -------------------------------------------------------------------

## Valores atuais de uma seção (cópia).
func get_section(section: String) -> Dictionary:
	return (_values.get(section, DEFAULTS.get(section, {})) as Dictionary).duplicate()


func get_value(section: String, key: String) -> Variant:
	return get_section(section).get(key)


func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: Error = cfg.load(settings_path)
	_values.clear()
	_video_saved = err == OK and cfg.has_section(VIDEO)
	for section: String in DEFAULTS.keys():
		var raw: Dictionary = {}
		if err == OK and cfg.has_section(section):
			for key: String in cfg.get_section_keys(section):
				raw[key] = cfg.get_value(section, key)
		_values[section] = sanitize(section, raw)


## Tipos e faixas válidos: um arquivo editado à mão não quebra o jogo.
static func sanitize(section: String, values: Dictionary) -> Dictionary:
	var out: Dictionary = (DEFAULTS.get(section, {}) as Dictionary).duplicate()
	match section:
		VIDEO:
			var mode: Variant = values.get("window_mode")
			if mode is String and WINDOW_MODES.has(mode):
				out["window_mode"] = mode
			var res: Variant = values.get("resolution")
			if res is Vector2i and res.x >= 640 and res.y >= 360:
				out["resolution"] = res
			if values.get("vsync") is bool:
				out["vsync"] = values["vsync"]
			var fps: Variant = values.get("max_fps")
			if (fps is int or fps is float) and FPS_LIMITS.has(int(fps)):
				out["max_fps"] = int(fps)
			var scale: Variant = values.get("ui_scale")
			if scale is float or scale is int:
				out["ui_scale"] = clampf(float(scale), UI_SCALE_RANGE.x, UI_SCALE_RANGE.y)
			var quality: Variant = values.get("quality")
			if quality is String and QUALITIES.has(quality):
				out["quality"] = quality
		AUDIO:
			for key: String in AUDIO_BUSES.keys():
				var v: Variant = values.get(key)
				if v is float or v is int:
					out[key] = clampf(float(v), 0.0, 1.0)
	return out


# --- Escrita -------------------------------------------------------------------

## Valida, aplica, grava e avisa. Chaves ausentes ficam com o valor atual.
func set_section(section: String, values: Dictionary, persist: bool = true) -> void:
	if not DEFAULTS.has(section):
		push_warning("SettingsManager: seção desconhecida '%s'." % section)
		return
	var merged: Dictionary = get_section(section)
	merged.merge(values, true)
	_values[section] = sanitize(section, merged)
	_apply_section(section, true)
	if persist:
		save_settings()
	settings_changed.emit(section, get_section(section))


func restore_defaults(section: String, persist: bool = true) -> void:
	set_section(section, (DEFAULTS.get(section, {}) as Dictionary).duplicate(), persist)


## Grava só as seções deste manager, por cima do arquivo existente (as outras ficam).
func save_settings() -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	var load_err: Error = cfg.load(settings_path)
	if load_err != OK and load_err != ERR_FILE_NOT_FOUND:
		push_warning("SettingsManager: %s não abriu (%s); gravando só as configurações." % [settings_path, error_string(load_err)])
	for section: String in DEFAULTS.keys():
		var values: Dictionary = get_section(section)
		for key: String in values.keys():
			cfg.set_value(section, key, values[key])
	var err: Error = cfg.save(settings_path)
	if err != OK:
		push_warning("SettingsManager: falha ao gravar %s (%s)." % [settings_path, error_string(err)])
	return err


# --- Teste de vídeo (resolução / modo de janela) --------------------------------

## Mudança que pode deixar a tela inutilizável: aplica sem gravar e volta sozinha se
## confirm_video_trial() não vier em `seconds`.
func begin_video_trial(values: Dictionary, seconds: float = VIDEO_TRIAL_SECONDS) -> void:
	if _trial_previous.is_empty():
		_trial_previous = get_section(VIDEO)
	set_section(VIDEO, values, false)
	_trial_token += 1
	var token: int = _trial_token
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(seconds, true, false, true).timeout
	if token == _trial_token and is_video_trial_active():
		revert_video_trial()


func is_video_trial_active() -> bool:
	return not _trial_previous.is_empty()


func confirm_video_trial() -> void:
	if not is_video_trial_active():
		return
	_trial_previous.clear()
	_trial_token += 1
	save_settings()
	video_trial_finished.emit(true)


func revert_video_trial() -> void:
	if not is_video_trial_active():
		return
	var previous: Dictionary = _trial_previous
	_trial_previous = {}
	_trial_token += 1
	set_section(VIDEO, previous, false)
	video_trial_finished.emit(false)


## Mudança de modo de janela ou resolução (só elas pedem confirmação).
static func needs_video_trial(old_values: Dictionary, new_values: Dictionary) -> bool:
	return old_values.get("window_mode") != new_values.get("window_mode", old_values.get("window_mode")) \
		or old_values.get("resolution") != new_values.get("resolution", old_values.get("resolution"))


## Resoluções que cabem no monitor atual (todas, se o monitor não informar o tamanho).
static func available_resolutions() -> Array[Vector2i]:
	var screen: Vector2i = DisplayServer.screen_get_size()
	var out: Array[Vector2i] = []
	for res: Vector2i in RESOLUTIONS:
		if screen.x <= 0 or screen.y <= 0 or (res.x <= screen.x and res.y <= screen.y):
			out.append(res)
	return out


# --- Aplicação -------------------------------------------------------------------

## Início do jogo: aplica tudo; a janela só se houver escolha salva e nenhum --resolution.
func apply_all() -> void:
	var window: bool = _video_saved and not OS.get_cmdline_args().has("--resolution")
	for section: String in DEFAULTS.keys():
		_apply_section(section, window)


func _apply_section(section: String, apply_window: bool) -> void:
	match section:
		VIDEO:
			_apply_video(get_section(VIDEO), apply_window)
		AUDIO:
			_apply_audio(get_section(AUDIO))


func _apply_audio(values: Dictionary) -> void:
	for key: String in AUDIO_BUSES.keys():
		var bus: int = AudioServer.get_bus_index(AUDIO_BUSES[key])
		if bus < 0:
			continue
		var linear: float = float(values.get(key, 1.0))
		AudioServer.set_bus_mute(bus, linear <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear, 0.0001)))


func _apply_video(values: Dictionary, apply_window: bool) -> void:
	Engine.max_fps = int(values["max_fps"])
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	if tree != null:
		var root: Window = tree.root
		root.content_scale_factor = float(values["ui_scale"])
		var preset: Dictionary = QUALITY_PRESETS[values["quality"]]
		root.msaa_3d = preset["msaa"]
		root.scaling_3d_scale = float(preset["scale_3d"])
		root.positional_shadow_atlas_size = int(preset["shadow_size"])
	RenderingServer.directional_shadow_atlas_set_size(int(QUALITY_PRESETS[values["quality"]]["shadow_size"]), true)
	# Headless (testes, CI): sem janela de verdade, o resto não se aplica.
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(values["vsync"]) else DisplayServer.VSYNC_DISABLED)
	if not apply_window:
		return
	match str(values["window_mode"]):
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var res: Vector2i = values["resolution"]
			DisplayServer.window_set_size(res)
			var screen: Rect2i = DisplayServer.screen_get_usable_rect()
			if screen.size.x > 0:
				DisplayServer.window_set_position(screen.position + (screen.size - res) / 2)
