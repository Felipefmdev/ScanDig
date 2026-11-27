class_name UiMotion
extends RefCounted

## Vocabulário centralizado de micro-animações da UI (#252), calibrado para a estética tátil de
## papel gasto, madeira e tinta do ScanDig: transições curtas (0.14s–0.22s), pivô sempre centrado,
## cancelamento limpo ao interromper e determinismo automático em headless/snapshots estáticos.

const META_TWEEN: StringName = &"_ui_motion_tween"
const META_LOOP: StringName = &"_ui_motion_loop"
const META_PIVOT: StringName = &"_ui_motion_pivot"
const META_BUTTON: StringName = &"_ui_motion_button"

const CARD_DURATION: float = 0.18
const CARD_FROM_SCALE: float = 0.945
const TAB_DURATION: float = 0.15
const TAB_FROM_SCALE: float = 0.985
const TOAST_IN_DURATION: float = 0.18
const TOAST_OUT_DURATION: float = 0.22
const BUTTON_PRESS_DURATION: float = 0.065
const BUTTON_RELEASE_DURATION: float = 0.15

## Testes dedicados de animação ligam para exercitar os Tweens mesmo em modo headless/--script.
static var force_enabled: bool = false


## True durante capturas estáticas de tela (theme_snapshots / --prefix= / --out-dir=), exceto com force_enabled.
static func is_snapshot() -> bool:
	if force_enabled:
		return false
	for engine_arg: String in OS.get_cmdline_args():
		if engine_arg.contains("snapshots"):
			return true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(String(&"--prefix=")) or arg.begins_with(String(&"--out-dir=")):
			return true
	return false


## True em headless ou durante capturas estáticas (theme_snapshots / --prefix= / --out-dir=), exceto com force_enabled.
static func is_instant() -> bool:
	if force_enabled:
		return false
	return DisplayServer.get_name() == "headless" or is_snapshot()


## Mantém o pivot_offset no centro real do controle (mesmo no frame 0 antes do Container medir).
static func sync_center_pivot(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var sz: Vector2 = control.size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = control.get_combined_minimum_size()
	control.pivot_offset = sz * 0.5
	if not control.has_meta(META_PIVOT):
		control.set_meta(META_PIVOT, true)
		control.resized.connect(func() -> void:
			if is_instance_valid(control):
				control.pivot_offset = control.size * 0.5)


## Cancela tween ativo do item e restaura escala, rotação e opacidade nominais.
static func stop(item: CanvasItem, stop_loop: bool = false) -> void:
	if not is_instance_valid(item):
		return
	if item.has_meta(META_TWEEN):
		var prev: Tween = item.get_meta(META_TWEEN) as Tween
		if prev != null and prev.is_valid():
			prev.kill()
		item.remove_meta(META_TWEEN)
	if stop_loop and item.has_meta(META_LOOP):
		var loop_tw: Tween = item.get_meta(META_LOOP) as Tween
		if loop_tw != null and loop_tw.is_valid():
			loop_tw.kill()
		item.remove_meta(META_LOOP)
	item.modulate.a = 1.0
	if item is Control:
		var ctrl: Control = item as Control
		ctrl.scale = Vector2.ONE
		ctrl.rotation_degrees = 0.0


## Entrada tátil de cartão/modal: leve mola de escala + fade rápido, sempre a partir do centro.
static func pop_in(control: Control, pause_aware: bool = true, from_scale: float = CARD_FROM_SCALE, duration: float = CARD_DURATION, delay: float = 0.0) -> Tween:
	if not is_instance_valid(control):
		return null
	stop(control)
	sync_center_pivot(control)
	if is_instant() or not control.is_inside_tree():
		control.modulate.a = 1.0
		control.scale = Vector2.ONE
		return null
	control.modulate.a = 0.0 if delay > 0.0 else 0.22
	control.scale = Vector2.ONE * from_scale
	var tw: Tween = control.create_tween()
	if pause_aware:
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(control, ^"modulate:a", 1.0, duration * 0.78).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(control, ^"scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	control.set_meta(META_TWEEN, tw)
	return tw


## Escurecimento suave do fundo (Dim / ModalBackdrop) sincronizado com a abertura do modal.
static func fade_backdrop(backdrop: CanvasItem, pause_aware: bool = true, duration: float = 0.16) -> Tween:
	if not is_instance_valid(backdrop):
		return null
	stop(backdrop)
	if is_instant() or not backdrop.is_inside_tree():
		backdrop.modulate.a = 1.0
		return null
	backdrop.modulate.a = 0.0
	var tw: Tween = backdrop.create_tween()
	if pause_aware:
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(backdrop, ^"modulate:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	backdrop.set_meta(META_TWEEN, tw)
	return tw


## Troca de aba com assentamento sutil de folha de papel.
static func switch_tab_page(page: Control, pause_aware: bool = true, duration: float = TAB_DURATION) -> Tween:
	if not is_instance_valid(page):
		return null
	stop(page)
	sync_center_pivot(page)
	if is_instant() or not page.is_inside_tree():
		page.modulate.a = 1.0
		page.scale = Vector2.ONE
		return null
	page.modulate.a = 0.35
	page.scale = Vector2.ONE * TAB_FROM_SCALE
	var tw: Tween = page.create_tween()
	if pause_aware:
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(page, ^"modulate:a", 1.0, duration * 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(page, ^"scale", Vector2.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	page.set_meta(META_TWEEN, tw)
	return tw


## Entrada viva para avisos/toasts, com pop opcional no ícone lateral.
static func toast_enter(panel: Control, icon: Control = null, pause_aware: bool = true) -> Tween:
	if not is_instance_valid(panel):
		return null
	stop(panel)
	sync_center_pivot(panel)
	if is_instant() or not panel.is_inside_tree():
		panel.modulate.a = 1.0
		panel.scale = Vector2.ONE
		if is_instance_valid(icon):
			icon.scale = Vector2.ONE
			icon.rotation_degrees = 0.0
		return null
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.93, 0.93)
	var tw: Tween = panel.create_tween()
	if pause_aware:
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(panel, ^"modulate:a", 1.0, TOAST_IN_DURATION * 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, ^"scale", Vector2.ONE, TOAST_IN_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(icon) and icon.visible:
		sync_center_pivot(icon)
		icon.scale = Vector2(0.62, 0.62)
		icon.rotation_degrees = -12.0
		tw.tween_property(icon, ^"scale", Vector2.ONE, TOAST_IN_DURATION * 1.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(icon, ^"rotation_degrees", 0.0, TOAST_IN_DURATION * 1.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel.set_meta(META_TWEEN, tw)
	return tw


## Pulso comemorativo curto (compra concluída, código copiado, chip de recurso atualizado).
static func pulse(control: Control, peak_scale: float = 1.055, duration: float = 0.20, pause_aware: bool = true) -> Tween:
	if not is_instance_valid(control):
		return null
	stop(control)
	sync_center_pivot(control)
	if is_instant() or not control.is_inside_tree() or not control.is_visible_in_tree():
		control.scale = Vector2.ONE
		return null
	control.scale = Vector2.ONE * peak_scale
	var tw: Tween = control.create_tween()
	if pause_aware:
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(control, ^"scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	control.set_meta(META_TWEEN, tw)
	return tw


## Oscilação rotacional amortecida para feedback de bloqueio/erro (sem mover position em Containers).
static func shake(control: Control, amplitude_deg: float = 2.2, duration: float = 0.24, pause_aware: bool = true) -> Tween:
	if not is_instance_valid(control):
		return null
	stop(control)
	sync_center_pivot(control)
	if is_instant() or not control.is_inside_tree() or not control.is_visible_in_tree():
		control.rotation_degrees = 0.0
		return null
	var step: float = duration * 0.25
	var tw: Tween = control.create_tween()
	if pause_aware:
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(control, ^"rotation_degrees", amplitude_deg, step).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(control, ^"rotation_degrees", -amplitude_deg * 0.75, step).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(control, ^"rotation_degrees", amplitude_deg * 0.4, step).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(control, ^"rotation_degrees", 0.0, step).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	control.set_meta(META_TWEEN, tw)
	return tw


## Respiração contínua suave para emblemas de modais (troféu, caveira, alerta).
static func breathe_emblem(control: Control, peak_scale: float = 1.05, tilt_deg: float = 2.0, half_period: float = 1.15, pause_aware: bool = true) -> Tween:
	if not is_instance_valid(control):
		return null
	stop(control, true)
	sync_center_pivot(control)
	if is_instant() or not control.is_inside_tree():
		control.scale = Vector2.ONE
		control.rotation_degrees = 0.0
		return null
	var tw: Tween = control.create_tween().set_loops()
	if pause_aware:
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(control, ^"scale", Vector2.ONE * peak_scale, half_period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if absf(tilt_deg) > 0.01:
		tw.parallel().tween_property(control, ^"rotation_degrees", tilt_deg, half_period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(control, ^"scale", Vector2.ONE, half_period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if absf(tilt_deg) > 0.01:
		tw.parallel().tween_property(control, ^"rotation_degrees", -tilt_deg, half_period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	control.set_meta(META_LOOP, tw)
	return tw


## Micro-interação tátil uniforme para botões: hover, foco por teclado/controle (#122) e mola ao clicar.
static func attach_button(button: BaseButton, hover_scale: float = 1.024, press_scale: float = 0.965) -> void:
	if not is_instance_valid(button) or button.has_meta(META_BUTTON):
		return
	button.set_meta(META_BUTTON, true)
	sync_center_pivot(button)
	var btn_ref: WeakRef = weakref(button)
	var btn_tween: Array[Tween] = [null]
	var held: Array[bool] = [false]
	var current_target: Array[Vector2] = [Vector2.ONE]
	var bound_container: Array[WeakRef] = [null]
	var restore_after_sort: Callable = func() -> void:
		var b: BaseButton = btn_ref.get_ref() as BaseButton
		if b == null or not is_instance_valid(b):
			return
		sync_center_pivot(b)
		if (btn_tween[0] == null or not btn_tween[0].is_valid()) and not current_target[0].is_equal_approx(Vector2.ONE):
			b.scale = current_target[0]
	var unbind_parent_sort: Callable = func() -> void:
		if bound_container[0] != null:
			var prev_c: Container = bound_container[0].get_ref() as Container
			if prev_c != null and is_instance_valid(prev_c) and prev_c.sort_children.is_connected(restore_after_sort):
				prev_c.sort_children.disconnect(restore_after_sort)
			bound_container[0] = null
	var bind_parent_sort: Callable = func() -> void:
		var b: BaseButton = btn_ref.get_ref() as BaseButton
		if b == null or not is_instance_valid(b):
			return
		var parent_c: Container = b.get_parent() as Container
		var cur_c: Container = bound_container[0].get_ref() as Container if bound_container[0] != null else null
		if parent_c != cur_c:
			unbind_parent_sort.call()
			if parent_c != null:
				bound_container[0] = weakref(parent_c)
				if not parent_c.sort_children.is_connected(restore_after_sort):
					parent_c.sort_children.connect(restore_after_sort)
	bind_parent_sort.call()
	button.tree_entered.connect(bind_parent_sort)
	button.tree_exiting.connect(unbind_parent_sort)
	var apply_state: Callable = func(emphasize: bool, releasing: bool = false) -> void:
		if not is_instance_valid(button):
			return
		sync_center_pivot(button)
		var target_f: float = 1.0
		if not button.disabled and button.is_visible_in_tree():
			if held[0]:
				target_f = press_scale
			elif emphasize:
				target_f = hover_scale
		var target: Vector2 = Vector2.ONE * target_f
		current_target[0] = target
		if btn_tween[0] != null and btn_tween[0].is_valid():
			btn_tween[0].kill()
		if is_instant() or not button.is_inside_tree():
			button.scale = target
			return
		var dur: float = BUTTON_PRESS_DURATION if held[0] else BUTTON_RELEASE_DURATION
		var trans: Tween.TransitionType = Tween.TRANS_BACK if releasing else Tween.TRANS_CUBIC
		var tw: Tween = button.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(button, ^"scale", target, dur).set_trans(trans).set_ease(Tween.EASE_OUT)
		btn_tween[0] = tw
	button.mouse_entered.connect(func() -> void: apply_state.call(true, false))
	button.focus_entered.connect(func() -> void: apply_state.call(not InputDevice.using_pointer(), false))
	button.mouse_exited.connect(func() -> void:
		held[0] = false
		apply_state.call(button.has_focus() and not InputDevice.using_pointer(), false))
	button.focus_exited.connect(func() -> void:
		held[0] = false
		apply_state.call(button.is_hovered(), false))
	button.button_down.connect(func() -> void:
		held[0] = true
		apply_state.call(false, false))
	button.button_up.connect(func() -> void:
		var was_held: bool = held[0]
		held[0] = false
		apply_state.call(button.is_hovered() or (button.has_focus() and not InputDevice.using_pointer()), was_held))
	button.visibility_changed.connect(func() -> void:
		if not button.is_visible_in_tree():
			held[0] = false
			current_target[0] = Vector2.ONE
			if btn_tween[0] != null and btn_tween[0].is_valid():
				btn_tween[0].kill()
			button.scale = Vector2.ONE)
