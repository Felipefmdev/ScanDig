extends SceneTree

## Lista os textos visíveis sem tradução em inglês (#131). Uso:
##   godot --headless --path . --script res://tools/i18n/missing_keys.gd [-- <trecho do caminho>...]
## Cada linha: <arquivo:linha>\t<texto>. O texto entra em translations/scandig.csv (chave = o
## próprio PT-BR, coluna pt_BR igual, coluna en com a tradução) ou, se o jogador não o vê, em
## translations/i18n_ignore.txt (como está no fonte). Com trechos, só os textos que aparecem
## em algum arquivo com eles no caminho.

const SCAN: GDScript = preload("res://tools/i18n/i18n_scan.gd")


func _initialize() -> void:
	var filters: PackedStringArray = OS.get_cmdline_user_args()
	var rows: Dictionary = SCAN.csv_rows()
	var texts: Dictionary = SCAN.visible_texts()
	var missing: int = 0
	for key: String in texts.keys():
		if not str((rows.get(key, {}) as Dictionary).get("en", "")).is_empty():
			continue
		var where: Array = texts[key]
		if not filters.is_empty():
			where = where.filter(func(loc: String) -> bool:
				for part: String in filters:
					if loc.contains(part):
						return true
				return false)
			if where.is_empty():
				continue
		missing += 1
		print("%s\t%s" % [where[0], key.c_escape()])
	print("MISSING %d of %d" % [missing, texts.size()])
	quit()
