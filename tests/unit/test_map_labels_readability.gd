extends GutTest

## #154: legibilidade dos rótulos 3D de loja/entrega/objetivos nos mapas (Ruínas, Geleira, Cratera)

const MAPS: Dictionary = {
	"ruinas": "res://world/map_ruinas.tscn",
	"geleira": "res://world/map_geleira.tscn",
	"cratera": "res://world/map_cratera.tscn",
}


func test_shop_and_delivery_labels_present_and_readable_in_all_maps() -> void:
	for map_name: String in MAPS:
		var scene: PackedScene = load(MAPS[map_name]) as PackedScene
		assert_not_null(scene, "Cena %s deve carregar" % map_name)
		var map: Node3D = scene.instantiate() as Node3D
		add_child_autofree(map)

		# 1. Banca / LOJA
		var banca: Node3D = map.get_node_or_null("Banca") as Node3D
		assert_not_null(banca, "[%s] Mapa deve ter o nó Banca" % map_name)
		var shop_label: Label3D = banca.get_node_or_null("Label") as Label3D
		assert_not_null(shop_label, "[%s] Banca deve ter rótulo 3D 'LOJA'" % map_name)
		assert_eq(shop_label.text, "LOJA", "[%s] Texto do rótulo da banca deve ser 'LOJA'" % map_name)
		assert_eq(shop_label.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "[%s] Rótulo da banca deve ter billboard ativo" % map_name)
		assert_gte(shop_label.font_size, 48, "[%s] Rótulo da banca deve ter fonte grande para leitura à distância" % map_name)
		assert_gte(shop_label.pixel_size, 0.005, "[%s] Pixel size legível" % map_name)
		assert_gte(shop_label.outline_size, 10, "[%s] Contorno nítido" % map_name)
		assert_gte(shop_label.position.y, 2.0, "[%s] Rótulo LOJA deve ficar acima do balcão e ofertas" % map_name)

		# 2. BaseEntrega / ENTREGA [E]
		var entrega: Node3D = map.get_node_or_null("BaseEntrega") as Node3D
		assert_not_null(entrega, "[%s] Mapa deve ter BaseEntrega" % map_name)
		var delivery_label: Label3D = entrega.get_node_or_null("Label") as Label3D
		assert_not_null(delivery_label, "[%s] BaseEntrega deve ter rótulo" % map_name)
		assert_true(delivery_label.text.begins_with("ENTREGA"), "[%s] Texto de entrega" % map_name)
		assert_eq(delivery_label.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "[%s] Billboard ativo" % map_name)
		assert_gte(delivery_label.font_size, 48, "[%s] Fonte legível" % map_name)
		assert_gte(delivery_label.position.y, 2.4, "[%s] Rótulo de entrega deve ficar acima de adereços (feno/caixas)" % map_name)


func test_boss_altar_labels_readability() -> void:
	# Ruínas Guardian Altar
	var guardian_altar: BossAltar = BossAltar.new()
	guardian_altar.label_text = "O guardião dorme..."
	add_child_autofree(guardian_altar)
	var g_label: Label3D = guardian_altar.get_node_or_null("Label") as Label3D
	assert_not_null(g_label, "BossAltar cria nó Label")
	assert_eq(g_label.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "Billboard ativo no BossAltar")
	assert_gte(g_label.font_size, 48, "Fonte legível no BossAltar")
	assert_gte(g_label.pixel_size, 0.006, "Pixel size ampliado para visão à distância")
	assert_gte(g_label.outline_size, 12, "Contorno nítido no BossAltar")

	# Geleira Mammoth Altar
	var mammoth_altar: MammothAltar = MammothAltar.new()
	mammoth_altar.label_text = "O mamute descansa..."
	add_child_autofree(mammoth_altar)
	var m_label: Label3D = mammoth_altar.get_node_or_null("Label") as Label3D
	assert_not_null(m_label, "MammothAltar cria nó Label")
	assert_gte(m_label.font_size, 48, "Fonte legível no MammothAltar")
	assert_gte(m_label.pixel_size, 0.006, "Pixel size ampliado no MammothAltar")
	assert_gte(m_label.outline_size, 12, "Contorno nítido no MammothAltar")

	# Cratera Crater Altar
	var crater_altar: CraterAltar = CraterAltar.new()
	crater_altar.label_text = "O ser adormecido..."
	add_child_autofree(crater_altar)
	var c_label: Label3D = crater_altar.get_node_or_null("Label") as Label3D
	assert_not_null(c_label, "CraterAltar cria nó Label")
	assert_gte(c_label.font_size, 48, "Fonte legível no CraterAltar")
	assert_gte(c_label.pixel_size, 0.006, "Pixel size ampliado no CraterAltar")
	assert_gte(c_label.outline_size, 12, "Contorno nítido no CraterAltar")
