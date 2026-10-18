extends GutTest

## Guarda contra mojibake (texto UTF-8 lido como Latin-1/cp1252 e gravado de novo), como o
## "Larva T\u00c3\u00a9rmica" que apareceu na hotbar. Percorre os .gd/.tres/.tscn/.json de items,
## gameplay, ui, core e world e falha listando arquivo:linha. Padrões (montados por código para o
## próprio teste não casar):
##   - "Ã" + byte de continuação (U+0080..U+00BF) ou o caractere cp1252 de 0x80..0x9F
##     (Ã© Ã¡ Ã­ Ãº Ã£ Ã§ Ã³ Ãª Ã¢ Ãµ Ã‰ Ã“...): nenhuma palavra portuguesa tem "Ã" seguido disso
##     (NÃO, MÃE, ANCIÃ têm letra, espaço ou aspas depois);
##   - "Â" + U+00A0..U+00BF (Âº Â° Â« Â· e o NBSP): "Â" legítimo vem antes de letra (ÂNCORA);
##   - "â€" (aspas/travessões quebrados).

const ROOTS: Array[String] = ["res://items", "res://gameplay", "res://ui", "res://core", "res://world"]
const EXTENSIONS: Array[String] = ["gd", "tres", "tscn", "json"]
## Caracteres cp1252 de 0x80..0x9F (o que o Windows mostra no lugar do 2.º byte UTF-8).
const CP1252_HIGH: Array[int] = [0x20AC, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6,
	0x2030, 0x0160, 0x2039, 0x0152, 0x017D, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
	0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x017E, 0x0178]


static func is_mojibake_pair(first: int, second: int) -> bool:
	if first == 0xC3:
		return (second >= 0x80 and second <= 0xBF) or CP1252_HIGH.has(second)
	if first == 0xC2:
		return second >= 0xA0 and second <= 0xBF
	if first == 0xE2:
		return second == 0x20AC
	return false


static func line_has_mojibake(line: String) -> bool:
	for i: int in line.length() - 1:
		if is_mojibake_pair(line.unicode_at(i), line.unicode_at(i + 1)):
			return true
	return false


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if EXTENSIONS.has(file_name.get_extension()):
			out.append(dir_path.path_join(file_name))
	for sub: String in dir.get_directories():
		if not sub.begins_with("."):
			_collect(dir_path.path_join(sub), out)


func test_detector_patterns() -> void:
	var a_tilde: String = char(0xC3)
	assert_true(line_has_mojibake("Larva T" + a_tilde + char(0xA9) + "rmica"), "é quebrado")
	assert_true(line_has_mojibake("Tatu" + a_tilde + char(0xAD) + "ra"), "í quebrado")
	assert_true(line_has_mojibake(a_tilde + char(0x2030) + "poca"), "É quebrado (cp1252)")
	assert_true(line_has_mojibake("n" + char(0xC2) + char(0xBA) + " 1"), "º quebrado")
	assert_true(line_has_mojibake(char(0xE2) + char(0x20AC) + char(0x201D)), "travessão quebrado")
	for ok: String in ["N" + a_tilde + "O", "M" + a_tilde + "E", "ANCI" + a_tilde + " ", "\"ANCI" + a_tilde + "\"",
			char(0xC2) + "NCORA", char(0xC2) + "mbito", char(0xC2) + char(0x2022), "Larva Térmica", "Tatuíra",
			"ação", "à", "º", "—"]:
		assert_false(line_has_mojibake(ok), "legítimo: %s" % ok)


func test_project_text_has_no_mojibake() -> void:
	var files: Array[String] = []
	for root: String in ROOTS:
		_collect(root, files)
	assert_gt(files.size(), 100, "varreu os arquivos do projeto")
	var hits: Array[String] = []
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		var lines: PackedStringArray = text.split("\n")
		for i: int in lines.size():
			if line_has_mojibake(lines[i]):
				hits.append("%s:%d" % [path, i + 1])
	assert_eq(hits, [] as Array[String], "mojibake em: %s" % ", ".join(hits))
