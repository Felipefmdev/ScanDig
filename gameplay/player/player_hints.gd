extends RefCounted

## Dicas de primeira vez (uma por id, por jogador). Ficam em user:// à parte do save do
## mundo e das opções: valem para todos os saves deste computador.

const PATH: String = "user://scandig_hints.cfg"
const SECTION: String = "seen"
## Caminho trocável nos testes; no Engine porque o GUT recarrega scripts.
const PATH_META: StringName = &"scandig_hints_path"

const TEXTS: Dictionary = {
	"hunger": "💡 Com fome? Cave fora dos sinais: às vezes sai comida. Segure o clique com ela na mão para comer (um golpe interrompe).",
	"throw": "💡 Segure [{drop}] para arremessar o item: rápido, ele machuca os bichos.",
	"dynamite": "💡 Dinamite: clique para lançar. A explosão também te acerta: afaste-se!",
	"seagull": "💡 Gaivotas roubam itens do chão e da mochila. Derrube-a para recuperar.",
	"wear": "💡 As armas se gastam com o uso. Quando partirem, compre outra na banca.",
}


static func set_hints_path(p: String) -> void:
	Engine.set_meta(PATH_META, p)


static func hints_path() -> String:
	if Engine.has_meta(PATH_META):
		return str(Engine.get_meta(PATH_META))
	return TEST_PATH if _running_tests() else PATH


const TEST_PATH: String = "user://test_saves/hints_test.cfg"


## GUT, testes headless (*_test.gd) e bots (--bot=): nunca tocar nas dicas reais do jogador.
static func _running_tests() -> bool:
	for a: String in OS.get_cmdline_args():
		if a.contains("gut_cmdln") or a.ends_with("_test.gd") or a.contains("/tests/") or a.begins_with("--bot="):
			return true
	return false


static func has_seen(id: String) -> bool:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(hints_path()) != OK:
		return false
	return bool(cfg.get_value(SECTION, id, false))


## Marca como vista e devolve o texto, ou "" se já tinha sido mostrada (ou id desconhecido).
## Com "Mostrar dicas" desligado devolve "" sem marcar: a dica aparece quando religar.
static func take(id: String) -> String:
	var sm: SettingsManager = SettingsManager.instance
	if sm != null and sm.get_value(SettingsManager.GAMEPLAY, "show_hints") == false:
		return ""
	if not TEXTS.has(id) or has_seen(id):
		return ""
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(hints_path())
	cfg.set_value(SECTION, id, true)
	cfg.save(hints_path())
	return fill(str(TEXTS[id]))


## "Rever dicas" (Configurações > Jogabilidade): todas voltam a aparecer uma vez.
static func reset_all() -> void:
	if FileAccess.file_exists(hints_path()):
		DirAccess.remove_absolute(hints_path())


## "{drop}" e qualquer "{ação}" viram a tecla ou o botão do comando em uso (#102,
## InputDevice.action_label); sem o CoreSettings, os padrões do teclado ("Q").
static func fill(text: String) -> String:
	return InputDevice.fill_action_labels(text)
