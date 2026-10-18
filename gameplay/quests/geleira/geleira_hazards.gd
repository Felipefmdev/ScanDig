class_name GeleiraHazards
extends Node3D

## Geleira (#95): o barulho mexe com a montanha. Lê o DisturbanceMeter do host:
##   - avalanche: com a ameaça acima de avalanche_ratio, barulho a menos de avalanche_reach m de
##     uma encosta (as paredes de gelo do perímetro) solta uma pequena avalanche telegrafada
##     (tremor + pó de neve + aviso no chão) que empurra jogadores e itens e volta a tapar de
##     neve os spots da faixa (camadas de terra no máximo, com um monte de neve que derrete);
##   - estalactites: penduradas debaixo dos arcos de gelo. Cada uma junta "tensão" com o barulho
##     a menos de stalactite_reach m e perde-a com o tempo; passado o limite cai (sombra no chão
##     antes) e magoa quem está por baixo. Cavar com cuidado não chega a acumular tensão.
## O host decide (barulho, quando e onde) e manda tudo por RPC; os outros peers só mostram.

const AVALANCHE_LENGTH: float = 10.0
const AVALANCHE_WIDTH: float = 8.0
const AVALANCHE_PUSH: float = 9.0
const SNOW_MOUND_TIME: float = 30.0
const STALACTITE_SHADOW_TIME: float = 1.2
const STALACTITE_FALL_TIME: float = 0.35
const STALACTITE_HIT_RADIUS: float = 1.3
const STALACTITE_DAMAGE: float = 15.0
const STALACTITE_REGROW: float = 90.0
const MSG_AVALANCHE: String = "❄️ A encosta está cedendo! Afaste-se das paredes de gelo!"
const MSG_COLOR: Color = Color(0.7, 0.9, 1.0)
const SNOW: Color = Color("#eef5fb")
const ICE: Color = Color("#9fd4ea")

## Ameaça (fração do medidor) a partir da qual as encostas podem ceder.
@export var avalanche_ratio: float = 0.5
## Distância máxima (m) entre o barulho e a encosta para a avalanche.
@export var avalanche_reach: float = 12.0
@export var avalanche_cooldown: float = 40.0
@export var avalanche_telegraph: float = 2.5
## Distância (m) do centro do mapa às encostas de gelo (paredes do perímetro).
@export var slope_half: float = 29.0
@export var stalactite_reach: float = 5.0
## Tensão a partir da qual a estalactite cai e quanto perde por segundo.
@export var stalactite_strain_max: float = 10.0
@export var stalactite_strain_decay: float = 3.0

## Estalactites: debaixo do arco de gelo (4, -16, rodado 45°) e da gruta (0, -28.5).
var stalactites: Array[Dictionary] = []

var _meter: DisturbanceMeter = null
var _prev_noise: float = 0.0
var _avalanche_cd: float = 0.0
var _mat: ShaderMaterial = null
var _warning: GroundWarning = null


func _ready() -> void:
	_mat = ToonKit.vertex_material(true, true)
	_warning = GroundWarning.new()
	add_child(_warning)
	_build_stalactites()
	if HostSync.is_host(self):
		HostSync.on_peer_ready(self, func(peer_id: int) -> void:
			HostSync.send_to(self, peer_id, &"_rpc_stalactite_state", [_fallen_mask()]))


func _process(delta: float) -> void:
	_avalanche_cd = maxf(_avalanche_cd - delta, 0.0)
	for s: Dictionary in stalactites:
		s["strain"] = maxf(float(s["strain"]) - stalactite_strain_decay * delta, 0.0)
	if not HostSync.is_host(self):
		return
	if _meter == null or not is_instance_valid(_meter):
		_meter = DisturbanceMeter.instance
		if _meter == null:
			return
		_prev_noise = _meter.current_noise
	var noise: float = _meter.current_noise
	var added: float = noise - _prev_noise
	_prev_noise = noise
	# o medidor decai sozinho; um salto para cima é barulho novo (pazada, explosão, ...)
	if added > 0.5:
		on_noise(added, _meter.get(&"_last_origin"), _meter.get_ratio())


## Host: barulho novo `amount` em `origin`, com a ameaça a `ratio`. Público para testes.
func on_noise(amount: float, origin: Vector3, ratio: float) -> void:
	if not HostSync.is_host(self):
		return
	for i: int in stalactites.size():
		var s: Dictionary = stalactites[i]
		if bool(s["fallen"]):
			continue
		var top: Vector3 = s["top"]
		if Vector2(origin.x - top.x, origin.z - top.z).length() > stalactite_reach:
			continue
		s["strain"] = float(s["strain"]) + amount
		if float(s["strain"]) >= stalactite_strain_max:
			drop_stalactite(i)
	if ratio >= avalanche_ratio and _avalanche_cd <= 0.0:
		var slope: Dictionary = slope_near(origin)
		if not slope.is_empty():
			trigger_avalanche(slope["start"], slope["dir"])


## Atalho de debug/bot (DebugBridge "call": "Hazards", "method": "trigger"): junto do jogador
## local larga a estalactite mais próxima (se estiver a menos de 8 m) e solta a encosta mais
## próxima (se houver), sem esperar pelo barulho.
func trigger() -> void:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	if player == null:
		return
	var at: Vector3 = player.global_position
	var best: int = -1
	var best_d: float = 8.0
	for i: int in stalactites.size():
		var top: Vector3 = stalactites[i]["top"]
		var d: float = Vector2(at.x - top.x, at.z - top.z).length()
		if d < best_d and not bool(stalactites[i]["fallen"]):
			best_d = d
			best = i
	if best >= 0:
		drop_stalactite(best)
	var slope: Dictionary = slope_near(at)
	if not slope.is_empty():
		trigger_avalanche(slope["start"], slope["dir"])


## Ponto da encosta mais próxima de `origin` e direção para dentro do mapa; vazio se longe.
func slope_near(origin: Vector3) -> Dictionary:
	var dx: float = slope_half - absf(origin.x)
	var dz: float = slope_half - absf(origin.z)
	if minf(dx, dz) > avalanche_reach:
		return {}
	var limit: float = slope_half - AVALANCHE_WIDTH * 0.5
	if dx <= dz:
		var sx: float = signf(origin.x) if origin.x != 0.0 else 1.0
		return {"start": Vector3(sx * slope_half, 0.0, clampf(origin.z, -limit, limit)), "dir": Vector3(-sx, 0.0, 0.0)}
	var sz: float = signf(origin.z) if origin.z != 0.0 else 1.0
	return {"start": Vector3(clampf(origin.x, -limit, limit), 0.0, sz * slope_half), "dir": Vector3(0.0, 0.0, -sz)}


# ---------------------------------------------------------------------------
# Avalanche
# ---------------------------------------------------------------------------

## Host: aviso agora, a neve chega passado avalanche_telegraph s.
func trigger_avalanche(start: Vector3, dir: Vector3) -> void:
	if not HostSync.is_host(self):
		return
	_avalanche_cd = avalanche_cooldown
	_rpc_avalanche_warn(start, dir)
	HostSync.broadcast(self, &"_rpc_avalanche_warn", [start, dir])
	if not is_inside_tree():
		return
	get_tree().create_timer(avalanche_telegraph).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_inside_tree():
			_avalanche_hit(start, dir))


func _avalanche_hit(start: Vector3, dir: Vector3) -> void:
	var seed_v: int = randi()
	_rpc_avalanche_slide(start, dir, seed_v)
	HostSync.broadcast(self, &"_rpc_avalanche_slide", [start, dir, seed_v])
	var side: Vector3 = dir.cross(Vector3.UP)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Node3D = n as Node3D
		if p != null and in_avalanche(p.global_position, start, dir):
			_push_player(p, dir * AVALANCHE_PUSH + Vector3.UP * 3.0, 0.6)
	for n: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var it: ItemPickup = n as ItemPickup
		if it != null and in_avalanche(it.global_position, start, dir):
			it.push(dir * 5.0 + Vector3.UP * 1.5 + side * randf_range(-1.0, 1.0))
	var buried: Array[Vector3] = []
	for n: Node in get_tree().get_nodes_in_group(&"buried_spots"):
		var spot: BuriedSpot = n as BuriedSpot
		if spot == null or spot.is_queued_for_deletion() or not in_avalanche(spot.global_position, start, dir):
			continue
		if spot.dirt_layers > 0 and spot.dirt_layers < BuriedSpot.MAX_DIRT_LAYERS:
			spot.dirt_layers = BuriedSpot.MAX_DIRT_LAYERS
		buried.append(spot.global_position)
	if not buried.is_empty():
		_rpc_snow_mounds(buried)
		HostSync.broadcast(self, &"_rpc_snow_mounds", [buried])


## Dentro da faixa da avalanche (comprimento a partir da encosta, largura à volta).
static func in_avalanche(pos: Vector3, start: Vector3, dir: Vector3) -> bool:
	var rel: Vector3 = pos - start
	var along: float = rel.dot(dir)
	var across: float = absf(rel.dot(dir.cross(Vector3.UP)))
	return along >= -1.0 and along <= AVALANCHE_LENGTH and across <= AVALANCHE_WIDTH * 0.5


@rpc("authority", "call_remote", "reliable")
func _rpc_avalanche_warn(start: Vector3, dir: Vector3) -> void:
	_warning.show_line(start, dir, AVALANCHE_LENGTH, AVALANCHE_WIDTH)
	get_tree().create_timer(avalanche_telegraph).timeout.connect(func() -> void:
		if is_instance_valid(_warning):
			_warning.hide_warning())
	_snow_dust(start + Vector3.UP * 2.5, avalanche_telegraph)
	SFX.play_at(SFX.EMERGE_SAND, start, 4.0)
	for n: Node in get_tree().get_nodes_in_group(&"player"):
		var p: Node3D = n as Node3D
		if p == null:
			continue
		if p.global_position.distance_to(start) < avalanche_reach + AVALANCHE_LENGTH:
			if p.has_method(&"_shake_camera"):
				p.call(&"_shake_camera", 0.25, avalanche_telegraph)
			if p.has_method(&"_show_temporary_message"):
				p.call(&"_show_temporary_message", MSG_AVALANCHE, MSG_COLOR, 3.0)


## Neve a deslizar da encosta para dentro (só visual, igual em todos os peers pela semente).
@rpc("authority", "call_remote", "reliable")
func _rpc_avalanche_slide(start: Vector3, dir: Vector3, seed_v: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var side: Vector3 = dir.cross(Vector3.UP)
	SFX.play_at(SFX.FOOTSTEP_SNOW, start + dir * 3.0, 6.0)
	for i: int in 10:
		var across: float = rng.randf_range(-AVALANCHE_WIDTH * 0.45, AVALANCHE_WIDTH * 0.45)
		var from: Vector3 = start + side * across + Vector3.UP * rng.randf_range(2.0, 3.5)
		var reach: float = rng.randf_range(AVALANCHE_LENGTH * 0.6, AVALANCHE_LENGTH)
		var to_xz: Vector3 = start + side * across + dir * reach
		var to: Vector3 = Vector3(to_xz.x, GlacierTerrain.height_at(to_xz.x, to_xz.z) + 0.15, to_xz.z)
		var chunk: MeshInstance3D = _chunk(rng.randf_range(0.35, 0.7), SNOW if i % 3 != 0 else ICE)
		chunk.position = from
		chunk.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0.0)
		add_child(chunk)
		var tw: Tween = chunk.create_tween()
		tw.tween_property(chunk, ^"position", to, rng.randf_range(1.0, 1.6)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_interval(3.0)
		tw.tween_property(chunk, ^"scale", Vector3.ONE * 0.05, 2.0)
		tw.tween_callback(chunk.queue_free)
	_snow_dust(start + dir * 4.0 + Vector3.UP * 0.5, 1.5)


## Montes de neve por cima dos spots soterrados; derretem com o tempo.
@rpc("authority", "call_remote", "reliable")
func _rpc_snow_mounds(points: Array) -> void:
	for p: Variant in points:
		var mound: MeshInstance3D = _mound()
		mound.position = p as Vector3
		mound.name = "SnowMound"
		add_child(mound)
		var tw: Tween = mound.create_tween()
		tw.tween_interval(SNOW_MOUND_TIME * 0.7)
		tw.tween_property(mound, ^"scale", Vector3(1.0, 0.05, 1.0), SNOW_MOUND_TIME * 0.3)
		tw.tween_callback(mound.queue_free)


func get_snow_mound_count() -> int:
	var n: int = 0
	for c: Node in get_children():
		if c.name.begins_with("SnowMound") and not c.is_queued_for_deletion():
			n += 1
	return n


# ---------------------------------------------------------------------------
# Estalactites
# ---------------------------------------------------------------------------

func _build_stalactites() -> void:
	# [centro x, z, rotação°, alturas do teto (m acima do chão) por posição ao longo do arco]
	var arches: Array = [
		[4.0, -16.0, 45.0, [[-1.6, 3.9], [0.0, 4.4], [1.5, 3.9]]],
		[0.0, -28.5, 0.0, [[-1.3, 3.3], [0.4, 3.6], [1.6, 3.0]]],
	]
	for a: Array in arches:
		var basis: Basis = Basis(Vector3.UP, deg_to_rad(float(a[2])))
		for spot: Array in a[3]:
			var p: Vector3 = Vector3(float(a[0]), 0.0, float(a[1])) + basis * Vector3(float(spot[0]), 0.0, 0.0)
			var ground: float = GlacierTerrain.height_at(p.x, p.z)
			var top: Vector3 = Vector3(p.x, ground + float(spot[1]), p.z)
			var node: MeshInstance3D = _icicle()
			node.name = "Stalactite%d" % stalactites.size()
			node.position = top
			add_child(node)
			stalactites.append({"top": top, "ground": ground, "node": node, "fallen": false, "strain": 0.0})


## Host: a estalactite `i` cai (sombra primeiro). Público para testes.
func drop_stalactite(i: int) -> void:
	if not HostSync.is_host(self) or i < 0 or i >= stalactites.size() or bool(stalactites[i]["fallen"]):
		return
	stalactites[i]["fallen"] = true
	stalactites[i]["strain"] = 0.0
	_rpc_stalactite_fall(i)
	HostSync.broadcast(self, &"_rpc_stalactite_fall", [i])
	if not is_inside_tree():
		return
	get_tree().create_timer(STALACTITE_SHADOW_TIME + STALACTITE_FALL_TIME).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_inside_tree():
			_stalactite_impact(i))
	get_tree().create_timer(STALACTITE_REGROW).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_inside_tree():
			_regrow(i))


func _stalactite_impact(i: int) -> void:
	var s: Dictionary = stalactites[i]
	var hit: Vector3 = Vector3((s["top"] as Vector3).x, float(s["ground"]), (s["top"] as Vector3).z)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Node3D = n as Node3D
		if p == null:
			continue
		var d: Vector3 = p.global_position - hit
		if Vector2(d.x, d.z).length() <= STALACTITE_HIT_RADIUS:
			_hurt_player(p, STALACTITE_DAMAGE)
			_push_player(p, Vector3(d.x, 0.0, d.z).normalized() * 4.0 + Vector3.UP * 2.0, 0.4)


@rpc("authority", "call_remote", "reliable")
func _rpc_stalactite_fall(i: int) -> void:
	if i < 0 or i >= stalactites.size():
		return
	var s: Dictionary = stalactites[i]
	s["fallen"] = true
	var node: MeshInstance3D = s["node"]
	var top: Vector3 = s["top"]
	var ground: float = float(s["ground"])
	# sombra no chão que cresce até a estalactite cair
	var shadow: MeshInstance3D = _shadow()
	shadow.position = Vector3(top.x, ground + 0.05, top.z)
	shadow.scale = Vector3(0.2, 1.0, 0.2)
	add_child(shadow)
	var tw: Tween = create_tween()
	tw.tween_property(shadow, ^"scale", Vector3.ONE, STALACTITE_SHADOW_TIME)
	tw.parallel().tween_property(node, ^"rotation:z", 0.06, STALACTITE_SHADOW_TIME * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, ^"position:y", ground + 0.6, STALACTITE_FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		node.visible = false
		node.rotation = Vector3.ZERO
		node.position = top
		shadow.queue_free()
		SFX.play_at(SFX.SHELL_KNOCK, Vector3(top.x, ground, top.z), 6.0)
		_shards(Vector3(top.x, ground + 0.3, top.z)))


func _regrow(i: int) -> void:
	stalactites[i]["fallen"] = false
	_rpc_stalactite_regrow(i)
	HostSync.broadcast(self, &"_rpc_stalactite_regrow", [i])


@rpc("authority", "call_remote", "reliable")
func _rpc_stalactite_regrow(i: int) -> void:
	if i < 0 or i >= stalactites.size():
		return
	stalactites[i]["fallen"] = false
	var node: MeshInstance3D = stalactites[i]["node"]
	node.visible = true
	node.scale = Vector3(1.0, 0.1, 1.0)
	node.create_tween().tween_property(node, ^"scale", Vector3.ONE, 3.0)


## Quem entra a meio recebe as estalactites que já caíram.
@rpc("authority", "call_remote", "reliable")
func _rpc_stalactite_state(fallen_mask: int) -> void:
	for i: int in stalactites.size():
		var fallen: bool = (fallen_mask >> i) & 1 == 1
		stalactites[i]["fallen"] = fallen
		(stalactites[i]["node"] as Node3D).visible = not fallen


func _fallen_mask() -> int:
	var mask: int = 0
	for i: int in stalactites.size():
		if bool(stalactites[i]["fallen"]):
			mask |= 1 << i
	return mask


# ---------------------------------------------------------------------------
# Jogadores (a vida e a física são do dono, como nos inimigos)
# ---------------------------------------------------------------------------

func _hurt_player(p: Node, amount: float) -> void:
	if not p.has_method(&"apply_damage"):
		return
	if NetVisibility.is_online(multiplayer) and p.get_multiplayer_authority() != multiplayer.get_unique_id():
		p.rpc_id(p.get_multiplayer_authority(), &"apply_damage", amount, global_position)
	else:
		p.call(&"apply_damage", amount, global_position)


func _push_player(p: Node, impulse: Vector3, shake: float) -> void:
	if not p.has_method(&"apply_knockback"):
		return
	if NetVisibility.is_online(multiplayer) and p.get_multiplayer_authority() != multiplayer.get_unique_id():
		p.rpc_id(p.get_multiplayer_authority(), &"apply_knockback", impulse, shake)
	else:
		p.call(&"apply_knockback", impulse, shake)


# ---------------------------------------------------------------------------
# Visuais
# ---------------------------------------------------------------------------

func _icicle() -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3.ZERO, Vector3(0.0, -1.1, 0.0), 0.2, 0.0, 5, ICE)
	LowPolyMesh.prism(st, Vector3(0.12, 0.0, 0.05), Vector3(0.12, -0.55, 0.05), 0.09, 0.0, 4, ICE.lightened(0.2))
	return LowPolyMesh.commit(st, "Icicle", _mat)


func _chunk(size: float, color: Color) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0.0, -size * 0.5, 0.0), Vector3(0.0, size * 0.5, 0.0), size * 0.6, size * 0.4, 5, color)
	return LowPolyMesh.commit(st, "SnowChunk", _mat)


func _mound() -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3.ZERO, Vector3(0.0, 0.45, 0.0), 0.9, 0.35, 7, SNOW)
	return LowPolyMesh.commit(st, "SnowMound", _mat)


func _shadow() -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = STALACTITE_HIT_RADIUS
	disc.bottom_radius = STALACTITE_HIT_RADIUS
	disc.height = 0.02
	disc.radial_segments = 16
	mi.mesh = disc
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.05, 0.1, 0.2, 0.45)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _snow_dust(at: Vector3, seconds: float) -> void:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.position = at
	p.amount = 40
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(AVALANCHE_WIDTH * 0.5, 0.5, AVALANCHE_WIDTH * 0.5)
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0.0, -0.6, 0.0)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.7)
	quad.material = m
	p.mesh = quad
	add_child(p)
	p.emitting = true
	get_tree().create_timer(seconds + p.lifetime).timeout.connect(p.queue_free)


func _shards(at: Vector3) -> void:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.position = at
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 0.12)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = ICE
	box.material = m
	p.mesh = box
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)
