class_name SteamGeyser
extends Node3D

## Gêiser de vapor numa fenda da Cratera (#96). Ciclo previsível: repouso -> aviso (silvo e
## fiapos de vapor, a fenda acende) -> jato que lança para cima quem estiver por cima, jogadores
## e itens. Chão marcado com uma fenda violeta para se ver onde é. O host corre o ciclo e anuncia
## cada fase (rpc); cada peer lança o seu jogador local e o host empurra os itens (ItemPickup.push).

enum Phase { IDLE, WARN, BURST }

const FISSURE: Color = Color(0.72, 0.28, 0.95)
const RIM: Color = Color(0.2, 0.18, 0.24)
const STEAM: Color = Color(0.92, 0.9, 0.98, 0.7)

@export var idle_time: float = 7.0
@export var warn_time: float = 1.6
@export var burst_time: float = 1.2
## Desfasamento inicial (s) para os gêiseres não dispararem todos juntos.
@export var phase_offset: float = 0.0
@export var radius: float = 1.3
@export var launch_speed: float = 11.0
@export var item_launch: float = 7.0

var phase: Phase = Phase.IDLE
var _left: float = 0.0
var _crack: MeshInstance3D = null
var _steam: CPUParticles3D = null
var _wisps: CPUParticles3D = null


func _ready() -> void:
	_left = idle_time + phase_offset
	_build()


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_left -= delta
	if _left > 0.0:
		return
	match phase:
		Phase.IDLE:
			_announce(Phase.WARN)
		Phase.WARN:
			_announce(Phase.BURST)
		Phase.BURST:
			_announce(Phase.IDLE)


func _announce(p: Phase) -> void:
	_left = {Phase.IDLE: idle_time, Phase.WARN: warn_time, Phase.BURST: burst_time}[p]
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_rpc_phase.rpc(int(p))
	else:
		_rpc_phase(int(p))


## Dispara já (atalho de debug/bot: passo "call" com method "trigger").
func trigger() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_announce(Phase.BURST)


@rpc("authority", "call_local", "reliable")
func _rpc_phase(p: int) -> void:
	phase = p as Phase
	if _wisps != null:
		_wisps.emitting = phase == Phase.WARN
	if _steam != null:
		_steam.emitting = phase == Phase.BURST
	if _crack != null and _crack.material_override is StandardMaterial3D:
		var m: StandardMaterial3D = _crack.material_override as StandardMaterial3D
		m.albedo_color = FISSURE.lightened(0.35) if phase != Phase.IDLE else FISSURE.darkened(0.25)
	if phase == Phase.WARN:
		SFX.play_at(SFX.SLINGSHOT_FIRE, global_position, -6.0, 0.15)
	elif phase == Phase.BURST:
		SFX.play_at(SFX.PLAYER_DEATH, global_position, -4.0, 0.15)
		_launch()


func is_over(pos: Vector3) -> bool:
	var d: Vector3 = pos - global_position
	return Vector2(d.x, d.z).length() <= radius and d.y > -0.6 and d.y < 2.5


## Jogador local de cada peer (é dono da própria física); itens só no host.
func _launch() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var local: Node3D = tree.get_first_node_in_group(&"player") as Node3D
	if local != null and local.is_inside_tree() and local.has_method("apply_knockback") and is_over(local.global_position):
		local.call("apply_knockback", Vector3.UP * launch_speed, 0.05)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	for n: Node in tree.get_nodes_in_group(ItemPickup.GROUP):
		var pk: ItemPickup = n as ItemPickup
		if pk != null and is_instance_valid(pk) and pk.is_inside_tree() and is_over(pk.global_position):
			pk.push(Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6)).normalized() * item_launch)


func _build() -> void:
	# Fenda marcada no chão: losango violeta com borda de basalto.
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in 6:
		var a: float = TAU * float(k) / 6.0
		var p: Vector3 = Vector3(cos(a) * (radius + 0.15), 0.0, sin(a) * (radius + 0.15))
		LowPolyMesh.prism(st, p + Vector3.DOWN * 0.1, p + Vector3.UP * 0.22, 0.28, 0.12, 4, RIM)
	var rim: MeshInstance3D = MeshInstance3D.new()
	rim.name = "Rim"
	rim.mesh = ToonKit.commit(st)
	rim.material_override = ToonKit.vertex_material(true, true)
	add_child(rim)
	var crack_mesh: BoxMesh = BoxMesh.new()
	crack_mesh.size = Vector3(radius * 1.7, 0.03, 0.35)
	_crack = MeshInstance3D.new()
	_crack.name = "Crack"
	_crack.mesh = crack_mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = FISSURE.darkened(0.25)
	_crack.material_override = mat
	_crack.position.y = 0.03
	_crack.rotation.y = 0.5
	_crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_crack)
	var crack2: MeshInstance3D = _crack.duplicate() as MeshInstance3D
	crack2.rotation.y = -0.7
	crack2.scale = Vector3(0.7, 1, 1)
	crack2.material_override = mat
	add_child(crack2)
	_wisps = _steam_particles(10, 0.8, 1.5, 0.2)
	add_child(_wisps)
	_steam = _steam_particles(110, 1.0, 11.0, 0.22)
	add_child(_steam)


func _steam_particles(amount: int, lifetime: float, speed: float, size: float) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -1.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.25
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.6
	var m: BoxMesh = BoxMesh.new()
	m.size = Vector3.ONE * size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = STEAM
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	p.mesh = m
	p.emitting = false
	return p
