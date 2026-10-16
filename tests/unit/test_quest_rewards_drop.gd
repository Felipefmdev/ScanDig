extends GutTest

## #67: Testes unitários para QuestRewards.drop_item fallback e proteção de cena.

var _saved_current_scene: Node = null


func before_each() -> void:
	QuestRewards.reset_session()
	_saved_current_scene = get_tree().current_scene


func after_each() -> void:
	get_tree().current_scene = _saved_current_scene


func test_drop_item_null_tree() -> void:
	assert_false(QuestRewards.drop_item(null, "concha_dourada", Vector3.ZERO), "tree nula devolve false")


func test_drop_item_empty_or_missing_item() -> void:
	assert_false(QuestRewards.drop_item(get_tree(), "", Vector3.ZERO), "item_id vazio devolve false")
	assert_false(QuestRewards.drop_item(get_tree(), "item_inexistente_99999", Vector3.ZERO), "item fora do catalogo devolve false")


func test_drop_item_with_pickups_root_succeeds() -> void:
	var world: Node3D = Node3D.new()
	add_child_autoqfree(world)
	var pickups: PickupsRoot = PickupsRoot.new()
	pickups.name = "Pickups"
	world.add_child(pickups)

	var ok: bool = QuestRewards.drop_item(get_tree(), "concha_dourada", Vector3(1.0, 0.5, 2.0), Vector3.ZERO)
	assert_true(ok, "drop_item com PickupsRoot ativo tem de devolver true")

	var found_item: bool = false
	for child: Node in pickups.get_children():
		if child is ItemPickup and child.carried != null and child.carried.item != null and child.carried.item.id == "concha_dourada":
			found_item = true
			break
	assert_true(found_item, "ItemPickup foi criado como filho do PickupsRoot")


func test_drop_item_rejects_lobby_scene() -> void:
	var fake_lobby: Node3D = Node3D.new()
	fake_lobby.name = "LobbyBase"
	get_tree().root.add_child(fake_lobby)
	get_tree().current_scene = fake_lobby

	# Sem PickupsRoot presente, drop_item deve recusar largar na cena do Lobby
	var ok: bool = QuestRewards.drop_item(get_tree(), "concha_dourada", Vector3.ZERO)
	assert_false(ok, "drop_item tem de recusar largar itens no LobbyBase")
	assert_eq(fake_lobby.get_child_count(), 0, "nenhum ItemPickup pode ser filho do LobbyBase")

	get_tree().current_scene = _saved_current_scene
	get_tree().root.remove_child(fake_lobby)
	fake_lobby.free()


func test_drop_item_rejects_non_node3d_scene() -> void:
	var control_scene: Control = Control.new()
	control_scene.name = "MenuOrRunner"
	get_tree().root.add_child(control_scene)
	get_tree().current_scene = control_scene

	var ok: bool = QuestRewards.drop_item(get_tree(), "concha_dourada", Vector3.ZERO)
	assert_false(ok, "drop_item tem de recusar cenas que nao sao Node3D")
	assert_eq(control_scene.get_child_count(), 0, "nenhum ItemPickup na cena de UI")

	get_tree().current_scene = _saved_current_scene
	get_tree().root.remove_child(control_scene)
	control_scene.free()
