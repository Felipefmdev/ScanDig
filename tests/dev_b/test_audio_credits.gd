extends GutTest

## Guarda dos créditos (#123): todo arquivo de áudio em assets/audio aparece no CREDITS.md com
## licença CC0, e todo som que o jogo toca (banco do SFX e loops do CoreAmbience) mora lá.

const ROOT: String = "res://assets/audio/"
const CREDITS: String = ROOT + "CREDITS.md"


func _audio_files(dir: String = ROOT) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".ogg") or f.ends_with(".wav"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_audio_files(dir.path_join(d)))
	return out


func _used_paths() -> Array[String]:
	var out: Array[String] = SFX.all_paths()
	for id: String in AmbienceManager.AMBIENT_BY_MAP:
		out.append(AmbienceManager.ambient_path(id, false))
		out.append(AmbienceManager.ambient_path(id, true))
	for kind: String in AmbienceManager.WEATHER_LOOPS:
		out.append(str((AmbienceManager.WEATHER_LOOPS[kind] as Dictionary)["path"]))
	return out


func test_every_audio_file_is_credited_as_cc0() -> void:
	assert_true(FileAccess.file_exists(CREDITS), "CREDITS.md existe")
	var lines: PackedStringArray = FileAccess.get_file_as_string(CREDITS).split("\n")
	var files: Array[String] = _audio_files()
	assert_gt(files.size(), 50)
	for path: String in files:
		var key: String = "`%s`" % path.trim_prefix(ROOT)
		var row: String = ""
		for line: String in lines:
			if line.begins_with("| " + key):
				row = line
				break
		assert_ne(row, "", "CREDITS.md cita %s" % key)
		assert_string_contains(row, "CC0", false)


func test_every_used_sound_lives_in_assets_audio() -> void:
	for path: String in _used_paths():
		assert_true(path.begins_with(ROOT), "som do jogo em assets/audio: %s" % path)
		assert_true(FileAccess.file_exists(path), "existe: %s" % path)
