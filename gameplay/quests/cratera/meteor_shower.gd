class_name MeteorShower
extends Node3D

## Chuva de meteoritos da Cratera (#96). De tempos a tempos o host escolhe um ponto, avisa
## todos (sombra que cresce no chão + rasto violeta no céu) e, no impacto, a explosão empurra
## jogadores, itens e inimigos (Dynamite.apply_blast, o mesmo caos físico da dinamite). Fica uma
## cratera fumegante com um ponto de escavação fresco (achado da Cratera) que queima ao toque
## durante HOT_TIME s. Host decide (timer, ponto, física, spot); os peers só desenham e cada um
## sente o calor no seu próprio jogador.

const DYNAMITE: Script = preload("res://gameplay/weapons/dynamite/dynamite.gd")
const WARN_TIME: float = 2.6
const FALL_HEIGHT: float = 38.0
const HOT_TIME: float = 10.0
const HOT_RADIUS: float = 1.4
const HOT_DPS: float = 4.0
const CRATER_LIFETIME: float = 40.0
const CRUST: Color = Color(0.22, 0.2, 0.22)
const RUST: Color = Color(0.5, 0.32, 0.18)
const FISSURE: Color = Color(0.72, 0.28, 0.95)
const SCORCH: Color = Color(0.12, 0.09, 0.14)

@export var interval_min: float = 75.0
@export var interval_max: float = 120.0
@export var first_delay: float = 45.0
## Meia largura da zona de impacto (centrada na origem do mapa).
@export var area_half: float = 22.0
## Raio à volta da base de entrega e do NPC onde não cai nada.
@export var keep_clear: Array[Vector3] = [Vector3(3.5, 0, 3.5), Vector3(-12.5, 0, 8.5)]
@export var keep_clear_radius: float = 6.0
@export var enabled: bool = true

var _timer: float = 0.0
var _count: int = 0
## [pos, tempo restante de calor] das crateras ainda quentes (em todos os peers).
var _hot: Array = []


func _ready() -> void:
	_timer = first_delay


func _physics_process(delta: float) -> void:
	_tick_hot(delta)
	if not enabled or not _is_host():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(interval_min, interval_max)
		trigger()


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _online() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## Lança um meteorito já (host). Sem ponto, escolhe um válido ao acaso. Devolve o ponto.
func trigger(at: Vector3 = Vector3.INF) -> Vector3:
	if not _is_host():
		return Vector3.INF
	var p: Vector3 = at if at != Vector3.INF else pick_point()
	p.y = CraterTerrain.height_at(p.x, p.z)
	_count += 1
	if _online():
		_rpc_incoming.rpc(p, _count)
	else:
		_rpc_incoming(p, _count)
	return p


## Ponto ao acaso na zona, fora das áreas protegidas.
func pick_point() -> Vector3:
	for i: int in 24:
		var p: Vector3 = Vector3(randf_range(-area_half, area_half), 0.0, randf_range(-area_half, area_half))
		if is_point_allowed(p):
			return p
	return Vector3(-area_half * 0.6, 0.0, -area_half * 0.6)


func is_point_allowed(p: Vector3) -> bool:
	if absf(p.x) > area_half or absf(p.z) > area_half:
		return false
	for c: Vector3 in keep_clear:
		if Vector2(p.x - c.x, p.z - c.z).length() < keep_clear_radius:
			return false
	return true


## Em todos os peers: aviso (sombra + rasto) e, passado WARN_TIME, o impacto.
@rpc("authority", "call_local", "reliable")
func _rpc_incoming(p: Vector3, n: int) -> void:
	var shadow: MeshInstance3D = _disc(1.6, Color(0.05, 0.03, 0.08, 0.55))
	shadow.name = "MeteorShadow%d" % n
	add_child(shadow)
	shadow.global_position = p + Vector3.UP * 0.06
	shadow.scale = Vector3(0.2, 1.0, 0.2)
	var st: Tween = shadow.create_tween()
	st.tween_property(shadow, "scale", Vector3.ONE, WARN_TIME)
	var rock: Node3D = _meteor_model()
	rock.scale = Vector3.ONE * 1.6
	rock.name = "Meteor%d" % n
	add_child(rock)
	var start: Vector3 = p + Vector3(-9.0, FALL_HEIGHT, 6.0)
	rock.global_position = start
	var trail: CPUParticles3D = _particles(60, 0.9, FISSURE, 0.4, Vector3.ZERO, 0.4)
	trail.local_coords = false
	rock.add_child(trail)
	trail.emitting = true
	var rt: Tween = rock.create_tween()
	rt.tween_property(rock, "global_position", p, WARN_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	rt.tween_callback(_impact.bind(p, rock, shadow))
	SFX.play_at(SFX.SLINGSHOT_FIRE, p, 2.0, 0.3)


func _impact(p: Vector3, rock: Node3D, shadow: Node3D) -> void:
	if is_instance_valid(shadow):
		shadow.queue_free()
	if is_instance_valid(rock):
		rock.queue_free()
	_crater_fx(p)
	_hot.append([p, HOT_TIME])
	if _is_host():
		DYNAMITE.call("apply_blast", get_tree(), p + Vector3.UP * 0.3, null)
		_spawn_fresh_spot(p)
	# O clarão/estrondo partilhado com a dinamite (cada peer tem o seu jogador local).
	var local: Node = get_tree().get_first_node_in_group(&"player")
	if local != null and local.has_method("show_explosion"):
		local.call("show_explosion", p)


## Host: ponto de escavação novo no fundo da cratera, pelo SpotSpawner (replica sozinho).
func _spawn_fresh_spot(p: Vector3) -> void:
	var spawner: Node = _find_spot_spawner()
	if spawner == null:
		return
	var net: MultiplayerSpawner = spawner.get("_net_spawner") as MultiplayerSpawner
	var item: ItemData = spawner.call("_pick_item") as ItemData if spawner.has_method("_pick_item") else null
	if net == null or item == null:
		return
	var map_data: MapData = spawner.get("map_data") as MapData
	var spot: Node = net.spawn({
		"n": 9000 + _count,
		"item_id": item.id,
		"rare": map_data != null and randf() < map_data.rare_variant_chance,
		"pos": (spawner as Node3D).to_local(p),
	})
	if spot != null:
		spot.add_to_group(&"meteor_spots")
		print("[MeteorShower] ponto fresco %s (%s) em %s" % [spot.name, item.id, p])


## O SpotSpawner é irmão do CrateraSecrets no mapa: sobe até um antepassado que o tenha.
func _find_spot_spawner() -> Node:
	var n: Node = get_parent()
	while n != null:
		var s: Node = n.get_node_or_null(^"SpotSpawner")
		if s != null:
			return s
		n = n.get_parent()
	return null


## Calor: só o jogador local de cada peer (é ele quem manda na própria vida).
func _tick_hot(delta: float) -> void:
	if _hot.is_empty():
		return
	var local: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	for i: int in range(_hot.size() - 1, -1, -1):
		var h: Array = _hot[i]
		h[1] = float(h[1]) - delta
		if float(h[1]) <= 0.0:
			_hot.remove_at(i)
			continue
		if local == null or not local.has_method("take_damage"):
			continue
		var c: Vector3 = h[0]
		if Vector2(local.global_position.x - c.x, local.global_position.z - c.z).length() <= HOT_RADIUS \
				and absf(local.global_position.y - c.y) < 2.0:
			local.call("take_damage", HOT_DPS * delta)
			if local.has_method("_show_temporary_message") and int(Time.get_ticks_msec() / 700) % 3 == 0:
				local.call("_show_temporary_message", "🔥 Ainda está quente! Espera arrefecer.", Color(1.0, 0.55, 0.25), 0.8)


func hot_count() -> int:
	return _hot.size()


# --- Visuais -------------------------------------------------------------------

func _crater_fx(p: Vector3) -> void:
	var crater: Node3D = Node3D.new()
	crater.name = "MeteorCrater%d" % _count
	add_child(crater)
	crater.global_position = p
	var scorch: MeshInstance3D = _disc(2.4, SCORCH)
	scorch.position.y = 0.04
	crater.add_child(scorch)
	# Lascas do meteorito à volta, com as fissuras violeta da referência.
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in 7:
		var a: float = TAU * float(k) / 7.0 + randf_range(-0.3, 0.3)
		var r: float = randf_range(1.2, 2.1)
		var base: Vector3 = Vector3(cos(a) * r, -0.1, sin(a) * r)
		var col: Color = CRUST if k % 3 else RUST
		LowPolyMesh.prism(st, base, base + Vector3(cos(a) * 0.15, randf_range(0.3, 0.6), sin(a) * 0.15), randf_range(0.18, 0.32), 0.05, 4, col)
	LowPolyMesh.prism(st, Vector3(0, -0.2, 0), Vector3(0, 0.35, 0), 0.45, 0.25, 6, FISSURE)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ToonKit.commit(st)
	mi.material_override = ToonKit.vertex_material(true, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crater.add_child(mi)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.25)
	glow.light_energy = 2.5
	glow.omni_range = 4.0
	glow.position.y = 0.6
	crater.add_child(glow)
	var smoke: CPUParticles3D = _particles(24, 2.2, Color(0.35, 0.3, 0.38, 0.8), 0.35, Vector3.UP, 1.2)
	smoke.position.y = 0.3
	crater.add_child(smoke)
	smoke.emitting = true
	var t: Tween = crater.create_tween()
	t.tween_property(glow, "light_energy", 0.0, HOT_TIME)
	t.tween_callback(func() -> void: smoke.amount = 6)
	t.tween_interval(CRATER_LIFETIME - HOT_TIME)
	t.tween_callback(crater.queue_free)


func _meteor_model() -> Node3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0, -0.45, 0), Vector3(0, 0.0, 0), 0.15, 0.55, 6, CRUST)
	LowPolyMesh.prism(st, Vector3(0, 0.0, 0), Vector3(0.1, 0.5, 0.05), 0.55, 0.12, 6, RUST)
	LowPolyMesh.box(st, Vector3(0, 0.02, 0), Vector3(1.15, 0.08, 0.12), Basis(Vector3.UP, 0.6), FISSURE)
	LowPolyMesh.box(st, Vector3(0, 0.02, 0), Vector3(0.12, 0.08, 1.1), Basis(Vector3.UP, 0.6), FISSURE)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ToonKit.commit(st)
	mi.material_override = ToonKit.vertex_material(true, true)
	var root: Node3D = Node3D.new()
	root.add_child(mi)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = FISSURE
	light.light_energy = 3.0
	light.omni_range = 6.0
	root.add_child(light)
	return root


func _disc(radius: float, color: Color) -> MeshInstance3D:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = 0.02
	m.radial_segments = 10
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _particles(amount: int, lifetime: float, color: Color, size: float, dir: Vector3, speed: float) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.direction = dir if dir != Vector3.ZERO else Vector3.UP
	p.spread = 25.0 if dir != Vector3.ZERO else 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var m: BoxMesh = BoxMesh.new()
	m.size = Vector3.ONE * size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	p.mesh = m
	return p
