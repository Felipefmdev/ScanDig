extends GutTest

## Testes unitários para o sistema de vida dos NPCs (How to Fish: respiração, olhar e boca)

const NPC_BODY := preload("res://gameplay/quests/npc_body.gd")
const QUEST_NPC := preload("res://gameplay/quests/quest_npc.gd")


func test_build_animated_face_creates_parts() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var head: Node3D = NPC_BODY.build_animated_face(root, Vector3(0, 1.3, 0), 0.15, Color.BLACK, 2)
	assert_not_null(head)
	assert_eq(head.name, "NpcHead")
	
	var pupils: Node3D = head.find_child("NpcPupils", true, false) as Node3D
	assert_not_null(pupils, "NpcPupils deve existir")
	
	var mouth: Node3D = head.find_child("NpcMouth", true, false) as Node3D
	assert_not_null(mouth, "NpcMouth deve existir")
	
	var eyes: MeshInstance3D = head.find_child("EyesWhite", true, false) as MeshInstance3D
	assert_not_null(eyes, "EyesWhite deve existir")


func test_quest_npc_life_animation() -> void:
	var npc: QuestNpc = QUEST_NPC.new()
	add_child_autofree(npc)
	var model: Node3D = Node3D.new()
	model.name = "Model"
	npc.add_child(model)
	
	# Adiciona cara animada ao modelo
	var head: Node3D = NPC_BODY.build_animated_face(model, Vector3(0, 1.3, 0), 0.15, Color.BLACK, 1)
	var mouth: Node3D = head.find_child("NpcMouth", true, false) as Node3D
	var pupils: Node3D = head.find_child("NpcPupils", true, false) as Node3D
	
	npc._ready()
	assert_not_null(npc._head_node)
	assert_not_null(npc._mouth_node)
	assert_not_null(npc._pupils_node)
	
	# Simula processo idle: respiração deve alterar a escala do modelo
	npc._process(0.5)
	assert_ne(model.scale.y, 1.0, "Respiração deve alterar a escala Y")
	
	# Simula fala (_say_left > 0): boca deve mexer
	npc.show_say("Olá explorador!", 3.0)
	assert_gt(npc._say_left, 0.0)
	npc._process(0.1)
	assert_ne(mouth.scale.y, 1.0, "Boca deve articular durante a fala")


class DummyPlayerWithItem extends Node3D:
	var held_item: String = ""
	var selected_slot: int = 3
	var toolbar_items: Array = [null, null, null, null, null]

	func get_selected_item():
		return toolbar_items[selected_slot]


func test_quest_npc_reacts_to_player_holding_quest_item() -> void:
	var npc: QuestNpc = QUEST_NPC.new()
	npc.quest_id = "praia_farol_1892"
	npc.holding_item_id = "lente_fresnel_1892"
	npc.line_holding = "A lente do farol! Traz cá!"
	add_child_autofree(npc)
	var model: Node3D = Node3D.new()
	model.name = "Model"
	npc.add_child(model)
	NPC_BODY.build_animated_face(model, Vector3(0, 1.3, 0), 0.15, Color.BLACK, 1)
	npc._ready()
	npc.global_position = Vector3.ZERO

	var player := DummyPlayerWithItem.new()
	player.add_to_group("player")
	add_child_autofree(player)

	var item_res := Resource.new()
	item_res.set_meta("id", "lente_fresnel_1892")
	player.toolbar_items[3] = {"id": "lente_fresnel_1892"}

	# Fora do alcance (> 4.0 m): não deve reagir
	player.global_position = Vector3(0, 0, 5.5)
	npc._check_holding_reaction()
	assert_eq(npc._say_left, 0.0, "NPC não deve reagir quando o jogador está a > 4 m")

	# Dentro do alcance (<= 4.0 m) com o item pedido na mão: reage e fala line_holding
	player.global_position = Vector3(0, 0, 3.2)
	npc._check_holding_reaction()
	assert_gt(npc._say_left, 0.0, "NPC deve falar ao ver o item pedido a <= 4 m")
	assert_eq(npc._say_label.text, "A lente do farol! Traz cá!")
	assert_gt(npc._holding_cooldown_left, 0.0, "Cooldown de reação deve ser ativado")

	# Durante o cooldown: não re-dispara imediatamente
	npc._say_left = 0.0
	npc._check_holding_reaction()
	assert_eq(npc._say_left, 0.0, "Cooldown deve impedir spam da fala")


func test_all_five_secrets_npcs_have_holding_reaction_configured() -> void:
	var scenes := [
		"res://gameplay/quests/praia/praia_secrets.tscn",
		"res://gameplay/quests/campo/campo_secrets.tscn",
		"res://gameplay/quests/ruinas/ruinas_secrets.tscn",
		"res://gameplay/quests/geleira/geleira_secrets.tscn",
		"res://gameplay/quests/cratera/cratera_secrets.tscn",
	]
	for path in scenes:
		var packed: PackedScene = load(path) as PackedScene
		assert_not_null(packed, "Cena deve carregar: %s" % path)
		var inst: Node = packed.instantiate()
		add_child_autofree(inst)
		var found_npc: QuestNpc = _find_quest_npc(inst)
		assert_not_null(found_npc, "QuestNpc deve existir em %s" % path)
		assert_ne(found_npc.holding_item_id, "", "holding_item_id configurado em %s" % path)
		assert_ne(found_npc.line_holding, "", "line_holding configurado em %s" % path)


func _find_quest_npc(node: Node) -> QuestNpc:
	if node is QuestNpc:
		return node as QuestNpc
	for child in node.get_children():
		var res := _find_quest_npc(child)
		if res != null:
			return res
	return null

