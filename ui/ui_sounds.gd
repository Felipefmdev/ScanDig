class_name UISounds
extends Node

## Hover e clique uniformes em todos os menus (#123): cada BaseButton que entra na árvore
## (título, pausa, ajustes, Base, multiplayer, vitória, HUD) toca SFX.UI_HOVER ao passar o mouse
## ou ao receber foco pelo teclado/controle, e SFX.UI_CLICK ao ser apertado. Volume baixo
## (categoria ui_nav do SFX) e hover com intervalo mínimo, para não cansar.
## Um botão fica de fora com set_meta(UISounds.MUTE_META, true) ou no grupo "no_ui_sound".
## Autoload CoreUISounds.

const MUTE_META: StringName = &"ui_sound_mute"
const MUTE_GROUP: StringName = &"no_ui_sound"
const _HOOKED_META: StringName = &"_ui_sound_hooked"
## dB sobre a categoria ui_nav (CATEGORY_DB do SFX).
const HOVER_DB: float = -4.0
const CLICK_DB: float = 0.0
const HOVER_MIN_INTERVAL_MS: int = 45
## Ações que movem o foco: só elas fazem o hover do foco (um grab_focus ao abrir menu não toca).
const NAV_ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]

## Último som tocado (&"hover"/&"click") e quantos: para os testes.
var last_played: StringName = &""
var played_count: int = 0
var _last_hover_ms: int = -100000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_hook_all(get_tree().root)


func _hook_all(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_hook_all(child)


func _on_node_added(node: Node) -> void:
	var b: BaseButton = node as BaseButton
	if b == null or b.has_meta(_HOOKED_META):
		return
	b.set_meta(_HOOKED_META, true)
	b.mouse_entered.connect(_on_hover.bind(b, false))
	b.focus_entered.connect(_on_hover.bind(b, true))
	b.pressed.connect(_on_pressed.bind(b))


func _muted(b: BaseButton) -> bool:
	return not is_instance_valid(b) or bool(b.get_meta(MUTE_META, false)) or b.is_in_group(MUTE_GROUP)


func _on_hover(b: BaseButton, from_focus: bool) -> void:
	if _muted(b) or b.disabled or not b.is_visible_in_tree():
		return
	if from_focus and not _nav_pressed():
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_hover_ms < HOVER_MIN_INTERVAL_MS:
		return
	_last_hover_ms = now
	_play(&"hover", SFX.UI_HOVER, HOVER_DB)


func _on_pressed(b: BaseButton) -> void:
	if _muted(b):
		return
	_play(&"click", SFX.UI_CLICK, CLICK_DB)


func _nav_pressed() -> bool:
	for action: StringName in NAV_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			return true
	return false


func _play(kind: StringName, sound: Array[String], volume_db: float) -> void:
	last_played = kind
	played_count += 1
	SFX.play_ui(sound, volume_db, 0.05)
