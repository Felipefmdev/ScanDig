class_name SettingsManager
extends Node

## Configurações do jogo (vídeo, áudio, controles e jogabilidade, #77). Único dono do
## user://scandig_settings.cfg: lê, aplica e grava. Preserva as seções que não são dele
## ([player] name e [online] do NetworkManager). A UI e o player_settings.gd só falam com ele.
## Autoload CoreSettings.

signal settings_changed(section: String, values: Dictionary)
## Fim do teste de vídeo (resolução / modo de janela): kept = confirmado a tempo.
signal video_trial_finished(kept: bool)

const DEFAULT_PATH: String = "user://scandig_settings.cfg"
## Sob GUT/--script o arquivo real do jogador nunca é gravado: tudo vai para este (default_path()).
const TEST_PATH: String = "user://test_saves/settings_test.cfg"
const VIDEO: String = "video"
const AUDIO: String = "audio"
const CONTROLS: String = "controls"
## Coluna do comando (#102), seção à parte: o [controls] antigo (teclado/mouse) continua igual,
## sem migração, e cada coluna se aplica, confere conflito e restaura sozinha.
const CONTROLS_PAD: String = "controls_pad"
const GAMEPLAY: String = "gameplay"
## Idioma (#131), seção à parte: o "Restaurar padrão" das abas não troca o idioma.
const GENERAL: String = "general"
## Locales com tradução (translations/scandig.csv). O PT-BR é o texto-fonte e o padrão.
const LANGUAGES: Array[String] = ["pt_BR", "en"]
const DEFAULT_LANGUAGE: String = "pt_BR"

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
const SENSITIVITY_RANGE: Vector2 = Vector2(0.0005, 0.008)
const FOV_RANGE: Vector2 = Vector2(60.0, 100.0)
const HUD_TEXT_SCALE_RANGE: Vector2 = Vector2(0.8, 1.5)
## Olhar com o analógico direito (#102), em graus por segundo com o analógico no fim.
const PAD_LOOK_SENSITIVITY_RANGE: Vector2 = Vector2(60.0, 360.0)
## Antes do #77 as opções do Esc ficavam em [player] (player_settings.gd). Lidas se o arquivo
## ainda não tem [gameplay] e apagadas do [player] ao gravar (o nome continua lá).
const LEGACY_GAMEPLAY_KEYS: Array[String] = ["mouse_sensitivity", "fov", "view_bobbing"]
const LEGACY_SECTION: String = "player"
## Nós de HUD cujo texto acompanha o tamanho do texto do HUD (o HUD do player entra sozinho).
const HUD_TEXT_GROUP: StringName = &"settings_hud_text"
const _BASE_FONT_META: StringName = &"_settings_base_font_size"

const DEFAULTS: Dictionary = {
	GENERAL: {
		"language": DEFAULT_LANGUAGE,
	},
	VIDEO: {
		"window_mode": "windowed",
		"resolution": Vector2i(1280, 720),
		"vsync": true,
		"max_fps": 0,
		"ui_scale": 1.0,
		"quality": "high",
		# Clima (#99): partículas e névoa cheias; desligado, no mínimo (o jogo não muda).
		"strong_weather_fx": true,
	},
	AUDIO: {
		"master": 1.0,
		"music": 1.0,
		"sfx": 1.0,
	},
	# Só as trocas do jogador; o resto vem de DEFAULT_BINDINGS / DEFAULT_PAD_BINDINGS.
	CONTROLS: {},
	CONTROLS_PAD: {},
	GAMEPLAY: {
		"mouse_sensitivity": 0.0025,
		"fov": 75.0,
		"view_bobbing": true,
		"invert_y": false,
		"show_fps": false,
		"show_hints": true,
		"hud_text_scale": 1.0,
		"pad_look_sensitivity": 180.0,
		"controller_aim_assist": true,
		"weather_effects": true,
	},
}

## Por qualidade: MSAA 3D, escala do render 3D e tamanho dos atlas de sombra.
const QUALITY_PRESETS: Dictionary = {
	"low": {"msaa": Viewport.MSAA_DISABLED, "scale_3d": 0.75, "shadow_size": 1024},
	"medium": {"msaa": Viewport.MSAA_2X, "scale_3d": 0.9, "shadow_size": 2048},
	"high": {"msaa": Viewport.MSAA_2X, "scale_3d": 1.0, "shadow_size": 4096},
}

static var instance: SettingsManager = null

var settings_path: String = default_path()
var _values: Dictionary = {}
var _trial_previous: Dictionary = {}
var _trial_token: int = 0
## O arquivo tinha [video]: só então o início do jogo mexe na janela (sem escolha salva, vale o
## tamanho do projeto ou o --resolution da linha de comando).
var _video_saved: bool = false


func _init() -> void:
	# Antes de qualquer tela: sem isso valeria o idioma do sistema (inglês no CI, por exemplo).
	TranslationServer.set_locale(DEFAULT_LANGUAGE)


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	# Testes e capturas (--script, GUT) usam os padrões: as escolhas do jogador (escala da UI,
	# janela) mudariam layouts e PNGs. Os testes trocam settings_path e chamam load_settings().
	if _running_tests():
		_values = DEFAULTS.duplicate(true)
	else:
		load_settings()
	apply_all()
	get_tree().node_added.connect(_on_node_added)


static func _running_tests() -> bool:
	for arg: String in OS.get_cmdline_args():
		if arg == "--script" or arg == "-s" or arg.contains("gut_cmdln"):
			return true
	return false


## O cfg do jogador, ou o de teste (user://test_saves/) sob GUT/--script. Os testes que trocam
## settings_path voltam para este, nunca para DEFAULT_PATH.
static func default_path() -> String:
	if _running_tests():
		DirAccess.make_dir_recursive_absolute(TEST_PATH.get_base_dir())
		return TEST_PATH
	return DEFAULT_PATH


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
		if err == OK and section == GAMEPLAY:
			# Migração: valores antigos de [player]; o [gameplay], se houver, vence.
			for key: String in LEGACY_GAMEPLAY_KEYS:
				if cfg.has_section_key(LEGACY_SECTION, key):
					raw[key] = cfg.get_value(LEGACY_SECTION, key)
		if err == OK and cfg.has_section(section):
			for key: String in cfg.get_section_keys(section):
				raw[key] = cfg.get_value(section, key)
		_values[section] = sanitize(section, raw)


## Tipos e faixas válidos: um arquivo editado à mão não quebra o jogo.
static func sanitize(section: String, values: Dictionary) -> Dictionary:
	var out: Dictionary = (DEFAULTS.get(section, {}) as Dictionary).duplicate()
	match section:
		GENERAL:
			var language: Variant = values.get("language")
			if language is String and LANGUAGES.has(language):
				out["language"] = language
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
			if values.get("strong_weather_fx") is bool:
				out["strong_weather_fx"] = values["strong_weather_fx"]
		AUDIO:
			for key: String in AUDIO_BUSES.keys():
				var v: Variant = values.get(key)
				if v is float or v is int:
					out[key] = clampf(float(v), 0.0, 1.0)
		CONTROLS:
			for action: String in CONTROL_ACTIONS:
				if _valid_binding(values.get(action)):
					out[action] = {"type": values[action]["type"], "code": int(values[action]["code"])}
				elif _is_none_binding(values.get(action)):
					out[action] = {"type": "none"}
		CONTROLS_PAD:
			for action: String in CONTROL_ACTIONS:
				if _valid_pad_binding(values.get(action)):
					out[action] = _normalized_pad_binding(values[action])
				elif _is_none_binding(values.get(action)):
					out[action] = {"type": "none"}
		GAMEPLAY:
			var sens: Variant = values.get("mouse_sensitivity")
			if sens is float or sens is int:
				out["mouse_sensitivity"] = clampf(float(sens), SENSITIVITY_RANGE.x, SENSITIVITY_RANGE.y)
			var fov: Variant = values.get("fov")
			if fov is float or fov is int:
				out["fov"] = clampf(float(fov), FOV_RANGE.x, FOV_RANGE.y)
			for key: String in ["view_bobbing", "invert_y", "show_fps", "show_hints", "controller_aim_assist", "weather_effects"]:
				if values.get(key) is bool:
					out[key] = values[key]
			var hud: Variant = values.get("hud_text_scale")
			if hud is float or hud is int:
				out["hud_text_scale"] = clampf(float(hud), HUD_TEXT_SCALE_RANGE.x, HUD_TEXT_SCALE_RANGE.y)
			var pad_look: Variant = values.get("pad_look_sensitivity")
			if pad_look is float or pad_look is int:
				out["pad_look_sensitivity"] = clampf(float(pad_look), PAD_LOOK_SENSITIVITY_RANGE.x, PAD_LOOK_SENSITIVITY_RANGE.y)
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
		# A seção inteira é deste manager: apaga antes (uma troca desfeita some do arquivo).
		if cfg.has_section(section):
			cfg.erase_section(section)
		var values: Dictionary = get_section(section)
		for key: String in values.keys():
			cfg.set_value(section, key, values[key])
	# Já migradas para [gameplay]: saem do [player] (o name do NetworkManager fica).
	for key: String in LEGACY_GAMEPLAY_KEYS:
		if cfg.has_section_key(LEGACY_SECTION, key):
			cfg.erase_section_key(LEGACY_SECTION, key)
	var err: Error = cfg.save(settings_path)
	if err != OK:
		push_warning("SettingsManager: falha ao gravar %s (%s)." % [settings_path, error_string(err)])
	return err


## Troca o idioma do jogo na hora e grava (#131).
func set_language(language: String, persist: bool = true) -> void:
	set_section(GENERAL, {"language": language}, persist)


func get_language() -> String:
	return str(get_section(GENERAL)["language"])


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
	var window: bool = _video_saved and not window_from_cmdline(DisplayServer.window_get_size(), DisplayServer.window_get_mode())
	for section: String in DEFAULTS.keys():
		_apply_section(section, window)


## --resolution, --fullscreen e afins são do motor e não aparecem em OS.get_cmdline_args(): a
## janela que o motor abriu só difere da do projeto quando a linha de comando a escolheu (#126).
static func window_from_cmdline(size: Vector2i, mode: DisplayServer.WindowMode) -> bool:
	return size != project_window_size() or mode != int(ProjectSettings.get_setting("display/window/size/mode", 0))


static func project_window_size() -> Vector2i:
	var w: int = int(ProjectSettings.get_setting("display/window/size/window_width_override", 0))
	var h: int = int(ProjectSettings.get_setting("display/window/size/window_height_override", 0))
	if w <= 0:
		w = int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	if h <= 0:
		h = int(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	return Vector2i(w, h)


func _apply_section(section: String, apply_window: bool) -> void:
	match section:
		GENERAL:
			# Troca ao vivo: a Godot avisa todas as telas (NOTIFICATION_TRANSLATION_CHANGED).
			var language: String = str(get_section(GENERAL)["language"])
			if TranslationServer.get_locale() != language:
				TranslationServer.set_locale(language)
		VIDEO:
			_apply_video(get_section(VIDEO), apply_window)
		AUDIO:
			_apply_audio(get_section(AUDIO))
		CONTROLS, CONTROLS_PAD:
			_apply_controls()
		GAMEPLAY:
			# Sensibilidade, FOV, balanço e inverter Y: o player escuta settings_changed.
			# O contador de FPS é do PauseMenu.
			var scale: float = float(get_section(GAMEPLAY)["hud_text_scale"])
			if is_inside_tree():
				for node: Node in get_tree().get_nodes_in_group(HUD_TEXT_GROUP):
					apply_hud_text_scale(node, scale)


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


# --- Controles (#77, etapa 2) --------------------------------------------------

## Ações remapeáveis, na ordem da aba Controles. slot_prev/slot_next e look_* (#102) não têm
## tecla padrão (a roda e o mouse fazem isso), só botão/eixo do comando.
const CONTROL_ACTIONS: Array[String] = [
	"move_forward", "move_backward", "move_left", "move_right",
	"look_up", "look_down", "look_left", "look_right", "jump", "sprint",
	"interact", "use_tool", "careful_dig", "attack", "drop", "inspect", "marker", "slot_prev", "slot_next",
	"slot_1", "slot_2", "slot_3", "slot_4", "slot_5", "slot_6", "slot_7", "slot_8", "pause",
]
const ACTION_LABELS: Dictionary = {
	"move_forward": "Andar para frente", "move_backward": "Andar para trás",
	"move_left": "Andar para a esquerda", "move_right": "Andar para a direita",
	"jump": "Pular", "sprint": "Correr", "interact": "Interagir / pegar",
	"use_tool": "Usar ferramenta", "careful_dig": "Cavar com cuidado", "attack": "Atacar",
	"drop": "Soltar / arremessar item", "inspect": "Inspecionar item na mão", "marker": "Marcador no coop", "slot_prev": "Espaço anterior da mochila",
	"slot_next": "Próximo espaço da mochila", "look_up": "Olhar para cima", "look_down": "Olhar para baixo",
	"look_left": "Olhar para a esquerda", "look_right": "Olhar para a direita",
	"slot_1": "Espaço 1 da mochila", "slot_2": "Espaço 2 da mochila",
	"slot_3": "Espaço 3 da mochila", "slot_4": "Espaço 4 da mochila", "slot_5": "Espaço 5 da mochila",
	"slot_6": "Espaço 6 da mochila", "slot_7": "Espaço 7 da mochila", "slot_8": "Espaço 8 da mochila",
	"pause": "Pausa",
}
## Mesmos padrões do [input] do project.godot e do _ensure_default_input_mappings do player
## (tecla física). {"type": "key"|"mouse", "code": physical_keycode | button_index}
const DEFAULT_BINDINGS: Dictionary = {
	"move_forward": {"type": "key", "code": KEY_W}, "move_backward": {"type": "key", "code": KEY_S},
	"move_left": {"type": "key", "code": KEY_A}, "move_right": {"type": "key", "code": KEY_D},
	"jump": {"type": "key", "code": KEY_SPACE}, "sprint": {"type": "key", "code": KEY_SHIFT},
	"interact": {"type": "key", "code": KEY_E}, "use_tool": {"type": "mouse", "code": MOUSE_BUTTON_LEFT},
	"careful_dig": {"type": "mouse", "code": MOUSE_BUTTON_RIGHT}, "attack": {"type": "key", "code": KEY_F},
	"drop": {"type": "key", "code": KEY_Q}, "inspect": {"type": "key", "code": KEY_R}, "marker": {"type": "key", "code": KEY_T},
	"slot_1": {"type": "key", "code": KEY_1}, "slot_2": {"type": "key", "code": KEY_2},
	"slot_3": {"type": "key", "code": KEY_3}, "slot_4": {"type": "key", "code": KEY_4},
	"slot_5": {"type": "key", "code": KEY_5}, "slot_6": {"type": "key", "code": KEY_6},
	"slot_7": {"type": "key", "code": KEY_7}, "slot_8": {"type": "key", "code": KEY_8},
	"pause": {"type": "key", "code": KEY_ESCAPE},
}
## Comando (#102, Xbox/genérico pela SDL da Godot). Analógico esquerdo anda, direito olha;
## A pula, X interage, B solta/arremessa (segurar carrega, como o Q); RT usa a ferramenta, LT
## cava com cuidado; RB ataca, LB/Y trocam o espaço da mochila; Start pausa, L3 corre.
## {"type": "joy_button", "code": JoyButton} ou {"type": "joy_axis", "code": JoyAxis, "sign": 1|-1}
const DEFAULT_PAD_BINDINGS: Dictionary = {
	"move_forward": {"type": "joy_axis", "code": JOY_AXIS_LEFT_Y, "sign": -1},
	"move_backward": {"type": "joy_axis", "code": JOY_AXIS_LEFT_Y, "sign": 1},
	"move_left": {"type": "joy_axis", "code": JOY_AXIS_LEFT_X, "sign": -1},
	"move_right": {"type": "joy_axis", "code": JOY_AXIS_LEFT_X, "sign": 1},
	"look_up": {"type": "joy_axis", "code": JOY_AXIS_RIGHT_Y, "sign": -1},
	"look_down": {"type": "joy_axis", "code": JOY_AXIS_RIGHT_Y, "sign": 1},
	"look_left": {"type": "joy_axis", "code": JOY_AXIS_RIGHT_X, "sign": -1},
	"look_right": {"type": "joy_axis", "code": JOY_AXIS_RIGHT_X, "sign": 1},
	"jump": {"type": "joy_button", "code": JOY_BUTTON_A},
	"sprint": {"type": "joy_button", "code": JOY_BUTTON_LEFT_STICK},
	"interact": {"type": "joy_button", "code": JOY_BUTTON_X},
	"use_tool": {"type": "joy_axis", "code": JOY_AXIS_TRIGGER_RIGHT, "sign": 1},
	"careful_dig": {"type": "joy_axis", "code": JOY_AXIS_TRIGGER_LEFT, "sign": 1},
	"attack": {"type": "joy_button", "code": JOY_BUTTON_RIGHT_SHOULDER},
	"drop": {"type": "joy_button", "code": JOY_BUTTON_B},
	"marker": {"type": "joy_button", "code": JOY_BUTTON_DPAD_UP},
	"slot_prev": {"type": "joy_button", "code": JOY_BUTTON_LEFT_SHOULDER},
	"slot_next": {"type": "joy_button", "code": JOY_BUTTON_Y},
	"pause": {"type": "joy_button", "code": JOY_BUTTON_START},
}
## Fixos (fora da aba Controles): o direcional ←/→ também troca o espaço da mochila.
const EXTRA_PAD_EVENTS: Dictionary = {
	"slot_prev": [{"type": "joy_button", "code": JOY_BUTTON_DPAD_LEFT}],
	"slot_next": [{"type": "joy_button", "code": JOY_BUTTON_DPAD_RIGHT}],
}
## Zona morta por ação no InputMap: andar 0.2 (o get_vector faz o resto); olhar quase nenhuma
## (a curva e a zona morta radial ficam no InputDevice.look_vector); gatilhos 0.3.
const PAD_ACTION_DEADZONES: Dictionary = {
	"move_forward": 0.2, "move_backward": 0.2, "move_left": 0.2, "move_right": 0.2,
	"look_up": 0.02, "look_down": 0.02, "look_left": 0.02, "look_right": 0.02,
	"use_tool": 0.3, "careful_dig": 0.3,
}
const JOY_BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Select", JOY_BUTTON_GUIDE: "Guia", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "↑", JOY_BUTTON_DPAD_DOWN: "↓", JOY_BUTTON_DPAD_LEFT: "←", JOY_BUTTON_DPAD_RIGHT: "→",
}
## [eixo] -> [nome com sinal -1, nome com sinal +1]
const JOY_AXIS_NAMES: Dictionary = {
	JOY_AXIS_LEFT_X: ["Analógico E ←", "Analógico E →"], JOY_AXIS_LEFT_Y: ["Analógico E ↑", "Analógico E ↓"],
	JOY_AXIS_RIGHT_X: ["Analógico D ←", "Analógico D →"], JOY_AXIS_RIGHT_Y: ["Analógico D ↑", "Analógico D ↓"],
	JOY_AXIS_TRIGGER_LEFT: ["LT", "LT"], JOY_AXIS_TRIGGER_RIGHT: ["RT", "RT"],
}
const KEY_NAMES: Dictionary = {
	KEY_SPACE: "Espaço", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_ENTER: "Enter",
	KEY_KP_ENTER: "Enter (numérico)", KEY_TAB: "Tab", KEY_ESCAPE: "Esc", KEY_BACKSPACE: "Backspace",
	KEY_CAPSLOCK: "Caps Lock", KEY_UP: "Seta para cima", KEY_DOWN: "Seta para baixo",
	KEY_LEFT: "Seta para a esquerda", KEY_RIGHT: "Seta para a direita", KEY_DELETE: "Delete",
	KEY_INSERT: "Insert", KEY_HOME: "Home", KEY_END: "End", KEY_PAGEUP: "Page Up", KEY_PAGEDOWN: "Page Down",
}
const MOUSE_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "Botão esquerdo", MOUSE_BUTTON_RIGHT: "Botão direito",
	MOUSE_BUTTON_MIDDLE: "Botão do meio", MOUSE_BUTTON_WHEEL_UP: "Roda para cima",
	MOUSE_BUTTON_WHEEL_DOWN: "Roda para baixo", MOUSE_BUTTON_XBUTTON1: "Botão lateral 1",
	MOUSE_BUTTON_XBUTTON2: "Botão lateral 2",
}


static func _valid_binding(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var b: Dictionary = value
	return (b.get("type") == "key" or b.get("type") == "mouse") and (b.get("code") is int) and int(b["code"]) > 0


## Binding do comando: botão (0..JOY_BUTTON_MAX) ou eixo (0..JOY_AXIS_MAX) com sinal ±1.
static func _valid_pad_binding(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var b: Dictionary = value
	var code: Variant = b.get("code")
	if not (code is int or code is float):
		return false
	match b.get("type"):
		"joy_button":
			return int(code) >= 0 and int(code) < JOY_BUTTON_MAX
		"joy_axis":
			var sign_value: Variant = b.get("sign")
			return int(code) >= 0 and int(code) < JOY_AXIS_MAX and (sign_value is int or sign_value is float) and absi(int(sign_value)) == 1
	return false


## Ação sem binding nesta coluna (troca que tirou o dela; vence o padrão).
static func _is_none_binding(value: Variant) -> bool:
	return value is Dictionary and (value as Dictionary).get("type") == "none"


static func is_pad_binding(binding: Dictionary) -> bool:
	return binding.get("type") == "joy_button" or binding.get("type") == "joy_axis"


static func _normalized_pad_binding(b: Dictionary) -> Dictionary:
	if b["type"] == "joy_axis":
		return {"type": "joy_axis", "code": int(b["code"]), "sign": 1 if int(b["sign"]) > 0 else -1}
	return {"type": "joy_button", "code": int(b["code"])}


## Tecla ou botão atual da ação (o salvo ou o padrão).
func get_binding(action: String) -> Dictionary:
	var saved: Dictionary = get_section(CONTROLS)
	if _is_none_binding(saved.get(action)):
		return {}
	if _valid_binding(saved.get(action)):
		return (saved[action] as Dictionary).duplicate()
	return (DEFAULT_BINDINGS.get(action, {}) as Dictionary).duplicate()


## Botão/eixo atual da ação no comando (o salvo ou o padrão; {} = nenhum).
func get_pad_binding(action: String) -> Dictionary:
	var saved: Dictionary = get_section(CONTROLS_PAD)
	if _is_none_binding(saved.get(action)):
		return {}
	if _valid_pad_binding(saved.get(action)):
		return _normalized_pad_binding(saved[action])
	return (DEFAULT_PAD_BINDINGS.get(action, {}) as Dictionary).duplicate()


## Outra ação que já usa este binding na MESMA coluna (teclado/mouse ou comando), ou "".
func find_conflict(action: String, binding: Dictionary) -> String:
	var pad: bool = is_pad_binding(binding)
	for other: String in CONTROL_ACTIONS:
		if other == action:
			continue
		var current: Dictionary = get_pad_binding(other) if pad else get_binding(other)
		if current == binding:
			return other
	return ""


## Troca o binding de uma ação. Com conflito: false, a menos que swap (a outra ação fica com o
## binding antigo desta).
## A coluna vem do tipo do binding: tecla/mouse vai para [controls], botão/eixo do comando para
## [controls_pad]. Na troca, a outra ação fica com o binding antigo desta (se não tiver, fica sem).
func set_binding(action: String, binding: Dictionary, swap: bool = false) -> bool:
	var pad: bool = is_pad_binding(binding)
	if not CONTROL_ACTIONS.has(action) or not (_valid_pad_binding(binding) if pad else _valid_binding(binding)):
		return false
	var other: String = find_conflict(action, binding)
	if not other.is_empty() and not swap:
		return false
	var section: String = CONTROLS_PAD if pad else CONTROLS
	var controls: Dictionary = get_section(section)
	if not other.is_empty():
		var previous: Dictionary = get_pad_binding(action) if pad else get_binding(action)
		if previous.is_empty():
			# Sem binding antigo para devolver: a outra ação perde este (explícito, vence o padrão).
			controls[other] = {"type": "none"}
		else:
			controls[other] = previous
	controls[action] = _normalized_pad_binding(binding) if pad else {"type": binding["type"], "code": int(binding["code"])}
	_values[section] = sanitize(section, controls)
	_apply_section(section, false)
	save_settings()
	settings_changed.emit(section, get_section(section))
	return true


## "Restaurar padrão" da aba Controles: as duas colunas.
func reset_controls() -> void:
	_values[CONTROLS] = {}
	_values[CONTROLS_PAD] = {}
	_apply_section(CONTROLS, false)
	save_settings()
	settings_changed.emit(CONTROLS, {})
	settings_changed.emit(CONTROLS_PAD, {})


## Binding a partir de um evento capturado na tela ({} se não for tecla nem botão do mouse;
## no comando: botão apertado, ou eixo com |valor| > 0.5 e o sinal dele).
static func binding_from_event(event: InputEvent) -> Dictionary:
	var joy_button: InputEventJoypadButton = event as InputEventJoypadButton
	if joy_button != null:
		return {"type": "joy_button", "code": int(joy_button.button_index)} if joy_button.pressed and joy_button.button_index >= 0 else {}
	var joy_motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if joy_motion != null:
		if absf(joy_motion.axis_value) <= 0.5 or joy_motion.axis < 0:
			return {}
		return {"type": "joy_axis", "code": int(joy_motion.axis), "sign": 1 if joy_motion.axis_value > 0.0 else -1}
	var key: InputEventKey = event as InputEventKey
	if key != null:
		var code: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return {"type": "key", "code": code} if code > 0 else {}
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.button_index > 0:
		return {"type": "mouse", "code": int(mouse.button_index)}
	return {}


static func event_from_binding(binding: Dictionary) -> InputEvent:
	if binding.get("type") == "joy_button":
		var joy_button: InputEventJoypadButton = InputEventJoypadButton.new()
		joy_button.device = -1  # qualquer controle
		joy_button.button_index = int(binding["code"]) as JoyButton
		return joy_button
	if binding.get("type") == "joy_axis":
		var joy_motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		joy_motion.device = -1
		joy_motion.axis = int(binding["code"]) as JoyAxis
		joy_motion.axis_value = 1.0 if int(binding.get("sign", 1)) > 0 else -1.0
		return joy_motion
	if binding.get("type") == "mouse":
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.button_index = int(binding["code"]) as MouseButton
		return mouse
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = int(binding.get("code", 0)) as Key
	return key


## Nome legível no idioma atual ("Espaço", "Botão esquerdo", "E", "A", "LB", "RT", "Analógico E ↑").
static func binding_label(binding: Dictionary) -> String:
	if _valid_pad_binding(binding):
		var pad_code: int = int(binding["code"])
		if binding["type"] == "joy_axis":
			var names: Array = JOY_AXIS_NAMES.get(pad_code, [I18n.t("Eixo %d-") % pad_code, I18n.t("Eixo %d+") % pad_code])
			return I18n.t(str(names[1] if int(binding["sign"]) > 0 else names[0]))
		return I18n.t(str(JOY_BUTTON_NAMES.get(pad_code, I18n.t("Botão %d") % pad_code)))
	if not _valid_binding(binding):
		return "—"
	var code: int = int(binding["code"])
	if binding["type"] == "mouse":
		return I18n.t(str(MOUSE_NAMES.get(code, I18n.t("Botão %d do mouse") % code)))
	if KEY_NAMES.has(code):
		return I18n.t(str(KEY_NAMES[code]))
	return OS.get_keycode_string(code as Key)


## Troca no InputMap os eventos das duas colunas de cada ação: teclado/mouse e comando (os
## fixos do EXTRA_PAD_EVENTS entram junto com a coluna do comando).
func _apply_controls() -> void:
	for action: String in CONTROL_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(action, ev)
		var keyboard: Dictionary = get_binding(action)
		if not keyboard.is_empty():
			InputMap.action_add_event(action, event_from_binding(keyboard))
		var pad: Dictionary = get_pad_binding(action)
		if not pad.is_empty():
			InputMap.action_add_event(action, event_from_binding(pad))
		for extra: Dictionary in EXTRA_PAD_EVENTS.get(action, []):
			InputMap.action_add_event(action, event_from_binding(extra))
		if PAD_ACTION_DEADZONES.has(action):
			InputMap.action_set_deadzone(action, float(PAD_ACTION_DEADZONES[action]))


# --- Jogabilidade (#77, etapa 3) -----------------------------------------------

## Escala o texto de Labels e RichTextLabels sob `root` (o tamanho original fica em meta, então
## aplicar de novo não acumula). Textos criados depois (mensagens do HUD) entram por node_added.
static func apply_hud_text_scale(root: Node, scale: float) -> void:
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		_scale_text_node(node, scale)
		stack.append_array(node.get_children())


static func _scale_text_node(node: Node, scale: float) -> void:
	var control: Control = node as Control
	if control == null:
		return
	var key: StringName = &""
	if control is Label:
		key = &"font_size"
	elif control is RichTextLabel:
		key = &"normal_font_size"
	else:
		return
	if not control.has_meta(_BASE_FONT_META):
		control.set_meta(_BASE_FONT_META, control.get_theme_font_size(key))
	var base: int = int(control.get_meta(_BASE_FONT_META))
	if is_equal_approx(scale, 1.0):
		if control.has_theme_font_size_override(key) and control.get_theme_font_size(key) != base:
			control.add_theme_font_size_override(key, base)
		return
	control.add_theme_font_size_override(key, maxi(roundi(base * scale), 1))


func _on_node_added(node: Node) -> void:
	if not (node is Label or node is RichTextLabel):
		return
	var scale: float = float(get_section(GAMEPLAY)["hud_text_scale"])
	if is_equal_approx(scale, 1.0) and not node.has_meta(_BASE_FONT_META):
		return
	_scale_new_text.call_deferred(node)


## Depois do frame: o código que criou o texto já pôs o tamanho dele.
func _scale_new_text(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var parent: Node = node.get_parent()
	while parent != null:
		if parent.is_in_group(HUD_TEXT_GROUP):
			_scale_text_node(node, float(get_section(GAMEPLAY)["hud_text_scale"]))
			return
		parent = parent.get_parent()
