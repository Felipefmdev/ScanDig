extends SceneTree

## Regrava core/data/audio_credits.json a partir de assets/audio/CREDITS.md (#149). Rode depois
## de mexer no CREDITS.md (o test_audio_credits.gd avisa quando esquecer):
##   "$G" --headless --path . --script res://tools/gen_audio_credits.gd

const AudioCreditsScript: GDScript = preload("res://core/audio_credits.gd")


func _init() -> void:
	var md: String = FileAccess.get_file_as_string(AudioCreditsScript.SOURCE_PATH)
	var authors: Array[Dictionary] = AudioCreditsScript.parse_markdown(md)
	var file: FileAccess = FileAccess.open(AudioCreditsScript.DATA_PATH, FileAccess.WRITE)
	if authors.is_empty() or file == null:
		printerr("gen_audio_credits: falhou (autores: %d, abrir: %s)" % [authors.size(), FileAccess.get_open_error()])
		quit(1)
		return
	file.store_string(AudioCreditsScript.to_json_text(authors))
	file.close()
	print("gen_audio_credits: %d autores em %s" % [authors.size(), AudioCreditsScript.DATA_PATH])
	quit(0)
