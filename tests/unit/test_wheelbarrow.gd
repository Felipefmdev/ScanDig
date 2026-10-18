extends GutTest

## Testes unitários para o Carrinho de mão (#104).
## Cobre: transporte de achados (capacidade 5), redução de velocidade com peso,
## tombamento por ladeira forte ou impulso/explosão, derrame da carga com quebra de
## achados frágeis (#93), desvirar carrinho e entrega na base (SellPoint).

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const WHEELBARROW_SCRIPT: Script = preload("res://gameplay/objects/wheelbarrow/wheelbarrow.gd")

var _player: Player = null
var _wheelbarrow: CharacterBody3D = null


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(_player)

	_wheelbarrow = WHEELBARROW_SCRIPT.new() as CharacterBody3D
	add_child_autofree(_wheelbarrow)


func after_each() -> void:
	for n: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		if is_instance_valid(n):
			n.queue_free()


func _create_dummy_find(id: String = "moeda_antiga", fragility_val: float = 0.0) -> CarriedItem:
	var item_data: ItemData = ItemData.new()
	item_data.id = id
	item_data.display_name = "Achado Teste"
	item_data.base_value = 100
	item_data.fragility = fragility_val

	var carried: CarriedItem = CarriedItem.new()
	carried.item = item_data
	carried.final_value = 100
	carried.is_clean = true
	carried.integrity = 1.0
	return carried


func test_wheelbarrow_initial_state() -> void:
	assert_false(_wheelbarrow.is_tipped, "Carrinho deve começar em pé")
	assert_eq(_wheelbarrow.cargo.size(), 0, "Carga inicial deve ser 0")
	assert_eq(_wheelbarrow.MAX_CAPACITY, 5, "Capacidade máxima deve ser 5")
	assert_true(_wheelbarrow.can_add_item(), "Deve poder adicionar item quando vazio")
	assert_almost_eq(_wheelbarrow.get_push_speed_factor(), 0.85, 0.01, "Fator de velocidade vazio")


func test_add_and_remove_cargo() -> void:
	for i: int in 5:
		var find: CarriedItem = _create_dummy_find("item_%d" % i)
		assert_true(_wheelbarrow.add_item(find), "Deve aceitar item até o limite")

	assert_eq(_wheelbarrow.cargo.size(), 5, "Carrinho deve estar cheio com 5 itens")
	assert_false(_wheelbarrow.can_add_item(), "Não deve aceitar 6º item")

	# Velocidade reduzida com carrinho cheio
	assert_lt(_wheelbarrow.get_push_speed_factor(), 0.75, "Carrinho cheio deve ser mais pesado")

	# Remove o último
	var popped: CarriedItem = _wheelbarrow.remove_last_item()
	assert_not_null(popped)
	assert_eq(_wheelbarrow.cargo.size(), 4)
	assert_true(_wheelbarrow.can_add_item())


func test_tipping_and_fragile_spill() -> void:
	# Adiciona um achado robusto e um achado frágil limpo
	var robust_find: CarriedItem = _create_dummy_find("ferradura", 0.0)
	var fragile_find: CarriedItem = _create_dummy_find("vaso_ceramica", 0.8)

	_wheelbarrow.add_item(robust_find)
	_wheelbarrow.add_item(fragile_find)

	assert_true(fragile_find.is_clean, "Achado frágil começa com selo limpo")
	assert_almost_eq(fragile_find.integrity, 1.0, 0.01)

	# Tomba o carrinho
	_wheelbarrow.tip_over(Vector3(1, 0, 0))

	assert_true(_wheelbarrow.is_tipped, "Carrinho deve estar tombado")
	assert_eq(_wheelbarrow.cargo.size(), 0, "Carga deve ter sido toda derramada")

	# O achado frágil deve ter sofrido dano e perdido o selo de limpo/intacto (#93)
	assert_false(fragile_find.is_clean, "Achado frágil perdeu selo de limpo ao tombar")
	assert_lt(fragile_find.integrity, 1.0, "Integridade do achado frágil foi reduzida")

	# Deve ter gerado 2 pickups no mundo
	var pickups: Array[Node] = get_tree().get_nodes_in_group(ItemPickup.GROUP)
	assert_eq(pickups.size(), 2, "Itens derramados viram pickups no chão")


func test_impulse_tipping() -> void:
	# Impulso fraco não tomba
	_wheelbarrow.apply_impulse(Vector3(2.0, 0.0, 0.0))
	assert_false(_wheelbarrow.is_tipped, "Impulso leve não tomba o carrinho")

	# Impulso forte (explosão, golpe, geiser >= 6.0) tomba
	_wheelbarrow.apply_impulse(Vector3(8.0, 2.0, 0.0))
	assert_true(_wheelbarrow.is_tipped, "Impulso forte deve tombar o carrinho")


func test_upright_cart() -> void:
	_wheelbarrow.tip_over()
	assert_true(_wheelbarrow.is_tipped)

	_wheelbarrow.upright_cart()
	assert_false(_wheelbarrow.is_tipped, "Carrinho deve voltar a ficar em pé")
	assert_true(_wheelbarrow.can_add_item(), "Pode receber itens novamente")


func test_player_push_and_release() -> void:
	_player.global_position = Vector3(0, 0, 0)
	_wheelbarrow.global_position = Vector3(0, 0, 2)

	_player.start_pushing_wheelbarrow(_wheelbarrow)
	assert_eq(_player.pushing_wheelbarrow, _wheelbarrow, "Jogador está empurrando o carrinho")
	assert_eq(_wheelbarrow.pushing_player, _player, "Carrinho reconhece o jogador empurrador")

	# Soltar carrinho
	_player.stop_pushing_wheelbarrow()
	assert_null(_player.pushing_wheelbarrow)
	assert_null(_wheelbarrow.pushing_player)


func test_deliver_cargo_at_sell_point() -> void:
	var sp: SellPoint = SellPoint.new()
	add_child_autofree(sp)

	var find1: CarriedItem = _create_dummy_find("ouro_1", 0.0)
	var find2: CarriedItem = _create_dummy_find("ouro_2", 0.0)
	_wheelbarrow.add_item(find1)
	_wheelbarrow.add_item(find2)

	var total_delivered: int = _wheelbarrow.deliver_cargo(sp)
	assert_gt(total_delivered, 0, "Deve ter entregue valor dos achados")
	assert_eq(_wheelbarrow.cargo.size(), 0, "Carga deve esvaziar após entrega")
