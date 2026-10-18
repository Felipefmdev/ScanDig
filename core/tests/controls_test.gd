# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/controls_test.gd
## #77 etapa 2: remapear controles no SettingsManager. Arquivo do teste em user://test_saves/.
extends SceneTree

const PATH: String = "user://test_saves/controls_test.cfg"

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key) -> Dictionary:
	return {"type": "key", "code": int(code)}


## Teclas e botões que o InputMap tem para a ação (sem controle de jogo).
func _map_bindings(action: String) -> Array:
	var out: Array = []
	for ev: InputEvent in InputMap.action_get_events(action):
		var b: Dictionary = SettingsManager.binding_from_event(ev)
		if not b.is_empty() and not SettingsManager.is_pad_binding(b):
			out.append(b)
	return out


func _run() -> void:
	await _wait(3)
	var sm: SettingsManager = SettingsManager.instance
	_check(sm != null, "SettingsManager presente")
	if sm == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_saves"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var seed: ConfigFile = ConfigFile.new()
	seed.set_value("player", "name", "Murilo")
	seed.save(PATH)
	sm.settings_path = PATH
	sm.load_settings()
	sm.apply_all()

	# 1. Padrões no InputMap já no início (antes do player), inclusive a ação nova "pause".
	for action: String in SettingsManager.CONTROL_ACTIONS:
		# Ações só de comando (#102: olhar, espaço anterior/próximo) não têm tecla padrão.
		var expected: Array = [SettingsManager.DEFAULT_BINDINGS[action]] if SettingsManager.DEFAULT_BINDINGS.has(action) else []
		_check(_map_bindings(action) == expected, "%s no padrão: %s" % [action, str(_map_bindings(action))])
	_check(InputMap.has_action("pause") and _map_bindings("pause") == [_key(KEY_ESCAPE)], "pause = Esc")

	# 2. Remapear: aplica no InputMap e grava, preservando o [player].
	_check(sm.set_binding("jump", _key(KEY_J)), "pular → J")
	_check(_map_bindings("jump") == [_key(KEY_J)], "InputMap: pular só com J")
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_J
	ev.pressed = true
	_check(InputMap.event_is_action(ev, "jump"), "evento J dispara pular")
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	_check(cfg.get_value("controls", "jump", {}) == _key(KEY_J) and str(cfg.get_value("player", "name", "")) == "Murilo", "gravado sem apagar o nome")

	# 3. Recarrega do arquivo e reaplica (como ao abrir o jogo).
	InputMap.action_erase_events("jump")
	sm.load_settings()
	sm.apply_all()
	_check(_map_bindings("jump") == [_key(KEY_J)], "recarregado: pular com J")

	# 4. Conflito: sem troca não muda nada; com troca, a outra ação fica com a tecla antiga.
	_check(sm.find_conflict("interact", _key(KEY_J)) == "jump", "J já é de pular")
	_check(not sm.set_binding("interact", _key(KEY_J)) and sm.get_binding("interact") == _key(KEY_E), "conflito sem troca: nada muda")
	_check(sm.set_binding("interact", _key(KEY_J), true), "conflito com troca")
	_check(sm.get_binding("interact") == _key(KEY_J) and sm.get_binding("jump") == _key(KEY_E), "interagir J, pular E")
	_check(_map_bindings("jump") == [_key(KEY_E)] and _map_bindings("interact") == [_key(KEY_J)], "InputMap trocado")

	# 5. Mouse.
	var mouse: Dictionary = {"type": "mouse", "code": MOUSE_BUTTON_MIDDLE}
	_check(sm.set_binding("attack", mouse) and _map_bindings("attack") == [mouse], "atacar no botão do meio")

	# 6. Inválidos são recusados; sanitize ignora lixo do arquivo.
	_check(not sm.set_binding("voar", _key(KEY_V)) and not sm.set_binding("jump", {"type": "joy", "code": 1}), "ação ou binding inválido recusado")
	var clean: Dictionary = SettingsManager.sanitize(SettingsManager.CONTROLS, {"jump": {"type": "key", "code": -5}, "xyz": _key(KEY_X), "drop": _key(KEY_G)})
	_check(clean == {"drop": _key(KEY_G)}, "sanitize de controles: %s" % str(clean))

	# 7. Nomes em português.
	_check(SettingsManager.binding_label(_key(KEY_SPACE)) == "Espaço" and SettingsManager.binding_label(_key(KEY_ESCAPE)) == "Esc", "Espaço e Esc")
	_check(SettingsManager.binding_label({"type": "mouse", "code": MOUSE_BUTTON_LEFT}) == "Botão esquerdo", "Botão esquerdo")
	_check(SettingsManager.binding_label(_key(KEY_E)) == "E", "E")

	# 8. Restaurar padrão: tudo volta e a seção sai do arquivo.
	sm.reset_controls()
	_check(sm.get_binding("jump") == _key(KEY_SPACE) and _map_bindings("attack") == [_key(KEY_F)], "padrão restaurado")
	cfg = ConfigFile.new()
	cfg.load(PATH)
	_check(not cfg.has_section("controls") and str(cfg.get_value("player", "name", "")) == "Murilo", "sem [controls] no arquivo; nome continua")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	sm.settings_path = SettingsManager.DEFAULT_PATH
	print("RESULT fails=%d" % _fails)
	quit(_fails)
