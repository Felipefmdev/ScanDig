extends Node3D

## Auditoria de arte (#61): instancia UMA cena (IA desligada), enquadra-a pela AABB das malhas
## e grava capturas de frente, 3/4 e lado. Uso:
##   godot --path . res://gameplay/debug/art_audit.tscn -- --subject=res://...tscn --out=C:/dir/nome
##   (ou --subject=item:<id> para um item de museu de ItemModels)
## Grava <out>_0.png, <out>_1.png, <out>_2.png e sai. A frente do modelo é -Z (look_at do Godot).

const BG: Color = Color(0.88, 0.86, 0.8)
## Ângulos (graus) da câmara à volta do modelo, a partir da frente.
const VIEWS: Array[float] = [0.0, 35.0, 90.0]

var _subject: Node3D = null
var _out: String = ""
var _cam: Camera3D = null
## Altura relativa da câmara (y da direção de vista antes de normalizar).
var _elevation: float = 0.35


func _ready() -> void:
	var path: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--subject="):
			path = a.trim_prefix("--subject=")
		elif a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	if path.is_empty() or _out.is_empty():
		push_error("art_audit: faltam --subject= e --out=")
		get_tree().quit(2)
		return

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation = Vector3(-0.872665, -0.610865, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	if path.begins_with("item:"):
		# Itens de museu (#61): --subject=item:<id>, vistos mais de cima (estão deitados)
		_subject = ItemModels.build(path.trim_prefix("item:"))
		_elevation = 0.9
	else:
		if not ResourceLoader.exists(path):
			push_error("[ArtAudit] Subject path inexistente: %s" % path)
			get_tree().quit(1)
			return
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			push_error("[ArtAudit] Falha ao carregar cena: %s" % path)
			get_tree().quit(1)
			return
		_subject = scene.instantiate() as Node3D
	if _subject == null:
		push_error("[ArtAudit] Subject invalido ou nulo: %s" % path)
		get_tree().quit(1)
		return
	add_child(_subject)
	_subject.process_mode = Node.PROCESS_MODE_DISABLED
	var hud: CanvasLayer = _subject.get_node_or_null(^"BossHud") as CanvasLayer
	if hud != null:
		hud.visible = false

	_cam = Camera3D.new()
	_cam.fov = 35.0
	_cam.current = true
	add_child(_cam)
	_capture.call_deferred()


func _capture() -> void:
	# Os modelos procedimentais constroem-se no _ready; espera uns frames.
	for i: int in 8:
		await get_tree().process_frame
	# Chefes e inimigos que nascem numa pose ou debaixo da terra (ex.: múmia, toupeira)
	var body: Node3D = _subject.get(&"_body_root") as Node3D
	if body == null:
		body = _subject.get(&"body_root") as Node3D
	if body != null:
		body.rotation = Vector3.ZERO
		body.position = Vector3.ZERO
		body.visible = true
	if _subject is EnemyBase:
		_subject.position = Vector3.ZERO
	var box: AABB = _mesh_aabb(_subject)
	var center: Vector3 = box.get_center()
	var radius: float = maxf(box.size.length() * 0.5, 0.2)
	var dist: float = radius / sin(deg_to_rad(_cam.fov * 0.5)) * 1.05
	for i: int in VIEWS.size():
		var ang: float = deg_to_rad(VIEWS[i])
		var dir: Vector3 = Vector3(sin(ang), _elevation, -cos(ang)).normalized()
		_cam.look_at_from_position(center + dir * dist, center)
		for f: int in 4:
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("%s_%d.png" % [_out, i])
	get_tree().quit()


static func _mesh_aabb(root: Node) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var gi: GeometryInstance3D = n as GeometryInstance3D
		if gi == null or not gi.is_visible_in_tree():
			continue
		var b: AABB = gi.global_transform * gi.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out
