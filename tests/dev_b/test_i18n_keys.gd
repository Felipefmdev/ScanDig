extends GutTest

## Guarda da tradução (#131). A chave é o texto em PT-BR (o texto-fonte, que o test_ptbr_texts
## continua vigiando): translations/scandig.csv tem keys,pt_BR,en com pt_BR == chave e o inglês
## preenchido, e os %s/%d, "{ação}", "[E]" e tags BBCode da chave voltam iguais na tradução (um
## %d a menos quebra o "%" em tempo de execução).

const SCAN: GDScript = preload("res://tools/i18n/i18n_scan.gd")
const EN_PATH: String = "res://translations/scandig.en.translation"

var _placeholder: RegEx = RegEx.create_from_string("%[-+ 0-9.]*[sdifxXc%]")
var _action_tag: RegEx = RegEx.create_from_string("\\{[a-z_0-9]+\\}|\\[[A-Z]\\]|\\[/?(b|i|u|s|color|font_size|center|right|url|img|wave|shake|rainbow|outline_size|outline_color|code|font)(=[^\\]]*)?\\]")


func _tokens(regex: RegEx, text: String) -> Array[String]:
	var out: Array[String] = []
	for m: RegExMatch in regex.search_all(text):
		out.append(m.get_string())
	out.sort()
	return out


func test_csv_is_well_formed() -> void:
	var file: FileAccess = FileAccess.open(SCAN.CSV_PATH, FileAccess.READ)
	assert_not_null(file, "translations/scandig.csv existe")
	if file == null:
		return
	assert_eq(Array(file.get_csv_line()), ["keys", "pt_BR", "en"], "cabeçalho")
	var lines: int = 0
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() == 1 and line[0].is_empty():
			continue
		assert_eq(line.size(), 3, "linha %d com 3 colunas (a Godot para de ler na primeira errada)" % (lines + 2))
		lines += 1
	var rows: Dictionary = SCAN.csv_rows()
	assert_eq(rows.size(), lines, "sem chave repetida")
	var bad: Array[String] = []
	for key: String in rows.keys():
		var row: Dictionary = rows[key]
		if str(row["pt_BR"]) != key:
			bad.append("pt_BR difere da chave: %s" % key.c_escape())
		if str(row["en"]).strip_edges().is_empty():
			bad.append("sem inglês: %s" % key.c_escape())
		if _tokens(_placeholder, key) != _tokens(_placeholder, str(row["en"])):
			bad.append("%%s/%%d diferentes: %s -> %s" % [key.c_escape(), str(row["en"]).c_escape()])
		if _tokens(_action_tag, key) != _tokens(_action_tag, str(row["en"])):
			bad.append("{ação}/[E]/BBCode diferentes: %s -> %s" % [key.c_escape(), str(row["en"]).c_escape()])
	assert_eq(bad, [] as Array[String], "\n".join(bad))


## Todo texto visível de gameplay/, ui/, core/, items/ e world/ (literais dos .gd e campos de
## texto das .tscn/.tres, ver tools/i18n/i18n_scan.gd) é chave com inglês. Texto novo sem
## tradução: rode tools/i18n/missing.sh e ponha a linha no CSV (ou, se o jogador não vê, em
## translations/i18n_ignore.txt).
func test_every_visible_text_has_english() -> void:
	var rows: Dictionary = SCAN.csv_rows()
	var texts: Dictionary = SCAN.visible_texts()
	assert_gt(texts.size(), 500, "varreu os textos do jogo")
	var missing: Array[String] = []
	for key: String in texts.keys():
		if str((rows.get(key, {}) as Dictionary).get("en", "")).is_empty():
			missing.append("%s  %s" % [(texts[key] as Array)[0], key.c_escape()])
	assert_eq(missing, [] as Array[String], "%d texto(s) sem inglês (tools/i18n/missing.sh):\n%s" % [missing.size(), "\n".join(missing.slice(0, 40))])


## A varredura pega o que precisa: texto com espaço, acento ou pontuação entra; nome de nó, de
## tipo, caminho, id, SVG e mensagem "Classe: ..." do dev ficam de fora.
func test_scan_rules() -> void:
	for text: String in ["Loja", "Pegar a chave", "Espaço", "Mudo", "Vitória!", "%d itens", "Caranguejo-Rei"]:
		assert_true(SCAN.is_text(text), "texto: %s" % text)
	for code: String in ["rocks-sand-a", "res://ui/hud.tscn", "Panel/Label", "TabContainer/Expedições/Page",
			"Spot%d", "VBoxContainer", "FPS", "BossSlot_", "<svg width=\\\"24\\\">", "SaveManager: falhou", "x"]:
		assert_false(SCAN.is_text(code), "não é texto: %s" % code)
	var found: Array = SCAN.gd_literals("var a := \"Olá\"\n@export_group(\"Movimento\")\nnode.name = \"Pivot\"\nprint(\"dev\")\nvar b := &\"id\"\n")
	assert_eq(found, [[1, "Olá"]], "pula anotação, nome de nó, print e StringName")


## O importador da Godot lê o CSV igual ao csv_rows (aspas, quebras de linha): cada chave volta
## com o inglês do arquivo no .translation importado e pelo TranslationServer.
func test_imported_translation_matches_csv() -> void:
	var en: Translation = load(EN_PATH) as Translation
	assert_not_null(en, "scandig.en.translation importado")
	if en == null:
		return
	assert_true(TranslationServer.get_loaded_locales().has("en"), "inglês carregado pelo project.godot")
	assert_true(TranslationServer.get_loaded_locales().has("pt_BR"), "português carregado pelo project.godot")
	var rows: Dictionary = SCAN.csv_rows()
	var bad: Array[String] = []
	for key: String in rows.keys():
		if String(en.get_message(key)) != str(rows[key]["en"]):
			bad.append(key.c_escape())
	assert_eq(bad, [] as Array[String], "chaves que não voltam do .translation:\n%s" % "\n".join(bad))


func test_portuguese_is_the_default() -> void:
	assert_eq(SettingsManager.DEFAULTS[SettingsManager.GENERAL]["language"], "pt_BR")
	assert_eq(ProjectSettings.get_setting("internationalization/locale/fallback"), "pt_BR")
	assert_eq(TranslationServer.get_locale(), "pt_BR", "o jogo (e os testes) começam em PT-BR, qualquer que seja o idioma do sistema")
	assert_eq(SettingsManager.sanitize(SettingsManager.GENERAL, {})["language"], "pt_BR", "sem arquivo: PT-BR")
	assert_eq(SettingsManager.sanitize(SettingsManager.GENERAL, {"language": "fr"})["language"], "pt_BR", "idioma sem tradução: PT-BR")
	assert_eq(SettingsManager.sanitize(SettingsManager.GENERAL, {"language": 3})["language"], "pt_BR", "tipo errado: PT-BR")
	assert_eq(SettingsManager.sanitize(SettingsManager.GENERAL, {"language": "en"})["language"], "en")
