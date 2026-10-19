class_name A11y
extends Node

## Acessibilidade (#140): o único lugar que o jogo consulta para cores de daltonismo, tremor de
## tela, flashes, alternar × segurar e legendas de sons. Lê a seção [accessibility] do
## SettingsManager; sem ele (testes de gameplay soltos), tudo fica no padrão neutro.
## As funções são estáticas (o detector, o player e os inimigos chamam A11y.color(role) etc.);
## a instância (autoload CoreA11y) cuida do que precisa de nó: legendas, Shift do cavar com
## cuidado no modo alternar e recolorir as barras quando o modo daltônico muda.
## A tela das legendas é ui/captions_hud.gd (autoload CoreCaptionsUI).

## Legenda aceita (texto-chave em PT-BR; a tela traduz).
signal caption_shown(text: String)
## Aviso curto que não depende das legendas (ex.: o cuidado ligado no modo alternar).
signal notice_shown(text: String)

const SECTION: String = SettingsManager.ACCESSIBILITY

const CAPTION_CREATURE: String = "[Criatura se aproximando]"
const CAPTION_BOSS: String = "[Chefe]"
const CAPTION_WEATHER: String = "[Clima chegando]"
const CAPTION_EXPLOSION: String = "[Explosão]"
const CAREFUL_ON_TEXT: String = "Cavar com cuidado: ligado"
const CAREFUL_OFF_TEXT: String = "Cavar com cuidado: desligado"
## Quanto tempo uma legenda fica na tela, quantas cabem ao mesmo tempo e o intervalo mínimo
## até a MESMA legenda voltar (sem spam).
const CAPTION_SECONDS: float = 3.0
const CAPTION_MAX: int = 3
const CAPTION_COOLDOWN: float = 6.0
## Criaturas só contam até esta distância do jogador local (m).
const CREATURE_RANGE: float = 18.0
## Explosões se ouvem de mais longe.
const EXPLOSION_RANGE: float = 40.0
## Sons de bicho (trecho do caminho no SFX) que viram "[Criatura se aproximando]".
const CREATURE_SOUND_MARKS: Array[String] = ["crow_caw", "bat_screech", "wolf_growl", "wolf_howl", "gull_caw", "gull_dive", "emerge_"]
## Inimigos que entram logo depois de trocar de cena são do mapa, não "se aproximando".
const SCENE_SETTLE_MS: int = 1500
const BOSS_GROUP: StringName = &"bosses"
## Reduzir flashes: fração da intensidade e do alfa que sobra.
const REDUCED_FLASH: float = 0.3
## Modo alternar: um toque curto no Shift (até isto) liga/desliga o cuidado; segurar mais é
## correr, como sempre.
const CAREFUL_TAP_MS: int = 300
const BARS_GROUP: StringName = &"a11y_bars"
const _BAR_ROLE_META: StringName = &"_a11y_bar_role"
const _BAR_OWN_FILL_META: StringName = &"_a11y_own_fill"

## Cores do jogo como foram feitas (modo "off"). Toda cor que muda com o daltonismo tem um
## papel aqui; quem desenha pergunta A11y.color(papel).
const DEFAULT_PALETTE: Dictionary = {
	# Radar/detector (gameplay/detector/detector_radar.gd).
	&"radar_enemy": Color(1.0, 0.18, 0.15),
	&"radar_rare": Color(1.0, 0.85, 0.3),
	&"radar_pin": Color(0.4, 0.95, 1.0),
	&"material_ferro": Color(0.55, 0.55, 0.58),
	&"material_aluminio": Color(0.55, 0.85, 1.0),
	&"material_prata": Color(0.88, 0.94, 1.0),
	&"material_ouro": Color(1.0, 0.8, 0.15),
	&"material_desconhecido": Color(0.72, 0.3, 1.0),
	# Barras do HUD do player.
	&"bar_health": UiPalette.RED_BURNT,
	&"bar_hunger": UiPalette.ORANGE,
	&"threat_0": UiPalette.GREEN_BOTTLE,
	&"threat_1": UiPalette.GOLD,
	&"threat_2": UiPalette.ORANGE,
	&"threat_3": UiPalette.RED_BURNT,
	# Marcadores do coop (coop_marker_flag.gd: sinal, perigo, ajuda).
	&"marker_signal": Color(0.18, 0.88, 0.45),
	&"marker_danger": Color(0.95, 0.25, 0.2),
	&"marker_help": Color(0.25, 0.65, 1.0),
}
## Por modo, só os papéis que mudam. Protanopia/deuteranopia (vermelho × verde): paleta
## Okabe-Ito (laranja/azul/amarelo, com brilhos bem diferentes). Na protanopia o vermelho
## escurece, então inimigo e vida ficam mais claros. Tritanopia (azul × amarelo): vermelho,
## ciano e rosa.
const PALETTES: Dictionary = {
	"protanopia": {
		&"radar_enemy": Color("#FF8C42"), &"radar_rare": Color("#F0E442"), &"radar_pin": Color("#56B4E9"),
		&"material_ferro": Color("#8C8C8C"), &"material_aluminio": Color("#56B4E9"), &"material_prata": Color.WHITE,
		&"material_ouro": Color("#F0E442"), &"material_desconhecido": Color("#CC79A7"),
		&"bar_health": Color("#E8743B"), &"bar_hunger": Color("#E69F00"),
		&"threat_0": Color("#0072B2"), &"threat_1": Color("#56B4E9"), &"threat_2": Color("#F0E442"), &"threat_3": Color("#E8743B"),
		&"marker_signal": Color("#F0E442"), &"marker_danger": Color("#FF8C42"), &"marker_help": Color("#0072B2"),
	},
	"deuteranopia": {
		&"radar_enemy": Color("#D55E00"), &"radar_rare": Color("#F0E442"), &"radar_pin": Color("#56B4E9"),
		&"material_ferro": Color("#8C8C8C"), &"material_aluminio": Color("#56B4E9"), &"material_prata": Color.WHITE,
		&"material_ouro": Color("#F0E442"), &"material_desconhecido": Color("#CC79A7"),
		&"bar_health": Color("#D55E00"), &"bar_hunger": Color("#E69F00"),
		&"threat_0": Color("#0072B2"), &"threat_1": Color("#56B4E9"), &"threat_2": Color("#F0E442"), &"threat_3": Color("#D55E00"),
		&"marker_signal": Color("#F0E442"), &"marker_danger": Color("#D55E00"), &"marker_help": Color("#0072B2"),
	},
	"tritanopia": {
		&"radar_enemy": Color("#FF2A2A"), &"radar_rare": Color("#FF9EC4"), &"radar_pin": Color("#00D0D0"),
		&"material_ferro": Color("#8C8C8C"), &"material_aluminio": Color("#00D0D0"), &"material_prata": Color.WHITE,
		&"material_ouro": Color("#FF9EC4"), &"material_desconhecido": Color("#E85AE8"),
		&"bar_health": Color("#D81B1B"), &"bar_hunger": Color("#008B8B"),
		&"threat_0": Color("#008B8B"), &"threat_1": Color("#FFB3C6"), &"threat_2": Color("#FF5C5C"), &"threat_3": Color("#B00000"),
		&"marker_signal": Color("#00D0D0"), &"marker_danger": Color("#FF2A2A"), &"marker_help": Color("#FF9EC4"),
	},
}
## Papel de cada MarkerType do coop (SIGNAL, DANGER, HELP).
const MARKER_ROLES: Array[StringName] = [&"marker_signal", &"marker_danger", &"marker_help"]

static var instance: A11y = null
## Alternar × segurar: ação -> frame da última pergunta (a segurada segue enquanto alguém pergunta
## a cada frame) e ação -> frame em que o toque que parou foi gasto.
static var _hold_polled: Dictionary = {}
static var _hold_stopped: Dictionary = {}
## Ação -> estado travado (latched) e frame da última pergunta.
static var _latch_on: Dictionary = {}
static var _latch_polled: Dictionary = {}
static var _careful_latched: bool = false

## Legendas: texto -> ms da última vez, e quando cada uma visível some (ms).
var _caption_last_ms: Dictionary = {}
var _caption_until: Array[int] = []
var _shift_down_ms: int = -1
var _scene: Node = null
var _scene_since_ms: int = 0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	var sm: SettingsManager = SettingsManager.instance
	if sm != null:
		sm.settings_changed.connect(_on_settings_changed)
	var weather: WeatherManager = WeatherManager.instance
	if weather != null:
		weather.weather_changed.connect(_on_weather_changed)
	get_tree().node_added.connect(_on_node_added)


# --- Valores ---------------------------------------------------------------------

static func settings() -> Dictionary:
	var sm: SettingsManager = SettingsManager.instance
	if sm == null:
		return (SettingsManager.DEFAULTS[SECTION] as Dictionary).duplicate()
	return sm.get_section(SECTION)


static func colorblind_mode() -> String:
	return str(settings()["colorblind_mode"])


## Cor do papel no modo daltônico atual (no "off", a cor original do jogo).
static func color(role: StringName) -> Color:
	return color_for(role, colorblind_mode())


static func color_for(role: StringName, mode: String) -> Color:
	var palette: Dictionary = PALETTES.get(mode, {})
	if palette.has(role):
		return palette[role]
	return DEFAULT_PALETTE.get(role, Color.WHITE)


static func threat_role(level: int) -> StringName:
	return StringName("threat_%d" % clampi(level, 0, 3))


static func marker_role(marker_type: int) -> StringName:
	return MARKER_ROLES[clampi(marker_type, 0, MARKER_ROLES.size() - 1)]


## Multiplica todo tremor de tela (0 = nenhum).
static func shake_scale() -> float:
	return clampf(float(settings()["screen_shake"]), 0.0, 1.0)


## Multiplica intensidade e alfa de flashes (explosão, flash de dano).
static func flash_scale() -> float:
	return REDUCED_FLASH if bool(settings()["reduce_flashes"]) else 1.0


static func is_toggle_hold() -> bool:
	return str(settings()["hold_mode"]) == "toggle"


static func captions_enabled() -> bool:
	return bool(settings()["captions"])


# --- Alternar × segurar ------------------------------------------------------------

static func _frame() -> int:
	return Engine.get_physics_frames() if Engine.is_in_physics_frame() else Engine.get_process_frames()


## Continuação de uma segurada que o chamador já começou (comer, carregar o arremesso). Segurar:
## o botão está apertado. Alternar: segue até o próximo toque na ação. Pergunte a cada frame
## enquanto a segurada dura; um frame sem pergunta encerra.
static func holding(action: StringName) -> bool:
	if not is_toggle_hold():
		return InputMap.has_action(action) and Input.is_action_pressed(action)
	var frame: int = _frame()
	if int(_hold_stopped.get(action, -10)) == frame:
		return false
	var last: int = int(_hold_polled.get(action, -10))
	_hold_polled[action] = frame
	# Primeira pergunta (o toque que começou já passou) ou repetida no mesmo frame.
	if last < frame - 1 or last == frame:
		return true
	if InputMap.has_action(action) and Input.is_action_just_pressed(action):
		_hold_polled.erase(action)
		_hold_stopped[action] = frame
		return false
	return true


## Começo de uma segurada (o just_pressed da ação). No modo alternar, o toque que encerra uma
## segurada em andamento não começa outra.
static func just_pressed(action: StringName) -> bool:
	if not InputMap.has_action(action) or not Input.is_action_just_pressed(action):
		return false
	if not is_toggle_hold():
		return true
	var frame: int = _frame()
	return int(_hold_polled.get(action, -10)) < frame - 1 and int(_hold_stopped.get(action, -10)) != frame


## Segurada que começa no próprio botão (desistir caído com [E]). Segurar: o botão está
## apertado. Alternar: cada toque liga/desliga; um frame sem pergunta desliga.
static func latched(action: StringName) -> bool:
	if not is_toggle_hold():
		return InputMap.has_action(action) and Input.is_action_pressed(action)
	var frame: int = _frame()
	var last: int = int(_latch_polled.get(action, -10))
	_latch_polled[action] = frame
	if last < frame - 1:
		_latch_on[action] = false
	if last != frame and InputMap.has_action(action) and Input.is_action_just_pressed(action):
		_latch_on[action] = not bool(_latch_on.get(action, false))
	return bool(_latch_on.get(action, false))


## Cavar com cuidado (Shift + botão direito). Alternar: um toque curto no Shift trava o cuidado
## (segurar continua valendo).
static func careful_held() -> bool:
	var shift: bool = Input.is_physical_key_pressed(KEY_SHIFT)
	if not is_toggle_hold():
		return shift
	return shift or _careful_latched


static func is_careful_latched() -> bool:
	return _careful_latched


static func reset_holds() -> void:
	_hold_polled.clear()
	_hold_stopped.clear()
	_latch_on.clear()
	_latch_polled.clear()
	_careful_latched = false


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or key.echo or key.physical_keycode != KEY_SHIFT:
		return
	if key.pressed:
		_shift_down_ms = Time.get_ticks_msec()
		return
	if _shift_down_ms >= 0 and is_toggle_hold():
		on_careful_tap(Time.get_ticks_msec() - _shift_down_ms)
	_shift_down_ms = -1


## Shift solto depois de `held_ms`: toque curto liga/desliga o cuidado travado.
func on_careful_tap(held_ms: int) -> void:
	if held_ms > CAREFUL_TAP_MS:
		return
	_careful_latched = not _careful_latched
	notice_shown.emit(CAREFUL_ON_TEXT if _careful_latched else CAREFUL_OFF_TEXT)


# --- Barras ------------------------------------------------------------------------

## Pinta o preenchimento da barra com a cor do papel e a recolore quando o modo muda. Barra sem
## fill próprio (a vida usa o do tema): no modo desligado fica sem override, como sempre foi.
static func tint_bar(bar: ProgressBar, role: StringName) -> void:
	if bar == null:
		return
	bar.set_meta(_BAR_ROLE_META, role)
	if not bar.is_in_group(BARS_GROUP):
		bar.add_to_group(BARS_GROUP)
	var own: bool = bar.has_meta(_BAR_OWN_FILL_META)
	if bar.has_theme_stylebox_override(&"fill") and not own:
		var fill: StyleBoxFlat = bar.get_theme_stylebox(&"fill") as StyleBoxFlat
		if fill != null:
			fill.bg_color = color(role)
		return
	if colorblind_mode() == "off":
		if own:
			bar.remove_theme_stylebox_override(&"fill")
			bar.remove_meta(_BAR_OWN_FILL_META)
		return
	if not own:
		var base: StyleBoxFlat = bar.get_theme_stylebox(&"fill") as StyleBoxFlat
		if base == null:
			return
		bar.add_theme_stylebox_override(&"fill", base.duplicate() as StyleBoxFlat)
		bar.set_meta(_BAR_OWN_FILL_META, true)
	(bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color = color(role)


func _recolor_bars() -> void:
	for node: Node in get_tree().get_nodes_in_group(BARS_GROUP):
		var bar: ProgressBar = node as ProgressBar
		if bar != null and bar.has_meta(_BAR_ROLE_META):
			tint_bar(bar, StringName(bar.get_meta(_BAR_ROLE_META)))


func _on_settings_changed(section: String, _values: Dictionary) -> void:
	if section != SECTION:
		return
	_recolor_bars()
	if not is_toggle_hold():
		reset_holds()


# --- Legendas ----------------------------------------------------------------------

## Mostra a legenda se as legendas estão ligadas, a mesma não saiu há pouco e cabe na tela.
static func caption(text: String) -> bool:
	return instance.request_caption(text) if instance != null else false


func request_caption(text: String, now_ms: int = -1) -> bool:
	if text.is_empty() or not captions_enabled():
		return false
	var now: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	if _caption_last_ms.has(text) and now - int(_caption_last_ms[text]) < int(CAPTION_COOLDOWN * 1000.0):
		return false
	_caption_until = _caption_until.filter(func(until: int) -> bool: return until > now)
	if _caption_until.size() >= CAPTION_MAX:
		return false
	_caption_last_ms[text] = now
	_caption_until.append(now + int(CAPTION_SECONDS * 1000.0))
	caption_shown.emit(text)
	return true


## Esquece cooldowns e legendas visíveis (troca de cena, testes).
func reset_captions() -> void:
	_caption_last_ms.clear()
	_caption_until.clear()


## Som tocado pelo SFX: bicho perto do jogador local vira legenda.
static func on_sound(path: String, pos: Vector3) -> void:
	if instance == null or not captions_enabled():
		return
	for mark: String in CREATURE_SOUND_MARKS:
		if path.contains(mark):
			if instance.near_local_player(pos):
				caption(CAPTION_CREATURE)
			return


func near_local_player(pos: Vector3, range_m: float = CREATURE_RANGE) -> bool:
	for node: Node in get_tree().get_nodes_in_group(Player.LOCAL_GROUP):
		var player: Node3D = node as Node3D
		if player != null and player.is_inside_tree():
			return player.global_position.distance_to(pos) <= range_m
	return false


func _on_weather_changed(kind: String, phase: String) -> void:
	if phase == WeatherManager.PHASE_WARNING and not kind.is_empty():
		caption(CAPTION_WEATHER)


func _on_node_added(node: Node) -> void:
	if node is EnemyBase and captions_enabled():
		_check_enemy.call_deferred(node)


## Depois do _ready (o chefe entra no grupo "bosses" lá).
func _check_enemy(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var scene: Node = get_tree().current_scene
	if scene != _scene:
		_scene = scene
		_scene_since_ms = Time.get_ticks_msec()
		reset_captions()
	if node.is_in_group(BOSS_GROUP):
		caption(CAPTION_BOSS)
	elif Time.get_ticks_msec() - _scene_since_ms >= SCENE_SETTLE_MS and near_local_player((node as Node3D).global_position):
		caption(CAPTION_CREATURE)


## Explosão (dinamite, meteoro) perto do jogador local vira legenda.
static func on_explosion(pos: Vector3) -> void:
	if instance != null and captions_enabled() and instance.near_local_player(pos, EXPLOSION_RANGE):
		caption(CAPTION_EXPLOSION)
