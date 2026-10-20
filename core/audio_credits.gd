class_name AudioCredits
extends RefCounted

## Créditos dos sons por autor (#149), para a seção "Sons (CC0)" dos créditos (CreditsView).
## A fonte é a tabela de assets/audio/CREDITS.md, mas o .md não vai no export (*.md excluído):
## tools/gen_audio_credits.gd grava a lista em DATA_PATH (core/data/*.json vai no export) e o
## tests/dev_b/test_audio_credits.gd falha se ela ficar diferente do .md.
##
## Cada autor: {name, files, generated, works [{title, url}], recordings, contributors}. "Autor"
## é a coluna Autor separada por ";"; o que vem entre parênteses vira gravação ("gravação: X") ou,
## nos sons do projeto, quem gerou ("ScanDig (Dev B)"). A obra de um autor é o link da coluna
## Origem mais perto antes do nome dele (sem os do Freesound, que são a gravação original); se o
## nome não aparece lá, o primeiro link. Nos sons do projeto, as obras são os scripts tools/*.

const SOURCE_PATH: String = "res://assets/audio/CREDITS.md"
const DATA_PATH: String = "res://core/data/audio_credits.json"
const LICENSE: String = "CC0 1.0"
const LICENSE_URL: String = "https://creativecommons.org/publicdomain/zero/1.0/"
## Autor dos sons gerados por script no repositório.
const PROJECT_AUTHOR: String = "ScanDig"
const RECORDING_PREFIX: String = "gravação:"

static var _link: RegEx = RegEx.create_from_string("\\[([^\\]]+)\\]\\((https?://[^)\\s]+)\\)")
static var _tool: RegEx = RegEx.create_from_string("`(tools/[^`\\s]+)")


## Autores da tabela do CREDITS.md: os de fora por número de arquivos (depois o nome), os sons
## do projeto no fim.
static func parse_markdown(text: String) -> Array[Dictionary]:
	var by_name: Dictionary = {}
	for line: String in text.split("\n"):
		if not line.begins_with("| `"):
			continue
		var cells: PackedStringArray = line.strip_edges().trim_prefix("|").trim_suffix("|").split("|")
		if cells.size() < 4:
			continue
		var origin: String = cells[1].strip_edges()
		for part: String in cells[2].split(";"):
			_add_credit(by_name, part.strip_edges(), origin)
	var out: Array[Dictionary] = []
	for entry: Dictionary in by_name.values():
		out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["generated"] != b["generated"]:
			return not a["generated"]
		if a["files"] != b["files"]:
			return a["files"] > b["files"]
		return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
	return out


static func _add_credit(by_name: Dictionary, author: String, origin: String) -> void:
	if author.is_empty():
		return
	var name: String = author
	var note: String = ""
	var paren: int = author.find(" (")
	if paren > 0 and author.ends_with(")"):
		name = author.left(paren)
		note = author.substr(paren + 2, author.length() - paren - 3).strip_edges()
	if not by_name.has(name):
		by_name[name] = {"name": name, "files": 0, "generated": name == PROJECT_AUTHOR, "works": [],
			"recordings": [], "contributors": []}
	var entry: Dictionary = by_name[name]
	entry["files"] = int(entry["files"]) + 1
	if entry["generated"]:
		_append_unique(entry["contributors"], note)
		for m: RegExMatch in _tool.search_all(origin):
			_append_work(entry["works"], {"title": m.get_string(1), "url": ""})
		return
	if note.begins_with(RECORDING_PREFIX):
		_append_unique(entry["recordings"], note.trim_prefix(RECORDING_PREFIX).strip_edges())
	var work: Dictionary = _work_for(name, origin)
	if not work.is_empty():
		_append_work(entry["works"], work)


static func _work_for(name: String, origin: String) -> Dictionary:
	var links: Array[RegExMatch] = []
	for m: RegExMatch in _link.search_all(origin):
		if not m.get_string(2).contains("freesound.org"):
			links.append(m)
	if links.is_empty():
		return {}
	var chosen: RegExMatch = links[0]
	var at: int = origin.find(name)
	if at >= 0:
		for m: RegExMatch in links:
			if m.get_start() < at:
				chosen = m
	var title: String = chosen.get_string(1).trim_prefix(name + " — ")
	return {"title": title, "url": chosen.get_string(2)}


static func _append_work(works: Array, work: Dictionary) -> void:
	for w: Dictionary in works:
		if w["title"] == work["title"] and w["url"] == work["url"]:
			return
	works.append(work)


static func _append_unique(list: Array, value: String) -> void:
	if not value.is_empty() and not list.has(value):
		list.append(value)


## Texto do DATA_PATH para `authors` (o gerador grava, o teste compara).
static func to_json_text(authors: Array[Dictionary]) -> String:
	return JSON.stringify(authors, "\t") + "\n"


## Autores gravados em DATA_PATH ([] se faltar); "files" volta a int.
static func load_authors(path: String = DATA_PATH) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not parsed is Array:
		return out
	for item: Variant in parsed:
		if item is Dictionary:
			var entry: Dictionary = item
			entry["files"] = int(entry.get("files", 0))
			out.append(entry)
	return out


## URL sem o esquema, para mostrar ("kenney.nl/assets/rpg-audio").
static func short_url(url: String) -> String:
	return url.trim_prefix("https://").trim_prefix("http://").trim_suffix("/")
