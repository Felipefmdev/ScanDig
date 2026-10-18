class_name TideStrip
extends Node3D

## Maré da Praia (#94): a faixa molhada entre a praia e o mar (strip_x) só se cava na maré
## baixa, e na maré cheia o mar manda ondas que empurram as coisas soltas para a areia e às
## vezes deixam destroços (madeira, garrafas, conchas), com hipótese de um achado comum.
## O relógio é o da TideCycle (tide_path) do host. O host decide spots, ondas e achados; os
## outros peers recebem os spots pelo MultiplayerSpawner e as ondas por RPC, e cada peer avisa
## o seu jogador (HUD) a partir do relógio sincronizado da maré.

const BURIED_SPOT_SCENE: PackedScene = preload("res://items/buried_spot.tscn")
const MSG_LOW: String = "🌊 Maré baixa! A faixa molhada ficou descoberta: há coisas para cavar perto do mar."
const MSG_RISING: String = "🌊 A maré está subindo: os buracos da faixa molhada vão ficar debaixo da água!"
const MSG_HIGH: String = "🌊 Maré cheia: o mar cobriu a faixa molhada. As ondas trazem coisas à areia."
const MSG_COLOR: Color = Color(0.55, 0.85, 1.0)
const MSG_TIME: float = 4.0
const DEBRIS_LIFETIME: float = 60.0
const MAX_DEBRIS: int = 12

@export var tide_path: NodePath = ^"../Tide"
## Itens que podem sair nos spots da faixa e nos achados das ondas (o pool da Praia).
@export var map_data: MapData = null
## Faixa molhada (x de/até) e o comprimento em z onde nascem os spots de maré baixa.
@export var strip_x: Vector2 = Vector2(27.5, 29.8)
@export var strip_z: Vector2 = Vector2(-22.0, 22.0)
@export var spots_per_low_tide: int = 4
## Segundos antes do fim da maré baixa em que se avisa que a maré está a subir.
@export var warn_before_rise: float = 15.0
## Intervalo (s) entre ondas grandes na maré cheia e duração (s) de cada uma. A onda é um lençol
## de espuma que sobe a areia desde o mar até wash_x.x e volta (o mar é um plano que cobre o
## mapa todo: subi-lo inundava as covas do interior, por isso não se mexe no nível).
@export var wave_interval: Vector2 = Vector2(18.0, 30.0)
@export var wave_duration: float = 4.0
## x de onde a espuma parte (dentro de água na maré cheia).
@export var swash_start_x: float = 29.0
## Onde a onda deixa as coisas (x da areia molhada acima da água da maré cheia).
@export var wash_x: Vector2 = Vector2(24.5, 26.5)
## Itens soltos com x acima disto são empurrados para a areia pela onda.
@export var push_from_x: float = 21.0
@export_range(0.0, 1.0) var debris_chance: float = 0.6
@export_range(0.0, 1.0) var find_chance: float = 0.3
@export var max_finds_per_tide: int = 3

var _tide: TideCycle = null
var _spawner: MultiplayerSpawner = null
var _spots: Array[BuriedSpot] = []
var _spot_counter: int = 0
var _phase: int = -1  # 0 maré cheia, 1 maré baixa, 2 a subir (aviso dado)
var _wave_timer: float = 0.0
var _finds_this_tide: int = 0
var _debris_root: Node3D = null
var _debris_mat: ShaderMaterial = null
var _swash: MeshInstance3D = null
var _swash_mesh: ImmediateMesh = null
## Frente da espuma (x) enquanto uma onda corre; NAN sem onda.
var swash_front: float = NAN


func _ready() -> void:
	_tide = get_node_or_null(tide_path) as TideCycle
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "TideSpotSpawner"
	_spawner.spawn_path = NodePath("..")
	_spawner.spawn_function = _create_spot
	add_child(_spawner)
	_debris_root = Node3D.new()
	_debris_root.name = "Debris"
	add_child(_debris_root)
	_wave_timer = randf_range(wave_interval.x, wave_interval.y)
	_swash_mesh = ImmediateMesh.new()
	_swash = MeshInstance3D.new()
	_swash.name = "Swash"
	_swash.mesh = _swash_mesh
	_swash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var foam: StandardMaterial3D = StandardMaterial3D.new()
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.vertex_color_use_as_albedo = true
	foam.cull_mode = BaseMaterial3D.CULL_DISABLED
	_swash.material_override = foam
	add_child(_swash)


func _process(delta: float) -> void:
	if _tide == null:
		return
	var phase: int = current_phase()
	if phase != _phase:
		var first: bool = _phase == -1
		_phase = phase
		_on_phase_changed(phase, first)
	if _swash_mesh != null and (not is_nan(swash_front) or _swash_mesh.get_surface_count() > 0):
		_draw_swash()
	if HostSync.is_host(self) and phase == 0:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_wave_timer = randf_range(wave_interval.x, wave_interval.y)
			send_wave()


## 0 = maré cheia, 1 = maré baixa, 2 = maré baixa a acabar (a subir em breve).
func current_phase() -> int:
	if _tide == null:
		return 0
	if _tide.cycle_time >= _tide.low_duration:
		return 0
	return 2 if _tide.cycle_time >= _tide.low_duration - warn_before_rise else 1


func _on_phase_changed(phase: int, first: bool) -> void:
	match phase:
		1:
			if not first:
				_notify(MSG_LOW)
			if HostSync.is_host(self):
				_finds_this_tide = 0
				_spawn_strip_spots()
		2:
			if not first:
				_notify(MSG_RISING)
		0:
			if not first:
				_notify(MSG_HIGH)
			if HostSync.is_host(self):
				_cover_strip_spots()


## Mensagem no HUD do jogador local deste peer.
func _notify(text: String) -> void:
	if not is_inside_tree():
		return
	for n: Node in get_tree().get_nodes_in_group(&"player"):
		if n.has_method(&"_show_temporary_message"):
			n.call(&"_show_temporary_message", text, MSG_COLOR, MSG_TIME)


# ---------------------------------------------------------------------------
# Spots da faixa molhada (host)
# ---------------------------------------------------------------------------

func get_strip_spots() -> Array[BuriedSpot]:
	var out: Array[BuriedSpot] = []
	for s: BuriedSpot in _spots:
		if is_instance_valid(s) and not s.is_queued_for_deletion():
			out.append(s)
	return out


func _spawn_strip_spots() -> void:
	if map_data == null or map_data.item_pool.is_empty() or not is_inside_tree():
		return
	var placed: Array[Vector3] = []
	for i: int in spots_per_low_tide:
		for attempt: int in 12:
			var x: float = randf_range(strip_x.x, strip_x.y)
			var z: float = randf_range(strip_z.x, strip_z.y)
			var too_close: bool = false
			for q: Vector3 in placed:
				if Vector2(q.x - x, q.z - z).length() < 4.0:
					too_close = true
					break
			if too_close:
				continue
			var pos: Vector3 = Vector3(x, BeachTerrain.height_at(x, z), z)
			placed.append(pos)
			_spawn_spot(pos, map_data.item_pool.pick_random() as ItemData)
			break


func _spawn_spot(world_pos: Vector3, item: ItemData) -> void:
	if item == null:
		return
	_spot_counter += 1
	var data: Dictionary = {"n": _spot_counter, "item_id": item.id, "pos": to_local(world_pos)}
	# Como o SpotSpawner: o MultiplayerSpawner também serve offline (este processo é o servidor).
	var spot: BuriedSpot = _spawner.spawn(data) as BuriedSpot
	if spot != null:
		_spots.append(spot)


## spawn_function: corre no host e em cada cliente com os mesmos dados.
func _create_spot(data: Variant) -> Node:
	var d: Dictionary = data as Dictionary
	var spot: BuriedSpot = BURIED_SPOT_SCENE.instantiate() as BuriedSpot
	spot.name = "TideSpot%d" % int(d.get("n", 0))
	spot.networked = true
	var path: String = "res://items/catalog/%s.tres" % str(d.get("item_id", ""))
	spot.item = load(path) as ItemData if ResourceLoader.exists(path) else null
	spot.rare_decided = true
	spot.position = d.get("pos", Vector3.ZERO)
	return spot


## Maré cheia: o mar tapa os spots que ninguém acabou de cavar.
func _cover_strip_spots() -> void:
	for s: BuriedSpot in get_strip_spots():
		s.queue_free()
	_spots.clear()


# ---------------------------------------------------------------------------
# Ondas (o host decide, todos veem)
# ---------------------------------------------------------------------------

## Host: manda uma onda grande. Público para testes e para o bot.
func send_wave() -> void:
	if not HostSync.is_host(self):
		return
	var wave_seed: int = randi()
	_rpc_wave(wave_seed)
	HostSync.broadcast(self, &"_rpc_wave", [wave_seed])
	_push_loose_items()
	if _finds_this_tide < max_finds_per_tide and randf() < find_chance:
		_finds_this_tide += 1
		_wash_up_find(wave_seed)


@rpc("authority", "call_remote", "reliable")
func _rpc_wave(wave_seed: int) -> void:
	_play_swash()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = wave_seed
	if rng.randf() >= debris_chance:
		return
	for i: int in rng.randi_range(1, 3):
		var x: float = rng.randf_range(wash_x.x, wash_x.y)
		var z: float = rng.randf_range(strip_z.x, strip_z.y)
		_add_debris(rng.randi_range(0, 2), Vector3(x, BeachTerrain.height_at(x, z), z), rng.randf() * TAU)


## Host: a onda arrasta para a areia os itens soltos que estão na água/na faixa molhada.
func _push_loose_items() -> void:
	if not is_inside_tree():
		return
	for n: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var p: ItemPickup = n as ItemPickup
		if p == null or not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		if p.global_position.x >= push_from_x:
			p.push(Vector3(-randf_range(3.0, 5.0), 2.0, randf_range(-1.0, 1.0)))


## Espuma da onda: sobe a areia até wash_x.x em ~40 % do tempo e volta para o mar.
func _play_swash() -> void:
	if not is_inside_tree():
		return
	var tw: Tween = create_tween()
	swash_front = swash_start_x
	tw.tween_property(self, ^"swash_front", wash_x.x, wave_duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, ^"swash_front", swash_start_x, wave_duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: swash_front = NAN)


## Redesenha o lençol de espuma entre a frente da onda e o mar, colado à areia.
func _draw_swash() -> void:
	_swash_mesh.clear_surfaces()
	if is_nan(swash_front):
		return
	var back: float = swash_start_x + 1.0
	if swash_front >= back:
		return
	const STEP: float = 1.0
	const COLS: int = 3
	_swash_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var z: float = strip_z.x - 4.0
	while z < strip_z.y + 4.0:
		for c: int in COLS:
			var x0: float = lerpf(swash_front, back, float(c) / float(COLS))
			var x1: float = lerpf(swash_front, back, float(c + 1) / float(COLS))
			# a orla da frente é espuma branca, para trás fica água verde-clara transparente
			var a0: Color = Color(1.0, 1.0, 1.0, 0.85) if c == 0 else Color(0.75, 0.95, 0.95, 0.45)
			var a1: Color = Color(0.75, 0.95, 0.95, 0.45)
			var q: Array[Vector3] = [
				Vector3(x0, BeachTerrain.height_at(x0, z) + 0.04, z),
				Vector3(x1, BeachTerrain.height_at(x1, z) + 0.04, z),
				Vector3(x1, BeachTerrain.height_at(x1, z + STEP) + 0.04, z + STEP),
				Vector3(x0, BeachTerrain.height_at(x0, z + STEP) + 0.04, z + STEP),
			]
			var cols: Array[Color] = [a0, a1, a1, a0]
			for i: int in [0, 1, 2, 0, 2, 3]:
				_swash_mesh.surface_set_color(cols[i])
				_swash_mesh.surface_add_vertex(to_local(q[i]))
		z += STEP
	_swash_mesh.surface_end()


## Host: um achado comum fica na areia onde a onda rebentou.
func _wash_up_find(wave_seed: int) -> void:
	var commons: Array[ItemData] = []
	if map_data != null:
		for it: ItemData in map_data.item_pool:
			if it != null and it.category == ItemData.Category.COMUM:
				commons.append(it)
	if commons.is_empty():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = wave_seed ^ 0x5eed
	var item: ItemData = commons[rng.randi_range(0, commons.size() - 1)]
	var x: float = rng.randf_range(wash_x.x, wash_x.y)
	var z: float = rng.randf_range(strip_z.x, strip_z.y)
	QuestRewards.drop_item(get_tree(), item.id, Vector3(x, BeachTerrain.height_at(x, z) + 0.4, z), Vector3(-1.5, 1.5, 0.0))


## Destroço decorativo deixado pela onda (madeira, garrafa ou concha). Só visual, em cada peer.
func _add_debris(kind: int, pos: Vector3, yaw: float) -> void:
	if _debris_root.get_child_count() >= MAX_DEBRIS:
		_debris_root.get_child(0).queue_free()
	if _debris_mat == null:
		_debris_mat = ToonKit.vertex_material(true, true)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		0:  # tábua gasta
			LowPolyMesh.box(st, Vector3(0.0, 0.03, 0.0), Vector3(0.9, 0.06, 0.18), Basis.IDENTITY, Color("#8a6a48"))
			LowPolyMesh.box(st, Vector3(0.25, 0.065, 0.0), Vector3(0.05, 0.01, 0.16), Basis.IDENTITY, Color("#5e4630"))
		1:  # garrafa deitada
			LowPolyMesh.prism(st, Vector3(-0.12, 0.05, 0.0), Vector3(0.1, 0.05, 0.0), 0.05, 0.05, 6, Color("#6f9a62"))
			LowPolyMesh.prism(st, Vector3(0.1, 0.05, 0.0), Vector3(0.18, 0.05, 0.0), 0.05, 0.02, 6, Color("#6f9a62"))
		_:  # concha
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.05, 0.03), 0.09, 0.03, 7, Color("#f0c8b0"))
	var mi: MeshInstance3D = LowPolyMesh.commit(st, "Debris", _debris_mat)
	mi.position = pos
	mi.rotation.y = yaw
	_debris_root.add_child(mi)
	get_tree().create_timer(DEBRIS_LIFETIME).timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free())


func get_debris_count() -> int:
	return _debris_root.get_child_count() if _debris_root != null else 0
