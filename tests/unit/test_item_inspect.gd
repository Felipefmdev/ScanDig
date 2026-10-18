extends GutTest

## Testes unitários para a inspeção de item na mão (#88).
## Cobre: abertura/fecho do cartão (WornPanel), nome/descrição/desgaste de ferramentas,
## nome/descrição/valor/intacto vs rachado de achados do museu, atualização dinâmica
## de teclas quando o binding muda no SettingsManager, e rotação em ToolSway/ToolView.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if SettingsManager.instance != null:
		SettingsManager.instance.reset_controls()


func _spawn_player() -> Player:
	var p: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(p)
	return p


func test_inspect_card_opens_and_closes_for_shovel_and_detector() -> void:
	var p: Player = _spawn_player()
	assert_not_null(p.inspect_card, "Cartão de inspeção criado no HUD")
	assert_eq(p.inspect_card.theme_type_variation, &"WornPanel", "Usa estilo WornPanel do ScanDig")
	assert_false(p.is_inspecting)
	assert_false(p.inspect_card.visible)

	# Slot vazio -> inspeciona a Pá de Escavação
	p.toggle_inspect()
	assert_true(p.is_inspecting)
	assert_true(p.inspect_card.visible)
	assert_string_contains(p.inspect_card.title_label.text, "Pá de Escavação")
	assert_string_contains(p.inspect_card.description_label.text, "camadas de solo")
	assert_true(p.shovel_rig.visible, "Pá visível em 1.ª pessoa ao inspecionar de mãos vazias")

	# Equipa o Detetor de Metais -> cartão atualiza automaticamente
	var det: CarriedItem = CarriedItem.create_tool(&"detector", "Detetor de Metais")
	p.inventory.add_item(det)
	p.inventory.select(0)
	assert_string_contains(p.inspect_card.title_label.text, "Detetor de Metais")
	assert_string_contains(p.inspect_card.description_label.text, "bipes")

	# Fechar inspeção
	p.toggle_inspect()
	assert_false(p.is_inspecting)
	assert_false(p.inspect_card.visible)


func test_inspect_weapon_and_food_shows_description_and_wear() -> void:
	var p: Player = _spawn_player()
	var fork_td: ToolData = load("res://items/tools/forcado.tres") as ToolData
	var fork: CarriedItem = CarriedItem.create_from_tool_data(fork_td)
	fork.wear = 12
	p.inventory.add_item(fork)
	p.inventory.select(0)

	p.set_inspecting(true)
	var full: String = p.inspect_card.get_full_text()
	assert_string_contains(p.inspect_card.title_label.text, fork_td.display_name)
	assert_string_contains(p.inspect_card.description_label.text, fork_td.description)
	assert_string_contains(p.inspect_card.stats_label.text, "12/%d" % fork_td.durability)
	assert_string_contains(full, "%")

	# Trocar para comida no slot 1 atualiza o cartão com Vida e Saciedade
	var worm_td: ToolData = load("res://items/tools/minhoca.tres") as ToolData
	p.inventory.add_item(CarriedItem.create_from_tool_data(worm_td))
	p.inventory.select(1)
	assert_string_contains(p.inspect_card.title_label.text, worm_td.display_name)
	assert_string_contains(p.inspect_card.stats_label.text, "Vida")
	assert_string_contains(p.inspect_card.stats_label.text, "Saciedade")


func test_inspect_museum_find_shows_value_intact_and_cracked_state() -> void:
	var p: Player = _spawn_player()
	var vase: ItemData = load("res://items/catalog/calice_prata.tres") as ItemData
	var intact_find: CarriedItem = CarriedItem.create(vase, vase.base_value, 1.0, true, true)
	p.inventory.add_item(intact_find)
	p.inventory.select(0)

	p.set_inspecting(true)
	assert_string_contains(p.inspect_card.title_label.text, vase.display_name)
	assert_string_contains(p.inspect_card.stats_label.text, MoneyFormat.money(intact_find.final_value))
	assert_string_contains(p.inspect_card.stats_label.text, "Intacto")
	assert_string_contains(p.inspect_card.stats_label.text, "Variante Rara")

	# Quando o achado racha (#93), o cartão reflete o estado Rachado e o novo valor em R$
	intact_find.damage_integrity(0.35)
	p.inventory.notify_changed()
	assert_string_contains(p.inspect_card.stats_label.text, "Rachado")
	assert_string_contains(p.inspect_card.stats_label.text, MoneyFormat.money(intact_find.final_value))


func test_inspect_card_updates_controls_when_binding_changes_in_settings() -> void:
	var p: Player = _spawn_player()
	var sling_td: ToolData = load("res://items/tools/estilingue.tres") as ToolData
	p.inventory.add_item(CarriedItem.create_from_tool_data(sling_td))
	p.inventory.select(0)
	p.set_inspecting(true)

	var sm: SettingsManager = SettingsManager.instance
	assert_not_null(sm)
	assert_string_contains(p.inspect_card.controls_label.text, "[R] Fechar inspeção")
	assert_string_contains(p.inspect_card.controls_label.text, "[Q] Largar")

	# Remapeia 'inspect' para T e 'drop' para G
	assert_true(sm.set_binding("inspect", {"type": "key", "code": KEY_T}, true))
	assert_true(sm.set_binding("drop", {"type": "key", "code": KEY_G}, true))
	assert_string_contains(p.inspect_card.controls_label.text, "[T] Fechar inspeção")
	assert_string_contains(p.inspect_card.controls_label.text, "[G] Largar")


func test_inspecting_rotates_tool_sway_and_tool_view_smoothly() -> void:
	var p: Player = _spawn_player()
	var harpoon_td: ToolData = load("res://items/tools/arpao_corda.tres") as ToolData
	p.inventory.add_item(CarriedItem.create_from_tool_data(harpoon_td))
	p.inventory.select(0)
	p._equip_left = 0.0
	p.update_tool_sway(0.0)

	var sway_rot_rest: Vector3 = p.tool_sway.rotation
	var view_rot_rest: Vector3 = p.tool_view.rotation

	p.set_inspecting(true)
	p.update_tool_sway(0.4)
	var sway_rot_t1: Vector3 = p.tool_sway.rotation
	var view_rot_t1: Vector3 = p.tool_view.rotation
	assert_ne(sway_rot_t1, sway_rot_rest, "ToolSway inclina/roda durante a inspeção")
	assert_ne(view_rot_t1, view_rot_rest, "ToolView roda o modelo 3D durante a inspeção")

	p.update_tool_sway(0.5)
	assert_ne(p.tool_sway.rotation, sway_rot_t1, "Rotação continua a evoluir suavemente no tempo")
	assert_ne(p.tool_view.rotation, view_rot_t1)

	# Ao fechar a inspeção, volta à rotação de repouso
	p.set_inspecting(false)
	assert_almost_eq(p.tool_view.rotation.distance_to(view_rot_rest), 0.0, 0.001, "ToolView regressa ao repouso ao sair da inspeção")
