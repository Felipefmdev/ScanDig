extends GutTest

## Hotbar com ícones (#119): sem render (headless) fica a cor do item, sem erro; com o ícone no
## cache do ItemIcons ele aparece; marca do tipo no canto; slot selecionado com borda dourada e
## leve escala. Também: todos os ícones de UiIcons rasterizam e os modelos montam para o render.

var _inv: Inventory = null
var _hotbar: Hotbar = null


func before_each() -> void:
	ItemIcons.clear_cache()
	_inv = Inventory.new()
	_inv.capacity = 4
	add_child_autofree(_inv)
	_hotbar = Hotbar.new()
	add_child_autofree(_hotbar)
	_hotbar.bind(_inv)


func after_each() -> void:
	ItemIcons.clear_cache()


func _item(id: String, rare: bool = false) -> CarriedItem:
	var data: ItemData = load("res://items/catalog/%s.tres" % id) as ItemData
	return CarriedItem.create(data, data.base_value, 1.0, rare)


func _tool(id: String) -> CarriedItem:
	return CarriedItem.create_from_tool_data(load("res://items/tools/%s.tres" % id) as ToolData)


func _slot(i: int, path: String) -> Node:
	return _hotbar._slot_panels[i].get_node(path)


func test_headless_falls_back_to_color_swatch() -> void:
	assert_false(ItemIcons.can_render(), "testes rodam no headless")
	_inv.add_item(_item("moeda_antiga"))
	assert_null(ItemIcons.get_icon(_inv.get_item(0), get_tree()), "sem render: sem ícone")
	assert_true((_slot(0, "Box/Art/Swatch") as ColorRect).visible, "quadrado colorido no lugar")
	assert_false((_slot(0, "Box/Art/Icon") as TextureRect).visible)
	assert_eq((_slot(0, "Box/Name") as Label).text, "Moeda Antiga")
	assert_eq((_slot(0, "Overlay/Key") as Label).text, "1")


func test_empty_slot_is_only_the_frame() -> void:
	# #122 (E4): sem quadrado cinza, sem traço e sem fundo; só a borda (e o número do slot).
	_inv.add_item(_item("moeda_antiga"))
	_inv.select(0)
	for path: String in ["Box/Art/Swatch", "Box/Art/Icon"]:
		assert_false((_slot(1, path) as CanvasItem).visible, "vazio sem %s" % path)
	assert_eq((_slot(1, "Box/Name") as Label).text, "", "vazio sem traço")
	assert_eq((_slot(1, "Box/Value") as Label).text, "")
	assert_null((_slot(1, "Overlay/TypeMark") as TextureRect).texture)
	var style: StyleBoxFlat = _hotbar._slot_panels[1].get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_gt(style.bg_color.a, 0.0, "vazio mantém o fundo escuro habitual")
	assert_gt(style.border_width_left, 0, "a moldura fica")
	var filled: StyleBoxFlat = _hotbar._slot_panels[0].get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_gt(filled.bg_color.a, 0.0, "slot com item mantém o fundo")
	_inv.remove_at(0)
	assert_false((_slot(0, "Box/Art/Swatch") as ColorRect).visible, "esvaziado: sem quadrado")


func test_cached_icon_replaces_swatch() -> void:
	var c: CarriedItem = _item("concha_dourada")
	var fake: ImageTexture = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	ItemIcons._cache[ItemIcons.key_for(c)] = fake
	_inv.add_item(c)
	var icon: TextureRect = _slot(0, "Box/Art/Icon") as TextureRect
	assert_true(icon.visible, "ícone pronto aparece")
	assert_eq(icon.texture, fake)
	assert_false((_slot(0, "Box/Art/Swatch") as ColorRect).visible)


func test_type_mark_and_tool_texts() -> void:
	_inv.add_item(_item("moeda_antiga"))
	_inv.add_item(_item("bussola_naufragio", true))
	_inv.add_item(_tool("dinamite"))
	_inv.add_item(_tool("estilingue"))
	assert_eq((_slot(0, "Overlay/TypeMark") as TextureRect).texture, UiIcons.get_icon("museum", 32), "achado: museu")
	assert_eq((_slot(1, "Overlay/TypeMark") as TextureRect).texture, UiIcons.get_icon("gem", 32), "rara: gema")
	assert_false((_slot(1, "Box/Name") as Label).text.contains("✦"), "a gema substitui o ✦")
	assert_eq((_slot(2, "Overlay/TypeMark") as TextureRect).texture, UiIcons.get_icon("wrench", 32), "ferramenta: chave")
	assert_eq((_slot(2, "Box/Value") as Label).text, "", "sem a etiqueta 'ferramenta'")
	assert_string_contains((_slot(2, "Box/Name") as Label).text, "(x3)", "cargas no nome")
	assert_eq((_slot(3, "Box/Value") as Label).text, "100%", "desgaste embaixo")
	assert_false((_slot(3, "Box/Name") as Label).text.contains("%"), "e não repetido no nome")


func test_selected_slot_has_gold_border_and_scale() -> void:
	_inv.add_item(_item("moeda_antiga"))
	_inv.add_item(_item("concha_dourada"))
	_inv.select(1)
	var selected: PanelContainer = _hotbar._slot_panels[1]
	var other: PanelContainer = _hotbar._slot_panels[0]
	var style: StyleBoxFlat = selected.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(style.border_color, Hotbar.COLOR_SELECTED)
	assert_eq(style.border_width_top, 3)
	assert_almost_eq(selected.scale.x, Hotbar.SELECTED_SCALE, 0.001, "selecionado cresce")
	assert_almost_eq(other.scale.x, 1.0, 0.001)
	assert_eq(_hotbar.get_child_count(), 4, "um painel por slot")


func test_every_ui_icon_rasterizes() -> void:
	for icon_name: String in UiIcons.SHAPES:
		var tex: Texture2D = UiIcons.get_icon(icon_name, 48)
		assert_not_null(tex, "ícone %s" % icon_name)
		if tex != null:
			assert_eq(tex.get_size(), Vector2(48, 48), "lado de %s" % icon_name)
	assert_null(UiIcons.get_icon("nao_existe"))
	assert_eq(UiIcons.get_icon("coin", 24), UiIcons.get_icon("coin", 24), "cache")


func test_models_build_for_items_and_tools() -> void:
	for c: CarriedItem in [_item("moeda_antiga"), _tool("dinamite"), CarriedItem.create_tool(DetectorSpawn.TOOL_ID, DetectorSpawn.TOOL_NAME, DetectorSpawn.WORLD_MODEL)]:
		var model: Node3D = ItemIcons.build_model(c)
		assert_not_null(model, "modelo de %s" % ItemIcons.key_for(c))
		if model != null:
			model.free()
	assert_eq(ItemIcons.key_for(_item("bussola_naufragio", true)), "item:bussola_naufragio:rare")
	assert_eq(ItemIcons.key_for(_tool("dinamite")), "tool:dinamite")
