class_name GoldColossus
extends EnemyBase

## Colosso do Tesouro (#114): o chefe disfarçado da Ilha do Tesouro. Dorme como a maior pilha de
## ouro do Monte do Tesouro; quando a equipa mexe no tesouro certo (ou desenterra demasiado), as
## moedas, baús e ídolos levantam voo e juntam-se num gigante de ouro gasto com olhos de rubi.
##   - MURRO NO CHÃO: ergue os punhos (círculo no chão) e esmaga; onda de choque empurra todos;
##   - JORRO DE MOEDAS: abre o peito e cospe moedas em leque (linhas no chão; 3 na fase 2);
##   - GASTO: depois do jorro fica sem moedas no peito, o núcleo de rubi à vista (dano 2,5x).
## Fase 2 (vida < 50 %): mais rápido, leque mais largo, murros seguidos.
## Ao morrer desfaz-se numa chuva de ouro e solta o tesouro principal e achados de topo.
## Coop (#24): IA no host; estado, ponto e direção do ataque replicados.

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { ASSEMBLE, WALK, SLAM_TELE, SLAM, SPRAY_TELE, SPRAY, SPENT, DYING }

const BOSS_ID: StringName = &"gold_colossus"
const BOSS_NAME: String = "COLOSSO DO TESOURO"
const GROUP_BOSSES: StringName = &"bosses"
## Tesouro principal (vai para o Museu) e achados que caem com ele.
const TROPHY_ITEM_ID: String = "idolo_ouro"
const LOOT_ITEM_IDS: Array[String] = ["relogio_ouro", "mascara_ouro", "idolo_jade", "calice_prata"]

const WEAK_POINT_MULTIPLIER: float = 2.5
const PHASE_TWO_RATIO: float = 0.5
const SLAM_RADIUS: float = 4.2
const SPRAY_RANGE: float = 13.0
const SPRAY_WIDTH: float = 1.6
const SPRAY_FAN: float = 0.45
const ASSEMBLE_TIME: float = 2.8

const GOLD: Color = TreasureModel.GOLD
const GOLD_LIGHT: Color = TreasureModel.GOLD_LIGHT
const GOLD_WORN: Color = TreasureModel.GOLD_WORN
const PATINA: Color = TreasureModel.PATINA
const RUST: Color = TreasureModel.RUST
const RUBY: Color = TreasureModel.RUBY
const WOOD: Color = TreasureModel.WOOD

@export var move_speed: float = 2.0
@export var turn_speed: float = 2.6
@export var slam_damage: float = 24.0
@export var spray_damage: float = 14.0
@export var slam_telegraph: float = 1.15
@export var spray_telegraph: float = 1.0
@export var spent_time: float = 3.2
@export var attack_cooldown: float = 1.5

var state: State = State.ASSEMBLE
var phase: int = 1
var net_attack_dir: Vector3 = Vector3.FORWARD:
	set(value):
		net_attack_dir = value
		if not has_simulation_authority() and is_node_ready():
			_refresh_visuals()

var _state_time: float = 0.0
var _cooldown: float = 1.0
var _attack_cycle: int = 0
var _hit_done: bool = false
var _anim_time: float = 0.0
var _death_done: bool = false
var _hidden_pile: Node3D = null

var _hud: BossHud = null
var _warnings: Array[GroundWarning] = []
var _body_root: Node3D = null
## [nó, posição de repouso, posição de partida (na pilha)] de cada peça que se monta.
var _parts: Array = []
var _arm_left: Node3D = null
var _arm_right: Node3D = null
var _chest_coins: Node3D = null
var _core: MeshInstance3D = null


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	stun_fx_height = 3.4
	death_color = GOLD
	_build_model()
	_hud = BossHud.create("💰 " + tr(BOSS_NAME), max_health, Color(0.98, 0.78, 0.3))
	add_child(_hud)
	for i: int in 3:
		var w: GroundWarning = GroundWarning.new()
		add_child(w)
		_warnings.append(w)
	boss_defeated.connect(_report_defeat_to_core)
	_hide_disguise()
	_enter_state(State.ASSEMBLE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_attack_dir")


## Em todos os peers: esconde a pilha de ouro por onde o colosso se fazia passar.
func _hide_disguise() -> void:
	var best: float = 2.5
	for n: Node in get_tree().get_nodes_in_group(&"island_treasures"):
		var t: Node3D = n as Node3D
		if t == null or not t.visible:
			continue
		var d: float = Vector2(t.global_position.x - global_position.x, t.global_position.z - global_position.z).length()
		if d < best:
			best = d
			_hidden_pile = t
	if _hidden_pile != null:
		_hidden_pile.visible = false
		var body: Node = _hidden_pile.get_node_or_null(^"Body")
		if body is CollisionObject3D:
			(body as CollisionObject3D).collision_layer = 0


func _exit_tree() -> void:
	super._exit_tree()
	# Fugiu (300 s) ou a expedição acabou: a pilha volta ao sítio. Vencido: o tesouro já saiu.
	if _hidden_pile != null and is_instance_valid(_hidden_pile) and not _dead:
		_hidden_pile.visible = true
		var body: Node = _hidden_pile.get_node_or_null(^"Body")
		if body is CollisionObject3D:
			(body as CollisionObject3D).collision_layer = 1


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	var k: float = 0.8 if phase == 2 else 1.0
	match state:
		State.ASSEMBLE:
			if _state_time >= ASSEMBLE_TIME:
				_hud.visible = true
				_enter_state(State.WALK)
		State.WALK:
			_process_walk(delta)
		State.SLAM_TELE:
			_pulse(delta)
			_face(net_attack_dir, delta)
			if _state_time >= slam_telegraph * k:
				_enter_state(State.SLAM)
		State.SLAM:
			if not _hit_done and _state_time >= 0.12:
				_hit_done = true
				_execute_slam()
			if _state_time >= 0.6:
				# fase 2: segundo murro seguido de vez em quando
				if phase == 2 and _attack_cycle % 2 == 0 and _state_time < 0.65:
					_attack_cycle += 1
					_enter_state(State.SLAM_TELE)
				else:
					_enter_state(State.WALK)
		State.SPRAY_TELE:
			_pulse(delta)
			_face(net_attack_dir, delta)
			if _state_time >= spray_telegraph * k:
				_enter_state(State.SPRAY)
		State.SPRAY:
			if not _hit_done and _state_time >= 0.1:
				_hit_done = true
				_execute_spray()
			if _state_time >= 0.6:
				_enter_state(State.SPENT)
		State.SPENT:
			if _state_time >= spent_time:
				_cooldown = attack_cooldown
				_enter_state(State.WALK)


func _process(delta: float) -> void:
	_anim_time += delta
	_animate(delta)
	if state == State.DYING and _dead:
		_state_time += delta
		_process_dying()
	elif not has_simulation_authority():
		_state_time += delta
		_hud.set_health(health)
		_pulse(delta)


func _pulse(delta: float) -> void:
	for w: GroundWarning in _warnings:
		if w.visible:
			w.pulse(delta)


# --- Estados e ataques ---------------------------------------------------------

func _enter_state(s: State) -> void:
	state = s
	_state_time = 0.0
	_hit_done = false
	match s:
		State.ASSEMBLE:
			collision_layer = 0
			SFX.play_at(SFX.EMERGE_SAND, global_position, 6.0)
		State.WALK:
			collision_layer = 8
		State.SLAM:
			SFX.play_at(SFX.PLAYER_DEATH, global_position, 6.0, 0.15)
		State.SPRAY:
			SFX.play_at(SFX.SLINGSHOT_FIRE, global_position, 6.0, 0.15)
		State.SPENT:
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 5.0)
	_refresh_visuals()


func _process_walk(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	_cooldown -= delta
	if target == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var dir: Vector3 = to / dist if dist > 0.01 else Vector3.FORWARD
	_face(dir, delta)
	if _cooldown <= 0.0:
		_attack_cycle += 1
		net_attack_dir = dir
		if dist <= SLAM_RADIUS * 0.9 or _attack_cycle % 3 != 0:
			if dist <= SLAM_RADIUS + 1.5:
				_enter_state(State.SLAM_TELE)
				return
		if dist <= SPRAY_RANGE:
			_enter_state(State.SPRAY_TELE)
			return
	var spd: float = move_speed * (1.3 if phase == 2 else 1.0)
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	move_and_slide()


## Direções do leque do jorro (1 na fase 1, 3 na fase 2).
func spray_dirs() -> Array[Vector3]:
	var out: Array[Vector3] = [net_attack_dir]
	if phase == 2:
		out.append(net_attack_dir.rotated(Vector3.UP, SPRAY_FAN))
		out.append(net_attack_dir.rotated(Vector3.UP, -SPRAY_FAN))
	return out


func _execute_slam() -> void:
	spawn_particles(global_position + Vector3.UP * 0.3, GOLD, 40, 6.0)
	for p: Node3D in _all_players():
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() <= SLAM_RADIUS:
			_deal_damage(p, slam_damage)
			var out: Vector3 = d.normalized() if d.length() > 0.1 else net_attack_dir
			_knockback(p, out * 12.0 + Vector3.UP * 6.0, 0.14)


func _execute_spray() -> void:
	spawn_particles(global_position + Vector3.UP * 2.0, GOLD_LIGHT, 50, 9.0)
	for p: Node3D in _all_players():
		for dir: Vector3 in spray_dirs():
			if _in_line(p.global_position, dir):
				_deal_damage(p, spray_damage)
				_knockback(p, dir * 9.0 + Vector3.UP * 3.0, 0.06)
				break


func _in_line(pos: Vector3, dir: Vector3) -> bool:
	var to: Vector3 = pos - global_position
	to.y = 0.0
	var along: float = to.dot(dir)
	if along < 0.0 or along > SPRAY_RANGE:
		return false
	return (to - dir * along).length() <= SPRAY_WIDTH * 0.5 + 0.4


func _face(dir: Vector3, delta: float) -> void:
	_turn_towards(dir, 0.0, turn_speed, delta)


# --- Regras de combate ---------------------------------------------------------

func is_phase_two() -> bool:
	return health < max_health * PHASE_TWO_RATIO


func is_weak_point_exposed() -> bool:
	return state == State.SPENT


func _can_take_damage() -> bool:
	return state != State.ASSEMBLE and state != State.DYING


func _can_be_stunned() -> bool:
	return state == State.WALK or state == State.SPENT


func _modify_damage(amount: float, _from: Vector3) -> float:
	return amount * WEAK_POINT_MULTIPLIER if is_weak_point_exposed() else amount


func flee_from(_origin: Vector3, _seconds: float) -> void:
	pass


func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	super.take_damage(amount, from)
	if _dead or not has_simulation_authority():
		return
	_hud.set_health(health)
	health_changed.emit(health, max_health)
	if phase == 1 and is_phase_two():
		phase = 2
		spawn_particles(global_position + Vector3.UP * 2.5, RUBY, 30, 5.0)


func wake_immediately() -> void:
	if state == State.ASSEMBLE:
		_state_time = ASSEMBLE_TIME
		_hud.visible = true
		_enter_state(State.WALK)


func _on_died() -> void:
	_hud.set_health(0.0)
	_set_stun_fx(false)
	_enter_state(State.DYING)
	set_physics_process(false)


func _process_dying() -> void:
	var t: float = clampf(_state_time / 2.2, 0.0, 1.0)
	# as peças voltam a cair e espalham-se: o ouro desfaz-se
	for part: Array in _parts:
		var n: Node3D = part[0]
		if is_instance_valid(n):
			n.position = (part[1] as Vector3).lerp((part[2] as Vector3) * 1.6, t * t)
	if not _death_done and _state_time >= 0.8:
		_death_done = true
		_hud.visible = false
		spawn_particles(global_position + Vector3.UP * 1.5, GOLD_LIGHT, 70, 7.0)
		if has_simulation_authority():
			var tree: SceneTree = get_tree()
			QuestRewards.drop_item(tree, TROPHY_ITEM_ID, global_position + Vector3.UP * 1.8, Vector3(0, 4.0, 0))
			for i: int in LOOT_ITEM_IDS.size():
				var a: float = TAU * float(i) / float(LOOT_ITEM_IDS.size())
				QuestRewards.drop_item(tree, LOOT_ITEM_IDS[i], global_position + Vector3.UP * 1.2,
					Vector3(cos(a) * 3.0, 4.5, sin(a) * 3.0))
		boss_defeated.emit(BOSS_ID)
	if _state_time >= 2.6:
		queue_free()


func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


func _on_remote_state(_new_state: int) -> void:
	_state_time = 0.0
	_hud.visible = state != State.ASSEMBLE and state != State.DYING
	_refresh_visuals()


func _refresh_visuals() -> void:
	for w: GroundWarning in _warnings:
		w.hide_warning()
	match state:
		State.SLAM_TELE:
			_warnings[0].show_circle(global_position, SLAM_RADIUS)
		State.SPRAY_TELE:
			var dirs: Array[Vector3] = spray_dirs()
			for i: int in dirs.size():
				_warnings[i].show_line(global_position, dirs[i], SPRAY_RANGE, SPRAY_WIDTH)
	if _chest_coins != null:
		_chest_coins.visible = state != State.SPENT
	if _core != null and _core.material_override is ShaderMaterial:
		var m: ShaderMaterial = _core.material_override as ShaderMaterial
		m.set_shader_parameter(&"flash_amount", 0.6 if state == State.SPENT else 0.0)


# --- Animação e modelo ---------------------------------------------------------

func _animate(_delta: float) -> void:
	if _body_root == null:
		return
	if state == State.ASSEMBLE:
		# cada peça voa da pilha para o seu lugar, umas atrás das outras
		var t: float = clampf(_state_time / ASSEMBLE_TIME, 0.0, 1.0)
		for i: int in _parts.size():
			var part: Array = _parts[i]
			var n: Node3D = part[0]
			var k: float = clampf(t * 1.6 - float(i) / float(_parts.size()) * 0.6, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			n.position = (part[2] as Vector3).lerp(part[1], k) + Vector3.UP * sin(k * PI) * 1.4
			n.scale = Vector3.ONE * lerpf(0.35, 1.0, k)
		return
	if state == State.DYING:
		return
	var bob: float = sin(_anim_time * 2.4) * 0.05
	_body_root.position.y = bob
	var raise: float = 0.0
	match state:
		State.SLAM_TELE:
			raise = clampf(_state_time / slam_telegraph, 0.0, 1.0) * 2.2
		State.SLAM:
			raise = lerpf(2.2, -0.4, clampf(_state_time / 0.15, 0.0, 1.0))
		State.SPRAY_TELE, State.SPRAY:
			raise = 0.6
	var swing: float = sin(_anim_time * 3.0) * 0.25 if state == State.WALK else 0.0
	if _arm_left != null:
		_arm_left.rotation.x = -raise + swing
	if _arm_right != null:
		_arm_right.rotation.x = -raise - swing


func _part(parent: Node3D, st: SurfaceTool, rest: Vector3, name_: String) -> Node3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ToonKit.commit(st)
	mi.material_override = ToonKit.vertex_material(true, true)
	var n: Node3D = Node3D.new()
	n.name = name_
	n.add_child(mi)
	parent.add_child(n)
	n.position = rest
	var a: float = randf() * TAU
	# parte da pilha onde o colosso dormia (à volta da origem, rente ao chão)
	var start: Vector3 = Vector3(cos(a) * randf_range(0.4, 1.4), 0.15, sin(a) * randf_range(0.4, 1.4))
	_parts.append([n, rest, start])
	return n


func _st() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _coins(st: SurfaceTool, center: Vector3, spread: Vector3, count: int, r: float) -> void:
	var tones: Array[Color] = [GOLD, GOLD_LIGHT, GOLD_WORN, GOLD, PATINA, RUST]
	for i: int in count:
		var p: Vector3 = center + Vector3(randf_range(-spread.x, spread.x), randf_range(-spread.y, spread.y), randf_range(-spread.z, spread.z))
		TreasureModel.coin(st, p, r, Basis.from_euler(Vector3(randf_range(-1.2, 1.2), randf() * TAU, randf_range(-1.2, 1.2))), tones[i % tones.size()])


func _build_model() -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 1.1
	cap.height = 3.8
	col.shape = cap
	col.position.y = 1.9
	add_child(col)
	_body_root = Node3D.new()
	_body_root.name = "Body"
	add_child(_body_root)
	# pernas: pilhas de moedas
	for side: float in [-0.55, 0.55]:
		var st: SurfaceTool = _st()
		LowPolyMesh.prism(st, Vector3(0, 0, 0), Vector3(0, 1.1, 0), 0.42, 0.34, 7, GOLD_WORN)
		_coins(st, Vector3(0, 0.55, 0), Vector3(0.3, 0.5, 0.3), 10, 0.1)
		_part(_body_root, st, Vector3(side, 0.0, 0), "Leg")
	# tronco: monte facetado de ouro com moedas e um cálice preso
	var torso: SurfaceTool = _st()
	LowPolyMesh.prism(torso, Vector3(0, 0, 0), Vector3(0, 1.6, 0), 0.95, 1.15, 8, GOLD)
	LowPolyMesh.prism(torso, Vector3(0, 1.6, 0), Vector3(0, 1.95, 0), 1.15, 0.7, 8, GOLD_WORN)
	LowPolyMesh.box(torso, Vector3(0.6, 0.9, 0.5), Vector3(0.3, 0.5, 0.3), Basis.from_euler(Vector3(0.2, 0.4, 0.1)), PATINA)
	LowPolyMesh.box(torso, Vector3(-0.7, 1.3, 0.3), Vector3(0.25, 0.4, 0.25), Basis.from_euler(Vector3(0.1, 0.8, -0.2)), RUST)
	_part(_body_root, torso, Vector3(0, 1.1, 0), "Torso")
	# peito aberto: moedas que se vão no jorro e o núcleo de rubi
	var chest: SurfaceTool = _st()
	_coins(chest, Vector3.ZERO, Vector3(0.45, 0.35, 0.12), 18, 0.12)
	_chest_coins = _part(_body_root, chest, Vector3(0, 2.1, 0.75), "ChestCoins")
	var core_st: SurfaceTool = _st()
	LowPolyMesh.prism(core_st, Vector3(0, -0.3, 0), Vector3(0, 0.3, 0), 0.26, 0.0, 6, RUBY)
	LowPolyMesh.prism(core_st, Vector3(0, -0.3, 0), Vector3(0, -0.55, 0), 0.26, 0.0, 6, RUBY.darkened(0.2))
	var core_node: Node3D = _part(_body_root, core_st, Vector3(0, 2.15, 0.6), "Core")
	_core = core_node.get_child(0) as MeshInstance3D
	# cabeça: baú com a tampa como boca, olhos de rubi e coroa de ídolo
	var head: SurfaceTool = _st()
	LowPolyMesh.box(head, Vector3(0, 0, 0), Vector3(1.0, 0.6, 0.75), Basis.IDENTITY, WOOD)
	LowPolyMesh.box(head, Vector3(0, 0.38, -0.05), Vector3(1.02, 0.18, 0.8), Basis(Vector3.RIGHT, -0.35), WOOD.darkened(0.25))
	for x: float in [-0.42, 0.42]:
		LowPolyMesh.box(head, Vector3(x, 0, 0), Vector3(0.08, 0.62, 0.78), Basis.IDENTITY, GOLD_WORN)
	for x: float in [-0.22, 0.22]:
		LowPolyMesh.box(head, Vector3(x, 0.08, 0.39), Vector3(0.16, 0.16, 0.04), Basis(Vector3.FORWARD, PI * 0.25), RUBY)
	LowPolyMesh.box(head, Vector3(0, -0.16, 0.39), Vector3(0.6, 0.06, 0.04), Basis.IDENTITY, GOLD_LIGHT)
	for i: int in 5:
		var a: float = TAU * float(i) / 5.0
		LowPolyMesh.prism(head, Vector3(cos(a) * 0.32, 0.5, sin(a) * 0.25), Vector3(cos(a) * 0.32, 0.85, sin(a) * 0.25), 0.08, 0.0, 4, GOLD_LIGHT)
	_part(_body_root, head, Vector3(0, 3.35, 0.05), "Head")
	# braços: colunas de moedas com punhos de ouro maciço (rodam no ombro)
	for side: float in [-1.0, 1.0]:
		var shoulder: Node3D = Node3D.new()
		shoulder.name = "Shoulder"
		_body_root.add_child(shoulder)
		shoulder.position = Vector3(side * 1.25, 2.8, 0)
		var arm: SurfaceTool = _st()
		LowPolyMesh.prism(arm, Vector3(0, 0, 0), Vector3(0, -1.4, 0.1), 0.32, 0.28, 6, GOLD_WORN)
		_coins(arm, Vector3(0, -0.7, 0), Vector3(0.25, 0.6, 0.25), 8, 0.09)
		LowPolyMesh.prism(arm, Vector3(0, -1.4, 0.1), Vector3(0, -2.05, 0.2), 0.5, 0.42, 7, GOLD)
		_part(shoulder, arm, Vector3.ZERO, "Arm")
		if side < 0.0:
			_arm_left = shoulder
		else:
			_arm_right = shoulder
	# ombros também partem da pilha (posição local ao ombro): corrige o ponto de partida
	for part: Array in _parts:
		var n: Node3D = part[0]
		if n.get_parent() != _body_root:
			part[2] = (part[2] as Vector3) - (n.get_parent() as Node3D).position
