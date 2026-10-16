class_name Player
extends CharacterBody3D

signal health_changed(current: float, max_value: float)
signal died

@export var speed: float = 4.5
@export var jump_velocity: float = 4.2
@export var mouse_sensitivity: float = 0.0025
@export var dig_range: float = 1.8
## Nível da pá: cada nível reduz o cooldown de escavação e o dano à integridade dos itens.
## Com GameState vem do upgrade "shovel" (1 a 4, ver _apply_shovel_level).
@export_range(1, 10) var shovel_level: int = 1

@export_group("Vida")
@export var max_health: float = 100.0

@export_group("Golpe com a Pá")
@export var attack_damage: float = 25.0
@export var attack_range: float = 2.2
@export var attack_cooldown: float = 0.6
## Cosseno do meio-ângulo do cone à frente do jogador (0.5 = 60° para cada lado).
@export_range(-1.0, 1.0, 0.05) var attack_cone_dot: float = 0.5

@export_group("Mochila e Interação")
## Alcance do raycast da câmara para apanhar itens.
@export var interact_range: float = 2.5
## Cone frontal de recurso quando o raycast não acerta (cosseno do meio-ângulo).
@export_range(-1.0, 1.0, 0.05) var pickup_cone_dot: float = 0.85
@export var drop_impulse: float = 1.4

@export_group("Ferramentas Compráveis")
@export var slingshot_damage: float = 20.0
@export var slingshot_cooldown: float = 0.8
@export var slingshot_speed: float = 22.0
@export var repellent_radius: float = 8.0
@export var repellent_flee_seconds: float = 8.0
@export var repellent_noise_reduction: float = 30.0
@export var net_trap_distance: float = 1.6
@export var medkit_heal: float = 40.0

@export_group("Forcado")
@export var pitchfork_damage: float = 35.0
@export var pitchfork_range: float = 3.2
@export var pitchfork_cooldown: float = 0.75
@export_range(-1.0, 1.0, 0.05) var pitchfork_cone_dot: float = 0.55
@export var pitchfork_knockback: float = 12.0
@export var pitchfork_stun: float = 0.5

@export_group("Som")
@export var footsteps_enabled: bool = true
## Volume dos passos na areia (dB). Baixo de propósito: é um som repetitivo.
@export_range(-40.0, 0.0) var footsteps_volume_db: float = -24.0

const BASE_DIG_COOLDOWN: float = 0.35
## Layer 5 (ItemPickup).
const PICKUP_MASK: int = 1 << 4
const GROUND_MASK: int = 1
const DIRT_CLOD_COLOR: Color = Color(0.78, 0.64, 0.42)
const DIRT_CLOD_LIFETIME: float = 3.0
const TOOL_SLINGSHOT: StringName = &"estilingue"
const TOOL_REPELLENT: StringName = &"repelente"
const TOOL_NET_TRAP: StringName = &"armadilha_rede"
const TOOL_MEDKIT: StringName = &"kit_medico"
const TOOL_LANTERN: StringName = &"lanterna_magnesio"
const TOOL_FORCADO: StringName = &"forcado"
## Recarga do clarão da Lanterna de Magnésio (#42).
const LANTERN_COOLDOWN: float = 4.0
## Empurrão (#57): segundos sem controlo por m/s de impulso, e o máximo.
const KNOCKBACK_TIME_PER_SPEED: float = 0.05
const KNOCKBACK_TIME_MAX: float = 0.9
## Modelos na mão (#37) das ferramentas sem nó próprio no player.tscn (o estilingue tem).
const MEDKIT_MODEL: Script = preload("res://gameplay/weapons/medkit/medkit_model.gd")
const REPELLENT_MODEL: Script = preload("res://gameplay/weapons/repellent/repellent_model.gd")
const PITCHFORK_MODEL: Script = preload("res://gameplay/weapons/pitchfork/pitchfork_model.gd")
## Ferramentas de que cada jogador só leva uma (em coop há um detetor por jogador no spawn).
const UNIQUE_TOOLS: Array[StringName] = [&"detector"]
const REPELLENT_COLOR: Color = Color(0.45, 1.0, 0.35, 0.85)
const SHOVEL_COOLDOWN_REDUCTION_PER_LEVEL: float = 0.25
const SHOVEL_DAMAGE_REDUCTION_PER_LEVEL: float = 0.15
const MIN_SHOVEL_DAMAGE_MULTIPLIER: float = 0.3
const THREAT_COLORS: Array[Color] = [
	Color(0.55, 0.75, 0.35),
	Color(0.95, 0.85, 0.25),
	Color(1.0, 0.55, 0.15),
	Color(0.95, 0.15, 0.15),
]
## #34: o que sai de uma pazada fora de um sinal, pelo chão de cada mapa (MapData.id).
const EMPTY_DIG_GROUND: Dictionary = {"praia": "Só areia...", "campo": "Só terra..."}
const EMPTY_DIG_DEFAULT: String = "Nada aqui..."
const MAX_MESSAGES: int = 3
## Linhas no total (uma descoberta tem 3-4): a pilha não desce até à mira em janelas pequenas.
const MAX_MESSAGE_LINES: int = 4
const MESSAGE_FONT_SIZE: int = 22
const THREAT_MESSAGE_FONT_SIZE: int = 30
const THREAT_MESSAGE_COLOR: Color = Color(1, 0.32, 0.2, 1)
const THREAT_MESSAGES: Array[String] = [
	"O chão treme...",
	"O chão treme... algo se mexe lá em baixo.",
	"O chão treme... O SUBSOLO ACORDOU!",
]

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var detector: MetalDetector = $Head/Camera3D/Hand/MetalDetector
@onready var shovel_rig: Node3D = $Head/Camera3D/ShovelRig
@onready var inventory: Inventory = $Inventory
@onready var dig_animator: ShovelDigAnimator = $ShovelDigAnimator
@onready var tool_view: Node3D = $Head/Camera3D/ToolView
@onready var slingshot_model: SlingshotModel = $Head/Camera3D/ToolView/Slingshot

# HUD Elements
## Pilha de mensagens temporárias (#32): no topo, por baixo do nome/barra do chefe (BossHud,
## y 70-125); o prompt [E] fica sozinho por baixo da mira.
@onready var message_stack: VBoxContainer = $HUD/MessageStack
@onready var session_info_label: Label = $HUD/SessionInfoLabel
@onready var threat_panel: Control = $HUD/ThreatPanel
@onready var threat_bar: ProgressBar = $HUD/ThreatPanel/ThreatBar
@onready var health_label: Label = $HUD/HealthPanel/HealthLabel
@onready var health_bar: ProgressBar = $HUD/HealthPanel/HealthBar
@onready var hotbar: Hotbar = $HUD/Hotbar
@onready var interact_prompt: Label = $HUD/InteractPrompt
@onready var avatar: PlayerAvatar = $Avatar
@onready var net_sync: MultiplayerSynchronizer = $NetSync

## Grupo com SÓ o jogador local (o desta máquina). Inimigos, DebugBridge e testes usam-no
## como "o jogador". Fase 1 do coop: os inimigos ainda correm em cada peer (#5 bloco F).
const LOCAL_GROUP: StringName = &"player"
## Grupo com todos os jogadores da cena (local + remotos).
const ALL_GROUP: StringName = &"players"

var health: float = 100.0
## Replicado (NetSync): o dono tem itens escavados na mochila? É o que has_loot()
## responde num jogador remoto (ex.: a gaivota no host escolhe quem roubar).
var carrying_loot: bool = false
## Ferramenta na mão (replicada para o avatar que os outros veem).
var held_tool_id: StringName = &"":
	set(value):
		held_tool_id = value
		if avatar != null:
			avatar.set_tool(value)

var _dig_cooldown: float = 0.0
var _attack_cooldown: float = 0.0
var _shake_tween: Tween = null
## #57: tempo a voar depois de um empurrão (sem controlo nem atrito no chão).
var _knockback_time: float = 0.0
var _threat_fill_style: StyleBoxFlat = null
var _spawn_transform: Transform3D = Transform3D.IDENTITY
var _target_pickup: ItemPickup = null
var _target_offer: ShopOffer = null
var _use_cooldown: float = 0.0
var _tool_view_rest: Vector3 = Vector3.ZERO
## tool_id -> modelo no ToolView (só um visível: o da ferramenta selecionada).
var _held_models: Dictionary = {}
## Distância percorrida desde o último passo (sons de passos na areia).
var _step_distance: float = 0.0
const STEP_LENGTH: float = 1.15
var _dig_target: BuriedSpot = null
var _dig_is_careful: bool = false
## Cliente: request_pickup pendente até este instante (evita pedidos repetidos com E).
var _pickup_pending_until: int = 0
const PICKUP_REQUEST_TIMEOUT_MS: int = 2000

# Contador de Sessão: total já entregue na base
var session_money: int = 0
var session_items_count: int = 0


## O PlayersRoot dá ao nó o nome do peer dono (str(peer_id)); fora do coop (testes,
## cenas antigas) o nome não é um número e a autoridade fica no peer local.
func _enter_tree() -> void:
	var owner_id: int = peer_id_from_name(name)
	if owner_id > 0:
		set_multiplayer_authority(owner_id)
	var local: bool = is_multiplayer_authority()
	# Antes de os filhos entrarem: um jogador remoto nunca rouba a câmara nem mostra HUD.
	var cam: Camera3D = get_node_or_null(^"Head/Camera3D") as Camera3D
	if cam != null:
		cam.current = local
		cam.visible = local  # mãos/pá/detector em 1.ª pessoa
	var hud: CanvasLayer = get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = local
	var body: Node3D = get_node_or_null(^"Avatar") as Node3D
	if body != null:
		body.visible = not local


static func peer_id_from_name(node_name: StringName) -> int:
	var s: String = String(node_name)
	return s.to_int() if s.is_valid_int() else 0


func is_local() -> bool:
	return is_multiplayer_authority()


func _ready() -> void:
	add_to_group(ALL_GROUP)
	net_sync.add_visibility_filter(_sync_visible_to)
	if not is_local():
		_setup_remote()
		return
	add_to_group(LOCAL_GROUP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ensure_default_input_mappings()
	_update_session_hud()

	_spawn_transform = global_transform
	health = max_health
	health_changed.connect(_on_health_changed)
	_on_health_changed(health, max_health)

	_setup_threat_hud()

	_apply_backpack_capacity()
	_apply_shovel_level()
	inventory.inventory_changed.connect(_on_inventory_changed)
	inventory.selected_slot_changed.connect(_on_selected_slot_changed)
	hotbar.bind(inventory)
	_on_inventory_changed()
	if interact_prompt != null:
		interact_prompt.text = ""

	dig_animator.setup(shovel_rig, camera, self)
	dig_animator.impact.connect(_on_shovel_impact)
	dig_animator.throw_dirt.connect(_on_shovel_throw_dirt)
	dig_animator.swing_hit.connect(_on_swing_hit)

	if tool_view != null:
		_tool_view_rest = tool_view.position
		_setup_held_models()
	if GameState.instance != null:
		GameState.instance.money_changed.connect(_on_team_money_changed)
		GameState.instance.upgrades_changed.connect(_on_upgrades_changed)


## Jogador de outro peer: só corpo + nome; posição/rotação chegam pelo NetSync.
func _setup_remote() -> void:
	set_physics_process(false)
	set_process_unhandled_input(false)
	var owner_id: int = get_multiplayer_authority()
	avatar.setup(owner_id, "Anfitrião" if owner_id == 1 else "Convidado")
	avatar.set_tool(held_tool_id)


## Visibilidade da replicação (spawn + sync) deste jogador para `peer_id`:
## - no host: só para peers com o mapa carregado (CoreSession.peer_scene_ready), senão o
##   cliente recebe "Node not found" a meio do carregamento;
## - num cliente (dono do seu jogador): para o host e para quem já tem um jogador na
##   cena (o host só cria o jogador de um peer depois de ele estar pronto).
func _sync_visible_to(peer_id: int) -> bool:
	if multiplayer.is_server():
		var sm: SessionManager = SessionManager.instance
		if sm == null or not sm.is_in_expedition():
			return true
		return sm.is_peer_scene_ready(peer_id)
	return peer_id == 1 or (get_parent() != null and get_parent().has_node(str(peer_id)))


func _ensure_default_input_mappings() -> void:
	_add_key_if_empty("move_forward", KEY_W)
	_add_key_if_empty("move_backward", KEY_S)
	_add_key_if_empty("move_left", KEY_A)
	_add_key_if_empty("move_right", KEY_D)
	_add_key_if_empty("jump", KEY_SPACE)
	_add_mouse_if_empty("use_tool", MOUSE_BUTTON_LEFT)
	_add_mouse_if_empty("careful_dig", MOUSE_BUTTON_RIGHT)
	_add_key_if_empty("attack", KEY_F)
	_add_key_if_empty("interact", KEY_E)
	_add_key_if_empty("drop", KEY_Q)
	_add_key_if_empty("slot_1", KEY_1)
	_add_key_if_empty("slot_2", KEY_2)
	_add_key_if_empty("slot_3", KEY_3)
	# Mochila Reforçada até 8 slots.
	_add_key_if_empty("slot_4", KEY_4)
	_add_key_if_empty("slot_5", KEY_5)
	_add_key_if_empty("slot_6", KEY_6)
	_add_key_if_empty("slot_7", KEY_7)
	_add_key_if_empty("slot_8", KEY_8)


func _add_key_if_empty(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var ev: InputEventKey = InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)


func _add_mouse_if_empty(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = button
		InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))

	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseButton and event.is_pressed():
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			inventory.cycle(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			inventory.cycle(1)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if _knockback_time > 0.0:
		_knockback_time -= delta
	elif direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	_update_footsteps(delta)

	# Aplica balanço procedural (sway) na haste do detector enquanto caminha
	if detector != null:
		var is_walking: bool = (velocity.length() > 0.2 and is_on_floor())
		detector.apply_walk_sway(is_walking, delta)

	if _dig_cooldown > 0.0:
		_dig_cooldown -= delta
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	if _use_cooldown > 0.0:
		_use_cooldown -= delta

	_handle_dig_actions()
	_handle_attack_action()
	_handle_inventory_actions()
	_handle_use_tool_action()


func _process(_delta: float) -> void:
	if not is_local():
		avatar.set_pitch(head.rotation.x)
		return
	_update_interaction_target()


## Botão direito saca a pá e cava: sozinho = pá rápida, com Shift = escavação cuidadosa.
## (A ação "careful_dig" é o botão direito no InputMap; o botão esquerdo já não cava.)
func _handle_dig_actions() -> void:
	if _dig_cooldown > 0.0 or dig_animator.is_playing():
		return
	if Input.is_action_just_pressed("careful_dig"):
		_perform_dig(Input.is_physical_key_pressed(KEY_SHIFT))


func get_dig_cooldown() -> float:
	var level_bonus: float = float(maxi(shovel_level, 1) - 1)
	return BASE_DIG_COOLDOWN / (1.0 + level_bonus * SHOVEL_COOLDOWN_REDUCTION_PER_LEVEL)


func get_dig_damage_multiplier() -> float:
	var level_bonus: float = float(maxi(shovel_level, 1) - 1)
	return maxf(MIN_SHOVEL_DAMAGE_MULTIPLIER, 1.0 - level_bonus * SHOVEL_DAMAGE_REDUCTION_PER_LEVEL)


## Fator de velocidade da animação de cavar (pás melhores cavam mais depressa).
func get_dig_speed_factor() -> float:
	return 1.0 + float(maxi(shovel_level, 1) - 1) * SHOVEL_COOLDOWN_REDUCTION_PER_LEVEL


func _perform_dig(is_careful: bool) -> void:
	var spots: Array[Node] = get_tree().get_nodes_in_group("buried_spots")
	var closest_spot: BuriedSpot = null
	var min_dist: float = dig_range + 0.1
	var player_pos: Vector3 = global_position

	for s: Node in spots:
		if s is BuriedSpot and s.is_inside_tree():
			var dist: float = player_pos.distance_to(s.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_spot = s

	var has_spot: bool = closest_spot != null and min_dist <= dig_range
	_dig_target = closest_spot if has_spot else null
	_dig_is_careful = is_careful

	# Ponto real do chão onde a lâmina vai cravar: no spot, ou à frente do jogador.
	var aim: Vector3
	if has_spot:
		aim = closest_spot.global_position
	else:
		var fwd: Vector3 = -global_basis.z
		fwd.y = 0.0
		aim = global_position + fwd.normalized() * 1.2
	var ground: Vector3 = _find_ground_point(aim)

	var duration: float = dig_animator.play(ground, is_careful, get_dig_speed_factor())
	_dig_cooldown = maxf(get_dig_cooldown(), duration)


func _find_ground_point(around: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		around + Vector3.UP * 1.5, around + Vector3.DOWN * 3.0, GROUND_MASK, [get_rid()]
	)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return Vector3(around.x, global_position.y, around.z)
	return hit["position"]


func _on_remote_dig_result(res: Dictionary, is_careful: bool, spot_pos: Vector3) -> void:
	# TODO Fase 3 (#5 G): barulho de quem cavou, reportado deste lado (o host cavou com
	# report_noise = false); com o DisturbanceMeter em rede isto passa a chegar ao host.
	DisturbanceMeter.report(
		DisturbanceMeter.NOISE_CAREFUL_DIG if is_careful else DisturbanceMeter.NOISE_FAST_DIG, spot_pos)
	if bool(res.get("revealed", false)) and res.get("item") != null:
		DisturbanceMeter.report(DisturbanceMeter.NOISE_REVEAL, spot_pos)
	_show_dig_feedback(res, is_careful)


## A lâmina cravou: só agora o dig() é aplicado.
func _on_shovel_impact(ground_point: Vector3) -> void:
	SFX.play_at(SFX.DIG_CAREFUL if _dig_is_careful else SFX.DIG_FAST, ground_point, -6.0 if _dig_is_careful else -3.0, 0.06)
	if not _dig_is_careful:
		_shake_camera(0.035, 0.2)
	var spot: BuriedSpot = _dig_target
	_dig_target = null
	if spot != null and is_instance_valid(spot) and spot.is_inside_tree() and spot.is_in_group("buried_spots"):
		if spot.networked and not multiplayer.is_server():
			# Coop (#5 D): o host cava e responde só a nós com o resultado.
			spot.remote_dig_result.connect(_on_remote_dig_result.bind(_dig_is_careful, spot.global_position),
				CONNECT_ONE_SHOT)
			spot.request_dig.rpc_id(1, _dig_is_careful, get_dig_damage_multiplier())
			return
		var res: Dictionary = spot.dig(_dig_is_careful, get_dig_damage_multiplier())
		_show_dig_feedback(res, _dig_is_careful)
	else:
		_show_temporary_message(get_empty_dig_message(), Color(0.95, 0.4, 0.4), 1.2)


func _on_shovel_throw_dirt(blade_position: Vector3, side: Vector3) -> void:
	# Os torrões caem ~0.45 s depois de saírem da lâmina.
	var land: Vector3 = blade_position + side * 1.0
	get_tree().create_timer(0.05).timeout.connect(func() -> void: SFX.play_at(SFX.DIRT_FALL, land, -8.0, 0.08))
	var count: int = randi_range(3, 6)
	var parent: Node = get_parent() if get_parent() != null else self
	var strength: float = 1.0 if _dig_is_careful else 1.6
	for i: int in count:
		_spawn_dirt_clod(parent, blade_position + Vector3(randf_range(-0.08, 0.08), 0.0, randf_range(-0.08, 0.08)),
			(side * randf_range(1.2, 2.2) + Vector3.UP * randf_range(1.6, 2.8)) * strength
			+ Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4)))


## Torrão de terra físico: não colide com o jogador (layer 0, só vê o chão) e some em ~3s.
func _spawn_dirt_clod(parent: Node, pos: Vector3, velocity_start: Vector3) -> void:
	var clod: RigidBody3D = RigidBody3D.new()
	clod.collision_layer = 0
	clod.collision_mask = GROUND_MASK
	clod.mass = 0.08
	var size: float = randf_range(0.05, 0.1)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3.ONE * size
	shape.shape = box
	clod.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var cube: BoxMesh = BoxMesh.new()
	cube.size = box.size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = DIRT_CLOD_COLOR.darkened(randf_range(0.0, 0.25))
	mat.roughness = 1.0
	cube.material = mat
	mesh.mesh = cube
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clod.add_child(mesh)
	parent.add_child(clod)
	clod.global_position = pos
	clod.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	clod.linear_velocity = velocity_start
	clod.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	var tween: Tween = clod.create_tween()
	tween.tween_interval(DIRT_CLOD_LIFETIME - 0.5)
	tween.tween_property(mesh, "scale", Vector3.ONE * 0.01, 0.5)
	tween.tween_callback(clod.queue_free)


func _show_dig_feedback(res: Dictionary, is_careful: bool) -> void:
	var revealed: bool = res.get("revealed", false)
	var dirt_left: int = res.get("dirt_layers", 0)
	var max_layers: int = res.get("max_layers", 3)
	var integrity: float = res.get("integrity", 1.0)
	var damaged: bool = res.get("damaged", false)
	var item: ItemData = res.get("item", null)
	var final_val: int = res.get("final_value", 0)
	var is_rare_variant: bool = res.get("is_rare_variant", false)
	var is_perfect: bool = res.get("is_perfect", false)

	if revealed:
		var rarity_str: String = _get_category_name(item.category if item != null else 0)
		var item_name: String = item.display_name if item != null else "Artefato Misterioso"
		var msg: String = ""
		var color: Color = Color(1.0, 0.88, 0.25)
		var duration: float = 3.5
		if is_rare_variant:
			msg += "✦ RARO ✦\n"
			color = Color(0.85, 0.55, 1.0)
			duration = 4.5
		msg += "★ DESCOBERTA: %s [%s]!\nIntegridade: %d%% | Valor: R$ %d" % [
			item_name, rarity_str, int(integrity * 100.0), final_val
		]
		if is_perfect:
			msg += "\n✔ ESCAVAÇÃO PERFEITA! (+25%)"
		msg += "\n[E] apanhar"
		_show_temporary_message(msg, color, duration)
	elif damaged:
		var layer_num: int = max_layers - dirt_left
		var msg: String = "💥 CRACK! Você bateu com a pá no objeto!\nIntegridade caiu para %d%% (Camada %d/%d)" % [
			int(integrity * 100.0), layer_num, max_layers
		]
		_show_temporary_message(msg, Color(1.0, 0.35, 0.35), 2.2)
	else:
		var tool_name: String = "Escavação Cuidadosa" if is_careful else "Pá Rápida"
		var layer_num: int = max_layers - dirt_left
		var msg: String = "⛏️ [%s] Escavando terra... (Camada %d/%d)" % [
			tool_name, layer_num, max_layers
		]
		_show_temporary_message(msg, Color(0.85, 0.95, 0.85), 1.6)


func _show_temporary_message(text: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	_push_message(text, color, duration, MESSAGE_FONT_SIZE, 8)


## Mete uma mensagem na pilha do HUD. A mesma mensagem repetida só renova o tempo (ex.: cavar
## várias vezes fora de um sinal); com mais de MAX_MESSAGES sai a mais antiga.
func _push_message(text: String, color: Color, duration: float, font_size: int, outline: int) -> void:
	if message_stack == null:
		return
	for child: Node in message_stack.get_children():
		var existing: Label = child as Label
		if existing != null and not existing.is_queued_for_deletion() and existing.text == text:
			_fade_message(existing, duration)
			return
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", outline)
	label.modulate.a = 0.0
	message_stack.add_child(label)
	var live: Array[Label] = []
	for child: Node in message_stack.get_children():
		if child is Label and not child.is_queued_for_deletion():
			live.append(child as Label)
	while live.size() > 1 and (live.size() > MAX_MESSAGES or _line_count(live) > MAX_MESSAGE_LINES):
		live.pop_front().queue_free()
	_fade_message(label, duration)


static func _line_count(labels: Array[Label]) -> int:
	var lines: int = 0
	for l: Label in labels:
		lines += l.text.count("\n") + 1
	return lines


func _fade_message(label: Label, duration: float) -> void:
	var old: Tween = label.get_meta(&"fade", null) as Tween
	if old != null and old.is_valid():
		old.kill()
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.08)
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)
	label.set_meta(&"fade", tween)


## Mensagem de uma pazada sem sinal por perto, com o chão do mapa atual.
func get_empty_dig_message() -> String:
	return empty_dig_message_for(_current_map_id())


static func empty_dig_message_for(map_id: String) -> String:
	var ground: String = str(EMPTY_DIG_GROUND.get(map_id, EMPTY_DIG_DEFAULT))
	return "❌ %s nenhum sinal aqui (aproxime-se de um sinal)" % ground


## Mapa atual: o da sessão (CoreSession) ou, em cenas abertas diretamente (bot, testes), o do
## SpotSpawner do mapa. "" se não houver nenhum.
func _current_map_id() -> String:
	var sm: SessionManager = SessionManager.instance
	if sm != null and sm.get_current_map() != null:
		return sm.get_current_map().id
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	var spawner: SpotSpawner = scene.get_node_or_null(^"SpotSpawner") as SpotSpawner if scene != null else null
	if spawner != null and spawner.map_data != null:
		return spawner.map_data.id
	return ""


## Textos que a pilha do HUD mostra agora (testes e dumps do bot).
func get_hud_messages() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if message_stack != null:
		for child: Node in message_stack.get_children():
			if child is Label and not child.is_queued_for_deletion():
				out.append((child as Label).text)
	return out


func _update_session_hud() -> void:
	if session_info_label == null:
		return
	var bag: String = "🎒 Mochila: %d/%d (R$ %d)" % [inventory.get_count(), inventory.capacity, inventory.get_total_value()]
	if GameState.instance != null:
		session_info_label.text = "%s | 💰 Equipa: R$ %d" % [bag, GameState.instance.team_money]
	else:
		session_info_label.text = "%s | 💰 Entregue: R$ %d" % [bag, session_money]


func _on_team_money_changed(_new_amount: int) -> void:
	_update_session_hud()


## Mochila Reforçada: slots = CoreGameState.get_backpack_capacity() (3 a 8).
## Cada peer lê o seu próprio GameState (o host sincroniza-o por snapshot).
func _apply_backpack_capacity() -> void:
	if GameState.instance != null:
		inventory.capacity = GameState.instance.get_backpack_capacity()


## Pá de Fibra: shovel_level = CoreGameState.get_shovel_level() (1 = pá básica, até 4).
func _apply_shovel_level() -> void:
	if GameState.instance != null:
		shovel_level = GameState.instance.get_shovel_level()


## Snapshot tardio (coop) pode trazer os níveis depois do _ready.
## A mochila só cresce: encolher a meio da expedição deitaria itens fora.
func _on_upgrades_changed(_levels: Dictionary) -> void:
	if GameState.instance == null:
		return
	_apply_shovel_level()
	if GameState.instance.get_backpack_capacity() > inventory.capacity:
		_apply_backpack_capacity()


func _get_category_name(cat: int) -> String:
	match cat:
		ItemData.Category.COMUM:
			return "Comum"
		ItemData.Category.HISTORICO:
			return "Histórico"
		ItemData.Category.RARO:
			return "Raro"
		ItemData.Category.ESTRANHO:
			return "Estranho"
	return "Comum"


# ---------------------------------------------------------------------------
# Ameaça do Subsolo (DisturbanceMeter)
# ---------------------------------------------------------------------------

func _setup_threat_hud() -> void:
	if threat_bar != null:
		var fill: StyleBox = threat_bar.get_theme_stylebox("fill")
		if fill is StyleBoxFlat:
			_threat_fill_style = (fill as StyleBoxFlat).duplicate() as StyleBoxFlat
			threat_bar.add_theme_stylebox_override("fill", _threat_fill_style)

	var meter: DisturbanceMeter = DisturbanceMeter.instance
	if meter == null:
		# Cena sem DisturbanceMeter: esconde o indicador.
		if threat_panel != null:
			threat_panel.visible = false
		return

	meter.noise_changed.connect(_on_noise_changed)
	meter.threshold_reached.connect(_on_threshold_reached)
	meter.threshold_cleared.connect(_on_threshold_cleared)
	_on_noise_changed(meter.current_noise, meter.max_noise)


func _on_noise_changed(current: float, max_noise: float) -> void:
	if threat_bar == null:
		return
	threat_bar.max_value = max_noise
	threat_bar.value = current
	_update_threat_color()


func _on_threshold_reached(level: int, _origin: Vector3) -> void:
	_update_threat_color()
	var idx: int = clampi(level - 1, 0, THREAT_MESSAGES.size() - 1)
	_show_threat_message(THREAT_MESSAGES[idx], 2.5 + float(level) * 0.5)
	_shake_camera(0.04 * float(level), 0.5 + 0.15 * float(level))


func _on_threshold_cleared(_level: int) -> void:
	_update_threat_color()


func _update_threat_color() -> void:
	if _threat_fill_style == null:
		return
	var level: int = DisturbanceMeter.instance.current_level if DisturbanceMeter.instance != null else 0
	_threat_fill_style.bg_color = THREAT_COLORS[clampi(level, 0, THREAT_COLORS.size() - 1)]


## Aviso da ameaça do subsolo: na mesma pilha, maior e a vermelho.
func _show_threat_message(text: String, duration: float) -> void:
	_push_message(text, THREAT_MESSAGE_COLOR, duration, THREAT_MESSAGE_FONT_SIZE, 10)


func _shake_camera(strength: float, duration: float) -> void:
	if camera == null:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps: int = maxi(int(duration / 0.04), 1)
	for i: int in steps:
		var falloff: float = 1.0 - float(i) / float(steps)
		var offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * falloff
		_shake_tween.tween_property(camera, "h_offset", offset.x, 0.04)
		_shake_tween.parallel().tween_property(camera, "v_offset", offset.y, 0.04)
	_shake_tween.tween_property(camera, "h_offset", 0.0, 0.05)
	_shake_tween.parallel().tween_property(camera, "v_offset", 0.0, 0.05)


# ---------------------------------------------------------------------------
# Vida
# ---------------------------------------------------------------------------

## Dano vindo de outro peer (contrato #5 B): `apply_damage.rpc_id(dono, amount, from)`.
## A vida é do dono; o `from` fica para efeitos futuros (empurrão, direção do golpe).
@rpc("any_peer", "call_local", "reliable")
func apply_damage(amount: float, _from: Vector3 = Vector3.INF) -> void:
	if is_local():
		take_damage(amount)


## #57: empurrão exagerado (inimigos/chefes). Como apply_damage: quem acerta chama
## `apply_knockback.rpc_id(dono, impulse, shake)` num jogador remoto; só o dono aplica.
@rpc("any_peer", "call_local", "reliable")
func apply_knockback(impulse: Vector3, shake: float = 0.0) -> void:
	if not is_local() or health <= 0.0:
		return
	velocity += impulse
	_knockback_time = clampf(impulse.length() * KNOCKBACK_TIME_PER_SPEED, 0.15, KNOCKBACK_TIME_MAX)
	if shake > 0.0:
		_shake_camera(shake, 0.3)


func take_damage(amount: float) -> void:
	# Num jogador remoto a vida não é nossa: quem acerta usa apply_damage.rpc_id(dono).
	if not is_local() or amount <= 0.0 or health <= 0.0:
		return
	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(health, max_health)
	_shake_camera(0.03, 0.25)
	if health > 0.0:
		SFX.play_ui(SFX.PLAYER_HURT, -2.0)
	if health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	health = clampf(health + amount, 0.0, max_health)
	health_changed.emit(health, max_health)


func _die() -> void:
	died.emit()
	SFX.play_ui(SFX.PLAYER_DEATH)
	dig_animator.cancel()
	var lost: int = _drop_all_items()
	var msg: String = "💀 Você desmaiou... e acordou de volta no ponto de partida."
	if lost > 0:
		msg += "\nA mochila caiu no local da morte (%d itens) — volte para apanhar!" % lost
	_show_temporary_message(msg, Color(1.0, 0.4, 0.4), 4.0)
	_respawn()


## Larga todos os itens da mochila espalhados à volta do jogador. Devolve quantos caíram.
func _drop_all_items() -> int:
	var items: Array[CarriedItem] = inventory.take_all()
	var parent: Node = get_parent()
	if parent == null:
		return 0
	var origin: Vector3 = global_position + Vector3.UP * 0.8
	for i: int in items.size():
		var angle: float = TAU * float(i) / float(items.size()) + randf_range(-0.3, 0.3)
		var dir: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		ItemPickup.spawn(parent, items[i], origin + dir * 0.3, dir * randf_range(0.8, 1.4) + Vector3.UP * 1.6)
	return items.size()


func _respawn() -> void:
	velocity = Vector3.ZERO
	global_transform = _spawn_transform
	if head != null:
		head.rotation.x = 0.0
	health = max_health
	health_changed.emit(health, max_health)
	get_tree().create_timer(0.35).timeout.connect(func() -> void: SFX.play_ui(SFX.RESPAWN, -6.0))


func _on_health_changed(current: float, max_value: float) -> void:
	if health_bar != null:
		health_bar.max_value = max_value
		health_bar.value = current
	if health_label != null:
		health_label.text = "❤ Vida: %d / %d" % [int(ceilf(current)), int(max_value)]


# ---------------------------------------------------------------------------
# Golpe corpo-a-corpo com a pá
# ---------------------------------------------------------------------------

func _handle_attack_action() -> void:
	if _attack_cooldown > 0.0 or dig_animator.is_playing():
		return
	if Input.is_action_just_pressed("attack"):
		var c: CarriedItem = inventory.get_selected()
		if c != null and c.tool_id == TOOL_FORCADO:
			if _use_cooldown <= 0.0:
				_attack_pitchfork()
		else:
			_perform_attack()


func get_attack_damage() -> float:
	return attack_damage * (1.0 + 0.2 * float(maxi(shovel_level, 1) - 1))


func _perform_attack() -> void:
	_attack_cooldown = attack_cooldown
	if dig_animator.play_swing() <= 0.0:
		_on_swing_hit()


func _on_swing_hit() -> void:
	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var origin: Vector3 = global_position
	var damage: float = get_attack_damage()
	var hits: int = 0

	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node3D) or not n.has_method("take_damage"):
			continue
		var target: Node3D = n as Node3D
		var to_target: Vector3 = target.global_position - origin
		to_target.y = 0.0
		var dist: float = to_target.length()
		if dist > attack_range:
			continue
		if dist > 0.05 and forward.dot(to_target / dist) < attack_cone_dot:
			continue
		if target.has_method("is_alive"):
			target.call("take_damage", damage, global_position)  # EnemyBase: origem do golpe
		else:
			target.call("take_damage", damage)
		hits += 1

	if hits > 0:
		_shake_camera(0.02, 0.15)
		_show_temporary_message("⚔️ Golpe com a pá! (%d de dano)" % int(damage), Color(1.0, 0.75, 0.4), 0.8)


# ---------------------------------------------------------------------------
# Mochila, apanhar/largar e entrega
# ---------------------------------------------------------------------------

func _handle_inventory_actions() -> void:
	for i: int in inventory.capacity:
		var action: StringName = StringName("slot_%d" % (i + 1))
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			inventory.select(i)
	if Input.is_action_just_pressed("interact"):
		_interact()
	if InputMap.has_action("drop") and Input.is_action_just_pressed("drop"):
		_drop_selected()


func _interact() -> void:
	if _target_offer != null and is_instance_valid(_target_offer):
		_buy_offer(_target_offer)
		return
	var sell_point: SellPoint = _get_sell_point_in_range()
	if sell_point != null and _count_deliverable() > 0:
		var items: Array[CarriedItem] = inventory.take_where(SellPoint.can_deliver)
		var total: int = sell_point.deliver(items)
		session_items_count += items.size()
		session_money += total
		_update_session_hud()
		SFX.play_ui(SFX.DELIVER_COINS)
		_show_temporary_message("📦 Entregue: %d itens, R$ %d" % [items.size(), total], Color(0.5, 1.0, 0.55), 2.5)
		return

	if _target_pickup == null or not is_instance_valid(_target_pickup):
		if sell_point != null:
			_show_temporary_message("Nada para entregar (as ferramentas ficam na mochila).", Color(0.9, 0.9, 0.9), 1.4)
		return
	if inventory.is_full():
		SFX.play_ui(SFX.ERROR, -4.0)
		_show_temporary_message("🎒 Mochila cheia! Entregue na base ou largue um item [Q].", Color(1.0, 0.6, 0.3), 1.8)
		return
	if _already_has_unique_tool(_target_pickup.carried):
		SFX.play_ui(SFX.ERROR, -4.0)
		_show_temporary_message("Já tem um %s (deixe-o para outro jogador)." % _target_pickup.carried.get_display_name(),
			Color(0.9, 0.9, 0.9), 1.6)
		return
	var root: PickupsRoot = PickupsRoot.find(get_tree())
	if root != null and not multiplayer.is_server():
		# Coop (#5 E): pede ao host; o item chega por receive_granted_item.
		if _pickup_pending_until > Time.get_ticks_msec():
			return
		_pickup_pending_until = Time.get_ticks_msec() + PICKUP_REQUEST_TIMEOUT_MS
		root.take(_target_pickup)
		_target_pickup = null
		return
	var c: CarriedItem = root.take(_target_pickup) if root != null else _target_pickup.take()
	_target_pickup = null
	_add_picked_item(c)


func _already_has_unique_tool(c: CarriedItem) -> bool:
	if c == null or not c.is_tool() or not UNIQUE_TOOLS.has(c.tool_id):
		return false
	for slot: CarriedItem in inventory.slots:
		if slot != null and slot.tool_id == c.tool_id:
			return true
	return false


func _add_picked_item(c: CarriedItem) -> void:
	if c == null:
		return
	if not inventory.add_item(c):
		# A mochila encheu enquanto o host respondia: o item volta ao chão.
		ItemPickup.spawn(get_parent(), c, global_position + Vector3.UP * 0.8, Vector3.UP * 1.2)
		_show_temporary_message("🎒 Mochila cheia! O item caiu no chão.", Color(1.0, 0.6, 0.3), 1.8)
		return
	SFX.play_ui(SFX.PICKUP)
	var value: String = "" if c.is_tool() else " (R$ %d)" % c.final_value
	_show_temporary_message("✋ Apanhou: %s%s" % [c.get_display_name(), value],
		Color(0.85, 0.55, 1.0) if c.is_rare_variant else Color(0.95, 0.95, 0.85), 1.4)


## PickupsRoot (cliente): o host aceitou o nosso request_pickup.
func receive_granted_item(c: CarriedItem) -> void:
	_pickup_pending_until = 0
	_add_picked_item(c)


## PickupsRoot (cliente): outro jogador apanhou primeiro (ou ficámos longe demais).
func on_pickup_denied() -> void:
	_pickup_pending_until = 0
	_show_temporary_message("Alguém apanhou primeiro.", Color(0.9, 0.9, 0.9), 1.2)


func _drop_selected() -> void:
	var c: CarriedItem = inventory.take_selected()
	if c == null:
		_show_temporary_message("Slot vazio.", Color(0.9, 0.9, 0.9), 0.8)
		return
	var fwd: Vector3 = -camera.global_basis.z
	var pos: Vector3 = camera.global_position + fwd * 0.7 + Vector3.DOWN * 0.3
	var flat: Vector3 = Vector3(fwd.x, 0.0, fwd.z).normalized()
	ItemPickup.spawn(get_parent(), c, pos, flat * drop_impulse + Vector3.UP * 0.6)
	SFX.play_at(SFX.DROP, pos, -3.0)


## Interactable (#39/#40): o [E] fica com o jogador quando ele tem alvo próprio (produto da
## banca, item no chão ou entrega possível na base).
func has_own_interact_target() -> bool:
	if _target_offer != null and is_instance_valid(_target_offer):
		return true
	if _target_pickup != null and is_instance_valid(_target_pickup):
		return true
	return _get_sell_point_in_range() != null and _count_deliverable() > 0


func _get_sell_point_in_range() -> SellPoint:
	for n: Node in get_tree().get_nodes_in_group(SellPoint.GROUP):
		var sp: SellPoint = n as SellPoint
		if sp != null and sp.is_in_range(global_position):
			return sp
	return null


## Pickup em mira: raycast da câmara (layer 5) ou, em alternativa, o mais próximo num cone frontal.
func _find_target_pickup() -> ItemPickup:
	var from: Vector3 = camera.global_position
	var fwd: Vector3 = -camera.global_basis.z
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from + fwd * interact_range, PICKUP_MASK, [get_rid()]
	)
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty() and hit["collider"] is ItemPickup:
		return hit["collider"] as ItemPickup

	var best: ItemPickup = null
	var best_dist: float = interact_range
	for n: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var p: ItemPickup = n as ItemPickup
		if p == null or p.carried == null:
			continue
		var to_p: Vector3 = p.global_position - from
		var dist: float = to_p.length()
		if dist > best_dist or dist < 0.01:
			continue
		if fwd.dot(to_p / dist) < pickup_cone_dot:
			continue
		best = p
		best_dist = dist
	return best


func _update_interaction_target() -> void:
	var offer: ShopOffer = _find_target_offer()
	if offer != _target_offer:
		if _target_offer != null and is_instance_valid(_target_offer):
			_target_offer.set_highlighted(false)
		_target_offer = offer
		if _target_offer != null:
			_target_offer.set_highlighted(true)

	var target: ItemPickup = null if _target_offer != null else _find_target_pickup()
	if target != _target_pickup:
		if _target_pickup != null and is_instance_valid(_target_pickup):
			_target_pickup.set_highlighted(false)
		_target_pickup = target
		if _target_pickup != null:
			_target_pickup.set_highlighted(true)

	if interact_prompt == null:
		return
	var sell_point: SellPoint = _get_sell_point_in_range()
	var deliverable: int = _count_deliverable()
	if _target_offer != null:
		var full: String = "  — mochila cheia!" if inventory.is_full() else ""
		interact_prompt.text = _target_offer.get_prompt() + full
	elif sell_point != null and deliverable > 0:
		interact_prompt.text = "[E] Entregar mochila (%d itens, R$ %d)" % [deliverable, inventory.get_total_value()]
	elif _target_pickup != null and _target_pickup.carried != null:
		var aimed: CarriedItem = _target_pickup.carried
		var suffix: String = "  — mochila cheia!" if inventory.is_full() else ""
		if _already_has_unique_tool(aimed):
			suffix = "  — já tem um"
		var value: String = "" if aimed.is_tool() else " (R$ %d)" % aimed.final_value
		interact_prompt.text = "[E] Apanhar %s%s%s" % [aimed.get_display_name(), value, suffix]
	else:
		interact_prompt.text = ""


func _on_inventory_changed() -> void:
	_update_session_hud()
	_update_tool_in_hand()
	carrying_loot = _count_deliverable() > 0


func _on_selected_slot_changed(_index: int) -> void:
	_update_tool_in_hand()


func _count_deliverable() -> int:
	var n: int = 0
	for c: CarriedItem in inventory.slots:
		if SellPoint.can_deliver(c):
			n += 1
	return n


## O detector só aparece e funciona com o slot selecionado a conter a ferramenta "detector".
func _update_tool_in_hand() -> void:
	if detector == null:
		return
	var c: CarriedItem = inventory.get_selected()
	held_tool_id = c.tool_id if c != null else &""
	var active: bool = c != null and c.tool_id == &"detector"
	if detector.has_method("set_active"):
		detector.call("set_active", active)
	else:
		detector.visible = active
	if tool_view != null:
		var tool_id: StringName = c.tool_id if c != null else &""
		tool_view.visible = _held_models.has(tool_id)
		for id: StringName in _held_models:
			(_held_models[id] as Node3D).visible = id == tool_id


## O estilingue já está no player.tscn; o kit e o repelente são criados aqui, sem owner (o
## editor não os grava, #47). A mão (ToolHand) agarra na origem do ToolView.
func _setup_held_models() -> void:
	if slingshot_model != null:
		_held_models[TOOL_SLINGSHOT] = slingshot_model
	# Kit erguido à frente da mão, a cruz virada para a câmara (inteiro no ecrã).
	_held_models[TOOL_MEDKIT] = _add_held_model(MEDKIT_MODEL,
		Transform3D(Basis(Vector3.UP, -0.35).scaled(Vector3.ONE * 0.5), Vector3(-0.06, 0.01, -0.03)))
	# Lata agarrada a meio, o rótulo meio virado para a câmara.
	_held_models[TOOL_REPELLENT] = _add_held_model(REPELLENT_MODEL,
		Transform3D(Basis(Vector3.UP, -PI * 0.25).scaled(Vector3.ONE * 0.85), Vector3(0.0, -0.09, 0.0)))
	# Forcado com o cabo a passar pela mão e apontado ligeiramente para a frente e para cima
	var fork_pose: Transform3D = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-65.0)).rotated(Vector3.UP, deg_to_rad(15.0)).scaled(Vector3.ONE * 0.7), Vector3(0.02, -0.06, -0.15))
	var fork_model: Node3D = _add_held_model(PITCHFORK_MODEL, fork_pose)
	if "show_left_hand" in fork_model:
		fork_model.set("show_left_hand", true)
	_held_models[TOOL_FORCADO] = fork_model
	_update_tool_in_hand()


func _add_held_model(model_script: Script, pose: Transform3D) -> Node3D:
	var model: Node3D = Node3D.new()
	model.set_script(model_script)
	model.name = "Held" + model_script.resource_path.get_file().get_basename().to_pascal_case()
	model.transform = pose
	model.visible = false
	tool_view.add_child(model)
	return model


# ---------------------------------------------------------------------------
# Loja (ShopOffer) e ferramentas compráveis (botão esquerdo)
# ---------------------------------------------------------------------------

## Produto da banca em mira: o mais alinhado com a mira dentro do alcance (cone frontal).
func _find_target_offer() -> ShopOffer:
	var from: Vector3 = camera.global_position
	var fwd: Vector3 = -camera.global_basis.z
	var best: ShopOffer = null
	var best_dot: float = 0.93
	for n: Node in get_tree().get_nodes_in_group(ShopOffer.GROUP):
		var offer: ShopOffer = n as ShopOffer
		if offer == null or offer.tool_data == null:
			continue
		var to_o: Vector3 = (offer.global_position + Vector3.UP * 0.15) - from
		var dist: float = to_o.length()
		if dist > interact_range or dist < 0.01:
			continue
		var d: float = fwd.dot(to_o / dist)
		if d > best_dot:
			best = offer
			best_dot = d
	return best


func _buy_offer(offer: ShopOffer) -> void:
	if inventory.is_full():
		SFX.play_ui(SFX.ERROR, -4.0)
		_show_temporary_message("🎒 Mochila cheia! Liberte um slot antes de comprar.", Color(1.0, 0.6, 0.3), 1.8)
		return
	var result: Dictionary = await offer.try_buy(inventory)
	if not is_inside_tree():
		return
	var message: String = result.get("message", "")
	if not result.get("ok", false):
		SFX.play_ui(SFX.ERROR, -4.0)
		_show_temporary_message("❌ " + message, Color(1.0, 0.45, 0.4), 1.8)
		return
	var c: CarriedItem = result.get("carried", null)
	# A mochila pode ter enchido enquanto o host respondia: o item cai aos pés.
	if c != null and not inventory.add_item(c):
		ItemPickup.spawn(get_parent(), c, global_position + Vector3.UP * 0.8, Vector3.UP * 1.2)
	SFX.play_ui(SFX.BUY)
	_show_temporary_message("🛒 " + message, Color(0.55, 0.9, 1.0), 1.6)


## A gaivota (Dev_Detector) chama isto: há algum item escavado para roubar?
func has_loot() -> bool:
	return _count_deliverable() > 0 if is_local() else carrying_loot


## Gaivota no host (contrato #5 F): pede ao dono deste jogador que lhe entregue um item
## escavado. O dono tira-o da mochila e responde com request_seagull_loot; dicionário
## vazio = não havia nada (a gaivota bica em vez de roubar).
@rpc("any_peer", "call_local", "reliable")
func _steal_from(gull_path: NodePath) -> void:
	if not is_local() or multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	var c: CarriedItem = steal_loot()
	var gull: Node = get_node_or_null(gull_path)
	if gull == null or not gull.has_method("request_seagull_loot"):
		return
	var data: Dictionary = c.to_dict() if c != null else {}
	# No host (jogador do host ou solo) um rpc_id(1) "call_remote" não correria: chamada direta.
	if multiplayer.is_server():
		gull.call(&"request_seagull_loot", data)
	else:
		gull.rpc_id(1, &"request_seagull_loot", data)


## Tira e devolve UM item escavado aleatório (nunca ferramentas). null se não houver.
func steal_loot() -> CarriedItem:
	var candidates: Array[int] = []
	for i: int in inventory.slots.size():
		if SellPoint.can_deliver(inventory.slots[i]):
			candidates.append(i)
	if candidates.is_empty():
		return null
	var c: CarriedItem = inventory.remove_at(candidates.pick_random())
	if c != null:
		_show_temporary_message("🐦 Uma gaivota roubou %s!" % c.get_display_name(), Color(1.0, 0.55, 0.35), 2.2)
		_shake_camera(0.02, 0.2)
	return c


func _handle_use_tool_action() -> void:
	if not Input.is_action_just_pressed("use_tool") or _use_cooldown > 0.0:
		return
	var c: CarriedItem = inventory.get_selected()
	if c == null or c.tool_data == null:
		return
	match c.tool_id:
		TOOL_SLINGSHOT:
			_fire_slingshot()
		TOOL_LANTERN:
			_flash_lantern(c)
		TOOL_REPELLENT:
			_use_repellent()
			_consume(c)
		TOOL_NET_TRAP:
			if _place_net_trap():
				_consume(c)
		TOOL_MEDKIT:
			if health >= max_health:
				_show_temporary_message("A vida já está cheia.", Color(0.9, 0.9, 0.9), 1.0)
				return
			heal(medkit_heal)
			SFX.play_ui(SFX.MEDKIT)
			_show_temporary_message("🩹 +%d de vida" % int(medkit_heal), Color(0.5, 1.0, 0.55), 1.2)
			_consume(c)
		TOOL_FORCADO:
			_attack_pitchfork()


## Clarão em cone (LanternFlash, Dev_Detector): atordoa e espanta; em coop o stun vai ao host.
func _flash_lantern(c: CarriedItem) -> void:
	var hit: int = LanternFlash.fire(camera.global_position, -camera.global_transform.basis.z, self)
	if hit < 0:
		return
	_use_cooldown = LANTERN_COOLDOWN
	if c.tool_data.charges > 0:
		_consume(c)
		_use_cooldown = LANTERN_COOLDOWN
	if hit > 0:
		_show_temporary_message("Flash! %d atordoado%s" % [hit, "" if hit == 1 else "s"], Color(1.0, 0.95, 0.6), 1.2)


## Gasta uma carga do item selecionado; remove-o do slot quando acaba.
func _consume(c: CarriedItem) -> void:
	_use_cooldown = 0.35
	if c.consume_charge():
		var idx: int = inventory.slots.find(c)
		if idx >= 0:
			inventory.remove_at(idx)
		_show_temporary_message("%s acabou." % c.tool_name, Color(0.9, 0.9, 0.9), 1.2)
	else:
		inventory.notify_changed()


func _fire_slingshot() -> void:
	_use_cooldown = slingshot_cooldown
	var fwd: Vector3 = -camera.global_basis.z
	var pos: Vector3 = camera.global_position + fwd * 0.6 + camera.global_basis.x * 0.04 - camera.global_basis.y * 0.05
	SFX.play_ui(SFX.SLINGSHOT_STRETCH, -8.0, 0.1)
	get_tree().create_timer(0.06).timeout.connect(func() -> void: SFX.play_ui(SFX.SLINGSHOT_FIRE, -2.0, 0.1))
	SlingshotProjectile.launch(get_parent(), self, pos, fwd * slingshot_speed + Vector3.UP * 1.2, slingshot_damage)
	# Recuo do estilingue na mão: elástico estica e solta.
	if slingshot_model != null and tool_view != null:
		var t: Tween = create_tween()
		t.tween_property(slingshot_model, "pull", 1.0, 0.06)
		t.parallel().tween_property(tool_view, "position", _tool_view_rest + Vector3(0, -0.02, 0.06), 0.06)
		t.tween_property(slingshot_model, "pull", 0.0, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(tool_view, "position", _tool_view_rest, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Ataque corpo a corpo de alcance médio do Forcado (#38).
## Alcance ~3.2m em cone frontal, aplica dano (35), atordoamento breve e knockback forte.
## Suporta coop via request_hit e request_stun nos inimigos replicados.
func attack_pitchfork() -> int:
	_use_cooldown = pitchfork_cooldown
	_attack_cooldown = pitchfork_cooldown

	# Animação de estocada com o forcado na mão
	if tool_view != null:
		var t: Tween = create_tween()
		var forward_thrust: Vector3 = _tool_view_rest + Vector3(0.0, 0.04, -0.28)
		t.tween_property(tool_view, "position", forward_thrust, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(tool_view, "rotation:x", -0.12, 0.08)
		t.tween_property(tool_view, "position", _tool_view_rest, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(tool_view, "rotation:x", 0.0, 0.26)

	var forward: Vector3 = -camera.global_basis.z if camera != null else -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var origin: Vector3 = camera.global_position if camera != null else global_position
	var hits: int = 0

	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node3D):
			continue
		var target: Node3D = n as Node3D
		if target.has_method("is_alive") and not target.call("is_alive"):
			continue
		var to_target: Vector3 = target.global_position - origin
		to_target.y = 0.0
		var dist: float = to_target.length()
		if dist > pitchfork_range:
			continue
		if dist > 0.05 and forward.dot(to_target / dist) < pitchfork_cone_dot:
			continue

		var push_dir: Vector3 = to_target / dist if dist > 0.01 else forward

		# Suporte a coop: no cliente sem autoridade usa request_hit/request_stun para o host
		if target.has_method("request_hit") and not (target.has_method("has_simulation_authority") and target.call("has_simulation_authority")):
			target.call("request_hit", pitchfork_damage, origin)
		elif target.has_method("take_damage"):
			target.call("take_damage", pitchfork_damage, origin)

		if target.has_method("request_stun") and not (target.has_method("has_simulation_authority") and target.call("has_simulation_authority")):
			target.call("request_stun", pitchfork_stun)
		elif target.has_method("stun"):
			target.call("stun", pitchfork_stun)

		if target.has_method("apply_knockback"):
			target.call("apply_knockback", push_dir * pitchfork_knockback + Vector3.UP * 2.5, 0.06)
		if target is CharacterBody3D:
			var cb: CharacterBody3D = target as CharacterBody3D
			cb.velocity += push_dir * pitchfork_knockback + Vector3.UP * 2.0
			cb.move_and_collide(push_dir * (pitchfork_knockback * 0.12))

		hits += 1

	if hits > 0:
		_shake_camera(0.03, 0.18)
		SFX.play_ui(SFX.STONE_IMPACT, -2.0, 0.1)
		_show_temporary_message("🔱 Golpe de Forcado! (%d de dano)" % int(pitchfork_damage), Color(1.0, 0.85, 0.4), 0.9)
	else:
		SFX.play_ui(SFX.SLINGSHOT_FIRE, -10.0, 0.2)

	return hits


func _attack_pitchfork() -> void:
	attack_pitchfork()


func _use_repellent() -> void:
	var fwd: Vector3 = -camera.global_basis.z
	SFX.play_ui(SFX.SPRAY, -6.0)
	_spawn_spray(camera.global_position + fwd * 0.6 - camera.global_basis.y * 0.15, fwd)
	var fled: int = 0
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e: Node3D = n as Node3D
		if e == null or e.global_position.distance_to(global_position) > repellent_radius:
			continue
		if e.has_method("is_alive") and not e.call("is_alive"):
			continue
		if e.has_method("flee_from"):
			e.call("flee_from", global_position, repellent_flee_seconds)
			fled += 1
	if DisturbanceMeter.instance != null:
		DisturbanceMeter.instance.add_noise(-repellent_noise_reduction, global_position)
	_show_temporary_message("💨 Repelente! %d criatura(s) fugiram. A ameaça baixou." % fled, Color(0.5, 1.0, 0.45), 1.6)


func _spawn_spray(pos: Vector3, dir: Vector3) -> void:
	var parent: Node = get_parent() if get_parent() != null else self
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 70
	p.lifetime = 0.9
	p.explosiveness = 0.75
	p.direction = Vector3.FORWARD
	p.spread = 22.0
	p.initial_velocity_min = 3.5
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -0.6, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = REPELLENT_COLOR
	mesh.material = mat
	p.mesh = mesh
	parent.add_child(p)
	p.global_position = pos
	p.look_at(pos + dir, Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD)
	p.restart()
	get_tree().create_timer(p.lifetime + 0.6).timeout.connect(p.queue_free)


func _place_net_trap() -> bool:
	var fwd: Vector3 = -global_basis.z
	fwd.y = 0.0
	var aim: Vector3 = global_position + fwd.normalized() * net_trap_distance
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		aim + Vector3.UP * 1.5, aim + Vector3.DOWN * 3.0, GROUND_MASK, [get_rid()]
	)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		_show_temporary_message("Não dá para pousar a rede aqui.", Color(1.0, 0.6, 0.4), 1.2)
		return false
	NetTrap.place(get_parent(), hit["position"], rotation.y)
	_show_temporary_message("🕸️ Armadilha de rede armada.", Color(0.95, 0.85, 0.6), 1.2)
	return true


## Passos na areia: um passo a cada STEP_LENGTH metros percorridos no chão
## (andar mais depressa = ritmo mais rápido).
func _update_footsteps(delta: float) -> void:
	var horizontal: Vector2 = Vector2(velocity.x, velocity.z)
	if not footsteps_enabled or not is_on_floor() or horizontal.length() < 0.5:
		_step_distance = STEP_LENGTH * 0.6  # o 1.o passo sai pouco depois de arrancar
		return
	_step_distance += horizontal.length() * delta
	if _step_distance >= STEP_LENGTH:
		_step_distance = 0.0
		SFX.play_at(SFX.FOOTSTEP_SAND, global_position, footsteps_volume_db + randf_range(-1.5, 1.5), 0.05)
