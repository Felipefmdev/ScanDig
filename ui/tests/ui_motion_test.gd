extends SceneTree

## Valida o vocabulário central de micro-animações UiMotion (#252):
## - modo instantâneo em headless por padrão (sem órfãos nem alteração de retângulos);
## - curvas reais com force_enabled = true (pop_in, switch_tab_page, toast_enter, pulse, shake,
##   breathe_emblem, attach_button e cancelamento limpo via stop).

var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
	await process_frame


func _run() -> void:
	# 1. Padrão headless: is_instant() == true preserva escala/opacidade nominais no frame 0.
	_check(UiMotion.is_instant(), "headless usa modo instantâneo por padrão")
	var host: Control = Control.new()
	host.size = Vector2(640, 360)
	root.add_child(host)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 120)
	card.size = Vector2(240, 120)
	host.add_child(card)
	await process_frame

	var instant_tw: Tween = UiMotion.pop_in(card)
	_check(instant_tw == null and card.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(card.modulate.a, 1.0),
		"modo instantâneo mantém escala 1.0 e opacidade 1.0")

	# 2. Com force_enabled = true, exercita todos os Tweens reais e valida pivô central e convergência.
	UiMotion.force_enabled = true
	_check(not UiMotion.is_instant(), "force_enabled ativa Tweens reais")

	var pop_tw: Tween = UiMotion.pop_in(card, true, 0.90, 0.14)
	_check(pop_tw != null and card.pivot_offset.is_equal_approx(Vector2(120, 60)), "pop_in centraliza pivot_offset")
	_check(card.scale.x < 0.95 and card.modulate.a < 0.5, "pop_in inicia em escala reduzida e fade")
	await _wait(0.18)
	_check(card.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(card.modulate.a, 1.0),
		"pop_in converge para escala 1.0 e opacidade 1.0")

	# 3. Troca de aba
	var tab_page: Control = Control.new()
	tab_page.size = Vector2(300, 180)
	host.add_child(tab_page)
	var tab_tw: Tween = UiMotion.switch_tab_page(tab_page, true, 0.12)
	_check(tab_tw != null and tab_page.scale.x < 1.0, "switch_tab_page inicia transição")
	await _wait(0.16)
	_check(tab_page.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(tab_page.modulate.a, 1.0),
		"switch_tab_page converge limpo")

	# 4. Toast com ícone lateral
	var toast: PanelContainer = PanelContainer.new()
	toast.size = Vector2(260, 44)
	var icon: TextureRect = TextureRect.new()
	icon.size = Vector2(22, 22)
	toast.add_child(icon)
	host.add_child(toast)
	var toast_tw: Tween = UiMotion.toast_enter(toast, icon, true)
	_check(toast_tw != null and icon.scale.x < 0.8 and icon.rotation_degrees < -5.0, "toast_enter anima painel e ícone")
	await _wait(0.24)
	_check(toast.scale.is_equal_approx(Vector2.ONE) and icon.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(icon.rotation_degrees, 0.0),
		"toast_enter assenta painel e ícone em 1.0 / 0°")

	# 5. Pulse e Shake sem deslocar position
	var orig_pos: Vector2 = card.position
	UiMotion.pulse(card, 1.08, 0.12)
	_check(card.scale.x > 1.04, "pulse aplica pico inicial")
	await _wait(0.16)
	_check(card.scale.is_equal_approx(Vector2.ONE), "pulse retorna a 1.0")

	UiMotion.shake(card, 3.0, 0.16)
	await _wait(0.03)
	_check(card.position.is_equal_approx(orig_pos) and absf(card.rotation_degrees) > 0.1,
		"shake gira em torno do pivô sem deslocar position")
	await _wait(0.20)
	_check(is_equal_approx(card.rotation_degrees, 0.0) and card.position.is_equal_approx(orig_pos),
		"shake retorna rotação a 0°")

	# 6. Emblema em loop + cancelamento via stop(..., true)
	var emblem: Control = Control.new()
	emblem.size = Vector2(32, 32)
	host.add_child(emblem)
	var loop_tw: Tween = UiMotion.breathe_emblem(emblem, 1.06, 2.5, 0.10)
	_check(loop_tw != null and loop_tw.is_valid(), "breathe_emblem cria loop válido")
	await _wait(0.06)
	UiMotion.stop(emblem, true)
	_check(emblem.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(emblem.rotation_degrees, 0.0),
		"stop cancela loop e restaura emblema")

	# 7. Botão tátil (attach_button): compressão no clique e mola na soltura, respeitando disabled
	var btn: Button = Button.new()
	btn.size = Vector2(160, 44)
	host.add_child(btn)
	UiMotion.attach_button(btn, 1.03, 0.95)
	btn.button_down.emit()
	await _wait(0.08)
	_check(btn.scale.x < 0.98, "attach_button comprime no button_down")
	btn.button_up.emit()
	await _wait(0.18)
	_check(btn.scale.is_equal_approx(Vector2.ONE), "attach_button retorna a 1.0 no button_up")

	btn.disabled = true
	btn.mouse_entered.emit()
	await _wait(0.05)
	_check(btn.scale.is_equal_approx(Vector2.ONE), "botão desativado não escala no hover")

	UiMotion.force_enabled = false
	host.free()
	await process_frame
	print("RESULT fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
