# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/death_screen_test.gd
# Tela de morte (#244): abertura via Player.died, captura de itens antes do drop, filtro de downed/expedição,
# pausa em solo, foco/atalho Esc, tradução EN e botão Voltar à base.
extends SceneTree

class FakeInventory extends RefCounted:
	var count: int = 0

	func get_count() -> int:
		return count

class FakePlayer extends Node:
	signal died
	var local: bool = true
	var is_downed: bool = false
	var inventory: FakeInventory = FakeInventory.new()

	func is_local() -> bool:
		return local

	func simulate_solo_death() -> void:
		died.emit()
		# Simula _drop_all_items() rodando logo após died.emit() no mesmo frame.
		inventory.count = 0

	func simulate_coop_downed() -> void:
		died.emit()
		inventory.count = 0
		is_downed = true

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _wait(frames: int = 3) -> void:
	for i: int in frames:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveManager.instance.use_test_save_dir("death_screen_test")
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)

	var ui: SessionUI = SessionUI.instance
	var ds: DeathScreen = DeathScreen.instance
	var sm: SessionManager = SessionManager.instance
	_check(ui != null and ds != null and ui.death_screen == ds, "DeathScreen montada pela SessionUI")
	if ui == null or ds == null or sm == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	_check(not DeathScreen.is_open(), "começa fechada")

	# 1. Fora de expedição: died não abre a tela de morte (protege testes unitários isolados).
	var player: FakePlayer = FakePlayer.new()
	player.inventory.count = 2
	current_scene.add_child(player)
	await _wait(2)
	sm.set("_current_map", null)
	player.simulate_solo_death()
	await _wait(4)
	_check(not DeathScreen.is_open() and not paused, "fora de expedição: died não abre tela nem pausa")

	# 2. Em expedição, modo coop downed: died NÃO abre tela de morte (preserva câmera orbital/socorro).
	sm.set("_current_map", load("res://items/maps/praia.tres"))
	player.inventory.count = 3
	player.is_downed = false
	player.simulate_coop_downed()
	await _wait(4)
	_check(not DeathScreen.is_open() and not paused, "coop downed: não cobre estado caído")

	# 3. Em expedição solo: died captura contagem exata ANTES do drop e abre pausando.
	player.is_downed = false
	player.inventory.count = 4
	player.simulate_solo_death()
	await _wait(4)
	_check(DeathScreen.is_open(), "solo em expedição: tela de morte aberta")
	_check(paused, "solo: árvore pausada enquanto tela de morte está aberta")
	_check(UiFocus.modal_open(), "UiFocus.modal_open reconhece tela de morte")
	_check(not PauseMenu.instance.can_open(), "PauseMenu não abre por cima da tela de morte")
	_check(ds.bag_label.text.contains("4 itens"), "capturou 4 itens antes do drop: '%s'" % ds.bag_label.text)
	_check(ds.location_label.text.contains("Praia"), "mostra mapa atual: '%s'" % ds.location_label.text)
	_check(ds.continue_button.has_focus(), "foco inicial em Continuar expedição")
	_check(ds.return_base_button.visible, "host em expedição vê Voltar à base")

	# 4. Tradução ao vivo para inglês e caso 1 item / 0 itens.
	var prev_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	await _wait(2)
	_check(ds.title_label.text == "You passed out!", "título em inglês: '%s'" % ds.title_label.text)
	_check(ds.continue_button.text == "Continue expedition", "botão em inglês: '%s'" % ds.continue_button.text)
	TranslationServer.set_locale(prev_locale)
	await _wait(2)

	# 5. Fechar por botão Continuar expedição despausa e limpa modal.
	ds.continue_button.pressed.emit()
	await _wait(3)
	_check(not DeathScreen.is_open() and not paused, "Continuar fecha e despausa")
	_check(PauseMenu.instance.can_open(), "PauseMenu volta a poder abrir")

	# 6. Casos 1 item e 0 itens + fechar via Esc (ui_cancel).
	ds.open({"dropped_items": 1, "map_name": "Praia", "day": 2})
	await _wait(2)
	_check(ds.bag_label.text.contains("1 item"), "singular 1 item: '%s'" % ds.bag_label.text)
	ds.open({"dropped_items": 0, "map_name": "Praia", "day": 2, "night": true})
	await _wait(2)
	_check(ds.bag_label.text == DeathScreen.BAG_EMPTY_TEXT, "mochila vazia: '%s'" % ds.bag_label.text)
	_check(ds.location_label.text.contains("noite"), "modo noturno exibido na localização: '%s'" % ds.location_label.text)
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	ds._input(esc)
	await _wait(2)
	_check(not DeathScreen.is_open() and not paused, "Esc fecha tela de morte e despausa")

	# Cleanup.
	sm.set("_current_map", null)
	player.queue_free()
	await _wait(3)
	print("RESULT fails=%d" % _fails)
	quit(_fails)
