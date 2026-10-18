extends GutTest

## Falas do Mapa do Tesouro (#115): QuestNpc.line_map_hint. Regra: no DONE, enquanto faltar
## fragmento, alterna com line_done (a dica primeiro); com o mapa completo, só line_done.

const SCENES: Dictionary = {
	"Zé": "res://gameplay/quests/praia/praia_secrets.tscn",
	"Dona Lurdes": "res://gameplay/quests/campo/campo_secrets.tscn",
	"Arqueóloga Inês": "res://gameplay/quests/ruinas/ruinas_secrets.tscn",
	"Velho Björn": "res://gameplay/quests/geleira/geleira_secrets.tscn",
	"Dra. Vega": "res://gameplay/quests/cratera/cratera_secrets.tscn",
}
## O tesouro da ilha é um chefe disfarçado: nenhuma dica pode contar.
const SPOILERS: Array[String] = ["monstro", "colosso", "chefe", "vivo", "disfarç", "acorda"]


func before_each() -> void:
	GameState.instance.reset_state()


func after_each() -> void:
	GameState.instance.reset_state()


func _npc() -> QuestNpc:
	var npc: QuestNpc = QuestNpc.new()
	npc.npc_name = "Teste"
	npc.line_done = "obrigado"
	npc.line_map_hint = "dica do mapa"
	add_child_autofree(npc)
	npc.set_state(QuestNpc.QuestState.DONE)
	return npc


func _talk(npc: QuestNpc) -> String:
	npc._on_interact(HostSync.local_peer(npc))
	return npc._say_label.text


func test_done_alternates_hint_first() -> void:
	var npc: QuestNpc = _npc()
	assert_eq(_talk(npc), "dica do mapa", "1ª conversa depois da missão: a dica")
	assert_eq(_talk(npc), "obrigado")
	assert_eq(_talk(npc), "dica do mapa")


func test_full_map_only_done_line() -> void:
	var npc: QuestNpc = _npc()
	var all_frags: Array[String] = GameState.MAP_FRAGMENT_IDS.duplicate()
	GameState.instance.map_fragments = all_frags
	assert_true(GameState.instance.has_all_map_fragments())
	assert_eq(_talk(npc), "obrigado")
	assert_eq(_talk(npc), "obrigado")


func test_empty_hint_keeps_old_behaviour() -> void:
	var npc: QuestNpc = _npc()
	npc.line_map_hint = ""
	assert_eq(_talk(npc), "obrigado")
	assert_eq(_talk(npc), "obrigado")


func test_other_states_ignore_hint() -> void:
	var npc: QuestNpc = _npc()
	npc.line_active = "ainda à espera"
	npc.set_state(QuestNpc.QuestState.ACTIVE)
	assert_eq(_talk(npc), "ainda à espera")


func test_five_npcs_have_a_map_hint_without_spoiler() -> void:
	for npc_name: String in SCENES:
		var hint: String = _scene_hint(SCENES[npc_name], npc_name)
		assert_false(hint.is_empty(), "%s tem line_map_hint" % npc_name)
		for word: String in SPOILERS:
			assert_false(hint.to_lower().contains(word), "%s: sem spoiler (%s)" % [npc_name, word])


## line_map_hint do QuestNpc com esse npc_name, lido do PackedScene sem instanciar.
func _scene_hint(path: String, npc_name: String) -> String:
	var state: SceneState = (load(path) as PackedScene).get_state()
	for node: int in state.get_node_count():
		var props: Dictionary = {}
		for i: int in state.get_node_property_count(node):
			props[state.get_node_property_name(node, i)] = state.get_node_property_value(node, i)
		if props.get("npc_name", "") == npc_name:
			return String(props.get("line_map_hint", ""))
	return ""
