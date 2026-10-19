extends GutTest

## Versão única (#138): a tela inicial mostra application/config/version (pt e en), com o
## commit só no build de debug ("dev" sem o build_info.json do CI), e o export_presets.cfg
## (file_version/product_version do .exe) bate com o project.godot.

const TITLE_SCENE: PackedScene = preload("res://world/title_screen.tscn")


func after_each() -> void:
	TranslationServer.set_locale("pt_BR")


func _title() -> TitleScreen:
	var title: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	title.auto_skip = false
	title.scene_change_enabled = false
	add_child_autofree(title)
	return title


func test_format_release_and_debug() -> void:
	assert_eq(BuildInfo.format_display("0.1.0", "a1b2c3d", false), "v0.1.0", "release sem commit")
	assert_eq(BuildInfo.format_display("0.1.0", "a1b2c3d", true), "v0.1.0 (a1b2c3d)", "debug com commit")
	assert_eq(BuildInfo.format_display("1.2.3", BuildInfo.DEV_COMMIT, true), "v1.2.3 (dev)", "local cai em dev")
	assert_eq(BuildInfo.windows_version("0.1.0"), "0.1.0.0")
	assert_eq(BuildInfo.windows_version("2.0"), "2.0.0.0")


func test_version_comes_from_project_settings() -> void:
	var project: String = str(ProjectSettings.get_setting("application/config/version", ""))
	assert_false(project.is_empty(), "config/version definida")
	assert_eq(BuildInfo.version(), project)
	if not FileAccess.file_exists(BuildInfo.INFO_PATH):
		assert_eq(BuildInfo.commit(), BuildInfo.DEV_COMMIT, "sem build_info.json: dev")


func test_title_shows_version_in_pt_and_en() -> void:
	var expected: String = BuildInfo.format_display(BuildInfo.version(), BuildInfo.commit(), OS.is_debug_build())
	assert_string_starts_with(expected, "v" + BuildInfo.version())
	for locale: String in ["pt_BR", "en"]:
		TranslationServer.set_locale(locale)
		var title: TitleScreen = _title()
		assert_eq(title.version_label.text, expected, "versão no título (%s)" % locale)
		title.queue_free()
		await wait_frames(1)


func test_export_presets_match_project_version() -> void:
	var presets: ConfigFile = ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK, "export_presets.cfg carrega")
	var expected: String = BuildInfo.windows_version(BuildInfo.version())
	var found: int = 0
	for section: String in presets.get_sections():
		if not section.ends_with(".options") or not presets.has_section_key(section, "application/file_version"):
			continue
		found += 1
		for key: String in ["application/file_version", "application/product_version"]:
			assert_eq(str(presets.get_value(section, key)), expected,
				"%s %s segue config/version (rode tools/sync_version.sh)" % [section, key])
	assert_gt(found, 0, "preset do Windows com file_version")
