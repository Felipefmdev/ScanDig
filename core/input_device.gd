class_name InputDevice
extends Node

## Dispositivo em uso (#102): comando ou teclado/mouse, pelo último input. Só observa (_input
## nunca marca o evento como tratado). Troca para o comando com botão do controle ou eixo além da
## zona morta; volta para teclado/mouse com tecla, botão do mouse ou movimento do mouse de alguns
## px (tremida não alterna). action_label(ação) devolve a tecla ou o botão do dispositivo ativo.
## A mira assistida no comando (#90) deve usar is_using_gamepad() / device_changed daqui.
## Também guarda a matemática do olhar com o analógico (look_vector). Autoload CoreInputDevice.
## Ponteiro (#122): o mouse foi o último a mexer (tecla ou comando desligam); os menus só mostram
## a borda de foco fora dele (UiFocus.follow_pointer).

signal device_changed(using_gamepad: bool)
signal pointer_changed(using_pointer: bool)

## Eixo além disto conta como "usando o comando" (deriva leve dos analógicos não conta).
const AXIS_ACTIVITY: float = 0.35
## Movimento do mouse maior que isto (px num evento) volta para teclado/mouse.
const MOUSE_ACTIVITY_PX: float = 4.0
## Olhar com o analógico: zona morta radial e curva (pow) da resposta.
const LOOK_DEADZONE: float = 0.15
const LOOK_CURVE: float = 1.7

static var instance: InputDevice = null

var _using_gamepad: bool = false
## Começa no mouse: o foco inicial dos menus não acende a borda até alguém navegar.
var _using_pointer: bool = true


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_ui_pad_events()


func _input(event: InputEvent) -> void:
	observe(event)


## Atualiza o dispositivo a partir de um evento (os testes chamam direto).
func observe(event: InputEvent) -> void:
	var gamepad: int = -1
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			gamepad = 1
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > AXIS_ACTIVITY:
			gamepad = 1
	elif event is InputEventKey:
		if (event as InputEventKey).pressed:
			gamepad = 0
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			gamepad = 0
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > MOUSE_ACTIVITY_PX:
			gamepad = 0
	if gamepad >= 0:
		set_using_gamepad(gamepad == 1)
		set_using_pointer(gamepad == 0 and (event is InputEventMouseButton or event is InputEventMouseMotion))


func set_using_gamepad(on: bool) -> void:
	if on == _using_gamepad:
		return
	_using_gamepad = on
	device_changed.emit(on)


func is_using_gamepad() -> bool:
	return _using_gamepad


func set_using_pointer(on: bool) -> void:
	if on == _using_pointer:
		return
	_using_pointer = on
	pointer_changed.emit(on)


## Atalho seguro (sem o autoload: mouse).
static func using_pointer() -> bool:
	return instance == null or instance._using_pointer


## Atalho seguro (sem o autoload: teclado/mouse).
static func using_gamepad() -> bool:
	return instance != null and instance._using_gamepad


## "E", "Q", "Espaço"... ou, no comando, "X", "B", "RT"... A coluna do dispositivo em uso; se a
## ação não tiver binding nela, cai na outra.
static func action_label(action: String) -> String:
	var sm: SettingsManager = SettingsManager.instance
	var keyboard: Dictionary = sm.get_binding(action) if sm != null else (SettingsManager.DEFAULT_BINDINGS.get(action, {}) as Dictionary)
	var pad: Dictionary = sm.get_pad_binding(action) if sm != null else (SettingsManager.DEFAULT_PAD_BINDINGS.get(action, {}) as Dictionary)
	var first: Dictionary = pad if using_gamepad() else keyboard
	var other: Dictionary = keyboard if using_gamepad() else pad
	return SettingsManager.binding_label(first if not first.is_empty() else other)


## Prompts antigos escritos com a tecla ("[E] Apanhar"): o literal vira o botão/tecla atual.
const LEGACY_KEY_TOKENS: Dictionary = {"[E]": "interact", "[Q]": "drop", "[F]": "attack"}


## "[E] Apanhar", "[Q] Largar"... e "{ação}": tudo com o rótulo do dispositivo em uso. Com o
## teclado nos padrões o texto fica igual.
static func fill_key_prompts(text: String) -> String:
	for token: String in LEGACY_KEY_TOKENS.keys():
		if text.contains(token):
			text = text.replace(token, "[%s]" % action_label(str(LEGACY_KEY_TOKENS[token])))
	return fill_action_labels(text)


## Troca "{ação}" (ex.: "{drop}", "{interact}") pelo action_label de cada ação conhecida.
static func fill_action_labels(text: String) -> String:
	if not text.contains("{"):
		return text
	for action: String in SettingsManager.CONTROL_ACTIONS:
		var tag: String = "{%s}" % action
		if text.contains(tag):
			text = text.replace(tag, action_label(action))
	return text


## Analógico -> direção do olhar: zona morta radial (abaixo dela é zero; acima, reescala para
## começar em 0) e curva na magnitude (precisão perto do centro).
static func look_vector(raw: Vector2, deadzone: float = LOOK_DEADZONE, curve: float = LOOK_CURVE) -> Vector2:
	var length: float = raw.length()
	if length <= deadzone:
		return Vector2.ZERO
	var magnitude: float = clampf((minf(length, 1.0) - deadzone) / (1.0 - deadzone), 0.0, 1.0)
	return raw / length * pow(magnitude, curve)


## O mesmo "relative" que um movimento de mouse daria (o player usa apply_mouse_look para os dois):
## graus/s × delta, convertidos pela sensibilidade do mouse.
static func pad_look_relative(raw: Vector2, delta: float, degrees_per_second: float, mouse_sensitivity: float) -> Vector2:
	var shaped: Vector2 = look_vector(raw)
	if shaped == Vector2.ZERO:
		return Vector2.ZERO
	return shaped * deg_to_rad(degrees_per_second) * delta / maxf(mouse_sensitivity, 0.00001)


## Vetor cru do analógico de olhar (ações look_*, sem a zona morta do InputMap).
static func raw_look_input() -> Vector2:
	if not InputMap.has_action(&"look_right"):
		return Vector2.ZERO
	return Vector2(
		Input.get_action_raw_strength(&"look_right") - Input.get_action_raw_strength(&"look_left"),
		Input.get_action_raw_strength(&"look_down") - Input.get_action_raw_strength(&"look_up"))


## Menus: A confirma (ui_accept) e B volta (ui_cancel). Os ui_* padrão da Godot só trazem o
## direcional e o analógico esquerdo.
static func ensure_ui_pad_events() -> void:
	_add_pad_button(&"ui_accept", JOY_BUTTON_A)
	_add_pad_button(&"ui_cancel", JOY_BUTTON_B)


static func _add_pad_button(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == button:
			return
	var joy: InputEventJoypadButton = InputEventJoypadButton.new()
	joy.device = -1
	joy.button_index = button
	InputMap.action_add_event(action, joy)
