class_name UiNavAudit
extends RefCounted

## Auditoria de navegação por teclado e comando (#135): injeta as ações de menu com eventos reais
## (InputEventKey ou InputEventJoypadButton, pressionar e soltar) no viewport e percorre o grafo de
## foco de uma tela a partir do foco inicial. Diz quais controles interativos foram alcançados ×
## existentes, as armadilhas (foco perdido, em controle oculto/desativado, fora da camada ou região
## sem volta) e os controles sem borda de foco. Usado pelos testes GUT e pelo passo "nav_audit" do
## bot (DebugBridge).

const KEYBOARD: String = "keyboard"
const PAD: String = "pad"
const MOVES_KEYBOARD: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]
## O comando não tem Tab: só o direcional (as abas trocam com LB/RB).
const MOVES_PAD: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]
## Metadado para tirar um controle da conta (ex.: atalho duplicado só para o mouse).
const SKIP_META: StringName = &"nav_skip"

const KEYS: Dictionary = {
	&"ui_up": KEY_UP, &"ui_down": KEY_DOWN, &"ui_left": KEY_LEFT, &"ui_right": KEY_RIGHT,
	&"ui_focus_next": KEY_TAB, &"ui_focus_prev": KEY_TAB, &"ui_accept": KEY_ENTER, &"ui_cancel": KEY_ESCAPE,
}
const PAD_BUTTONS: Dictionary = {
	&"ui_up": JOY_BUTTON_DPAD_UP, &"ui_down": JOY_BUTTON_DPAD_DOWN, &"ui_left": JOY_BUTTON_DPAD_LEFT,
	&"ui_right": JOY_BUTTON_DPAD_RIGHT, &"ui_accept": JOY_BUTTON_A, &"ui_cancel": JOY_BUTTON_B,
	&"tab_prev": JOY_BUTTON_LEFT_SHOULDER, &"tab_next": JOY_BUTTON_RIGHT_SHOULDER,
}


static func moves(device: String) -> Array[StringName]:
	return MOVES_PAD if device == PAD else MOVES_KEYBOARD


## Eventos (pressionar, soltar) da ação no dispositivo; [] se ele não tem a ação. "tab_next" e
## "tab_prev" são a troca de aba (Ctrl+Tab / Ctrl+Shift+Tab, RB / LB).
static func events(action: StringName, device: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for pressed: bool in [true, false]:
		if device == PAD:
			if not PAD_BUTTONS.has(action):
				return []
			var joy: InputEventJoypadButton = InputEventJoypadButton.new()
			joy.button_index = PAD_BUTTONS[action]
			joy.pressed = pressed
			joy.pressure = 1.0 if pressed else 0.0
			out.append(joy)
		else:
			var key: InputEventKey = InputEventKey.new()
			var code: Key = KEY_TAB if action == &"tab_next" or action == &"tab_prev" else KEYS.get(action, KEY_NONE)
			if code == KEY_NONE:
				return []
			key.keycode = code
			key.physical_keycode = code
			key.pressed = pressed
			key.shift_pressed = action == &"ui_focus_prev" or action == &"tab_prev"
			key.ctrl_pressed = action == &"tab_next" or action == &"tab_prev"
			out.append(key)
	return out


## Injeta a ação (pressionar e soltar) e espera um frame. Pelo Input, como o teclado/comando de
## verdade (o TabBar só anda no comando com Input.is_action_just_pressed; viewport.push_input não
## atualiza esse estado), entregue na hora à janela.
static func inject(viewport: Viewport, action: StringName, device: String) -> void:
	for ev: InputEvent in events(action, device):
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
	await viewport.get_tree().process_frame


## Controle que o jogador usaria: visível, ativo, recebe mouse e é de um tipo interativo.
static func is_interactive(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree() or control.has_meta(SKIP_META):
		return false
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE and control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton:
		return not (control as BaseButton).disabled
	if control is ScrollBar:
		return false
	if control is Range:
		return control.focus_mode != Control.FOCUS_NONE or control is Slider
	if control is LineEdit:
		return (control as LineEdit).editable
	if control is TextEdit or control is ItemList or control is TabBar:
		return true
	if control is TabContainer:
		return control.focus_mode != Control.FOCUS_NONE
	return false


## Controles interativos sob `root` (sem os filhos internos, como as barras do ScrollContainer).
static func interactive(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var control: Control = node as Control
		if control != null and not control.is_visible_in_tree():
			continue
		if node is CanvasItem and not (node as CanvasItem).visible:
			continue
		if control != null and is_interactive(control):
			out.append(control)
		var children: Array[Node] = node.get_children()
		for i: int in range(children.size() - 1, -1, -1):
			stack.append(children[i])
	return out


## Nome legível: caminho relativo a `root` (+ texto do botão, se houver).
static func label_of(root: Node, control: Control) -> String:
	if control == null:
		return "<nenhum>"
	var path: String = str(root.get_path_to(control)) if _inside(root, control) else str(control.get_path())
	var button: Button = control as Button
	if button != null and not button.text.is_empty():
		return "%s (%s)" % [path, button.text.substr(0, 24)]
	return path


## `control` é `root` ou está dentro dela (a raiz pode ser o próprio botão, como o Voltar do museu).
static func _inside(root: Node, control: Node) -> bool:
	return control != null and (control == root or root.is_ancestor_of(control))


static func _disabled(control: Control) -> bool:
	return control is BaseButton and (control as BaseButton).disabled


## Borda de foco presente com teclado/comando (o tema do ponteiro, UiFocus, troca por vazio).
## O ItemList marca o foco na linha selecionada (selected_focus/cursor); o slider, no grabber.
static func has_focus_style(control: Control) -> bool:
	if control is Slider:
		return control.has_theme_icon(&"grabber_highlight")
	var names: PackedStringArray = ["focus"]
	if control is TabContainer or control is TabBar:
		names = PackedStringArray(["tab_focus"])
	elif control is ItemList:
		names = PackedStringArray(["selected_focus", "cursor"])
	for style_name: String in names:
		var box: StyleBox = control.get_theme_stylebox(style_name)
		if box != null and not box is StyleBoxEmpty:
			return true
	return false


## Estado que as setas mudam sem mover o foco (slider, aba, linha da lista): guarda e repõe, para a
## auditoria não mexer nas configurações nem na seleção.
static func _snapshot(control: Control) -> Variant:
	if control is Range:
		return (control as Range).value
	if control is TabContainer:
		return (control as TabContainer).current_tab
	if control is TabBar:
		return (control as TabBar).current_tab
	if control is ItemList:
		return (control as ItemList).get_selected_items()
	return null


static func _restore(control: Control, state: Variant) -> void:
	if state == null or not is_instance_valid(control):
		return
	if control is Range and not is_equal_approx((control as Range).value, float(state)):
		(control as Range).value = float(state)
	elif control is TabContainer and (control as TabContainer).current_tab != int(state):
		(control as TabContainer).current_tab = int(state)
	elif control is TabBar and (control as TabBar).current_tab != int(state):
		(control as TabBar).current_tab = int(state)
	elif control is ItemList:
		var list: ItemList = control
		var before: PackedInt32Array = state
		if list.get_selected_items() != before:
			list.deselect_all()
			for i: int in before:
				list.select(i, false)
			if not before.is_empty():
				list.item_selected.emit(before[0])


## Percorre o foco de `root` com as setas (e Tab no teclado) a partir do foco atual. Corrotina.
## `allow_leave`: sair de `root` para outro controle visível não é armadilha (telas lado a lado,
## como a Base e o menu de rede); em camadas modais é.
## Devolve {device, initial, initial_ok, existing, reached, missing, traps, no_focus_style, left_to}.
static func audit(root: Control, device: String, allow_leave: bool = false) -> Dictionary:
	var viewport: Viewport = root.get_viewport()
	var tree: SceneTree = root.get_tree()
	var initial: Control = viewport.gui_get_focus_owner()
	var existing: Array[Control] = interactive(root)
	var result: Dictionary = {
		"device": device, "initial": label_of(root, initial),
		"initial_ok": _inside(root, initial) and initial.is_visible_in_tree() and not _disabled(initial),
		"existing": [], "reached": [], "missing": [], "traps": [], "no_focus_style": [], "left_to": [],
	}
	for c: Control in existing:
		(result["existing"] as Array).append(label_of(root, c))
	if not _inside(root, initial):
		result["missing"] = (result["existing"] as Array).duplicate()
		(result["traps"] as Array).append("sem foco inicial na tela (%s)" % label_of(root, initial))
		return result
	var visited: Array[Control] = [initial]
	var edges: Dictionary = {}
	var queue: Array[Control] = [initial]
	var traps: Array = result["traps"]
	while not queue.is_empty():
		var from: Control = queue.pop_front()
		var targets: Array[Control] = []
		for action: StringName in moves(device):
			if not is_instance_valid(from) or not from.is_visible_in_tree():
				break
			var state: Variant = _snapshot(from)
			from.grab_focus()
			await inject(viewport, action, device)
			var to: Control = viewport.gui_get_focus_owner()
			_restore(from, state)
			# Tab/page restoration schedules layout and focus links for the next frame.
			# Drain it before testing another edge from the restored control.
			await tree.process_frame
			var trap: String = ""
			if to == null:
				trap = "foco perdido"
			elif not to.is_visible_in_tree():
				trap = "foco em controle oculto %s" % label_of(root, to)
			elif _disabled(to):
				trap = "foco em controle desativado %s" % label_of(root, to)
			elif not _inside(root, to):
				if allow_leave:
					if not (result["left_to"] as Array).has(label_of(root, to)):
						(result["left_to"] as Array).append(label_of(root, to))
					continue
				trap = "foco saiu da camada para %s" % label_of(root, to)
			if not trap.is_empty():
				var text: String = "%s --%s--> %s" % [label_of(root, from), action, trap]
				if not traps.has(text):
					traps.append(text)
				if not _inside(root, to):
					continue
			targets.append(to)
			if not visited.has(to):
				visited.append(to)
				queue.append(to)
		edges[from] = targets
	# Região sem volta: alcançado, mas de lá não se chega mais ao foco inicial.
	var back: Array[Control] = [initial]
	var changed: bool = true
	while changed:
		changed = false
		for node: Variant in edges.keys():
			if back.has(node):
				continue
			for to: Control in edges[node]:
				if back.has(to):
					back.append(node)
					changed = true
					break
	for c: Control in visited:
		if not back.has(c) and is_instance_valid(c):
			traps.append("sem volta ao foco inicial a partir de %s" % label_of(root, c))
	for c: Control in visited:
		if not is_instance_valid(c):
			continue
		(result["reached"] as Array).append(label_of(root, c))
		if not has_focus_style(c):
			(result["no_focus_style"] as Array).append(label_of(root, c))
	for c: Control in existing:
		if not visited.has(c):
			(result["missing"] as Array).append(label_of(root, c))
	if is_instance_valid(initial) and initial.is_visible_in_tree():
		initial.grab_focus()
	await tree.process_frame
	return result


## B/Esc fecha `layer` (ou a deixa invisível) e o foco cai em algo visível. Corrotina.
## Devolve {closed, focus_after, focus_ok}.
static func check_cancel(layer: Control, device: String) -> Dictionary:
	var viewport: Viewport = layer.get_viewport()
	var tree: SceneTree = layer.get_tree()
	await inject(viewport, &"ui_cancel", device)
	await tree.process_frame
	var closed: bool = not is_instance_valid(layer) or not layer.is_visible_in_tree()
	var focus: Control = viewport.gui_get_focus_owner()
	return {
		"closed": closed,
		"focus_after": str(focus.get_path()) if focus != null else "<nenhum>",
		"focus_ok": focus == null or (focus.is_visible_in_tree() and not _disabled(focus)),
	}


## Resumo de uma linha: "alcançados/total".
static func score(result: Dictionary) -> String:
	var total: int = (result.get("existing", []) as Array).size()
	var reached_existing: int = total - (result.get("missing", []) as Array).size()
	return "%d/%d" % [reached_existing, total]


## Uma tela inteira para o bot (passo "nav_audit" do DebugBridge): audita `root` em cada
## dispositivo e, com `cancel_layer`, aperta B/Esc (no último dispositivo) e vê se ela fechou.
## Devolve {root, <dispositivo>: audit(...), cancel: check_cancel(...) ou {}}. Corrotina.
static func screen_report(root: Control, devices: Array, allow_leave: bool = false, cancel_layer: Control = null) -> Dictionary:
	var report: Dictionary = {"root": str(root.get_path()), "cancel": {}}
	var start: Control = root.get_viewport().gui_get_focus_owner()
	var device: String = KEYBOARD
	for d: Variant in devices:
		device = str(d)
		if is_instance_valid(start) and start.is_visible_in_tree():
			start.grab_focus()
		report[device] = await audit(root, device, allow_leave)
	if cancel_layer != null:
		report["cancel"] = await check_cancel(cancel_layer, device)
	return report
