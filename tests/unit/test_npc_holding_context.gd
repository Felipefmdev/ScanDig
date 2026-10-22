extends GutTest

class HeldPlayer extends Node3D:
	var held_tool_id: String = ""

var npc: Node3D
var player: HeldPlayer

func before_each() -> void:
	var path: String = "res://gameplay/quests/quest_npc.gd"
	npc = (load(path) as Script).new()
	npc.set("quest_id", "ze_anzol")
	npc.set("holding_item_id", "concha_dourada,objetivo_exato")
	npc.set("reward_item_id", "concha_dourada")
	npc.set("line_holding", "PEDIDO_ESPECIFICO")
	npc.set("line_done", "MISSAO_CONCLUIDA")
	npc.set("line_ready", "OBJETIVO_JA_PRONTO")
	add_child_autofree(npc)
	npc.set_process(false)
	player = HeldPlayer.new()
	add_child_autofree(player)
	player.position = Vector3(0, 0, 2)

func _reaction(state: int, item: String) -> String:
	npc.set("state", state)
	npc.set("_say_left", 0.0)
	npc.set("_holding_cooldown_left", 0.0)
	npc.set("_was_holding_in_range", false)
	player.held_tool_id = item
	npc.call("_check_holding_reaction", 0.0, player)
	return (npc.get("_say_label") as Label3D).text if float(npc.get("_say_left")) > 0 else ""

func test_done_never_requests_reward_or_objective_again() -> void:
	for item: String in ["concha_dourada", "objetivo_exato", "alianca_ouro"]:
		assert_ne(_reaction(4, item), "PEDIDO_ESPECIFICO", item)
		assert_eq(_reaction(4, item), "MISSAO_CONCLUIDA", "DONE reaction keeps completed context")

func test_reward_and_family_never_masquerade_as_requested_object() -> void:
	for state: int in [0, 1, 2]:
		for item: String in ["concha_dourada", "alianca_ouro"]:
			assert_ne(_reaction(state, item), "PEDIDO_ESPECIFICO", "State %d / %s" % [state, item])
	assert_eq(_reaction(0, "objetivo_exato"), "PEDIDO_ESPECIFICO")
	assert_eq(_reaction(1, "objetivo_exato"), "PEDIDO_ESPECIFICO")
	assert_eq(_reaction(2, "objetivo_exato"), "OBJETIVO_JA_PRONTO")

func test_event_unrelated_item_distance_and_cooldown_preserved() -> void:
	assert_eq(_reaction(3, "objetivo_exato"), "")
	assert_eq(_reaction(1, "sem_relacao"), "")
	player.position = Vector3(0, 0, 5)
	assert_eq(_reaction(1, "objetivo_exato"), "")
	player.position = Vector3(0, 0, 2)
	assert_eq(_reaction(1, "objetivo_exato"), "PEDIDO_ESPECIFICO")
	npc.set("_say_left", 0.0)
	npc.call("_check_holding_reaction", 0.0, player)
	assert_eq(float(npc.get("_say_left")), 0.0)
