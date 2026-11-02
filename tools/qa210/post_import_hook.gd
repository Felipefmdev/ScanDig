extends "res://addons/gut/hook_script.gd"

## QA somente: valida readiness antes do único script; sem fixtures, asserts ou await.
const RESOURCES: Array[String] = ["res://addons/gut/fonts/AnonymousPro-Regular.ttf", "res://addons/gut/fonts/CourierPrime-Regular.ttf", "res://addons/gut/gui/arrow.png", "res://addons/gut/gui/play.png", "res://addons/gut/images/green.png", "res://addons/gut/images/red.png", "res://addons/gut/images/yellow.png", "res://ui/theme/fonts/Kalam-Bold.ttf", "res://ui/theme/fonts/PatrickHand-Regular.ttf", "res://ui/theme/icons/arrow_down.png", "res://ui/theme/icons/radio_checked.png", "res://ui/theme/icons/radio_unchecked.png", "res://ui/theme/icons/slider_grabber.png", "res://ui/theme/icons/slider_grabber_disabled.png", "res://ui/theme/icons/slider_grabber_hover.png", "res://ui/theme/paper_worn.png"]
const CSV: String = "res://translations/scandig.csv"
var _report: Dictionary = {"schema": "qa210-post-import-v1", "valid": false, "errors": [], "resources": [], "translations": []}


func run() -> void:
	for path: String in RESOURCES:
		var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		_report["resources"].append({"path": path, "loaded": resource != null})
		if resource == null:
			_report["errors"].append("Resource not loadable after import: " + path)
	var csv: FileAccess = FileAccess.open(CSV, FileAccess.READ)
	if csv == null:
		_report["errors"].append("CSV cannot be opened")
	else:
		var header: PackedStringArray = csv.get_csv_line(",")
		if header != PackedStringArray(["keys", "pt_BR", "en"]):
			_report["errors"].append("Unexpected CSV locale header")
		else:
			var expected: Array[Dictionary] = [{}, {}]
			while not csv.eof_reached():
				var row: PackedStringArray = csv.get_csv_line(",")
				if row.is_empty() or row[0].is_empty():
					continue
				if row.size() != 3:
					_report["errors"].append("Malformed CSV row: " + row[0])
					continue
				for index: int in range(2):
					expected[index][row[0]] = row[index + 1].c_unescape()
			for index: int in range(2):
				var locale: String = header[index + 1]
				var path: String = "res://translations/scandig." + locale + ".translation"
				var translation: Translation = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Translation
				var checked: int = 0
				if translation == null or translation.get_locale() != locale:
					_report["errors"].append("Missing/incorrect generated locale: " + locale)
				else:
					for key: String in expected[index]:
						if translation.get_message(key) != str(expected[index][key]):
							_report["errors"].append("CSV/translation mismatch: " + locale + ":" + key)
						checked += 1
				_report["translations"].append({"path": path, "locale": locale, "checked_keys": checked, "sha256": FileAccess.get_sha256(path).to_upper()})
		csv.close()
	_report["csv_sha256"] = FileAccess.get_sha256(CSV).to_upper()
	_report["valid"] = _report["errors"].is_empty()
	var output_path: String = OS.get_environment("QA210_POSTIMPORT_REPORT")
	var output: FileAccess = FileAccess.open(output_path, FileAccess.WRITE) if not output_path.is_empty() else null
	if output != null:
		output.store_string(JSON.stringify(_report, "\t"))
		output.close()
	if not bool(_report["valid"]) or output == null:
		push_error("QA210 post-import validation failed; target tests aborted")
		set_exit_code(70)
		abort()
