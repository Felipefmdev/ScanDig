extends GutTest

## Guarda do português do Brasil: o texto que o jogador vê não pode voltar a ter construções de
## Portugal. Varre os literais entre aspas dos .gd (fora de comentários, StringName e NodePath, e
## sem as linhas de print/push_warning/push_error, que só o dev vê) e os campos de texto das
## .tscn/.tres (text, display_name, description, prompt, say_text, line_*...) de gameplay, ui,
## core, items e world. Ficam de fora as pastas tests/ e gameplay/debug/ (mensagens de bot).
## Literal com cara de id (só minúsculas ASCII, dígitos e _-./:%, sem espaço: "rocks-sand-a",
## "res://...") não é texto exibido e fica de fora. O texto vai para minúsculas antes dos padrões:
##   - vocabulário: equipa, apanhar, bónus, ecrã, registar, ficheiro, detetor, connosco,
##     "aos bocados", "por esses sítios fora", algures, artefacto, arrefecer, "lá em baixo";
##   - "estar/andar/ficar a + infinitivo" (está a cavar → está cavando);
##   - ênclise com hífen (dá-lhe, leva-o, abre-se, encontrá-las). Decisão: pronome oblíquo com
##     hífen também sai do PT-BR culto ("pegá-lo", "recuperá-la") e o texto é reescrito ("pegue",
##     "leve até a base"). Ficam liberados só os imperativos com "você" que o Brasil usa assim
##     mesmo em avisos (ALLOWED_ENCLISIS: afaste-se, aproxime-se, prepare-se...);
##   - tratamento por "tu": teu/tua, contigo, vosso, tens, consegues, estiveres... e o pretérito
##     em -aste/-iste (chegaste, conseguiste; "existe", "triste", "contraste" etc. ficam de fora);
##   - acento de Portugal antes de m/n + vogal (bónus, harmónica, ténis): no Brasil é ô/ê.
## "Câmara" (a câmara selada) e "sítio" (sítio arqueológico) são PT-BR legítimos e ficam.

const ROOTS: Array[String] = ["res://gameplay", "res://ui", "res://core", "res://items", "res://world"]
const SKIP_PARTS: Array[String] = ["/tests/", "res://gameplay/debug/"]
## Chaves de texto exibido nas .tscn/.tres (line_* é prefixo: falas de NPC).
const RESOURCE_KEYS: Array[String] = ["text", "display_name", "description", "prompt", "say_text",
	"npc_name", "event_name", "defend_name", "fail_text", "success_text", "progress_text", "seen_text",
	"label_text", "tooltip_text", "placeholder_text", "dialog_text", "ok_button_text",
	"cancel_button_text", "title"]
const DEV_ONLY_CALLS: Array[String] = ["print(", "printerr(", "print_debug(", "push_warning(", "push_error(",
	"print_rich("]
const LETTER: String = "[a-zà-öø-ÿ]"
const ALLOWED_ENCLISIS: Array[String] = ["afaste-se", "aproxime-se", "prepare-se", "reagrupe-se",
	"esquente-se", "segure-se", "proteja-se"]
const TU_PAST_OK: Array[String] = ["haste", "triste", "existe", "resiste", "insiste", "consiste", "desiste",
	"contraste", "traste", "engaste", "afaste", "arraste", "desgaste", "gaste", "persiste", "assiste", "subsiste", "despiste", "baste", "viste"]

var _rules: Array[Dictionary] = []
var _id_like: RegEx = RegEx.create_from_string("^[a-z0-9_./:%-]*$")


func before_all() -> void:
	var nb: String = "(?<!%s)" % LETTER
	var na: String = "(?!%s)" % LETTER
	_add("vocabulário", nb + "(equipa|equipas|apanh" + LETTER + "*|bónus|ecrã|ecrãs|registar" + LETTER
		+ "*|ficheiro|ficheiros|detetor|detetores|connosco|algures|artefacto|artefactos|arrefec" + LETTER
		+ "*|telemóvel|autocarro|comboio)" + na)
	_add("expressão", "aos bocados|sítios fora|lá em baixo|ao pé d")
	_add("estar a + infinitivo", nb + "(está|estás|estão|estou|estamos|estava|estavam|estar|anda|andam|fica|ficam|continua|continuam) a "
		+ LETTER + "+(ar|er|ir)" + na)
	_add("ênclise", nb + LETTER + "+-(te|me|lhe|lhes|lo|la|los|las|mo|ma|mos|mas|o|a|os|as|se|nos|vos)" + na)
	_add("tratamento por tu", nb + "(teu|tua|teus|tuas|contigo|vosso|vossa|vossos|vossas|tens|queres|podes|consegues|ouves|encontras|estás|foste|estiveres|quiseres|precisares|ajudares|ouvires|abateres)" + na)
	_add("pretérito com tu", nb + LETTER + "+(aste|iste)" + na)
	_add("acento de Portugal", nb + LETTER + "*[óé][mn][aeiouáéíóú]" + LETTER + "*")


func _add(rule_name: String, pattern: String) -> void:
	var regex: RegEx = RegEx.create_from_string(pattern)
	assert_true(regex != null and regex.is_valid(), "regra '%s' compila" % rule_name)
	_rules.append({"name": rule_name, "regex": regex})


## Devolve "regra: trecho" de cada padrão de Portugal achado no texto (vazio = PT-BR ok).
func find_ptpt(text: String) -> Array[String]:
	var hits: Array[String] = []
	if _id_like.search(text) != null:
		return hits
	var lower: String = text.to_lower()
	for rule: Dictionary in _rules:
		for m: RegExMatch in (rule["regex"] as RegEx).search_all(lower):
			var found: String = m.get_string()
			if rule["name"] == "ênclise" and ALLOWED_ENCLISIS.has(found):
				continue
			if rule["name"] == "pretérito com tu" and TU_PAST_OK.has(found):
				continue
			hits.append("%s: %s" % [rule["name"], found])
	return hits


## Literais entre aspas de um .gd, fora de comentários; pula &"..." e ^"..." e as linhas de
## print/push_*. Cada item: [linha, texto].
static func gd_literals(source: String) -> Array:
	var out: Array = []
	var lines: PackedStringArray = source.split("\n")
	var i: int = 0
	var line_no: int = 1
	var n: int = source.length()
	while i < n:
		var c: String = source[i]
		if c == "\n":
			line_no += 1
			i += 1
			continue
		if c == "#":
			while i < n and source[i] != "\n":
				i += 1
			continue
		if c == "\"" or c == "'":
			var quote: String = c.repeat(3) if source.substr(i, 3) == c.repeat(3) else c
			var j: int = i + quote.length()
			var start_line: int = line_no
			var buf: String = ""
			while j < n and source.substr(j, quote.length()) != quote:
				if source[j] == "\\":
					buf += source.substr(j, 2)
					j += 2
					continue
				if source[j] == "\n":
					line_no += 1
				buf += source[j]
				j += 1
			var prefix: String = source[i - 1] if i > 0 else ""
			if prefix != "&" and prefix != "^" and not _is_dev_only(lines[start_line - 1]):
				out.append([start_line, buf])
			i = j + quote.length()
			continue
		i += 1
	return out


static func _is_dev_only(line: String) -> bool:
	for call: String in DEV_ONLY_CALLS:
		if line.contains(call):
			return true
	return false


## Campos de texto exibido de uma .tscn/.tres. Cada item: [linha, texto].
static func resource_texts(source: String) -> Array:
	var out: Array = []
	var regex: RegEx = RegEx.create_from_string("(?m)^([A-Za-z_][A-Za-z0-9_]*) = \"((?:[^\"\\\\]|\\\\.)*)\"")
	for m: RegExMatch in regex.search_all(source):
		var key: String = m.get_string(1)
		if RESOURCE_KEYS.has(key) or key.begins_with("line_"):
			out.append([source.count("\n", 0, m.get_start()) + 1, m.get_string(2)])
	return out


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if ["gd", "tscn", "tres"].has(file_name.get_extension()):
			out.append(dir_path.path_join(file_name))
	for sub: String in dir.get_directories():
		if not sub.begins_with("."):
			_collect(dir_path.path_join(sub), out)


func _skipped(path: String) -> bool:
	for part: String in SKIP_PARTS:
		if path.contains(part):
			return true
	return false


func test_patterns_catch_pt_pt() -> void:
	for bad: String in ["💰 Equipa: R$ 10", "[E] Apanhar a chave", "Bónus de 25%", "O ecrã treme",
			"Registar no Museu", "Ficheiro não encontrado", "Detetor de Metais", "Vem connosco",
			"um mapa partido aos bocados", "enterrados por esses sítios fora", "algures pelo gelo",
			"O chefe está a cansar-se", "alguém está a cavar demais", "Leva-o à base!", "Dá-lhe!",
			"O geodo abre-se", "Consegues encontrá-las?", "na tua mão", "quando estiveres pronto",
			"Foste derrubado", "Conseguiste!", "Encontraste o diário", "nota harmónica", "lá em baixo"]:
		assert_gt(find_ptpt(bad).size(), 0, "PT-PT pego: %s" % bad)


func test_patterns_allow_pt_br() -> void:
	for ok: String in ["Loja de Equipamentos", "💰 Equipe: R$ 10", "[E] Pegar a chave", "Afaste-se!",
			"Aproxime-se de um sinal", "Prepare-se... onda 1/3", "A câmara selada", "Fauna dos Sítios",
			"Já existe uma expedição em andamento.", "Alto contraste", "Detector nível 2", "Corvo-Rei",
			"Caranguejo-Rei", "à beira-mar", "alto-falantes", "Você conseguiu!", "Bônus de 25%",
			"Também", "A expedição está cavando", "fica a 8 m", "Você foi derrubado", "lá embaixo",
			"Registrar no Museu", "triste", "Estação da Dra. Vega", "rocks-sand-a"]:
		assert_eq(find_ptpt(ok), [] as Array[String], "PT-BR legítimo: %s" % ok)


func test_literal_extraction_skips_code_noise() -> void:
	var src: String = "# Equipa num comentário\nvar a := &\"equipa\"\nvar b := ^\"Apanhar\"\n" \
		+ "push_warning(\"ficheiro\")\nvar c := \"Pegar\" # apanhar\nvar d := \"x\\\"y\"\n"
	var found: Array = gd_literals(src)
	assert_eq(found.size(), 2, "só os literais exibíveis: %s" % [found])
	assert_eq(found[0], [5, "Pegar"])
	var res: Array = resource_texts("[node]\ntext = \"Olá\"\nname = \"Equipa\"\nline_offer = \"Toma\"\n")
	assert_eq(res, [[2, "Olá"], [4, "Toma"]])


func test_visible_text_is_pt_br() -> void:
	var files: Array[String] = []
	for root: String in ROOTS:
		_collect(root, files)
	assert_gt(files.size(), 100, "varreu os arquivos do projeto")
	var hits: Array[String] = []
	for path: String in files:
		if _skipped(path):
			continue
		var source: String = FileAccess.get_file_as_string(path)
		var texts: Array = gd_literals(source) if path.ends_with(".gd") else resource_texts(source)
		for entry: Array in texts:
			for hit: String in find_ptpt(str(entry[1])):
				hits.append("%s:%d %s" % [path, int(entry[0]), hit])
	assert_eq(hits, [] as Array[String], "texto de Portugal em:\n%s" % "\n".join(hits))
