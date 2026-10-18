class_name ItemIcons
extends Node

## Ícones 3D dos itens da hotbar (#119). Cada achado (ItemModels.build) ou ferramenta (a
## world_scene dela) é renderizado uma vez num SubViewport próprio (own_world_3d, fundo
## transparente, câmera e luz próprias) e vira uma ImageTexture no cache estático, por item_id
## (e variante rara). get_icon() devolve a textura pronta ou null; no null a hotbar mostra a cor
## de antes e escuta icon_ready para trocar quando a renderização terminar. Sem render (headless)
## nada é pedido e fica sempre a cor, sem erro.

signal icon_ready(key: String)

const SIDE: int = 128
const FOV: float = 28.0
## Direção da câmera (de cima, à frente e um pouco à direita) e folga em volta do modelo.
const VIEW_DIR: Vector3 = Vector3(0.45, 0.55, 1.0)
const MARGIN: float = 1.12

static var _cache: Dictionary = {}
## Chaves sem modelo ou que falharam: não tenta de novo.
static var _failed: Dictionary = {}
static var _renderer: ItemIcons = null

var _queue: Array[Dictionary] = []
var _busy: bool = false


static func key_for(c: CarriedItem) -> String:
	if c == null:
		return ""
	if c.is_tool():
		return "tool:%s" % c.tool_id
	if c.item == null:
		return ""
	return "item:%s%s" % [c.item.id, ":rare" if c.is_rare_variant else ""]


static func can_render() -> bool:
	return DisplayServer.get_name() != "headless"


static func cached(key: String) -> Texture2D:
	return _cache.get(key, null) as Texture2D


## Ícone pronto, ou null (e pede a renderização se der). `tree` é onde o renderizador mora.
static func get_icon(c: CarriedItem, tree: SceneTree) -> Texture2D:
	var key: String = key_for(c)
	if key.is_empty() or _failed.has(key):
		return null
	if _cache.has(key):
		return _cache[key]
	if not can_render() or tree == null:
		return null
	renderer(tree).request(key, c)
	return null


## O nó que renderiza (um só, filho da raiz).
static func renderer(tree: SceneTree) -> ItemIcons:
	if _renderer == null or not is_instance_valid(_renderer):
		_renderer = ItemIcons.new()
		_renderer.name = "ItemIcons"
		tree.root.add_child.call_deferred(_renderer)
	return _renderer


static func clear_cache() -> void:
	_cache.clear()
	_failed.clear()


func request(key: String, c: CarriedItem) -> void:
	for job: Dictionary in _queue:
		if job["key"] == key:
			return
	_queue.append({"key": key, "item": c})
	if not _busy:
		_drain.call_deferred()


func _drain() -> void:
	_busy = true
	while not _queue.is_empty():
		if not is_inside_tree():
			await tree_entered
		var job: Dictionary = _queue.pop_front()
		var key: String = job["key"]
		if _cache.has(key) or _failed.has(key):
			continue
		var texture: Texture2D = await _render(job["item"] as CarriedItem)
		if texture == null:
			_failed[key] = true
		else:
			_cache[key] = texture
			icon_ready.emit(key)
	_busy = false


static func build_model(c: CarriedItem) -> Node3D:
	if c.is_tool():
		var scene: PackedScene = c.world_scene
		if scene == null and c.tool_data != null:
			scene = c.tool_data.world_scene
		return scene.instantiate() as Node3D if scene != null else null
	return ItemModels.build(c.item.id, c.is_rare_variant) if c.item != null else null


func _render(c: CarriedItem) -> Texture2D:
	var model: Node3D = build_model(c)
	if model == null:
		return null
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SIDE, SIDE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1.0, 0.97, 0.92)
	env.environment.ambient_light_energy = 0.55
	viewport.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = 1.25
	viewport.add_child(sun)
	sun.look_at_from_position(Vector3(1.0, 2.0, 1.5), Vector3.ZERO)
	var camera: Camera3D = Camera3D.new()
	camera.fov = FOV
	camera.current = true
	viewport.add_child(camera)
	viewport.add_child(model)
	# Os modelos de ferramenta montam a malha no _ready: espera um frame antes de medir.
	await get_tree().process_frame
	var box: AABB = _bounds(model)
	var radius: float = maxf(box.size.length() * 0.5, 0.05)
	var distance: float = radius * MARGIN / sin(deg_to_rad(FOV * 0.5))
	camera.look_at_from_position(box.get_center() + VIEW_DIR.normalized() * distance, box.get_center())
	camera.near = maxf(distance - radius * 2.0, 0.01)
	camera.far = distance + radius * 2.0
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


## Caixa de todas as malhas visíveis do modelo, nas coordenadas do mundo do viewport.
static func _bounds(root: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var visual: VisualInstance3D = node as VisualInstance3D
		if visual == null or not visual.is_visible_in_tree():
			continue
		var local: AABB = visual.get_aabb()
		if local.size == Vector3.ZERO:
			continue
		var world: AABB = visual.global_transform * local
		box = world if first else box.merge(world)
		first = false
	return box if not first else AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))
