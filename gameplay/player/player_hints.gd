extends RefCounted

## Dicas de primeira vez (uma por id, por jogador). Ficam em user:// à parte do save do
## mundo e das opções: valem para todos os saves deste computador.

const PATH: String = "user://scandig_hints.cfg"
const SECTION: String = "seen"
## Caminho trocável nos testes; no Engine porque o GUT recarrega scripts.
const PATH_META: StringName = &"scandig_hints_path"

const TEXTS: Dictionary = {
	"first_pickup": "💡 Procure o detector junto à base. Mire nele e use [{interact}] para coletar.",
	"first_equip": "💡 Selecione o slot do detector na mochila para começar a procurar sinais.",
	"first_scan": "💡 Caminhe com o detector equipado e observe o radar: um sinal indica um achado enterrado.",
	"first_signal": "💡 Encontrou um sinal! Aproxime-se: a leitura fica mais forte perto do achado.",
	"first_dig": "💡 Está perto do achado: use [{careful_dig}] para cavar. Depois mire no objeto e colete com [{interact}].",
	"first_delivery": "💡 Há um achado na mochila. Volte ao ponto de entrega da base e use [{interact}]; suas ferramentas ficam com você.",
	"hunger": "💡 Com fome? Cave fora dos sinais: às vezes sai comida. Segure o clique com ela na mão para comer (um golpe interrompe).",
	"throw": "💡 Segure [{drop}] para arremessar o item: rápido, ele machuca os bichos.",
	"dynamite": "💡 Dinamite: clique para lançar. A explosão também acerta você: afaste-se!",
	"seagull": "💡 Gaivotas roubam itens do chão e da mochila. Derrube a gaivota para recuperar.",
	"wear": "💡 As armas se gastam com o uso. Quando quebrarem, compre outra na banca.",
}


## A etapa atual vence as anteriores; nunca orientar a voltar para uma etapa já vista.
## Só consulta o estado: take() continua sendo quem consome a dica, respeitando opções.
static func first_cycle_hint(has_detector: bool, equipped: bool, has_signal: bool, can_dig: bool, loot_count: int, completed: bool) -> String:
	if completed:
		return ""
	var stages: Array[String] = ["first_pickup", "first_equip", "first_scan", "first_signal", "first_dig", "first_delivery"]
	var stage: int = 0
	if loot_count > 0:
		stage = 5
	elif has_detector:
		stage = 1
		if equipped:
			stage = 2
			if has_signal:
				stage = 4 if can_dig else 3
	for i: int in range(stage, stages.size()):
		if has_seen(stages[i]):
			return ""
	return stages[stage]


static func set_hints_path(p: String) -> void:
	Engine.set_meta(PATH_META, p)


static func hints_path() -> String:
	if Engine.has_meta(PATH_META):
		return str(Engine.get_meta(PATH_META))
	return TEST_PATH if _running_tests() else PATH


const TEST_PATH: String = "user://test_saves/hints_test.cfg"


## GUT, testes headless (*_test.gd) e bots (--bot=): nunca tocar nas dicas reais do jogador.
static func _running_tests() -> bool:
	for a: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
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
	return InputDevice.fill_action_labels(TranslationServer.translate(text))
