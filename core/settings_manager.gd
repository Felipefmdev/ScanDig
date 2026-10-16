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
const VIDEO: String = "video"
const AUDIO: String = "audio"
const CONTROLS: String = "controls"
const GAMEPLAY: String = "gameplay"

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
## Antes do #77 as opções do Esc ficavam em [player] (player_settings.gd). Lidas se o arquivo
## ainda não tem [gameplay] e apagadas do [player] ao gravar (o nome continua lá).
const LEGACY_GAMEPLAY_KEYS: Array[String] = ["mouse_sensitivity", "fov", "view_bobbing"]
const LEGACY_SECTION: String = "player"
## Nós de HUD cujo texto acompanha o tamanho do texto do HUD (o HUD do player entra sozinho).
const HUD_TEXT_GROUP: StringName = &"settings_hud_text"
const _BASE_FONT_META: StringName = &"_settings_base_font_size"

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
	# Só as trocas do jogador; o resto vem de DEFAULT_BINDINGS.
	CONTROLS: {},
	GAMEPLAY: {
		"mouse_sensitivity": 0.0025,
		"fov": 75.0,
		"view_bobbing": true,
		"invert_y": false,
		"show_fps": false,
		"hud_text_scale": 1.0,
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
	get_tree().node_added.connect(_on_node_added)


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
		CONTROLS:
			for action: String in CONTROL_ACTIONS:
				if _valid_binding(values.get(action)):
					out[action] = {"type": values[action]["type"], "code": int(values[action]["code"])}
		GAMEPLAY:
			var sens: Variant = values.get("mouse_sensitivity")
			if sens is float or sens is int:
				out["mouse_sensitivity"] = clampf(float(sens), SENSITIVITY_RANGE.x, SENSITIVITY_RANGE.y)
			var fov: Variant = values.get("fov")
			if fov is float or fov is int:
				out["fov"] = clampf(float(fov), FOV_RANGE.x, FOV_RANGE.y)
			for key: String in ["view_bobbing", "invert_y", "show_fps"]:
				if values.get(key) is bool:
					out[key] = values[key]
			var hud: Variant = values.get("hud_text_scale")
			if hud is float or hud is int:
				out["hud_text_scale"] = clampf(float(hud), HUD_TEXT_SCALE_RANGE.x, HUD_TEXT_SCALE_RANGE.y)
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
		CONTROLS:
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

## Ações remapeáveis, na ordem da aba Controles.
const CONTROL_ACTIONS: Array[String] = [
	"move_forward", "move_backward", "move_left", "move_right", "jump", "sprint",
	"interact", "use_tool", "careful_dig", "attack", "drop",
	"slot_1", "slot_2", "slot_3", "slot_4", "slot_5", "slot_6", "slot_7", "slot_8", "pause",
]
const ACTION_LABELS: Dictionary = {
	"move_forward": "Andar para frente", "move_backward": "Andar para trás",
	"move_left": "Andar para a esquerda", "move_right": "Andar para a direita",
	"jump": "Pular", "sprint": "Correr", "interact": "Interagir / pegar",
	"use_tool": "Usar ferramenta", "careful_dig": "Cavar com cuidado", "attack": "Atacar",
	"drop": "Soltar / arremessar item", "slot_1": "Espaço 1 da mochila", "slot_2": "Espaço 2 da mochila",
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
	"drop": {"type": "key", "code": KEY_Q},
	"slot_1": {"type": "key", "code": KEY_1}, "slot_2": {"type": "key", "code": KEY_2},
	"slot_3": {"type": "key", "code": KEY_3}, "slot_4": {"type": "key", "code": KEY_4},
	"slot_5": {"type": "key", "code": KEY_5}, "slot_6": {"type": "key", "code": KEY_6},
	"slot_7": {"type": "key", "code": KEY_7}, "slot_8": {"type": "key", "code": KEY_8},
	"pause": {"type": "key", "code": KEY_ESCAPE},
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


## Tecla ou botão atual da ação (o salvo ou o padrão).
func get_binding(action: String) -> Dictionary:
	var saved: Dictionary = get_section(CONTROLS)
	if _valid_binding(saved.get(action)):
		return (saved[action] as Dictionary).duplicate()
	return (DEFAULT_BINDINGS.get(action, {}) as Dictionary).duplicate()


## Outra ação que já usa este binding, ou "".
func find_conflict(action: String, binding: Dictionary) -> String:
	for other: String in CONTROL_ACTIONS:
		if other != action and get_binding(other) == binding:
			return other
	return ""


## Troca o binding de uma ação. Com conflito: false, a menos que swap (a outra ação fica com o
## binding antigo desta).
func set_binding(action: String, binding: Dictionary, swap: bool = false) -> bool:
	if not CONTROL_ACTIONS.has(action) or not _valid_binding(binding):
		return false
	var other: String = find_conflict(action, binding)
	if not other.is_empty() and not swap:
		return false
	var controls: Dictionary = get_section(CONTROLS)
	if not other.is_empty():
		controls[other] = get_binding(action)
	controls[action] = {"type": binding["type"], "code": int(binding["code"])}
	_values[CONTROLS] = sanitize(CONTROLS, controls)
	_apply_section(CONTROLS, false)
	save_settings()
	settings_changed.emit(CONTROLS, get_section(CONTROLS))
	return true


func reset_controls() -> void:
	_values[CONTROLS] = {}
	_apply_section(CONTROLS, false)
	save_settings()
	settings_changed.emit(CONTROLS, {})


## Binding a partir de um evento capturado na tela ({} se não for tecla nem botão do mouse).
static func binding_from_event(event: InputEvent) -> Dictionary:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		var code: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return {"type": "key", "code": code} if code > 0 else {}
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.button_index > 0:
		return {"type": "mouse", "code": int(mouse.button_index)}
	return {}


static func event_from_binding(binding: Dictionary) -> InputEvent:
	if binding.get("type") == "mouse":
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.button_index = int(binding["code"]) as MouseButton
		return mouse
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = int(binding.get("code", 0)) as Key
	return key


## Nome legível em português ("Espaço", "Botão esquerdo", "E").
static func binding_label(binding: Dictionary) -> String:
	if not _valid_binding(binding):
		return "—"
	var code: int = int(binding["code"])
	if binding["type"] == "mouse":
		return str(MOUSE_NAMES.get(code, "Botão %d do mouse" % code))
	if KEY_NAMES.has(code):
		return str(KEY_NAMES[code])
	return OS.get_keycode_string(code as Key)


## Troca no InputMap os eventos de teclado e mouse de cada ação (controle de jogo fica).
func _apply_controls() -> void:
	for action: String in CONTROL_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventKey or ev is InputEventMouseButton:
				InputMap.action_erase_event(action, ev)
		InputMap.action_add_event(action, event_from_binding(get_binding(action)))


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
