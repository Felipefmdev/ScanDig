class_name MuseumDisplay
extends Node3D

## Vitrine 3D do Museu na base (#111): uma estante com uma seção por sítio (plaquinha com o nome
## e a contagem) e uma vaga por peça do catálogo. Doada = ItemModels.build; não achada = marca
## discreta no chão da prateleira. Intacta (#93) = selo verde na frente; rara (GameState.rare_items)
## = pedestal que brilha (emissão, sem luz). O ídolo de ouro, tesouro da Ilha, tem pedestal próprio
## com a única luz da vitrine.
## Lê só o GameState: o host muda o estado e o snapshot chega a todos, então cada peer monta a sua
## estante no state_synced/collection_updated, sem RPC. Só refaz as vagas que mudaram.

const CATALOG_DIR: String = "res://items/catalog/"
const MAPS_DIR: String = "res://items/maps/"
## Sítios na ordem da estante (linha de cima, depois a de baixo). O sítio de uma peça é o primeiro
## mapa cujo MapData.item_pool a tem; as que não saem no chão (troféus, segredos) vêm de EXTRA_SITES.
const SITES: Array[Dictionary] = [
	{"id": "praia", "name": "Praia"},
	{"id": "campo", "name": "Campo"},
	{"id": "ruinas", "name": "Ruínas"},
	{"id": "geleira", "name": "Geleira"},
	{"id": "cratera", "name": "Cratera"},
	{"id": "ilha_tesouro", "name": "Ilha"},
]
const EXTRA_SITES: Dictionary = {
	"alianca_ouro": "praia", "bussola_naufragio": "praia", "concha_dourada": "praia",
	"coroa_caranguejo_rei": "praia", "mapa_na_garrafa": "praia", "medalhao_sereia": "praia",
	"moeda_chocolate": "praia", "olho_do_polvo": "praia",
	"anel_do_poco": "campo", "cenoura_ouro": "campo", "fibula_romana": "campo",
	"garra_toupeira": "campo", "lanterna_espantalho": "campo", "moeda_celta": "campo",
	"pena_corvo_rei": "campo", "sino_bronze": "campo",
	"ligaduras_mumia": "ruinas", "nucleo_guardiao": "ruinas",
	"bussola_antiga": "geleira", "dente_mamute": "geleira", "fossil_gelo": "geleira",
	"machado_viking": "geleira",
	"cristal_eco": "cratera", "geodo_estrelar": "cratera", "nucleo_adormecido": "cratera",
	"orbe_vibrante": "cratera",
}
## Tesouro da Ilha (GoldColossus.TROPHY_ITEM_ID): fora das prateleiras, no pedestal da frente.
const HIGHLIGHT_ID: String = "idolo_ouro"
const HIGHLIGHT_SITE: String = "ilha_tesouro"

const COLUMNS: int = 3
const SECTION_WIDTH: float = 2.0
const SECTION_GAP: float = 0.12
const SECTION_HEIGHT: float = 0.95
## Prateleira de baixo alta o bastante para o pedestal do ídolo, à frente, não a esconder.
const BOTTOM_Y: float = 0.55
const SLOTS_PER_BOARD: int = 7
const DEPTH: float = 0.42
const PIECE_SCALE: float = 0.85
const PEDESTAL_HEIGHT: float = 0.07

const WOOD: Color = Color("#6b4426")
const WOOD_DARK: Color = Color("#3e2716")
const PLAQUE: Color = Color("#d9c08a")
## Fundo das prateleiras: madeira média (o WOOD_DARK ficava quase preto na sombra).
const BACK: Color = Color("#a87a4e")
## Plaquinha (#119): moldura de madeira com face de latão e texto de tinta.
const BRASS: Color = Color("#c9a24a")
const PLAQUE_INK: Color = Color("#2b2118")
const PLAQUE_SIZE: Vector2 = Vector2(0.98, 0.18)
## Brilho próprio do fundo: a prateleira de cima faz sombra e o fundo ficava cinza-escuro.
const BACK_GLOW: float = 0.22
const EMPTY_MARK: Color = Color(0.0, 0.0, 0.0, 0.35)
const SEAL: Color = Color("#3f9a52")
const SEAL_RIM: Color = Color("#e0b040")
const RARE_GLOW: Color = Color("#ffd36a")

## id -> vaga (Node3D) com a peça, a marca de vazio, o selo e o pedestal.
var _slots: Dictionary = {}
## id -> estado montado ("" vazio, "d" doada, + "r" rara, + "i" intacta).
var _shown: Dictionary = {}
## site_id -> Array[String] de ids, na ordem das vagas.
var _site_items: Dictionary = {}
var _plaques: Dictionary = {}
var _highlight_light: OmniLight3D = null
var _refresh_queued: bool = false
var _materials: Dictionary = {}


func _ready() -> void:
	_assign_sites()
	_build_cabinet()
	_build_highlight()
	var state: GameState = GameState.instance
	if state != null:
		state.state_synced.connect(_queue_refresh)
		state.collection_updated.connect(_on_collection_updated)
	refresh()


## Ids do catálogo agrupados por sítio (o HIGHLIGHT_ID fica no seu sítio, mas sem vaga na estante).
func get_site_items() -> Dictionary:
	return _site_items


func get_site_of(item_id: String) -> String:
	for site_id: String in _site_items:
		if (_site_items[site_id] as Array).has(item_id):
			return site_id
	return ""


## Peças (modelos) montadas agora.
func get_piece_count() -> int:
	var n: int = 0
	for id: String in _slots:
		if _slot_part(id, "Piece") != null:
			n += 1
	return n


func has_piece(item_id: String) -> bool:
	return _slot_part(item_id, "Piece") != null


func has_seal(item_id: String) -> bool:
	return _slot_part(item_id, "Seal") != null


func has_pedestal(item_id: String) -> bool:
	return _slot_part(item_id, "Pedestal") != null


func get_slot(item_id: String) -> Node3D:
	return _slots.get(item_id, null) as Node3D


func get_plaque_text(site_id: String) -> String:
	var label: Label3D = _plaques.get(site_id, null) as Label3D
	return label.text if label != null else ""


## Monta de novo só as vagas cujo estado mudou. Devolve quantas mudaram.
func refresh() -> int:
	_refresh_queued = false
	var state: GameState = GameState.instance
	var changed: int = 0
	for id: String in _slots:
		var key: String = _state_key(state, id)
		if _shown.get(id, "-") == key:
			continue
		_shown[id] = key
		_fill_slot(id, key)
		changed += 1
	_update_plaques(state)
	if _highlight_light != null:
		_highlight_light.visible = _shown.get(HIGHLIGHT_ID, "") != ""
	return changed


func _on_collection_updated(_found: int, _total: int) -> void:
	_queue_refresh()


## apply_snapshot emite collection_updated e state_synced em seguida: um refresh só por frame.
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	refresh.call_deferred()


static func _state_key(state: GameState, id: String) -> String:
	if state == null or not state.discovered_items.has(id):
		return ""
	var key: String = "d"
	if state.rare_items.has(id):
		key += "r"
	if state.intact_items.has(id):
		key += "i"
	return key


func _slot_part(item_id: String, part: String) -> Node:
	var slot: Node3D = _slots.get(item_id, null) as Node3D
	return slot.get_node_or_null(part) if slot != null else null


# --- Catálogo e sítios ---------------------------------------------------------

func _assign_sites() -> void:
	var catalog: Array[String] = _catalog_ids()
	var site_of: Dictionary = {}
	for site: Dictionary in SITES:
		var map_data: MapData = load(MAPS_DIR + "%s.tres" % site["id"]) as MapData
		if map_data == null:
			continue
		for item: ItemData in map_data.item_pool:
			if item != null and not site_of.has(item.id):
				site_of[item.id] = site["id"]
	site_of[HIGHLIGHT_ID] = HIGHLIGHT_SITE
	for site: Dictionary in SITES:
		_site_items[site["id"]] = [] as Array[String]
	for id: String in catalog:
		var site_id: String = str(site_of.get(id, EXTRA_SITES.get(id, HIGHLIGHT_SITE)))
		(_site_items[site_id] as Array[String]).append(id)


static func _catalog_ids() -> Array[String]:
	var ids: Array[String] = []
	var dir: DirAccess = DirAccess.open(CATALOG_DIR)
	if dir == null:
		push_warning("MuseumDisplay: catálogo '%s' não abriu." % CATALOG_DIR)
		return ids
	for file: String in dir.get_files():
		# Build exportada: os .tres viram .tres.remap.
		var clean: String = file.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			var item: ItemData = load(CATALOG_DIR + clean) as ItemData
			if item != null and not item.id.is_empty() and not ids.has(item.id):
				ids.append(item.id)
	ids.sort()
	return ids


# --- Estante -------------------------------------------------------------------

func _build_cabinet() -> void:
	var rows: int = ceili(float(SITES.size()) / float(COLUMNS))
	var total_w: float = COLUMNS * SECTION_WIDTH + (COLUMNS + 1) * SECTION_GAP
	var total_h: float = BOTTOM_Y + rows * SECTION_HEIGHT + 0.1
	# Assoalho da ala: a estante fica na grama, ao lado da tenda, com o pedestal do ídolo à frente.
	_add_box(self, "Deck", Vector3(0.0, 0.05, 0.85), Vector3(total_w + 0.6, 0.1, DEPTH + 2.2), WOOD)
	var back: MeshInstance3D = _add_box(self, "Back", Vector3(0.0, total_h * 0.5, -DEPTH * 0.5), Vector3(total_w, total_h, 0.06), BACK)
	var back_mat: StandardMaterial3D = (back.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	back_mat.emission_enabled = true
	back_mat.emission = BACK
	back_mat.emission_energy_multiplier = BACK_GLOW
	back.material_override = back_mat
	_add_box(self, "Top", Vector3(0.0, total_h, 0.0), Vector3(total_w + 0.1, 0.08, DEPTH + 0.06), WOOD)
	for c: int in COLUMNS + 1:
		var x: float = -total_w * 0.5 + SECTION_GAP * 0.5 + c * (SECTION_WIDTH + SECTION_GAP)
		_add_box(self, "Post%d" % c, Vector3(x, total_h * 0.5, 0.0), Vector3(SECTION_GAP, total_h, DEPTH), WOOD)
	for i: int in SITES.size():
		var site_id: String = SITES[i]["id"]
		var col: int = i % COLUMNS
		var row: int = rows - 1 - floori(float(i) / float(COLUMNS))
		var origin: Vector3 = Vector3(
			-total_w * 0.5 + SECTION_GAP + col * (SECTION_WIDTH + SECTION_GAP) + SECTION_WIDTH * 0.5,
			BOTTOM_Y + row * SECTION_HEIGHT, 0.0)
		_build_section(site_id, str(SITES[i]["name"]), origin)


func _build_section(site_id: String, title: String, origin: Vector3) -> void:
	var section: Node3D = Node3D.new()
	section.name = "Site_%s" % site_id
	section.position = origin
	add_child(section)
	var ids: Array[String] = []
	for id: String in _site_items[site_id]:
		if id != HIGHLIGHT_ID:
			ids.append(id)
	var boards: int = maxi(1, ceili(float(ids.size()) / float(SLOTS_PER_BOARD)))
	var board_step: float = (SECTION_HEIGHT - 0.3) / float(boards)
	for b: int in boards:
		_add_box(section, "Board%d" % b, Vector3(0.0, b * board_step - 0.03, 0.0), Vector3(SECTION_WIDTH, 0.05, DEPTH), WOOD)
	var step: float = SECTION_WIDTH / float(SLOTS_PER_BOARD)
	for k: int in ids.size():
		var b: int = floori(float(k) / float(SLOTS_PER_BOARD))
		var in_board: int = mini(SLOTS_PER_BOARD, ids.size() - b * SLOTS_PER_BOARD)
		var x: float = (float(k % SLOTS_PER_BOARD) - float(in_board - 1) * 0.5) * step
		var slot: Node3D = Node3D.new()
		slot.name = "Slot_%s" % ids[k]
		slot.position = Vector3(x, b * board_step, 0.02)
		section.add_child(slot)
		_slots[ids[k]] = slot
	var plaque: Label3D = _add_plaque(section, Vector3(0.0, SECTION_HEIGHT - 0.17, DEPTH * 0.5), PLAQUE_SIZE)
	_plaques[site_id] = plaque
	plaque.set_meta(&"title", title)


func _build_highlight() -> void:
	var stand: Node3D = Node3D.new()
	stand.name = "Highlight"
	stand.position = Vector3(0.0, 0.0, DEPTH + 1.4)
	add_child(stand)
	_add_box(stand, "Column", Vector3(0.0, 0.25, 0.0), Vector3(0.4, 0.5, 0.4), WOOD_DARK)
	_add_box(stand, "Cap", Vector3(0.0, 0.52, 0.0), Vector3(0.5, 0.05, 0.5), RARE_GLOW, true)
	var slot: Node3D = Node3D.new()
	slot.name = "Slot_%s" % HIGHLIGHT_ID
	slot.position = Vector3(0.0, 0.545, 0.0)
	stand.add_child(slot)
	_slots[HIGHLIGHT_ID] = slot
	var label: Label3D = _add_plaque(stand, Vector3(0.0, 0.32, 0.2), Vector2(0.64, 0.1))
	label.text = "Tesouro da Ilha"
	label.font_size = 28
	_highlight_light = OmniLight3D.new()
	_highlight_light.name = "Light"
	_highlight_light.position = Vector3(0.0, 1.2, 0.3)
	_highlight_light.light_color = RARE_GLOW
	_highlight_light.light_energy = 1.4
	_highlight_light.omni_range = 2.2
	_highlight_light.visible = false
	stand.add_child(_highlight_light)


func _fill_slot(id: String, key: String) -> void:
	var slot: Node3D = _slots[id]
	for child: Node in slot.get_children():
		slot.remove_child(child)
		child.queue_free()
	if key.is_empty():
		var mark: MeshInstance3D = MeshInstance3D.new()
		mark.name = "Empty"
		var disc: CylinderMesh = CylinderMesh.new()
		disc.top_radius = 0.08
		disc.bottom_radius = 0.08
		disc.height = 0.006
		disc.radial_segments = 10
		disc.rings = 1
		mark.mesh = disc
		mark.material_override = _material(EMPTY_MARK)
		mark.position.y = 0.003
		slot.add_child(mark)
		return
	var rare: bool = key.contains("r")
	var lift: float = 0.0
	if rare and id != HIGHLIGHT_ID:
		_add_box(slot, "Pedestal", Vector3(0.0, PEDESTAL_HEIGHT * 0.5, 0.0), Vector3(0.2, PEDESTAL_HEIGHT, 0.2), RARE_GLOW, true)
		lift = PEDESTAL_HEIGHT
	var piece: Node3D = ItemModels.build(id, rare)
	if piece == null:
		piece = Node3D.new()
		_add_box(piece, "Box", Vector3(0.0, 0.08, 0.0), Vector3(0.16, 0.16, 0.16), PLAQUE)
	piece.name = "Piece"
	piece.scale = Vector3.ONE * PIECE_SCALE
	piece.position.y = lift
	slot.add_child(piece)
	if key.contains("i"):
		var seal: MeshInstance3D = MeshInstance3D.new()
		seal.name = "Seal"
		var disc: CylinderMesh = CylinderMesh.new()
		disc.top_radius = 0.035
		disc.bottom_radius = 0.035
		disc.height = 0.012
		disc.radial_segments = 10
		disc.rings = 1
		seal.mesh = disc
		seal.material_override = _material(SEAL)
		seal.rotation.x = PI * 0.5
		seal.position = Vector3(0.09, 0.05, DEPTH * 0.5 - 0.04)
		var rim: MeshInstance3D = MeshInstance3D.new()
		var rim_mesh: CylinderMesh = disc.duplicate() as CylinderMesh
		rim_mesh.top_radius = 0.045
		rim_mesh.bottom_radius = 0.045
		rim_mesh.height = 0.008
		rim.mesh = rim_mesh
		rim.material_override = _material(SEAL_RIM)
		rim.position.y = -0.005
		seal.add_child(rim)
		slot.add_child(seal)


func _update_plaques(state: GameState) -> void:
	for site_id: String in _plaques:
		var ids: Array = _site_items[site_id]
		var found: int = 0
		for id: String in ids:
			if state != null and state.discovered_items.has(id):
				found += 1
		var label: Label3D = _plaques[site_id]
		label.text = "%s  %d/%d" % [str(label.get_meta(&"title")), found, ids.size()]


## Plaquinha na frente de `parent`: moldura de madeira, face de latão e o texto de tinta (o
## Label3D "Plaque", que _update_plaques preenche).
func _add_plaque(parent: Node3D, front_center: Vector3, size: Vector2) -> Label3D:
	_add_box(parent, "PlaqueFrame", front_center + Vector3(0.0, 0.0, 0.006), Vector3(size.x + 0.04, size.y + 0.04, 0.012), WOOD_DARK)
	_add_box(parent, "PlaquePlate", front_center + Vector3(0.0, 0.0, 0.014), Vector3(size.x, size.y, 0.006), BRASS)
	var label: Label3D = Label3D.new()
	label.name = "Plaque"
	label.position = front_center + Vector3(0.0, 0.0, 0.019)
	# Legível na vista do "Ver museu" (MuseumView) em 960x540.
	label.pixel_size = 0.0026 if size.x < PLAQUE_SIZE.x else 0.0037
	label.font_size = 40
	label.outline_size = 0
	label.modulate = PLAQUE_INK
	label.shaded = false
	label.double_sided = false
	parent.add_child(label)
	return label


func _add_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _material(color, glow)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Um material por cor (as vagas e a estante dividem os mesmos).
func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key: String = "%s%s" % [color.to_html(), "g" if glow else ""]
	if _materials.has(key):
		return _materials[key]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.8
	_materials[key] = mat
	return mat
