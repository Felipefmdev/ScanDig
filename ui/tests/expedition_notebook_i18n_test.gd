extends SceneTree

## EN do CSV real em Translation temporária, sem import nem escrita em compiladas.
## Não comprova recursos importados, idioma salvo, layout EN ou integração gameplay/coop.
const SCAN: GDScript = preload("res://tools/i18n/i18n_scan.gd")
const KEYS: Array[String] = [
	"Caderno de Expedição",
	"A expedição continua enquanto você consulta o caderno.",
	"[%s] Caderno de Expedição",
]

var _fails: int = 0
var _previous_locale: String = ""
var _previous_messages: Dictionary = {}
var _original_translations: Array[Translation] = []
var _temporary: Translation = null
var _notebook: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	print(("PASS " if value else "FAIL ") + message)
	if not value:
		_fails += 1


func _run() -> void:
	SaveManager.instance.use_test_save_dir("expedition_notebook_i18n_test")
	print("USERDATA %s" % OS.get_user_data_dir())
	_previous_locale = TranslationServer.get_locale()
	for key: String in KEYS:
		_previous_messages[key] = String(TranslationServer.translate(key))
	var rows: Dictionary = SCAN.csv_rows()
	for key: String in KEYS:
		var row: Dictionary = rows.get(key, {}) as Dictionary
		_check(str(row.get("pt_BR", "")) == key and not str(row.get("en", "")).strip_edges().is_empty()
			and str(row.get("en", "")) != key, "CSV contém fonte PT e tradução EN: " + key)
	if _fails != 0:
		await _finish()
		return

	# Evita que traduções compiladas já carregadas façam o teste passar sem a temporária.
	# Guarda as mesmas instâncias configuradas no projeto e as devolve no cleanup.
	var paths: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	for path: String in paths:
		var translation: Translation = load(path) as Translation
		_check(translation != null, "preserva tradução configurada: " + path)
		if translation != null:
			_original_translations.append(translation)
			TranslationServer.remove_translation(translation)
	TranslationServer.set_locale("en")
	for key: String in KEYS:
		_check(String(TranslationServer.translate(key)) == key, "sem compilada ou fallback para a chave: " + key)
	if _fails != 0:
		await _finish()
		return

	_temporary = Translation.new()
	_temporary.locale = "en"
	for key: String in KEYS:
		var row: Dictionary = rows[key] as Dictionary
		_temporary.add_message(key, str(row["en"]))
	TranslationServer.add_translation(_temporary)
	for key: String in KEYS:
		var row: Dictionary = rows[key] as Dictionary
		_check(String(TranslationServer.translate(key)) == str(row["en"]), "TranslationServer resolve EN do CSV: " + key)
	var nb_script: GDScript = load("res://ui/expedition_notebook.gd") as GDScript
	_notebook = nb_script.new()
	root.add_child(_notebook)
	await process_frame
	var title: Label = _notebook.get("_title") as Label
	var hint: Label = _notebook.get("_hint") as Label
	_check(title != null and title.text == str((rows[KEYS[0]] as Dictionary)["en"]), "título do notebook usa EN do CSV em runtime")
	_check(hint != null and hint.text == str((rows[KEYS[1]] as Dictionary)["en"]), "hint do notebook usa EN do CSV em runtime")
	var prompt: String = String(TranslationServer.translate(KEYS[2]))
	var valid_placeholder: bool = prompt.count("%s") == 1 and prompt.count("%") == 1
	_check(valid_placeholder, "prompt EN mantém exatamente um placeholder de atalho")
	if valid_placeholder:
		for shortcut: String in ["G", "Select"]:
			var formatted: String = prompt % [shortcut]
			_check(formatted.begins_with("[" + shortcut + "] ") and not formatted.contains("%s"),
				"prompt formatado preserva atalho: " + shortcut)
	await _finish()


func _finish() -> void:
	if is_instance_valid(_notebook):
		_notebook.queue_free()
		_notebook = null
	for _frame: int in 2:
		await process_frame
	if _temporary != null:
		TranslationServer.remove_translation(_temporary)
		_temporary = null
	for translation: Translation in _original_translations:
		TranslationServer.add_translation(translation)
	_original_translations.clear()
	TranslationServer.set_locale(_previous_locale)
	for _frame: int in 2:
		await process_frame
	_check(TranslationServer.get_locale() == _previous_locale, "locale anterior restaurado")
	for key: String in KEYS:
		_check(String(TranslationServer.translate(key)) == str(_previous_messages[key]), "resolução anterior restaurada: " + key)
	print("RESULT fails=%d" % _fails)
	quit(_fails)
