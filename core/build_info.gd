class_name BuildInfo
extends RefCounted

## Versão do jogo (#138). A fonte única é `application/config/version` no project.godot;
## o export_presets.cfg segue a mesma (tools/sync_version.sh, conferido no GUT).
## O commit vem de res://build_info.json, gerado no CI antes do export
## (tools/write_build_info.sh) e fora do git: sem ele (rodando do editor) é "dev".
## Nada de git em runtime.

const DEFAULT_VERSION: String = "0.1.0"
const INFO_PATH: String = "res://build_info.json"
const DEV_COMMIT: String = "dev"


## "0.1.0".
static func version() -> String:
	var value: String = str(ProjectSettings.get_setting("application/config/version", ""))
	return value if not value.is_empty() else DEFAULT_VERSION


## Hash curto do commit do build, ou "dev" sem o build_info.json.
static func commit() -> String:
	if not FileAccess.file_exists(INFO_PATH):
		return DEV_COMMIT
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(INFO_PATH))
	if data is Dictionary and str(data.get("commit", "")) != "":
		return str(data["commit"])
	return DEV_COMMIT


## O que a tela inicial mostra: "v0.1.0" no release e "v0.1.0 (a1b2c3d)" no debug.
static func display_text() -> String:
	return format_display(version(), commit(), OS.is_debug_build())


static func format_display(game_version: String, build_commit: String, debug: bool) -> String:
	var text: String = "v" + game_version
	return "%s (%s)" % [text, build_commit] if debug else text


## "0.1.0" -> "0.1.0.0", o formato a.b.c.d do file_version/product_version do .exe.
static func windows_version(game_version: String) -> String:
	var parts: PackedStringArray = game_version.split(".")
	while parts.size() < 4:
		parts.append("0")
	return ".".join(parts)
