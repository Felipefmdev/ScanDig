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

	# 8. Contador suave de dinheiro no HUD (#255): interpola durante o Tween e converge exato.
	var hud_scene: PackedScene = load("res://ui/hud.tscn") as PackedScene
	var hud: HUD = hud_scene.instantiate() as HUD
	root.add_child(hud)
	await process_frame
	hud.update_money(100)
	hud._on_money_changed(1100)
	await _wait(0.08)
	_check(hud._displayed_money > 120.0 and hud._displayed_money < 1095.0,
		"HUD interpola contador de dinheiro durante o Tween")
	await _wait(0.28)
	_check(hud.money_label.text == tr("Dinheiro  %s") % UiFormat.money(1100),
		"HUD converge contador de dinheiro para o valor final exato")

	UiMotion.force_enabled = false
	hud._on_money_changed(2500)
	_check(hud.money_label.text == tr("Dinheiro  %s") % UiFormat.money(2500),
		"HUD atualiza dinheiro de forma síncrona em modo instantâneo")
	hud.free()

	# 9. Tons semânticos (#258): WeatherHud, CaptionsHud e SaveToast + som de abas em UISounds.
	if WeatherHud.instance != null:
		WeatherHud.instance.show_toast(WeatherHud.WARNING_TEXTS[WeatherManager.KIND_RAIN])
		var rain_box: StyleBoxFlat = WeatherHud.instance.toast_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
		_check(rain_box != null and not rain_box.bg_color.is_equal_approx(UiPalette.GREEN_BOTTLE),
			"WeatherHud usa tom de tempestade distinto de GREEN_BOTTLE na chuva")
		WeatherHud.instance.show_toast(WeatherHud.CLEAR_TEXT)
		var clear_box: StyleBoxFlat = WeatherHud.instance.toast_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
		_check(clear_box != null and clear_box.bg_color.is_equal_approx(UiPalette.GREEN_BOTTLE),
			"WeatherHud preserva GREEN_BOTTLE em tempo limpo")
		WeatherHud.instance.hide_toast()
	if CaptionsHud.instance != null:
		var cap_danger: PanelContainer = CaptionsHud.instance.show_line(A11y.CAPTION_CREATURE)
		var cap_box: StyleBoxFlat = cap_danger.get_theme_stylebox(&"panel") as StyleBoxFlat
		_check(cap_box != null and not cap_box.bg_color.is_equal_approx(UiPalette.GREEN_BOTTLE),
			"CaptionsHud usa tom de alerta em legenda de perigo")
		CaptionsHud.instance.clear()
	if SessionUI.instance != null and SessionUI.instance.save_toast_panel != null:
		var save_box: StyleBoxFlat = SessionUI.instance.save_toast_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
		_check(save_box != null and save_box.bg_color.is_equal_approx(UiPalette.RED_BURNT),
			"SaveToast usa RED_BURNT para erro de gravação/versão")
	var session_ui: SessionUI = SessionUI.instance
	if session_ui != null:
		UiMotion.force_enabled = true
		var earned_only: Dictionary = {"entries": [], "money_start": 100, "money_end": 150, "money_earned": 50}
		var final_total: String = tr("Total ganho: %s  (saldo: %s → %s)") % [UiFormat.money(50), UiFormat.money(100), UiFormat.money(150)]
		session_ui._show_summary(earned_only)
		_check(session_ui.summary_total_label.text.contains(tr("Total ganho: %s  (saldo: %s → %s)") % [UiFormat.money(0), UiFormat.money(100), UiFormat.money(100)]),
			"o total do resumo começa em zero para ganhos sem venda ou doação")
		await _wait(0.34)
		_check(session_ui.summary_total_label.text.contains(final_total), "o total do resumo converge para o ganho líquido")
		UiMotion.force_enabled = false
		session_ui._on_leave_pressed()
		session_ui.summary_close_button.grab_focus()
		session_ui._on_summary_close_pressed()
		_check(session_ui.leave_confirm_panel.visible and session_ui.leave_cancel_button.has_focus(),
			"fechar o resumo devolve o foco à confirmação aberta")
		session_ui._on_leave_cancel_pressed()
	var tabs: TabContainer = TabContainer.new()
	var page0: Control = Control.new()
	page0.name = "A"
	var page1: Control = Control.new()
	page1.name = "B"
	tabs.add_child(page0)
	tabs.add_child(page1)
	host.add_child(tabs)
	await process_frame
	var ui_sounds: UISounds = root.get_node_or_null(^"CoreUISounds") as UISounds
	if ui_sounds != null:
		var before_clicks: int = ui_sounds.played_count
		tabs.current_tab = 1
		_check(ui_sounds.played_count == before_clicks,
			"troca programática de current_tab não dispara som")
		tabs.get_tab_bar().tab_clicked.emit(0)
		_check(ui_sounds.played_count == before_clicks + 1 and ui_sounds.last_played == &"click",
			"clique em TabBar dispara UI_CLICK")
	tabs.free()

	host.free()
	await process_frame
	print("RESULT fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
