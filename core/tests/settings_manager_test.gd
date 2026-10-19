# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/settings_manager_test.gd
## #77: SettingsManager (autoload CoreSettings). Arquivo próprio do teste em user://test_saves/;
## o user://scandig_settings.cfg do jogador não é tocado.
extends SceneTree

const PATH: String = "user://test_saves/settings_manager_test.cfg"

var _fails: int = 0
var _trial_results: Array[bool] = []
var _changed: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _read() -> ConfigFile:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	return cfg


func _bus_db(bus_name: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name))


func _run() -> void:
	await _wait(3)
	var sm: SettingsManager = SettingsManager.instance
	_check(sm != null, "autoload CoreSettings presente")
	if sm == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_saves"))
	sm.settings_path = PATH
	sm.video_trial_finished.connect(func(kept: bool) -> void: _trial_results.append(kept))
	sm.settings_changed.connect(func(section: String, _values: Dictionary) -> void: _changed.append(section))

	# 1. Seções de outros donos ficam: nome, [online] e as opções do Esc.
	var initial: ConfigFile = ConfigFile.new()
	initial.set_value("player", "name", "Murilo")
	initial.set_value("player", "fov", 90.0)
	initial.set_value("online", "noray_port", 9999)
	_check(initial.save(PATH) == OK, "arquivo inicial gravado")
	sm.load_settings()
	_check(sm.get_section(SettingsManager.AUDIO) == SettingsManager.DEFAULTS[SettingsManager.AUDIO], "sem [audio]: padrões")
	sm.set_section(SettingsManager.AUDIO, {"master": 0.5, "music": 0.0, "sfx": 0.8})
	sm.set_section(SettingsManager.VIDEO, {"vsync": false, "max_fps": 60, "ui_scale": 1.2, "quality": "low"})
	var cfg: ConfigFile = _read()
	_check(str(cfg.get_value("player", "name", "")) == "Murilo" and is_equal_approx(float(cfg.get_value("gameplay", "fov", 0.0)), 90.0), "nome no [player]; fov antigo migrado para [gameplay]")
	_check(int(cfg.get_value("online", "noray_port", 0)) == 9999, "[online] preservado")
	_check(_changed == ["audio", "video"], "settings_changed por seção: %s" % str(_changed))

	# 2. Recarrega do arquivo: mesmos valores.
	sm.restore_defaults(SettingsManager.AUDIO, false)
	sm.load_settings()
	var audio: Dictionary = sm.get_section(SettingsManager.AUDIO)
	var video: Dictionary = sm.get_section(SettingsManager.VIDEO)
	_check(is_equal_approx(float(audio["master"]), 0.5) and is_equal_approx(float(audio["music"]), 0.0) and is_equal_approx(float(audio["sfx"]), 0.8), "áudio recarregado: %s" % str(audio))
	_check(video["vsync"] == false and int(video["max_fps"]) == 60 and is_equal_approx(float(video["ui_scale"]), 1.2) and video["quality"] == "low", "vídeo recarregado: %s" % str(video))

	# 3. Aplicação: buses (Music existe), mudo no zero, FPS, escala da UI e qualidade.
	sm.apply_all()
	_check(AudioServer.get_bus_index(&"Music") >= 0, "bus Music no default_bus_layout")
	_check(is_equal_approx(_bus_db(&"Master"), linear_to_db(0.5)), "Master a 50 %%: %.2f dB" % _bus_db(&"Master"))
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "Music mudo em 0")
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "SFX não mudo a 80 %")
	_check(Engine.max_fps == 60, "limite de FPS 60: %d" % Engine.max_fps)
	_check(is_equal_approx(root.content_scale_factor, 1.2), "escala da UI 1.2: %.2f" % root.content_scale_factor)
	_check(root.msaa_3d == Viewport.MSAA_DISABLED and is_equal_approx(root.scaling_3d_scale, 0.75), "qualidade baixa: MSAA desligado e render 3D a 75 %")

	# 4. Valores inválidos (arquivo editado à mão) viram padrão ou ficam na faixa.
	var bad: Dictionary = SettingsManager.sanitize(SettingsManager.VIDEO, {"window_mode": "gigante", "max_fps": 77, "ui_scale": 5.0, "quality": 3, "resolution": Vector2i(10, 10)})
	_check(bad["window_mode"] == "windowed" and int(bad["max_fps"]) == 0 and is_equal_approx(float(bad["ui_scale"]), 1.3) and bad["quality"] == "high" and bad["resolution"] == Vector2i(1280, 720), "vídeo inválido sanitizado: %s" % str(bad))
	var bad_audio: Dictionary = SettingsManager.sanitize(SettingsManager.AUDIO, {"master": 7.0, "sfx": "alto"})
	_check(is_equal_approx(float(bad_audio["master"]), 1.0) and is_equal_approx(float(bad_audio["sfx"]), 1.0), "áudio inválido sanitizado")

	# 5. Resolução sem confirmação: volta sozinha e não grava.
	var before: Dictionary = sm.get_section(SettingsManager.VIDEO)
	_check(SettingsManager.needs_video_trial(before, {"resolution": Vector2i(1600, 900)}), "resolução pede confirmação")
	_check(not SettingsManager.needs_video_trial(before, {"vsync": true}), "VSync não pede confirmação")
	sm.begin_video_trial({"resolution": Vector2i(1600, 900), "window_mode": "borderless"}, 0.3)
	_check(sm.is_video_trial_active() and sm.get_value(SettingsManager.VIDEO, "resolution") == Vector2i(1600, 900), "teste de vídeo aplicado")
	_check(_read().get_value("video", "resolution", Vector2i.ZERO) == before["resolution"], "teste de vídeo não grava")
	await create_timer(0.6).timeout
	_check(not sm.is_video_trial_active() and sm.get_section(SettingsManager.VIDEO) == before, "sem confirmação: voltou ao anterior")
	_check(_trial_results == [false], "video_trial_finished(false): %s" % str(_trial_results))

	# 6. Com confirmação: fica e grava.
	sm.begin_video_trial({"resolution": Vector2i(1600, 900)}, 0.3)
	sm.confirm_video_trial()
	await create_timer(0.6).timeout
	_check(sm.get_value(SettingsManager.VIDEO, "resolution") == Vector2i(1600, 900), "confirmado: resolução mantida")
	_check(_read().get_value("video", "resolution", Vector2i.ZERO) == Vector2i(1600, 900), "confirmado: gravado")
	_check(_trial_results == [false, true], "video_trial_finished(true): %s" % str(_trial_results))

	# 7. Restaurar padrão.
	sm.restore_defaults(SettingsManager.VIDEO)
	_check(sm.get_section(SettingsManager.VIDEO) == SettingsManager.DEFAULTS[SettingsManager.VIDEO], "vídeo no padrão")
	_check(str(_read().get_value("player", "name", "")) == "Murilo", "nome continua depois de restaurar")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	sm.settings_path = SettingsManager.default_path()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
