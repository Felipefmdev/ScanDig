extends Node

## Opt-in visual da banca da Praia. Não altera o Theme nem a lógica dos alvos.
const SHOP_THEME: Theme = preload("res://ui/theme/scandig_theme.tres")

@export_node_path("Node3D") var map_root: NodePath
@export var title_labels: Array[NodePath] = []
@export var body_labels: Array[NodePath] = []
@export var offers: Array[NodePath] = []

var _product_labels: Array[Label3D] = []
var _heading: Label3D


func _ready() -> void:
	var map: Node3D = get_node_or_null(map_root) as Node3D
	if map == null or map != get_parent() or map.name != &"MapPraia":
		_fail("raiz MapPraia explícita inválida")
		return
	if not map.is_node_ready():
		await map.ready
	if not is_instance_valid(map) or not map.is_node_ready():
		_fail("raiz não está pronta")
		return
	if title_labels.size() != 3 or body_labels.size() != 1 or offers.size() != 4:
		_fail("lista deve conter três placas, um prompt e quatro ofertas")
		return

	var labels: Array[Label3D] = []
	for path: NodePath in title_labels + body_labels:
		var label: Label3D = _target(map, path) as Label3D
		if label == null:
			_fail("Label3D ausente ou inválida: %s" % path)
			return
		labels.append(label)
	for path: NodePath in offers:
		var offer: ShopOffer = _target(map, path) as ShopOffer
		if offer == null:
			_fail("ShopOffer ausente ou inválida: %s" % path)
			return
		var direct_labels: Array[Label3D] = []
		for child: Node in offer.get_children():
			if child is Label3D:
				direct_labels.append(child as Label3D)
		if direct_labels.size() != 1:
			_fail("oferta sem Label3D filha direta única: %s" % path)
			return
		labels.append(direct_labels[0])

	# Nenhuma atribuição ocorre até validar o conjunto inteiro e ambas as fontes.
	var unique: Dictionary = {}
	for label: Label3D in labels:
		if not is_instance_valid(label) or not label.is_node_ready() or label.is_queued_for_deletion() or not map.is_ancestor_of(label):
			_fail("alvo não está pronto ou deixou a raiz")
			return
		if unique.has(label.get_instance_id()):
			_fail("Label3D repetida na lista")
			return
		unique[label.get_instance_id()] = true
	var title_font: Font = SHOP_THEME.get_font(&"font", &"TitleLabel")
	var body_font: Font = SHOP_THEME.default_font
	if unique.size() != 8 or title_font == null or body_font == null:
		_fail("conjunto de oito alvos ou fontes incompleto")
		return
	for index: int in labels.size():
		labels[index].font = title_font if index < title_labels.size() else body_font
		var label: Label3D = labels[index]
		if index == 0:
			label.fixed_size = true
			label.pixel_size = 0.0011
			label.outline_size = 8
		elif index == 1:
			label.fixed_size = true
			label.pixel_size = 0.0015
			label.outline_size = 8
		elif index == 2:
			label.fixed_size = true
			label.pixel_size = 0.0011
			label.outline_size = 8
			_heading = label
		elif index == 3:
			label.fixed_size = true
			label.pixel_size = 0.0015
			label.outline_size = 8
		else:
			label.pixel_size = 0.0032
			label.outline_size = 8
			_product_labels.append(label)



## Limita a ampliação perto da câmera sem deslocar a legenda do produto.
func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	if is_instance_valid(_heading):
		var heading_distance: float = camera.global_position.distance_to(_heading.global_position)
		var weight: float = clampf((heading_distance - 2.8) / 2.5, 0.0, 1.0)
		_heading.offset = Vector2(lerpf(-100.0, -130.0, weight), lerpf(60.0, 120.0, weight))
	for label: Label3D in _product_labels:
		if not is_instance_valid(label) or label.is_queued_for_deletion():
			set_process(false)
			return
		var distance: float = camera.global_position.distance_to(label.global_position)
		label.pixel_size = 0.0032 * minf(1.0, distance / 2.8)


func _target(map: Node3D, path: NodePath) -> Node:
	if path.is_empty() or path.is_absolute() or path.get_subname_count() != 0:
		return null
	for index: int in path.get_name_count():
		if path.get_name(index) == &"..":
			return null
	var target: Node = map.get_node_or_null(path)
	if target == null or not map.is_ancestor_of(target) or not target.is_node_ready() or target.is_queued_for_deletion():
		return null
	return target


func _fail(reason: String) -> void:
	push_error("WorldShopTypography: %s; nenhuma fonte aplicada." % reason)
