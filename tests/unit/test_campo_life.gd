class_name TestCampoLife
extends GutTest

## Testes unitários para a vida reativa do Campo Antigo (Issue #98):
## animais que fogem e deixam achados/comida, árvores que largam frutos ao golpe da pá,
## e rajadas de vento na seara que inclinam o trigo e revelam sinal metálico.

const CampoLifeScript = preload("res://gameplay/quests/campo/campo_life.gd")

var world: Node3D
var life: CampoLife


func before_each() -> void:
	world = Node3D.new()
	add_child_autofree(world)
	var pickups: PickupsRoot = PickupsRoot.new()
	world.add_child(pickups)
	life = CampoLifeScript.new()
	world.add_child(life)


func test_campo_secrets_scene_wires_campo_life() -> void:
	var secrets: Node3D = (load("res://gameplay/quests/campo/campo_secrets.tscn") as PackedScene).instantiate() as Node3D
	add_child_autofree(secrets)
	var node: CampoLife = secrets.get_node_or_null(^"CampoLife") as CampoLife
	assert_not_null(node, "campo_secrets.tscn deve conter o nó CampoLife")
	assert_gt(node.animals.size(), 0, "CampoLife deve criar animais pacíficos")
	assert_gt(node.trees.size(), 0, "CampoLife deve criar árvores sacudíveis")
	assert_gt(node.wheat_stalks.size(), 0, "CampoLife deve criar feixes de trigo na seara")


func test_animals_flee_from_nearby_disturbance_and_drop_loot() -> void:
	var a0: Dictionary = life.animals[0]
	var node0: Node3D = a0["node"] as Node3D
	var start_pos: Vector3 = node0.global_position

	# Barulho longe (> 6 m) não assusta
	var far_spooked: int = life.spook_animals_near(start_pos + Vector3(12.0, 0.0, 0.0), true)
	assert_eq(far_spooked, 0, "Distúrbio longe (> 6 m) não deve assustar o animal")

	# Corrida/escavação perto (<= 6 m) assusta e faz cair comida/achado
	var dropped: ItemPickup = life.spook_animal(0, start_pos + Vector3(-2.0, 0.0, 0.0), 0.1)
	assert_not_null(dropped, "Animal assustado com roll < flee_drop_chance deve largar ItemPickup")
	assert_not_null(dropped.carried, "ItemPickup largado pelo animal deve ter CarriedItem válido")
	assert_gt(float(life.animals[0]["flee_left"]), 0.0, "Animal deve entrar em estado de fuga")

	# Avança o tempo e verifica que o animal se afastou da origem do susto
	life._process(1.2)
	assert_gt(node0.global_position.distance_to(start_pos), 1.5, "Animal em fuga deve deslocar-se pelo campo")


func test_tree_shake_on_shovel_hit_drops_fruit_and_respects_cooldown() -> void:
	var t0: Dictionary = life.trees[0]
	var tree_pos: Vector3 = t0["pos"]
	var player_pos: Vector3 = tree_pos + Vector3(0.0, 0.0, 2.0)
	var forward: Vector3 = (tree_pos - player_pos).normalized()

	var hit_idx: int = life.hit_tree_at(player_pos, forward)
	assert_eq(hit_idx, 0, "Golpe de pá em frente à árvore deve atingir a árvore 0")
	assert_eq(int(life.trees[0]["drops"]), 1, "Árvore sacudida deve contabilizar 1 drop")
	assert_gt(float(life.trees[0]["cooldown"]), 0.0, "Árvore deve entrar em cooldown após largar fruto/ninho")

	# Durante o cooldown não larga outro fruto
	var second_try: ItemPickup = life.shake_tree(0)
	assert_null(second_try, "Árvore em cooldown não deve largar segundo fruto")

	# Após o cooldown, novo golpe larga outro fruto/relíquia
	life._process(life.tree_cooldown + 0.5)
	var after_cd: ItemPickup = life.shake_tree(0)
	assert_not_null(after_cd, "Após o cooldown a árvore deve voltar a largar fruto/ninho")


func test_wind_gust_bends_wheat_and_reveals_metallic_signal() -> void:
	assert_false(life.is_wind_gust_active(), "Sem rajada ativa no início")

	var glint_pos: Vector3 = life.trigger_wind_gust(Vector3(16.4, 0.0, -14.2))
	assert_true(life.is_wind_gust_active(), "trigger_wind_gust deve ativar a rajada de vento")
	assert_almost_eq(glint_pos.x, 16.4, 0.01)
	assert_true(life._glint_node.visible, "Brilho metálico na seara deve ficar visível durante a rajada")
	assert_not_null(life._wheat_spot, "Rajada na seara deve garantir um BuriedSpot metálico escondido no trigo")

	var stalk0: Node3D = life.wheat_stalks[0]
	assert_gt(absf(stalk0.rotation.z) + absf(stalk0.rotation.x), 0.2, "Feixes de trigo devem inclinar-se com o vento")

	# Depois de passar a duração da rajada, o brilho esconde-se
	life._process(life.gust_duration + 0.2)
	assert_false(life.is_wind_gust_active(), "Rajada deve terminar após gust_duration")
	assert_false(life._glint_node.visible, "Brilho metálico deve esconder-se quando o vento acalma")
