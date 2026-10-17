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
