class_name UiFocus
extends RefCounted

## Navegação por comando e teclado nos menus (#102): achar e focar o primeiro controle de uma
## tela, encadear cima/baixo entre os controles visíveis (a busca automática de vizinho da Godot
## não acha bem os controles dentro de CanvasLayer) e trocar de aba com LB/RB (ou Ctrl+Tab).
## Borda de foco só ao navegar por teclado/comando (#122): follow_pointer.

## Tipos cuja borda de foco some com o mouse (o LineEdit mantém: mostra onde se digita).
const POINTER_HIDDEN_FOCUS: Array[StringName] = [&"Button", &"CheckBox", &"CheckButton", &"OptionButton",
	&"MenuButton", &"ItemList", &"HSlider", &"VSlider", &"SpinBox"]

## Grupo da tela "de casa" (a Base): quem fecha uma camada e não tem para onde devolver o foco
## chama focus_home() nele (#135), para o comando não ficar sem foco nenhum.
const HOME_GROUP: StringName = &"ui_focus_home"

static var _pointer_theme: Theme = null


## Tema que só apaga a borda de foco; o resto cai no tema dos ancestrais.
static func pointer_theme() -> Theme:
	if _pointer_theme == null:
		_pointer_theme = Theme.new()
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		for type: StringName in POINTER_HIDDEN_FOCUS:
			_pointer_theme.set_stylebox(&"focus", type, empty)
		_pointer_theme.set_stylebox(&"tab_focus", &"TabContainer", empty)
		_pointer_theme.set_stylebox(&"tab_focus", &"TabBar", empty)
	return _pointer_theme


## `target` (sem tema próprio) esconde a borda de foco dos descendentes enquanto o último input
## for o mouse e mostra de novo com teclado/comando. A busca de tema da Godot passa pelo tema mais
## próximo e cai no dos ancestrais para o que ele não tem.
static func follow_pointer(target: Control) -> void:
	if target == null:
		return
	target.theme = pointer_theme() if InputDevice.using_pointer() else null
	if InputDevice.instance == null:
		return
	var apply: Callable = func(on: bool) -> void:
		if is_instance_valid(target):
			target.theme = pointer_theme() if on else null
	InputDevice.instance.pointer_changed.connect(apply)
	target.tree_exiting.connect(func() -> void:
		if InputDevice.instance != null and InputDevice.instance.pointer_changed.is_connected(apply):
			InputDevice.instance.pointer_changed.disconnect(apply))


## Controles visíveis e focáveis sob `root`, em ordem de árvore.
static func focusables(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_front()
		var control: Control = node as Control
		if control != null:
			if not control.is_visible_in_tree():
				continue
			if control.focus_mode == Control.FOCUS_ALL:
				out.append(control)
		var children: Array[Node] = node.get_children()
		for i: int in range(children.size() - 1, -1, -1):
			stack.push_front(children[i])
	return out


## Botão desativado sai da navegação (#135): sem foco por teclado/comando (a busca de vizinho da
## Godot pula FOCUS_NONE, também nos vizinhos explícitos) até voltar a ficar ativo. O que está com
## o foco fica como está, para o foco não pular sozinho (ex.: o Comprar recém-apertado, desativado
## enquanto a compra processa). Só para botões que normalmente navegam (FOCUS_ALL).
static func skip_disabled(buttons: Array) -> void:
	for b: Variant in buttons:
		var button: BaseButton = b as BaseButton
		if button == null:
			continue
		if not button.disabled:
			button.focus_mode = Control.FOCUS_ALL
		elif not button.has_focus():
			button.focus_mode = Control.FOCUS_NONE


## Uma camada por cima (resumo do dia, aviso da sessão, pausa, vitória) está aberta: telas de baixo
## que acabam de abrir (lobby carregando atrás do resumo) não tiram o foco dela (#135).
static func modal_open() -> bool:
	if PauseMenu.is_open() or VictoryScreen.is_open():
		return true
	var ui: SessionUI = SessionUI.instance
	if ui == null or ui.summary_panel == null:
		return false
	return ui.summary_panel.visible or ui.host_lost_panel.visible or ui.leave_confirm_panel.visible


## O primeiro ativo (botão não desativado); se todos estiverem desativados, o primeiro mesmo.
static func first_focusable(root: Node) -> Control:
	var all: Array[Control] = focusables(root)
	for control: Control in all:
		if not (control is BaseButton and (control as BaseButton).disabled):
			return control
	return all[0] if not all.is_empty() else null


## Cima/baixo (e Tab/Shift+Tab) em anel na ordem dada.
static func link_chain(controls: Array) -> void:
	var list: Array[Control] = []
	for c: Variant in controls:
		var control: Control = c as Control
		if control != null and control.is_visible_in_tree() and not list.has(control):
			list.append(control)
	var count: int = list.size()
	for i: int in count:
		var control: Control = list[i]
		var up: NodePath = list[(i - 1 + count) % count].get_path()
		var down: NodePath = list[(i + 1) % count].get_path()
		control.focus_neighbor_top = up
		control.focus_neighbor_bottom = down
		control.focus_previous = up
		control.focus_next = down


## Esquerda/direita entre controles de uma linha (botões lado a lado).
static func link_row(controls: Array) -> void:
	var list: Array[Control] = []
	for c: Variant in controls:
		var control: Control = c as Control
		if control != null and control.is_visible_in_tree():
			list.append(control)
	for i: int in list.size():
		if i > 0:
			list[i].focus_neighbor_left = list[i - 1].get_path()
		if i < list.size() - 1:
			list[i].focus_neighbor_right = list[i + 1].get_path()


## Encadeia os controles de `root` (mais os `extra`, no fim) e foca o primeiro; false se não há.
static func focus_first(root: Node, extra: Array = []) -> bool:
	var chain: Array = []
	chain.append_array(focusables(root))
	chain.append_array(extra)
	link_chain(chain)
	var control: Control = first_focusable(root)
	if control == null or not control.is_inside_tree():
		return false
	control.grab_focus()
	return true


## -1/+1 para trocar de aba (LB/RB no comando; Ctrl+Shift+Tab / Ctrl+Tab no teclado), 0 senão.
static func tab_step(event: InputEvent) -> int:
	var joy: InputEventJoypadButton = event as InputEventJoypadButton
	if joy != null and joy.pressed:
		if joy.button_index == JOY_BUTTON_LEFT_SHOULDER:
			return -1
		if joy.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			return 1
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.ctrl_pressed and key.keycode == KEY_TAB:
		return -1 if key.shift_pressed else 1
	return 0


## Vai para a aba vizinha que não esteja desativada/oculta e foca o primeiro controle dela.
static func step_tab(tabs: TabContainer, direction: int, extra: Array = []) -> void:
	var count: int = tabs.get_tab_count()
	if count == 0 or direction == 0:
		return
	var index: int = tabs.current_tab
	for i: int in count:
		index = posmod(index + direction, count)
		if not tabs.is_tab_disabled(index) and not tabs.is_tab_hidden(index):
			break
	tabs.current_tab = index
	# No fim do frame: a página nova da TabContainer só fica visível depois.
	focus_tab_page.call_deferred(tabs, extra)


## Foca o primeiro controle da aba atual; aba sem controles (só texto ou desenho, #135) foca a
## barra de abas, que troca de aba com esquerda/direita, em vez de deixar o foco na aba oculta.
static func focus_tab_page(tabs: TabContainer, extra: Array = []) -> void:
	if tabs == null or not tabs.is_visible_in_tree():
		return
	if focus_first(tabs.get_current_tab_control(), extra):
		return
	var bar: TabBar = tabs.get_tab_bar()
	bar.focus_mode = Control.FOCUS_ALL
	# Tab/Shift+Tab ficam na barra (sem isso a Godot não acha o próximo e o foco some).
	bar.focus_next = NodePath(".")
	bar.focus_previous = NodePath(".")
	bar.grab_focus()
