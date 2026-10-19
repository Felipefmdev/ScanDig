extends RefCounted

## Varredura dos textos que o jogador vê (#131), usada pela guarda tests/dev_b/test_i18n_keys.gd e
## por tools/i18n/missing_keys.gd. A chave da tradução é o próprio texto em PT-BR (o texto-fonte):
## todo literal "com cara de texto" dos .gd e todo campo de texto exibido das .tscn/.tres precisa
## ser uma chave de translations/scandig.csv (com o inglês preenchido) ou estar em
## translations/i18n_ignore.txt (literal que o jogador não vê: nome de nó, de tipo do tema...).
##
## Fora da varredura: comentários, &"StringName", ^"NodePath", linhas de print/push_* e
## anotações (@export_group etc.), pastas tests/ e gameplay/debug/ (mensagens de bot) e os
## literais que não são texto: sem duas letras seguidas, com cara de id ("rocks-sand-a",
## "res://..."), caminho de nó ("Panel/Label"), nome com %d ("Spot%d"), CamelCase ("VBox"),
## SIGLA ("FPS") ou com _ / dígito / ":" sem espaço.

const ROOTS: Array[String] = ["res://gameplay", "res://ui", "res://core", "res://items", "res://world"]
## build_theme.gd é ferramenta (gera o .tres do tema), não tela.
const SKIP_PARTS: Array[String] = ["/tests/", "res://gameplay/debug/", "res://ui/theme/build_theme.gd"]
const CSV_PATH: String = "res://translations/scandig.csv"
const IGNORE_PATH: String = "res://translations/i18n_ignore.txt"
## Campos de texto exibido das .tscn/.tres (line_* é prefixo: falas de NPC). Mesmos do
## test_ptbr_texts.gd.
const RESOURCE_KEYS: Array[String] = ["text", "display_name", "description", "prompt", "say_text",
	"npc_name", "event_name", "defend_name", "fail_text", "success_text", "progress_text", "seen_text",
	"label_text", "tooltip_text", "placeholder_text", "dialog_text", "ok_button_text",
	"cancel_button_text", "title"]
## Linhas que só o dev vê ou que só nomeiam nós/grupos.
const SKIP_LINE_MARKS: Array[String] = ["print(", "printerr(", "print_debug(", "push_warning(", "push_error(",
	"print_rich(", "assert(", "get_node(", "get_node_or_null(", "has_node(", "find_child("]

static var _id_like: RegEx = RegEx.create_from_string("^[a-z0-9_./:%-]*$")
static var _letters: RegEx = RegEx.create_from_string("[A-Za-zÀ-ÿ]{2}")
static var _ascii_word: RegEx = RegEx.create_from_string("^[A-Za-z0-9_./:%#@$-]*$")
static var _code_marks: RegEx = RegEx.create_from_string("[_/0-9:%]|[a-z][A-Z]|^[A-Z]{2,}$")
static var _dev_prefix: RegEx = RegEx.create_from_string("^[A-Z][a-z]+[A-Z][A-Za-z]*: ")
static var _node_assign: RegEx = RegEx.create_from_string("(?<![A-Za-z0-9_])name\\s*=\\s*\"")
static var _resource_field: RegEx = RegEx.create_from_string("(?m)^([A-Za-z_][A-Za-z0-9_/]*) = \"((?:[^\"\\\\]|\\\\.)*)\"")


## Literal com cara de texto exibido (não id, não nome de nó/tipo).
static func is_text(literal: String) -> bool:
	if _id_like.search(literal) != null or _letters.search(literal) == null:
		return false
	if not literal.contains(" ") and literal.contains("/"):
		return false  # caminho de nó com acento ("TabContainer/Expedições/MapList")
	if literal.contains("=\\\"") or literal.contains("=\""):
		return false  # marcação com atributo (SVG dos ícones, linhas de .tscn)
	if _dev_prefix.search(literal) != null:
		return false  # "SaveManager: ..." (mensagem do dev, com o nome da classe na frente)
	if _ascii_word.search(literal) != null and _code_marks.search(literal) != null:
		return false
	return true


static func _skip_line(line: String) -> bool:
	var trimmed: String = line.strip_edges()
	if trimmed.begins_with("@") or trimmed.begins_with("class_name") or trimmed.begins_with("extends"):
		return true
	for mark: String in SKIP_LINE_MARKS:
		if line.contains(mark):
			return true
	return _node_assign.search(line) != null


## Literais entre aspas de um .gd, fora de comentários; pula &"..." e ^"..." e as linhas de
## _skip_line. Cada item: [linha, texto como está no fonte (com os escapes)].
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
			if prefix != "&" and prefix != "^" and not _skip_line(lines[start_line - 1]):
				out.append([start_line, buf])
			i = j + quote.length()
			continue
		i += 1
	return out


## Campos de texto exibido de uma .tscn/.tres. Cada item: [linha, texto com os escapes].
static func resource_texts(source: String) -> Array:
	var out: Array = []
	for m: RegExMatch in _resource_field.search_all(source):
		var key: String = m.get_string(1)
		var field: String = key.get_slice("/", key.get_slice_count("/") - 1)
		if RESOURCE_KEYS.has(field) or field.begins_with("line_"):
			out.append([source.count("\n", 0, m.get_start()) + 1, m.get_string(2)])
	return out


static func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if ["gd", "tscn", "tres"].has(file_name.get_extension()):
			out.append(dir_path.path_join(file_name))
	for sub: String in dir.get_directories():
		if not sub.begins_with("."):
			_collect(dir_path.path_join(sub), out)


static func _skipped(path: String) -> bool:
	for part: String in SKIP_PARTS:
		if path.contains(part):
			return true
	return false


## Literais ignorados (como estão no fonte, um por linha; "#" no começo = comentário).
static func ignored() -> Dictionary:
	var out: Dictionary = {}
	var text: String = FileAccess.get_file_as_string(IGNORE_PATH)
	for line: String in text.split("\n"):
		var entry: String = line.trim_suffix("\r")
		if entry.is_empty() or entry.begins_with("# "):
			continue
		out[entry] = true
	return out


## Texto visível -> ["arquivo:linha", ...]. A chave já vem sem os escapes (c_unescape), como a
## Godot a vê em tempo de execução.
static func visible_texts() -> Dictionary:
	var files: Array[String] = []
	for root: String in ROOTS:
		_collect(root, files)
	var skip: Dictionary = ignored()
	var out: Dictionary = {}
	for path: String in files:
		if _skipped(path):
			continue
		var source: String = FileAccess.get_file_as_string(path)
		var gd: bool = path.ends_with(".gd")
		var texts: Array = gd_literals(source) if gd else resource_texts(source)
		for entry: Array in texts:
			var raw: String = str(entry[1])
			if skip.has(raw) or raw.strip_edges().is_empty():
				continue
			if gd and not is_text(raw):
				continue
			var key: String = raw.c_unescape()
			if not out.has(key):
				out[key] = []
			(out[key] as Array).append("%s:%d" % [path, int(entry[0])])
	return out


## Linhas do CSV: chave -> {"pt_BR": ..., "en": ...} (lido como a Godot lê: get_csv_line, e os
## valores com c_unescape).
static func csv_rows() -> Dictionary:
	var out: Dictionary = {}
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return out
	var header: PackedStringArray = file.get_csv_line()
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() != header.size():
			break
		var row: Dictionary = {}
		for col: int in range(1, header.size()):
			row[header[col]] = line[col].c_unescape()
		out[line[0]] = row
	return out
