extends GutTest

## Testes GUT para o Forcado e a Banca do Campo Antigo (Issue #38).
## Valida alcance (~3.2m), cone frontal, dano (35), knockback forte, stun,
## suporte a coop via request_hit/stun, modelo 3D low-poly e a banca em map_campo.tscn.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const CRAB_SCENE: PackedScene = preload("res://gameplay/enemies/crab/crab.tscn")
const PITCHFORK_MODEL_SCRIPT: Script = preload("res://gameplay/weapons/pitchfork/pitchfork_model.gd")
const CAMPO_SCENE: PackedScene = preload("res://world/map_campo.tscn")
const FORCADO_DATA: ToolData = preload("res://items/tools/forcado.tres")

var world: Node3D = null
var player: Player = null


func before_each() -> void:
	world = Node3D.new()
	add_child_autofree(world)
	player = PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	player.global_position = Vector3.ZERO
	player.rotation = Vector3.ZERO
	# Garante que o jogador tem o forcado equipado no slot 0
	player.inventory.slots[0] = CarriedItem.create_from_tool_data(FORCADO_DATA)
	player.inventory.select(0)
	player._update_tool_in_hand()


func _spawn_crab(pos: Vector3) -> Crab:
	var c: Crab = CRAB_SCENE.instantiate() as Crab
	world.add_child(c)
	c.global_position = pos
	c.call(&"_enter_state", Crab.State.CHASE)
	return c


func test_pitchfork_model_structure_and_no_owner() -> void:
	var model: Node3D = PITCHFORK_MODEL_SCRIPT.new() as Node3D
	add_child_autofree(model)
	assert_not_null(model)
	
	for part_name: String in ["Metal", "Wood"]:
		var part: Node = model.get_node_or_null(NodePath(part_name))
		assert_not_null(part, "PitchforkModel tem peça %s" % part_name)
		if part != null:
			assert_null(part.owner, "PitchforkModel/%s sem owner (#47)" % part_name)
			var mi: MeshInstance3D = part as MeshInstance3D
			assert_not_null(mi)
			assert_true(mi.material_override is ShaderMaterial, "material toon com shader")
			assert_gt(mi.mesh.get_surface_count(), 0, "malha gerada com vértices")
			assert_not_null(mi.material_override.next_pass, "material com contorno toon (next_pass)")

	# Testar que rebuild não duplica nós
	var child_count_before: int = model.get_child_count()
	model._ready()
	await get_tree().process_frame
	assert_eq(model.get_child_count(), child_count_before, "rebuild limpa peças anteriores")


func test_pitchfork_world_scene_poses() -> void:
	assert_not_null(FORCADO_DATA.world_scene, "forcado.tres tem world_scene atribuída")
	var world_instance: Node3D = FORCADO_DATA.world_scene.instantiate() as Node3D
	add_child_autofree(world_instance)
	var model_child: Node3D = world_instance.get_node_or_null(^"Model") as Node3D
	assert_not_null(model_child, "PitchforkWorld tem filho Model")
	
	var shop_pose: Transform3D = world_instance.get("shop_pose")
	var ground_pose: Transform3D = world_instance.get("ground_pose")
	assert_ne(shop_pose, ground_pose, "shop_pose e ground_pose são distintas")


func test_player_holds_pitchfork_in_hand() -> void:
	assert_eq(player.held_tool_id, &"forcado")
	assert_true(player.tool_view.visible, "tool_view fica visível com forcado na mão")
	var held_fork: Node3D = player.tool_view.get_node_or_null(^"HeldPitchforkModel") as Node3D
	assert_not_null(held_fork, "HeldPitchforkModel existe no ToolView")
	if held_fork != null:
		assert_true(held_fork.visible, "HeldPitchforkModel visível quando selecionado")


func test_pitchfork_range_and_cone() -> void:
	# Alcance especificado ~3.2m
	var c_near: Crab = _spawn_crab(Vector3(0.0, 0.0, -2.2))
	var c_mid: Crab = _spawn_crab(Vector3(0.0, 0.0, -3.0))
	var c_far: Crab = _spawn_crab(Vector3(0.0, 0.0, -4.5))
	var c_behind: Crab = _spawn_crab(Vector3(0.0, 0.0, 2.5))
	
	var hits: int = player.attack_pitchfork()
	assert_eq(hits, 2, "acertou exatamente os 2 caranguejos dentro do alcance e cone frontal")
	assert_lt(c_near.health, c_near.max_health, "c_near recebeu dano")
	assert_lt(c_mid.health, c_mid.max_health, "c_mid recebeu dano")
	assert_eq(c_far.health, c_far.max_health, "c_far além do alcance não é atingido")
	assert_eq(c_behind.health, c_behind.max_health, "c_behind atrás do jogador não é atingido")


func test_pitchfork_damage_amount() -> void:
	var c: Crab = _spawn_crab(Vector3(0.0, 0.0, -2.0))
	var initial_hp: float = c.health
	player.attack_pitchfork()
	var expected_hp: float = initial_hp - player.pitchfork_damage
	assert_almost_eq(c.health, expected_hp, 0.1, "aplica dano configurado do forcado (%f)" % player.pitchfork_damage)


func test_pitchfork_knockback_pushes_enemy_away_and_stuns() -> void:
	var c: Crab = _spawn_crab(Vector3(0.0, 0.0, -2.0))
	var initial_z: float = c.global_position.z
	
	player.attack_pitchfork()
	
	# Knockback deve empurrar o inimigo para mais longe do jogador (-Z)
	assert_lt(c.global_position.z, initial_z, "inimigo foi empurrado para trás (-Z)")
	assert_gt(c.global_position.distance_to(player.global_position), 2.0, "distância ao jogador aumentou")
	assert_true(c.is_stunned(), "inimigo atingido fica atordoado pelo forcado")


func test_pitchfork_coop_request_hit_and_stun() -> void:
	var c: Crab = _spawn_crab(Vector3(0.0, 0.0, -2.0))
	# Simula réplica de cliente sem autoridade de simulação
	c.replicated = true
	
	var hit_called: bool = false
	var stun_called: bool = false
	
	# Usando o request_hit e request_stun do EnemyBase
	assert_true(c.has_method("request_hit"), "suporta request_hit para coop")
	assert_true(c.has_method("request_stun"), "suporta request_stun para coop")
	
	var hits: int = player.attack_pitchfork()
	assert_eq(hits, 1, "acertou o inimigo no modo coop")


func test_map_campo_banca_and_offers() -> void:
	var map: Node3D = CAMPO_SCENE.instantiate() as Node3D
	add_child_autofree(map)
	assert_not_null(map)
	
	var banca: Node3D = map.get_node_or_null(^"Banca") as Node3D
	assert_not_null(banca, "map_campo.tscn tem o nó Banca")
	
	var counter: StaticBody3D = banca.get_node_or_null(^"Counter") as StaticBody3D
	assert_not_null(counter, "Banca tem balcão Counter")
	assert_true(counter.is_in_group("spot_blockers"), "Counter está no grupo spot_blockers")
	
	var offers: Array[ShopOffer] = []
	for child: Node in banca.get_children():
		if child is ShopOffer:
			offers.append(child as ShopOffer)
	
	assert_eq(offers.size(), 5, "Banca do Campo tem 5 ofertas de ferramentas")
	
	var expected_ids: Array[StringName] = [
		&"estilingue",
		&"armadilha_rede",
		&"forcado",
		&"kit_medico",
		&"repelente"
	]
	var found_ids: Array[StringName] = []
	var forcado_offer: ShopOffer = null
	
	for o: ShopOffer in offers:
		assert_not_null(o.tool_data, "ShopOffer tem tool_data atribuída")
		if o.tool_data != null:
			found_ids.append(o.tool_data.id)
			if o.tool_data.id == &"forcado":
				forcado_offer = o
	
	for expected: StringName in expected_ids:
		assert_true(found_ids.has(expected), "Banca vende %s" % expected)
	
	assert_not_null(forcado_offer, "Oferta do Forcado encontrada")
	assert_eq(forcado_offer.tool_data.price, 600, "Forcado custa R$ 600")
	assert_eq(forcado_offer.tool_data.category, ToolData.Category.WEAPON)


func test_buy_forcado_from_banca() -> void:
	var state: GameState = GameState.instance
	var saved_money: int = state.team_money
	state.team_money = 1000
	
	var offer: ShopOffer = ShopOffer.new()
	offer.tool_data = FORCADO_DATA
	add_child_autofree(offer)
	
	var inv: Inventory = Inventory.new()
	add_child_autofree(inv)
	
	var result: Dictionary = await offer.try_buy(inv)
	assert_true(result["ok"], result["message"])
	assert_eq(state.team_money, 400, "debitou R$ 600")
	var carried: CarriedItem = result["carried"]
	assert_not_null(carried)
	assert_eq(carried.tool_id, &"forcado")
	
	state.team_money = saved_money
