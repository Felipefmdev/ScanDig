class_name Player
extends CharacterBody3D

signal health_changed(current: float, max_value: float)
signal died
signal player_downed(player: Player)
signal player_carried(carrier: Player, carried: Player)
signal player_dropped(carrier: Player, dropped: Player)
signal player_revived(player: Player, by_player: Player)

@export_group("Coop Downed State")
@export var allow_downed: bool = false
@export var carry_speed_multiplier: float = 0.85

@export var speed: float = 4.5
@export var jump_velocity: float = 4.2
@export var mouse_sensitivity: float = 0.0025
@export var dig_range: float = 1.8
## Nível da pá: cada nível reduz o cooldown de escavação e o dano à integridade dos itens.
## Com GameState vem do upgrade "shovel" (1 a 4, ver _apply_shovel_level).
@export_range(1, 10) var shovel_level: int = 1

@export_group("Movimento")
## Correr (Shift andando pra frente): mesma proporção 1,5× do andar usada em jogos de coleta.
@export var sprint_multiplier: float = 1.5
## Taxas (1/s) de aproximação da velocidade alvo: arranque com peso, parada mais firme.
@export var ground_acceleration: float = 12.0
@export var ground_deceleration: float = 16.0
## Fração do controle no ar.
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.35
## Ainda dá pra pular logo depois de sair da borda.
@export var coyote_time: float = 0.15
## Pulo apertado um pouco antes de tocar o chão também sai.
@export var jump_buffer_time: float = 0.12
## Queda mais pesada que a subida (pulo menos "flutuante").
@export var fall_gravity_multiplier: float = 1.6
@export_group("Câmera")
@export var view_bobbing: bool = true
@export var invert_y: bool = false
## Amplitudes do balanço (m) a velocidade de andar; correndo cresce junto.
@export var head_bob_vertical: float = 0.035
@export var head_bob_horizontal: float = 0.02
## Ferramenta na mão: atraso ao olhar (sway), balanço ao andar, respiração e troca.
@export var tool_sway_amount: float = 0.0012
@export var tool_sway_max: float = 0.035
@export var tool_sway_rot_deg: float = 6.0
@export var tool_sway_return: float = 9.0
@export var tool_bob_amount: float = 0.012
@export var tool_breathe_amount: float = 0.004
@export var tool_equip_time: float = 0.3

@export_group("Vida")
@export var max_health: float = 100.0
## Janela sem dano depois de um acerto (evita dano em rajada de vários inimigos no mesmo frame).
@export var invulnerability_after_damage: float = 0.25

@export_group("Fome")
## A fome só corre na expedição (num mapa); no lobby fica parada.
@export var max_hunger: float = 100.0
## Pontos de fome perdidos por segundo (100 → 0 em ~16 min).
@export var hunger_decay_per_sec: float = 0.1
## Saciado acima desta fração: regenera vida gastando fome.
@export_range(0.0, 1.0, 0.05) var hunger_regen_threshold: float = 0.6
@export var regen_interval: float = 2.0
@export var regen_health: float = 4.0
@export var regen_hunger_cost: float = 2.0
## Segundos sem levar dano antes de começar a regenerar.
@export var regen_delay_after_damage: float = 5.0
## Faminto (fome 0): dano a cada starve_interval.
@export var starve_interval: float = 3.0
@export var starve_damage: float = 4.0

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
## Segurar [Q] carrega um arremesso: após throw_charge_delay, sobe até throw_max_impulse
## em throw_charge_time (toque rápido = largar como antes).
@export var throw_max_impulse: float = 9.0
@export var throw_charge_delay: float = 0.15
@export var throw_charge_time: float = 0.5

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

@export_group("Arpão de Corda")
@export var harpoon_damage: float = 40.0
@export var harpoon_range: float = 14.0
@export var harpoon_cooldown: float = 1.0
@export_range(-1.0, 1.0, 0.05) var harpoon_cone_dot: float = 0.75
@export var harpoon_pull_force: float = 14.0
@export var harpoon_stun: float = 0.8

@export_group("Pulso Magnético")
@export var magnetic_pulse_damage: float = 35.0
@export var magnetic_pulse_enemy_range: float = 7.5
@export var magnetic_pulse_pickup_range: float = 12.0
@export var magnetic_pulse_cooldown: float = 1.2
@export_range(-1.0, 1.0, 0.05) var magnetic_pulse_cone_dot: float = 0.5
@export var magnetic_pulse_knockback: float = 16.0
@export var magnetic_pulse_stun: float = 0.6

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
const TOOL_HARPOON: StringName = &"arpao_corda"
const TOOL_PULSE: StringName = &"pulso_magnetico"
## Recarga do clarão da Lanterna de Magnésio (#42).
const LANTERN_COOLDOWN: float = 4.0
## Empurrão (#57): segundos sem controlo por m/s de impulso, e o máximo.
const KNOCKBACK_TIME_PER_SPEED: float = 0.05
const KNOCKBACK_TIME_MAX: float = 0.9
## Teto da velocidade depois de empurrões acumulados (m/s).
const KNOCKBACK_MAX_FLAT: float = 14.0
const KNOCKBACK_MAX_UP: float = 12.0
## Modelos na mão (#37) das ferramentas sem nó próprio no player.tscn (o estilingue tem).
const MEDKIT_MODEL: Script = preload("res://gameplay/weapons/medkit/medkit_model.gd")
const REPELLENT_MODEL: Script = preload("res://gameplay/weapons/repellent/repellent_model.gd")
const PITCHFORK_MODEL: Script = preload("res://gameplay/weapons/pitchfork/pitchfork_model.gd")
const HARPOON_MODEL: Script = preload("res://gameplay/weapons/harpoon/harpoon_model.gd")
const NET_TRAP_MODEL: Script = preload("res://gameplay/weapons/net_trap/net_trap_model.gd")
const LANTERN_MODEL: Script = preload("res://gameplay/weapons/lantern/lantern_model.gd")
const PULSE_MODEL: Script = preload("res://gameplay/weapons/magnetic_pulse/magnetic_pulse_model.gd")
## Ferramentas de que cada jogador só leva uma (em coop há um detetor por jogador no spawn).
const UNIQUE_TOOLS: Array[StringName] = [&"detector"]
const REPELLENT_COLOR: Color = Color(0.45, 1.0, 0.35, 0.85)
const SHOVEL_COOLDOWN_REDUCTION_PER_LEVEL: float = 0.25
const SHOVEL_DAMAGE_REDUCTION_PER_LEVEL: float = 0.15
const MIN_SHOVEL_DAMAGE_MULTIPLIER: float = 0.3
const THREAT_COLORS: Array[Color] = [
	UiPalette.GREEN_BOTTLE,
	UiPalette.GOLD,
	UiPalette.ORANGE,
	UiPalette.RED_BURNT,
]
## #34: o que sai de uma pazada fora de um sinal, pelo chão de cada mapa (MapData.id).
const EMPTY_DIG_GROUND: Dictionary = {"praia": "Só areia...", "campo": "Só terra..."}
const EMPTY_DIG_DEFAULT: String = "Nada aqui..."
## Chance de uma pazada fora de sinal render comida (cuidadosa mexe mais a terra).
const FOOD_DIG_CHANCE: float = 0.3
const FOOD_DIG_CHANCE_CAREFUL: float = 0.45
## Comidas (ToolData FOOD) carregadas uma vez de GameState.TOOLS_DIR.
static var _food_cache: Array[ToolData] = []
static var _food_cache_loaded: bool = false
const MAX_MESSAGES: int = 3
## Linhas no total (uma descoberta tem 3-4): a pilha não desce até à mira em janelas pequenas.
const MAX_MESSAGE_LINES: int = 4
const MESSAGE_FONT_SIZE: int = 22
const THREAT_MESSAGE_FONT_SIZE: int = 30
const THREAT_MESSAGE_COLOR: Color = UiPalette.RED_BURNT
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
## Grupo para jogadores caídos (morte em expedição coop).
const DOWNED_GROUP: StringName = &"downed_players"

var health: float = 100.0
## Estado caído (downed) em expedição coop (#79).
var is_downed: bool = false:
	set(value):
		if is_downed == value:
			return
		is_downed = value
		_on_is_downed_changed(value)

## Jogador caído que este jogador está atualmente a carregar.
var carried_player: Player = null
## Jogador que está atualmente a carregar este jogador caído.
var carried_by: Player = null
## Jogador caído focado pela mira para carregar/reanimar.
var _target_downed_player: Player = null
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
## #57: preso (cobra enrolada, abanar as teclas solta), sem ferramenta (Corvo-Rei roubou-a) e
## tinta do polvo no ecrã. Tudo só no dono, posto pelos RPC apply_snare/apply_disarm/apply_ink.
var _snare_time: float = 0.0
var _disarm_time: float = 0.0
var _ink_time: float = 0.0
var _ink_layer: CanvasLayer = null
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
## Fase do balanço da câmera (rad): avança PI por passo, o passo toca no vale.
var _bob_phase: float = 0.0
var _bob_weight: float = 0.0
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _invulnerable_until_ms: int = 0
var hunger: float = 100.0
var _regen_timer: float = 0.0
var _starve_timer: float = 0.0
var _last_damage_ms: int = -100000
var _hunger_bar: ProgressBar = null
var _hunger_label: Label = null
signal hunger_changed(current: float, max_value: float)
var _hit_feedback: Node = null
## Pivô em runtime (filho da câmara) que leva o ToolView e a mão do detector.
var tool_sway: Node3D = null
var _sway_look: Vector2 = Vector2.ZERO
var _sway_offset: Vector2 = Vector2.ZERO
var _breathe_time: float = 0.0
var _equip_left: float = 0.0
const HIT_FEEDBACK_SCRIPT: Script = preload("res://gameplay/player/hit_feedback.gd")
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


func _exit_tree() -> void:
	if carried_player != null and is_instance_valid(carried_player):
		_perform_drop(self)
	if carried_by != null and is_instance_valid(carried_by):
		carried_by.carried_player = null
		carried_by = null


static func peer_id_from_name(node_name: StringName) -> int:
	var s: String = String(node_name)
	return s.to_int() if s.is_valid_int() else 0


func is_local() -> bool:
	return is_multiplayer_authority()


func is_alive() -> bool:
	return health > 0.0 and not is_downed


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
	hunger = max_hunger
	_setup_hunger_hud()

	_setup_threat_hud()
	_hit_feedback = HIT_FEEDBACK_SCRIPT.new()
	add_child(_hit_feedback)
	_setup_tool_sway()
	_setup_nearby_items_ui()
	_setup_settings()

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
	_add_key_if_empty("sprint", KEY_SHIFT)
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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_settings_open():
		apply_mouse_look((event as InputEventMouseMotion).relative)

	# [Esc] (ação "pause") é do menu de pausa (CorePauseMenu, #77).
	if is_settings_open() or is_downed:
		return
	if event is InputEventMouseButton and event.is_pressed():
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			inventory.cycle(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			inventory.cycle(1)


## Olhar com o mouse; invert_y inverte o eixo vertical (Jogabilidade, #77).
func apply_mouse_look(relative: Vector2) -> void:
	_sway_look += relative
	rotate_y(-relative.x * mouse_sensitivity)
	head.rotate_x(-relative.y * mouse_sensitivity * (-1.0 if invert_y else 1.0))
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))


func _physics_process(delta: float) -> void:
	if is_downed:
		if carried_by != null and is_instance_valid(carried_by):
			global_position = carried_by.global_position - carried_by.global_transform.basis.z * 0.35 + Vector3.UP * 0.85
			rotation.y = carried_by.rotation.y
			velocity = Vector3.ZERO
			return
		# No chão caído: apenas gravidade e amortecimento horizontal
		velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_deceleration * delta)
		if not is_on_floor():
			var grav: Vector3 = get_gravity()
			if velocity.y < 0.0:
				grav *= fall_gravity_multiplier
			velocity += grav * delta
		move_and_slide()
		return

	var on_floor: bool = is_on_floor()
	if not on_floor:
		var gravity: Vector3 = get_gravity()
		if velocity.y < 0.0:
			gravity *= fall_gravity_multiplier
		velocity += gravity * delta
	_coyote_left = coyote_time if on_floor else maxf(_coyote_left - delta, 0.0)
	if Input.is_action_just_pressed("jump") and not is_settings_open():
		_jump_buffer_left = jump_buffer_time
	else:
		_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0

	# Menu de pausa aberto (coop não pausa a árvore): parado, mas a física segue.
	var input_dir: Vector2 = Vector2.ZERO if is_settings_open() else Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	direction = _apply_chaos_effects(direction, delta)
	if _knockback_time > 0.0:
		_knockback_time -= delta
	else:
		_apply_horizontal_movement(direction, input_dir, on_floor, delta)

	move_and_slide()
	if carried_player != null and is_instance_valid(carried_player):
		carried_player.global_position = global_position - global_transform.basis.z * 0.35 + Vector3.UP * 0.85
		carried_player.rotation.y = rotation.y

	_update_footsteps(delta)
	if is_local() and health > 0.0 and _current_map_id() != "":
		tick_hunger(delta)

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

	if is_settings_open():
		return
	_handle_dig_actions()
	_handle_attack_action()
	_handle_inventory_actions()
	_handle_use_tool_action()


func _process(_delta: float) -> void:
	if not is_local():
		avatar.set_pitch(head.rotation.x)
		return
	if is_downed:
		if interact_prompt != null:
			if carried_by != null:
				interact_prompt.text = "🤝 A ser transportado por %s..." % _get_player_name(carried_by)
			else:
				interact_prompt.text = "💀 Estás caído! Aguarda que um colega te leve à base."
		return
	update_tool_sway(_delta)
	_update_interaction_target()


## Botão direito saca a pá e cava: sozinho = pá rápida, com Shift = escavação cuidadosa.
## (A ação "careful_dig" é o botão direito no InputMap; o botão esquerdo já não cava.)
func _handle_dig_actions() -> void:
	if carried_player != null or _dig_cooldown > 0.0 or dig_animator.is_playing():
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
	if not is_inside_tree() or res.is_empty():
		return
	if not bool(res.get("dug", true)):
		return
	# Fase 3 (#5 G): barulho de quem cavou, reportado deste lado (o host cavou com
	# report_noise = false); com o DisturbanceMeter em rede isto chega ao host.
	DisturbanceMeter.report(
		DisturbanceMeter.NOISE_CAREFUL_DIG if is_careful else DisturbanceMeter.NOISE_FAST_DIG, spot_pos)
	if bool(res.get("revealed_now", res.get("revealed", false))) and res.get("item") != null:
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
		var food: ToolData = roll_dig_food(_current_map_id(), _dig_is_careful)
		if food != null:
			_give_dug_food(food)
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
		var color: Color = UiPalette.GOLD
		var duration: float = 3.5
		if is_rare_variant:
			msg += "✦ RARO ✦\n"
			color = Color(0.85, 0.55, 1.0)
			duration = 4.5
		msg += "★ DESCOBERTA: %s [%s]!\nIntegridade: %d%% | Valor: %s" % [
			item_name, rarity_str, int(integrity * 100.0), MoneyFormat.money(final_val)
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
		_show_temporary_message(msg, UiPalette.RED_BURNT.lightened(0.2), 2.2)
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
	label.add_theme_color_override("font_outline_color", UiPalette.INK)
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
	var old: Tween = (label.get_meta(&"fade") as Tween) if label.has_meta(&"fade") else null
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
	var bag: String = "🎒 Mochila: %d/%d (%s)" % [inventory.get_count(), inventory.capacity, MoneyFormat.money(inventory.get_total_value())]
	if GameState.instance != null:
		session_info_label.text = "%s | 💰 Equipa: %s" % [bag, MoneyFormat.money(GameState.instance.team_money)]
	else:
		session_info_label.text = "%s | 💰 Entregue: %s" % [bag, MoneyFormat.money(session_money)]


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
	if not is_local() or health <= 0.0 or is_downed:
		return
	velocity += impulse
	# Vários empurrões seguidos não se somam sem fim (#57): teto para não sair do mapa.
	var flat: Vector2 = Vector2(velocity.x, velocity.z).limit_length(KNOCKBACK_MAX_FLAT)
	velocity = Vector3(flat.x, minf(velocity.y, KNOCKBACK_MAX_UP), flat.y)
	_knockback_time = clampf(impulse.length() * KNOCKBACK_TIME_PER_SPEED, 0.15, KNOCKBACK_TIME_MAX)
	if shake > 0.0:
		_shake_camera(shake, 0.3)


func take_damage(amount: float) -> void:
	# Num jogador remoto a vida não é nossa: quem acerta usa apply_damage.rpc_id(dono).
	if not is_local() or amount <= 0.0 or health <= 0.0 or is_downed:
		return
	var now: int = Time.get_ticks_msec()
	if now < _invulnerable_until_ms:
		return
	_invulnerable_until_ms = now + int(invulnerability_after_damage * 1000.0)
	_last_damage_ms = now
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
	if carried_player != null:
		drop_carried_player()
	var lost: int = _drop_all_items()
	if _should_enter_downed():
		enter_downed()
		return
	var msg: String = "💀 Você desmaiou... e acordou de volta no ponto de partida."
	if lost > 0:
		msg += "\nA mochila caiu no local da morte (%d itens) — volte para apanhar!" % lost
	_show_temporary_message(msg, Color(1.0, 0.4, 0.4), 4.0)
	_respawn()


func _should_enter_downed() -> bool:
	if allow_downed:
		return true
	var sm: SessionManager = SessionManager.instance
	var in_expedition: bool = sm != null and sm.is_in_expedition()
	var is_coop: bool = multiplayer.has_multiplayer_peer() and (multiplayer.get_peers().size() > 0 or not multiplayer.is_server())
	return in_expedition and is_coop


func enter_downed() -> void:
	if is_downed:
		return
	if carried_player != null:
		drop_carried_player()
	is_downed = true
	health = 0.0
	health_changed.emit(health, max_health)
	_on_is_downed_changed(true)
	if _is_multiplayer_active():
		if multiplayer.is_server():
			_rpc_sync_downed.rpc(true)
		else:
			_rpc_sync_downed.rpc_id(1, true)
	player_downed.emit(self)


func revive(restore_health_fraction: float = 0.5) -> void:
	is_downed = false
	if carried_by != null:
		if carried_by.carried_player == self:
			carried_by.carried_player = null
		carried_by = null
	collision_layer = 1
	health = maxf(max_health * restore_health_fraction, 1.0)
	health_changed.emit(health, max_health)
	set_hunger(max_hunger * 0.5)
	_on_is_downed_changed(false)
	if is_local():
		_show_temporary_message("✨ Foste reanimado na base! De volta à expedição.", Color(0.3, 1.0, 0.4), 3.0)
		SFX.play_ui(SFX.RESPAWN)


func _on_is_downed_changed(downed: bool) -> void:
	if avatar != null:
		avatar.set_downed(downed)
	if downed:
		if is_in_group(LOCAL_GROUP):
			remove_from_group(LOCAL_GROUP)
		if is_in_group(ALL_GROUP):
			remove_from_group(ALL_GROUP)
		if not is_in_group(DOWNED_GROUP):
			add_to_group(DOWNED_GROUP)
		if is_local():
			if head != null:
				head.position.y = 0.35
				head.rotation.x = deg_to_rad(-10.0)
			if shovel_rig != null:
				shovel_rig.visible = false
			if tool_view != null:
				tool_view.visible = false
			if detector != null:
				if detector.has_method("set_active"):
					detector.call("set_active", false)
				else:
					detector.visible = false
			_show_temporary_message("💀 Foste derrubado! Um colega tem de te levar à base para te reanimar.", Color(1.0, 0.35, 0.35), 5.0)
	else:
		if is_in_group(DOWNED_GROUP):
			remove_from_group(DOWNED_GROUP)
		if not is_in_group(ALL_GROUP):
			add_to_group(ALL_GROUP)
		if is_local():
			if not is_in_group(LOCAL_GROUP):
				add_to_group(LOCAL_GROUP)
			if head != null:
				head.position.y = 1.6
				head.rotation.x = 0.0
			_update_tool_in_hand()


# ---------------------------------------------------------------------------
# Transporte e Reanimação em Coop (#79)
# ---------------------------------------------------------------------------

func carry_player(target: Player) -> void:
	request_carry_player(target)


func drop_carried_player() -> void:
	request_drop_carried_player()


func revive_player(target: Player) -> void:
	request_revive_player(target)


func request_carry_player(target: Player) -> void:
	if target == null or is_downed or carried_player != null:
		return
	if not _is_multiplayer_active():
		_perform_carry(self, target)
		return
	if multiplayer.is_server():
		_host_validate_and_carry(self, target)
	else:
		_rpc_request_carry.rpc_id(1, get_path(), target.get_path())


func request_drop_carried_player() -> void:
	if carried_player == null:
		return
	if not _is_multiplayer_active():
		_perform_drop(self)
		return
	if multiplayer.is_server():
		_host_validate_and_drop(self)
	else:
		_rpc_request_drop.rpc_id(1, get_path())


func request_revive_player(target: Player) -> void:
	if target == null or not target.is_downed:
		return
	if not _is_multiplayer_active():
		_perform_revive(self, target)
		return
	if multiplayer.is_server():
		_host_validate_and_revive(self, target)
	else:
		_rpc_request_revive.rpc_id(1, get_path(), target.get_path())


func _host_validate_and_carry(carrier: Player, target: Player) -> void:
	if not multiplayer.is_server() or carrier == null or target == null:
		return
	if carrier.is_downed or carrier.carried_player != null:
		return
	if not target.is_downed or target.carried_by != null:
		return
	if carrier.global_position.distance_to(target.global_position) > interact_range + 2.0:
		return
	_perform_carry(carrier, target)
	_rpc_sync_carry.rpc(carrier.get_path(), target.get_path())


func _host_validate_and_drop(carrier: Player) -> void:
	if not multiplayer.is_server() or carrier == null or carrier.carried_player == null:
		return
	_perform_drop(carrier)
	_rpc_sync_drop.rpc(carrier.get_path())


func _host_validate_and_revive(reviver: Player, target: Player) -> void:
	if not multiplayer.is_server() or target == null or not target.is_downed:
		return
	var at_base: bool = false
	if reviver != null and reviver._get_sell_point_in_range() != null:
		at_base = true
	elif target._get_sell_point_in_range() != null:
		at_base = true
	if not at_base:
		return
	_perform_revive(reviver, target)
	_rpc_sync_revive.rpc(reviver.get_path() if reviver != null else NodePath(""), target.get_path())


@rpc("any_peer", "call_local", "reliable")
func _rpc_request_carry(carrier_path: NodePath, target_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var carrier: Player = get_node_or_null(carrier_path) as Player
	var target: Player = get_node_or_null(target_path) as Player
	if carrier != null and target != null:
		_host_validate_and_carry(carrier, target)


@rpc("any_peer", "call_local", "reliable")
func _rpc_request_drop(carrier_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var carrier: Player = get_node_or_null(carrier_path) as Player
	if carrier != null:
		_host_validate_and_drop(carrier)


@rpc("any_peer", "call_local", "reliable")
func _rpc_request_revive(reviver_path: NodePath, target_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var reviver: Player = get_node_or_null(reviver_path) as Player
	var target: Player = get_node_or_null(target_path) as Player
	if target != null:
		_host_validate_and_revive(reviver, target)


@rpc("authority", "call_local", "reliable")
func _rpc_sync_carry(carrier_path: NodePath, target_path: NodePath) -> void:
	var carrier: Player = get_node_or_null(carrier_path) as Player
	var target: Player = get_node_or_null(target_path) as Player
	if carrier != null and target != null:
		_perform_carry(carrier, target)


@rpc("authority", "call_local", "reliable")
func _rpc_sync_drop(carrier_path: NodePath) -> void:
	var carrier: Player = get_node_or_null(carrier_path) as Player
	if carrier != null:
		_perform_drop(carrier)


@rpc("authority", "call_local", "reliable")
func _rpc_sync_revive(reviver_path: NodePath, target_path: NodePath) -> void:
	var reviver: Player = get_node_or_null(reviver_path) as Player if not reviver_path.is_empty() else null
	var target: Player = get_node_or_null(target_path) as Player
	if target != null:
		_perform_revive(reviver, target)


@rpc("any_peer", "call_local", "reliable")
func _rpc_sync_downed(downed: bool) -> void:
	is_downed = downed


func _perform_carry(carrier: Player, target: Player) -> void:
	if carrier == null or target == null:
		return
	carrier.carried_player = target
	target.carried_by = carrier
	target.collision_layer = 0
	if carrier.is_local():
		carrier._show_temporary_message("🤝 A carregar %s. Leva-o à base!" % carrier._get_player_name(target), Color(0.4, 0.8, 1.0), 2.5)
	if target.is_local():
		target._show_temporary_message("🤝 %s está a carregar-te!" % target._get_player_name(carrier), Color(0.4, 0.8, 1.0), 2.5)
	carrier.player_carried.emit(carrier, target)


func _perform_drop(carrier: Player) -> void:
	if carrier == null or carrier.carried_player == null:
		return
	var dropped: Player = carrier.carried_player
	carrier.carried_player = null
	dropped.carried_by = null
	dropped.collision_layer = 1
	var fwd: Vector3 = -carrier.global_transform.basis.z
	fwd.y = 0.0
	dropped.global_position = carrier.global_position + fwd.normalized() * 0.9 + Vector3.UP * 0.1
	dropped.velocity = Vector3.ZERO
	if carrier.is_local():
		carrier._show_temporary_message("Largaste o corpo de %s." % carrier._get_player_name(dropped), Color(0.9, 0.9, 0.9), 1.5)
	carrier.player_dropped.emit(carrier, dropped)


func _perform_revive(reviver: Player, target: Player) -> void:
	if target == null:
		return
	if reviver != null and reviver.carried_player == target:
		reviver.carried_player = null
	target.carried_by = null
	target.revive()
	if reviver != null and reviver.is_local():
		reviver._show_temporary_message("✨ Reanimaste %s!" % reviver._get_player_name(target), Color(0.3, 1.0, 0.4), 2.5)
	target.player_revived.emit(target, reviver)


func _is_multiplayer_active() -> bool:
	return multiplayer != null and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func _get_player_name(p: Player) -> String:
	if p == null:
		return "Jogador"
	if p.has_method("get_player_display_name"):
		return p.get_player_display_name()
	return p.name


func get_player_display_name() -> String:
	var owner_id: int = get_multiplayer_authority()
	if owner_id == 1:
		return "Anfitrião"
	elif owner_id > 1:
		return "Jogador %d" % owner_id
	return name


func _is_player_at_base(p: Player) -> bool:
	if p == null:
		return false
	for n: Node in get_tree().get_nodes_in_group(SellPoint.GROUP):
		var sp: SellPoint = n as SellPoint
		if sp != null and sp.is_in_range(p.global_position):
			return true
	return false


func _find_target_downed_player() -> Player:
	if is_downed or carried_player != null:
		return null
	var from: Vector3 = camera.global_position if camera != null else global_position + Vector3.UP * 1.6
	var fwd: Vector3 = -camera.global_basis.z if camera != null else -global_transform.basis.z
	var candidates: Array[Node] = []
	candidates.append_array(get_tree().get_nodes_in_group(DOWNED_GROUP))
	for n: Node in get_tree().get_nodes_in_group(ALL_GROUP):
		if not candidates.has(n):
			candidates.append(n)

	var best: Player = null
	var best_dist: float = interact_range + 1.0
	for node: Node in candidates:
		var p: Player = node as Player
		if p == null or p == self or not p.is_downed or p.carried_by != null:
			continue
		var to_p: Vector3 = (p.global_position + Vector3.UP * 0.3) - from
		var dist: float = to_p.length()
		if dist > best_dist:
			continue
		if fwd.dot(to_p.normalized()) < 0.5:
			continue
		best = p
		best_dist = dist
	return best


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
	set_hunger(max_hunger * 0.5)
	get_tree().create_timer(0.35).timeout.connect(func() -> void: SFX.play_ui(SFX.RESPAWN, -6.0))


## Fome (estilo sobrevivência leve): cai com o tempo; saciado regenera vida, faminto perde.
func tick_hunger(delta: float) -> void:
	set_hunger(hunger - hunger_decay_per_sec * delta)
	if hunger <= 0.0:
		_regen_timer = 0.0
		_starve_timer += delta
		if _starve_timer >= starve_interval:
			_starve_timer = 0.0
			_invulnerable_until_ms = 0  # a fome não respeita a janela pós-golpe
			take_damage(starve_damage)
			_show_temporary_message("🍽️ Faminto! Cave e coma alguma coisa.", UiPalette.ORANGE, 1.5)
		return
	_starve_timer = 0.0
	var rested: bool = Time.get_ticks_msec() - _last_damage_ms >= int(regen_delay_after_damage * 1000.0)
	if health < max_health and hunger >= max_hunger * hunger_regen_threshold and rested:
		_regen_timer += delta
		if _regen_timer >= regen_interval:
			_regen_timer = 0.0
			heal(regen_health)
			set_hunger(hunger - regen_hunger_cost)
	else:
		_regen_timer = 0.0


func set_hunger(value: float) -> void:
	var v: float = clampf(value, 0.0, max_hunger)
	if is_equal_approx(v, hunger):
		return
	hunger = v
	hunger_changed.emit(hunger, max_hunger)
	_refresh_hunger_hud()


## Barra de fome logo acima da de vida (criada por código: o editor não a grava, #47).
func _setup_hunger_hud() -> void:
	var panel: Node = health_bar.get_parent() if health_bar != null else null
	if panel == null:
		return
	_hunger_label = Label.new()
	_hunger_label.name = "HungerLabel"
	if health_label != null:
		for prop: StringName in [&"font_color", &"font_outline_color"]:
			_hunger_label.add_theme_color_override(prop, health_label.get_theme_color(prop))
		_hunger_label.add_theme_constant_override(&"outline_size", 6)
		_hunger_label.add_theme_font_size_override(&"font_size", 16)
	_hunger_bar = ProgressBar.new()
	_hunger_bar.name = "HungerBar"
	_hunger_bar.custom_minimum_size = Vector2(280, 12)
	_hunger_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hunger_bar.show_percentage = false
	_hunger_bar.step = 0.01
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = UiPalette.ORANGE
	fill.set_corner_radius_all(3)
	_hunger_bar.add_theme_stylebox_override(&"fill", fill)
	panel.add_child(_hunger_label)
	panel.add_child(_hunger_bar)
	_refresh_hunger_hud()


func _refresh_hunger_hud() -> void:
	if _hunger_bar == null:
		return
	_hunger_bar.max_value = max_hunger
	_hunger_bar.value = hunger
	var low: bool = hunger <= max_hunger * 0.25
	_hunger_label.text = ("🍖 Fome: %d / %d" % [int(ceilf(hunger)), int(max_hunger)]) + ("  (com fome!)" if low else "")


func _on_health_changed(current: float, max_value: float) -> void:
	if health_bar != null:
		health_bar.max_value = max_value
		health_bar.value = current
	if health_label != null:
		health_label.text = "❤ Vida: %d / %d" % [int(ceilf(current)), int(max_value)]


# ---------------------------------------------------------------------------
# Golpe corpo-a-corpo com a pá
# ---------------------------------------------------------------------------

## Golpe apertado durante a recarga fica guardado por ATTACK_BUFFER s (combo fluido).
const ATTACK_BUFFER: float = 0.35
var _attack_buffer_left: float = 0.0


func _handle_attack_action() -> void:
	if carried_player != null:
		return
	if Input.is_action_just_pressed("attack"):
		_attack_buffer_left = ATTACK_BUFFER
	elif _attack_buffer_left > 0.0:
		_attack_buffer_left = maxf(_attack_buffer_left - get_physics_process_delta_time(), 0.0)
	if _attack_cooldown > 0.0 or dig_animator.is_playing() or _disarm_time > 0.0:
		return
	if _attack_buffer_left > 0.0:
		_attack_buffer_left = 0.0
		var c: CarriedItem = inventory.get_selected()
		if c != null and c.tool_id == TOOL_FORCADO:
			if _use_cooldown <= 0.0:
				_attack_pitchfork()
		elif c != null and c.tool_id == TOOL_HARPOON:
			if _use_cooldown <= 0.0:
				_fire_harpoon()
		elif c != null and c.tool_id == TOOL_PULSE:
			if _use_cooldown <= 0.0:
				_fire_magnetic_pulse()
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
		_register_hit(target, damage)
		hits += 1

	hits += push_pickups_in_cone(origin, forward, attack_range, attack_cone_dot, 3.5)
	if hits > 0:
		_shake_camera(0.02, 0.15)


## Itens soltos no cone do golpe saem voando (o golpe "acerta" o mundo, não só inimigos).
func push_pickups_in_cone(origin: Vector3, forward: Vector3, reach: float, cone_dot: float, strength: float) -> int:
	var pushed: int = 0
	for n: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var p: ItemPickup = n as ItemPickup
		if p == null or not is_instance_valid(p):
			continue
		var to: Vector3 = p.global_position - origin
		to.y = 0.0
		var d: float = to.length()
		if d > reach or (d > 0.05 and forward.dot(to / d) < cone_dot):
			continue
		var dir: Vector3 = (to / d) if d > 0.05 else forward
		p.push(dir * strength + Vector3.UP * strength * 0.6)
		pushed += 1
	return pushed


const SETTINGS_SCRIPT: Script = preload("res://gameplay/player/player_settings.gd")


## Opções vêm do CoreSettings (#77); a tela é a aba Jogabilidade do menu de pausa.
func _setup_settings() -> void:
	apply_settings(SETTINGS_SCRIPT.load_settings())
	var hud: Node = get_node_or_null(^"HUD")
	if hud != null:
		hud.add_to_group(SettingsManager.HUD_TEXT_GROUP)
	if SettingsManager.instance != null:
		SettingsManager.instance.settings_changed.connect(_on_core_settings_changed)


func _on_core_settings_changed(section: String, values: Dictionary) -> void:
	if section == SettingsManager.GAMEPLAY:
		apply_settings(values)


## Menu de pausa aberto: sem olhar, mover, atacar nem cavar (em coop o jogo segue).
func is_settings_open() -> bool:
	return PauseMenu.is_open()


func toggle_settings(open: bool) -> void:
	if PauseMenu.instance == null:
		return
	if open:
		PauseMenu.instance.open()
	else:
		PauseMenu.instance.close()


func current_settings() -> Dictionary:
	return {
		"mouse_sensitivity": mouse_sensitivity,
		"fov": camera.fov if camera != null else 75.0,
		"view_bobbing": view_bobbing,
		"invert_y": invert_y,
	}


func apply_settings(values: Dictionary) -> void:
	var v: Dictionary = SETTINGS_SCRIPT.sanitize(values)
	mouse_sensitivity = v["mouse_sensitivity"]
	view_bobbing = v["view_bobbing"]
	invert_y = v["invert_y"]
	if camera != null:
		camera.fov = v["fov"]
	SettingsManager.apply_hud_text_scale(get_node_or_null(^"HUD"), float(v["hud_text_scale"]))


var nearby_items_ui: Control = null
const NEARBY_ITEMS_UI_SCRIPT: Script = preload("res://gameplay/player/nearby_items_ui.gd")


func _setup_nearby_items_ui() -> void:
	var hud: Node = get_node_or_null(^"HUD")
	if hud == null:
		return
	nearby_items_ui = NEARBY_ITEMS_UI_SCRIPT.new()
	nearby_items_ui.name = "NearbyItems"
	nearby_items_ui.set("player", self)
	hud.add_child(nearby_items_ui)


func _setup_tool_sway() -> void:
	if camera == null:
		return
	tool_sway = Node3D.new()
	tool_sway.name = "ToolSway"
	camera.add_child(tool_sway)
	for n: Node3D in [tool_view, detector.get_parent() as Node3D if detector != null else null]:
		if n != null and n.get_parent() == camera:
			n.reparent(tool_sway, false)


## Sway (a ferramenta atrasa-se ao olhar), bob em fase com os passos, respiração parada
## e um mergulho curto ao trocar de slot. Tudo num pivô: os tweens de recuo seguem intactos.
func update_tool_sway(delta: float) -> void:
	if tool_sway == null:
		return
	var target: Vector2 = (-_sway_look * tool_sway_amount).limit_length(tool_sway_max)
	_sway_look = Vector2.ZERO
	_sway_offset = _sway_offset.lerp(target, 1.0 - exp(-tool_sway_return * delta))
	_breathe_time += delta
	var walk: float = _bob_weight
	var bob: Vector3 = Vector3(sin(_bob_phase * 0.5) * tool_bob_amount, -absf(sin(_bob_phase)) * tool_bob_amount, 0.0) * walk
	var breathe: float = sin(_breathe_time * 1.6) * tool_breathe_amount * (1.0 - walk)
	var equip: float = 0.0
	if _equip_left > 0.0:
		_equip_left = maxf(_equip_left - delta, 0.0)
		var t: float = _equip_left / maxf(tool_equip_time, 0.001)
		equip = t * t  # sai de baixo e assenta com ease-out
	var charge: float = get_throw_charge()
	tool_sway.position = Vector3(_sway_offset.x, _sway_offset.y + breathe - equip * 0.12 + charge * 0.03, charge * 0.12) + bob
	var k: float = deg_to_rad(tool_sway_rot_deg) / maxf(tool_sway_max, 0.0001)
	tool_sway.rotation = Vector3(-_sway_offset.y * k + equip * 0.5, _sway_offset.x * k, -_sway_offset.x * k * 0.6)


## Hitmarker na mira + número de dano no alvo (só no jogador local).
func _register_hit(target: Node3D, damage: float) -> void:
	if _hit_feedback == null or not is_instance_valid(target):
		return
	var killed: bool = target.has_method("is_alive") and not bool(target.call("is_alive"))
	_hit_feedback.show_hit(target.global_position + Vector3.UP * 0.6, damage, killed)
	if killed:
		_shake_camera(0.06, 0.25)  # matar pesa mais que acertar


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
	if InputMap.has_action("drop"):
		if Input.is_action_just_pressed("drop"):
			if carried_player != null:
				request_drop_carried_player()
				return
			_drop_hold = 0.0
			_drop_holding = inventory.get_selected() != null
			if not _drop_holding:
				_drop_selected()
		elif _drop_holding and Input.is_action_pressed("drop"):
			_drop_hold += get_physics_process_delta_time()
		elif _drop_holding:
			_drop_holding = false
			_drop_selected(get_throw_charge())
			_drop_hold = 0.0


func _interact() -> void:
	if is_downed:
		return
	if carried_player != null:
		var sp: SellPoint = _get_sell_point_in_range()
		if sp != null:
			request_revive_player(carried_player)
		else:
			request_drop_carried_player()
		return
	if _target_downed_player != null and is_instance_valid(_target_downed_player):
		var sp: SellPoint = _get_sell_point_in_range()
		if sp != null or _is_player_at_base(_target_downed_player):
			request_revive_player(_target_downed_player)
		else:
			request_carry_player(_target_downed_player)
		return

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
		_show_temporary_message("📦 Entregue: %d itens, %s" % [items.size(), MoneyFormat.money(total)], UiPalette.GREEN_BOTTLE.lightened(0.3), 2.5)
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
	var value: String = "" if c.is_tool() else " (%s)" % MoneyFormat.money(c.final_value)
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


var _drop_hold: float = 0.0
var _drop_holding: bool = false


## 0..1 do arremesso a ser carregado com [Q] (0 = só largar).
func get_throw_charge() -> float:
	if not _drop_holding and _drop_hold <= 0.0:
		return 0.0
	return clampf((_drop_hold - throw_charge_delay) / maxf(throw_charge_time, 0.01), 0.0, 1.0)


## Impulso do item largado: toque = cai à frente; carregado = voa na direção da mira
## (somando a velocidade do jogador, como um arremesso de verdade).
func get_throw_impulse(charge: float) -> Vector3:
	var fwd: Vector3 = -camera.global_basis.z
	var flat: Vector3 = Vector3(fwd.x, 0.0, fwd.z).normalized()
	if charge <= 0.0:
		return flat * drop_impulse + Vector3.UP * 0.6
	var aim: Vector3 = (fwd + Vector3.UP * 0.25).normalized()
	var carry: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * 0.5
	return aim * lerpf(drop_impulse, throw_max_impulse, charge) + carry


func _drop_selected(charge: float = 0.0) -> void:
	var c: CarriedItem = inventory.take_selected()
	if c == null:
		_show_temporary_message("Slot vazio.", Color(0.9, 0.9, 0.9), 0.8)
		return
	var fwd: Vector3 = -camera.global_basis.z
	var pos: Vector3 = camera.global_position + fwd * 0.7 + Vector3.DOWN * 0.3
	ItemPickup.spawn(get_parent(), c, pos, get_throw_impulse(charge))
	SFX.play_at(SFX.DROP if charge < 0.3 else SFX.SLINGSHOT_FIRE, pos, -3.0)


## Interactable (#39/#40): o [E] fica com o jogador quando ele tem alvo próprio (produto da
## banca, item no chão ou entrega possível na base).
func has_own_interact_target() -> bool:
	if carried_player != null:
		return true
	if _target_downed_player != null and is_instance_valid(_target_downed_player):
		return true
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
	var downed_p: Player = _find_target_downed_player()
	_target_downed_player = downed_p

	var offer: ShopOffer = null if (_target_downed_player != null or carried_player != null) else _find_target_offer()
	if offer != _target_offer:
		if _target_offer != null and is_instance_valid(_target_offer):
			_target_offer.set_highlighted(false)
		_target_offer = offer
		if _target_offer != null:
			_target_offer.set_highlighted(true)

	var target: ItemPickup = null if (_target_offer != null or _target_downed_player != null or carried_player != null) else _find_target_pickup()
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

	if carried_player != null:
		if sell_point != null:
			interact_prompt.text = "[E] Reanimar %s na base | [Q] Largar" % _get_player_name(carried_player)
		else:
			interact_prompt.text = "[Q] Largar corpo de %s" % _get_player_name(carried_player)
	elif _target_downed_player != null:
		if sell_point != null or _is_player_at_base(_target_downed_player):
			interact_prompt.text = "[E] Reanimar %s" % _get_player_name(_target_downed_player)
		else:
			interact_prompt.text = "[E] Carregar %s" % _get_player_name(_target_downed_player)
	elif _target_offer != null:
		var full: String = "  — mochila cheia!" if inventory.is_full() else ""
		interact_prompt.text = _target_offer.get_prompt() + full
	elif sell_point != null and deliverable > 0:
		interact_prompt.text = "[E] Entregar mochila (%d itens, %s)" % [deliverable, MoneyFormat.money(inventory.get_total_value())]
	elif _target_pickup != null and _target_pickup.carried != null:
		var aimed: CarriedItem = _target_pickup.carried
		var suffix: String = "  — mochila cheia!" if inventory.is_full() else ""
		if _already_has_unique_tool(aimed):
			suffix = "  — já tem um"
		var value: String = "" if aimed.is_tool() else " (%s)" % MoneyFormat.money(aimed.final_value)
		interact_prompt.text = "[E] Apanhar %s%s%s" % [aimed.get_display_name(), value, suffix]
	else:
		interact_prompt.text = ""


func _on_inventory_changed() -> void:
	_update_session_hud()
	_update_tool_in_hand()
	carrying_loot = _count_deliverable() > 0


func _on_selected_slot_changed(_index: int) -> void:
	_update_tool_in_hand()
	_equip_left = tool_equip_time


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
	# Arpão de Corda com a mão direita na coronha e a mão esquerda a apoiar o cano
	var harpoon_pose: Transform3D = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-8.0)).rotated(Vector3.UP, deg_to_rad(8.0)).scaled(Vector3.ONE * 0.75), Vector3(0.04, -0.07, -0.16))
	var harpoon_model: Node3D = _add_held_model(HARPOON_MODEL, harpoon_pose)
	if "show_left_hand" in harpoon_model:
		harpoon_model.set("show_left_hand", true)
	_held_models[TOOL_HARPOON] = harpoon_model
	# Pulso Magnético com a pega na mão direita e a mão esquerda por baixo das bobinas
	var pulse_pose: Transform3D = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-6.0)).rotated(Vector3.UP, deg_to_rad(6.0)).scaled(Vector3.ONE * 0.8), Vector3(0.03, -0.07, -0.16))
	var pulse_model: Node3D = _add_held_model(PULSE_MODEL, pulse_pose)
	if "show_left_hand" in pulse_model:
		pulse_model.set("show_left_hand", true)
	_held_models[TOOL_PULSE] = pulse_model
	# #61: Armadilha de Rede (rolo segurado de lado) e Lanterna de Magnésio (pela asa, refletor
	# para a frente).
	_held_models[TOOL_NET_TRAP] = _add_held_model(NET_TRAP_MODEL,
		Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)).scaled(Vector3.ONE * 0.45), Vector3(-0.02, -0.1, -0.06)))
	_held_models[TOOL_LANTERN] = _add_held_model(LANTERN_MODEL,
		Transform3D(Basis(Vector3.UP, deg_to_rad(-10.0)).scaled(Vector3.ONE * 0.7), Vector3(0.0, -0.16, -0.06)))
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
	if carried_player != null or not Input.is_action_just_pressed("use_tool") or _use_cooldown > 0.0 or _disarm_time > 0.0:
		return
	var c: CarriedItem = inventory.get_selected()
	if c == null or c.tool_data == null:
		return
	if c.tool_data.category == ToolData.Category.FOOD:
		eat(c)
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
		TOOL_HARPOON:
			_fire_harpoon()
		TOOL_PULSE:
			_fire_magnetic_pulse()


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


## Come a comida do slot: cura heal_amount e gasta a unidade. Falso se não comeu.
func eat(c: CarriedItem) -> bool:
	if c == null or c.tool_data == null or c.tool_data.category != ToolData.Category.FOOD:
		return false
	if health >= max_health and hunger >= max_hunger - 0.5:
		_show_temporary_message("Sem fome agora.", Color(0.9, 0.9, 0.9), 1.0)
		return false
	var amount: float = c.tool_data.heal_amount
	heal(amount)
	set_hunger(hunger + c.tool_data.hunger_restore)
	SFX.play_ui(SFX.MEDKIT, -6.0, 0.15)
	_show_temporary_message("😋 %s: +%d vida, +%d saciedade" % [c.tool_name, int(amount), int(c.tool_data.hunger_restore)],
		Color(0.5, 1.0, 0.55), 1.2)
	# Sem o aviso "acabou" do _consume: comer é sempre uma unidade só.
	if c.consume_charge():
		var idx: int = inventory.slots.find(c)
		if idx >= 0:
			inventory.remove_at(idx)
	else:
		inventory.notify_changed()
	_use_cooldown = 0.6
	return true


## Come a primeira comida da mochila (bots e atalhos). Falso se não havia ou não comeu.
func eat_any_food() -> bool:
	for c: CarriedItem in inventory.slots:
		if c != null and c.tool_data != null and c.tool_data.category == ToolData.Category.FOOD:
			return eat(c)
	return false


## Comidas que podem sair do chão de `map_id`.
static func foods_for_map(map_id: String) -> Array[ToolData]:
	if not _food_cache_loaded:
		_food_cache_loaded = true
		var dir: DirAccess = DirAccess.open(GameState.TOOLS_DIR)
		if dir != null:
			for file_name: String in dir.get_files():
				var clean: String = file_name.trim_suffix(".remap")
				if not clean.ends_with(".tres"):
					continue
				var td: ToolData = load("%s/%s" % [GameState.TOOLS_DIR, clean]) as ToolData
				if td != null and td.category == ToolData.Category.FOOD:
					_food_cache.append(td)
	var out: Array[ToolData] = []
	for td: ToolData in _food_cache:
		if td.dig_maps.has(map_id):
			out.append(td)
	return out


## Sorteia a comida de uma pazada fora de sinal (null = só terra). `roll` permite testar.
static func roll_dig_food(map_id: String, careful: bool, roll: float = -1.0) -> ToolData:
	var pool: Array[ToolData] = foods_for_map(map_id)
	if pool.is_empty():
		return null
	if roll < 0.0:
		roll = randf()
	var chance: float = FOOD_DIG_CHANCE_CAREFUL if careful else FOOD_DIG_CHANCE
	if roll >= chance:
		return null
	# Reaproveita o mesmo número para escolher qual: roll/chance cai em [0, 1).
	var total: float = 0.0
	for td: ToolData in pool:
		total += maxf(td.dig_weight, 0.0)
	var pick: float = (roll / chance) * total
	for td: ToolData in pool:
		pick -= maxf(td.dig_weight, 0.0)
		if pick < 0.0:
			return td
	return pool.back()


func _give_dug_food(food: ToolData) -> void:
	if inventory.is_full():
		_show_temporary_message("🪱 Saiu %s, mas a mochila está cheia e escapou." % food.display_name.to_lower(),
			Color(1.0, 0.6, 0.3), 1.6)
		return
	inventory.add_item(CarriedItem.create_from_tool_data(food))
	SFX.play_ui(SFX.PICKUP, -4.0)
	_show_temporary_message("🪱 Achou: %s! (clique para comer)" % food.display_name, Color(0.75, 0.95, 0.55), 1.8)


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
		_register_hit(target, pitchfork_damage)

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

	# A estocada também atira os itens soltos à frente (mais forte que a pá).
	var items_hit: int = push_pickups_in_cone(global_position, forward, pitchfork_range, pitchfork_cone_dot, 5.0)
	if hits > 0:
		_shake_camera(0.03, 0.18)
		SFX.play_ui(SFX.STONE_IMPACT, -2.0, 0.1)
	elif items_hit > 0:
		SFX.play_ui(SFX.STONE_IMPACT, -6.0, 0.1)
	else:
		SFX.play_ui(SFX.SLINGSHOT_FIRE, -10.0, 0.2)

	return hits


func _attack_pitchfork() -> void:
	attack_pitchfork()


## Disparo do Arpão de Corda (#43): alcance até ~14m.
## Se acertar num inimigo: aplica dano (40), atordoamento (0.8s) e puxa-o na direção do jogador.
## Se acertar num item no chão (ItemPickup): puxa o item até ao jogador.
## Suporta coop via request_hit/request_stun nos inimigos replicados.
func fire_harpoon() -> int:
	_use_cooldown = harpoon_cooldown
	_attack_cooldown = harpoon_cooldown

	# Animação de recuo do arpão no ToolView
	if tool_view != null:
		var t: Tween = create_tween()
		var recoil: Vector3 = _tool_view_rest + Vector3(0.0, 0.03, 0.15)
		t.tween_property(tool_view, "position", recoil, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(tool_view, "rotation:x", 0.12, 0.06)
		t.tween_property(tool_view, "position", _tool_view_rest, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(tool_view, "rotation:x", 0.0, 0.3)

	var fwd: Vector3 = -camera.global_basis.z if camera != null else -global_basis.z
	var fwd_flat: Vector3 = Vector3(fwd.x, 0.0, fwd.z).normalized()
	if fwd_flat.is_zero_approx():
		fwd_flat = Vector3.FORWARD
	var origin: Vector3 = camera.global_position if camera != null else global_position
	var hit_count: int = 0
	var hit_point: Vector3 = origin + fwd * harpoon_range

	var best_target: Node3D = null
	var best_dist: float = harpoon_range + 0.1
	var is_pickup: bool = false

	# 1. Inimigos alinhados com a mira dentro do alcance de 14m
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node3D):
			continue
		var enemy: Node3D = n as Node3D
		if enemy.has_method("is_alive") and not enemy.call("is_alive"):
			continue
		var to_e: Vector3 = enemy.global_position - origin
		var to_e_flat: Vector3 = Vector3(to_e.x, 0.0, to_e.z)
		var dist_flat: float = to_e_flat.length()
		var dist_3d: float = to_e.length()
		if dist_flat > harpoon_range or dist_3d < 0.2:
			continue
		var dot: float = fwd_flat.dot(to_e_flat / maxf(dist_flat, 0.001))
		if dot >= harpoon_cone_dot and dist_flat < best_dist:
			best_dist = dist_flat
			best_target = enemy
			is_pickup = false

	# 2. Se não encontrou inimigo, verifica pickups de itens no chão
	if best_target == null:
		for n: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
			var pickup: ItemPickup = n as ItemPickup
			if pickup == null or not is_instance_valid(pickup):
				continue
			var to_p: Vector3 = pickup.global_position - origin
			var dist: float = to_p.length()
			if dist > harpoon_range or dist < 0.2:
				continue
			var dot: float = fwd.dot(to_p / dist)
			if dot >= harpoon_cone_dot and dist < best_dist:
				best_dist = dist
				best_target = pickup
				is_pickup = true

	# 3. Raycast se o cone não encontrou
	if best_target == null:
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin, origin + fwd * harpoon_range, PICKUP_MASK | 1, [get_rid()]
		)
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			hit_point = hit["position"]
			var col: Object = hit.get("collider", null)
			if col is ItemPickup:
				best_target = col as ItemPickup
				is_pickup = true
			elif col is Node3D and (col as Node3D).is_in_group("enemies"):
				best_target = col as Node3D
				is_pickup = false

	if best_target != null:
		hit_point = best_target.global_position

	_spawn_harpoon_rope(origin + fwd * 0.4 - Vector3.UP * 0.1, hit_point)

	if best_target != null:
		hit_count = 1
		var pull_dir: Vector3 = (origin - best_target.global_position).normalized()
		pull_dir.y = 0.2
		pull_dir = pull_dir.normalized()

		if is_pickup:
			var pickup: ItemPickup = best_target as ItemPickup
			var pull_dest: Vector3 = global_position + (-fwd * 0.2) + Vector3.UP * 0.3
			pickup.linear_velocity = (pull_dest - pickup.global_position).normalized() * 10.0 + Vector3.UP * 2.5
			var t_p: Tween = pickup.create_tween()
			t_p.tween_property(pickup, "global_position", pull_dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			SFX.play_ui(SFX.PICKUP, -2.0)
			_show_temporary_message("⚓ Item fisgado pelo arpão!", Color(0.45, 0.85, 1.0), 1.0)
		else:
			var enemy: Node3D = best_target
			# Suporte a coop: no cliente sem autoridade usa request_hit/request_stun para o host
			if enemy.has_method("request_hit") and not (enemy.has_method("has_simulation_authority") and enemy.call("has_simulation_authority")):
				enemy.call("request_hit", harpoon_damage, origin)
			elif enemy.has_method("take_damage"):
				enemy.call("take_damage", harpoon_damage, origin)
			_register_hit(enemy, harpoon_damage)

			if enemy.has_method("request_stun") and not (enemy.has_method("has_simulation_authority") and enemy.call("has_simulation_authority")):
				enemy.call("request_stun", harpoon_stun)
			elif enemy.has_method("stun"):
				enemy.call("stun", harpoon_stun)

			if enemy.has_method("apply_knockback"):
				enemy.call("apply_knockback", pull_dir * harpoon_pull_force + Vector3.UP * 1.5, 0.08)
			if enemy is CharacterBody3D:
				var cb: CharacterBody3D = enemy as CharacterBody3D
				cb.velocity += pull_dir * harpoon_pull_force + Vector3.UP * 1.5
				cb.move_and_collide(pull_dir * (harpoon_pull_force * 0.12))

			_shake_camera(0.025, 0.16)
			SFX.play_ui(SFX.STONE_IMPACT, -1.0, 0.1)
			_show_temporary_message("⚓ Arpão cravado! Inimigo puxado e atordoado! (%d de dano)" % int(harpoon_damage), Color(0.5, 0.85, 1.0), 1.0)
	else:
		SFX.play_ui(SFX.SLINGSHOT_FIRE, -4.0, 0.2)

	return hit_count


func _fire_harpoon() -> void:
	fire_harpoon()


func _spawn_harpoon_rope(from: Vector3, to: Vector3) -> void:
	var parent: Node = get_parent() if get_parent() != null else self
	var rope: ImmediateMesh = ImmediateMesh.new()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = rope
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.76, 0.66, 0.48)
	mi.material_override = mat

	rope.surface_begin(Mesh.PRIMITIVE_LINES)
	rope.surface_add_vertex(from)
	rope.surface_add_vertex(to)
	rope.surface_end()

	parent.add_child(mi)
	var t: Tween = mi.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	t.tween_callback(mi.queue_free)


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


## Velocidade alvo: andar, ou correr com Shift indo pra frente (sem correr agachado na escavação).
func get_target_speed(input_dir: Vector2) -> float:
	var sprinting: bool = InputMap.has_action("sprint") and Input.is_action_pressed("sprint") \
		and input_dir.y < -0.1 and not dig_animator.is_playing() and carried_player == null
	var spd: float = speed * (sprint_multiplier if sprinting else 1.0)
	if carried_player != null:
		spd *= carry_speed_multiplier
	return spd


## Aproxima a velocidade horizontal do alvo de forma exponencial (independe do FPS).
func _apply_horizontal_movement(direction: Vector3, input_dir: Vector2, on_floor: bool, delta: float) -> void:
	var target: Vector3 = direction * get_target_speed(input_dir)
	var rate: float = ground_acceleration if direction != Vector3.ZERO else ground_deceleration
	if not on_floor:
		rate *= air_control
	var flat: Vector2 = Vector2(velocity.x, velocity.z).lerp(Vector2(target.x, target.z), 1.0 - exp(-rate * delta))
	velocity.x = flat.x
	velocity.z = flat.y


## Passos e balanço da câmera na mesma fase: um passo a cada STEP_LENGTH metros,
## e o som sai quando a câmera chega ao ponto mais baixo (pé tocando o chão).
func _update_footsteps(delta: float) -> void:
	var horizontal: float = Vector2(velocity.x, velocity.z).length()
	var walking: bool = is_on_floor() and horizontal >= 0.5
	_bob_weight = move_toward(_bob_weight, 1.0 if walking else 0.0, delta * 6.0)
	if walking:
		var prev_step: int = int(floor(_bob_phase / PI))
		_bob_phase += horizontal * delta * PI / STEP_LENGTH
		if int(floor(_bob_phase / PI)) != prev_step and footsteps_enabled:
			SFX.play_at(SFX.FOOTSTEP_SAND, global_position, footsteps_volume_db + randf_range(-1.5, 1.5), 0.05)
	else:
		# O 1.o passo sai pouco depois de arrancar.
		_bob_phase = PI * 0.4
	_apply_head_bob(horizontal)


func _apply_head_bob(horizontal: float) -> void:
	if camera == null:
		return
	if not view_bobbing:
		camera.position = Vector3.ZERO
		return
	var amp: float = _bob_weight * clampf(horizontal / maxf(speed, 0.01), 0.0, 1.6)
	# Vertical: |sin| invertido dá um vale por passo; horizontal: um vaivém a cada 2 passos.
	var y: float = -absf(sin(_bob_phase)) * head_bob_vertical * amp
	var x: float = sin(_bob_phase * 0.5) * head_bob_horizontal * amp
	camera.position = Vector3(x, y + head_bob_vertical * amp * 0.5, 0.0)


## Disparo do Pulso Magnético (#44): onda expansiva eletromagnética.
## Empurra criaturas/inimigos num raio de ~7.5m (dano, knockback forte e stun curto).
## Puxa todos os itens metálicos (ItemPickup) num raio de ~12m para perto do jogador.
## Suporta coop via request_hit/request_stun nos inimigos replicados.
func fire_magnetic_pulse() -> int:
	_use_cooldown = magnetic_pulse_cooldown
	_attack_cooldown = magnetic_pulse_cooldown

	# Animação de disparo com recuo elétrico no ToolView
	if tool_view != null:
		var t: Tween = create_tween()
		var recoil: Vector3 = _tool_view_rest + Vector3(0.0, 0.04, 0.16)
		t.tween_property(tool_view, "position", recoil, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(tool_view, "rotation:x", 0.14, 0.05)
		t.tween_property(tool_view, "position", _tool_view_rest, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(tool_view, "rotation:x", 0.0, 0.28)

	var fwd: Vector3 = -camera.global_basis.z if camera != null else -global_basis.z
	var fwd_flat: Vector3 = Vector3(fwd.x, 0.0, fwd.z).normalized()
	if fwd_flat.is_zero_approx():
		fwd_flat = Vector3.FORWARD
	var origin: Vector3 = camera.global_position if camera != null else global_position

	_spawn_magnetic_wave(origin + fwd * 0.5, fwd)

	var enemy_hits: int = 0
	var pulled_pickups: int = 0

	# 1. Empurra criaturas/inimigos num cone/raio de ~7.5m
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node3D):
			continue
		var enemy: Node3D = n as Node3D
		if enemy.has_method("is_alive") and not enemy.call("is_alive"):
			continue
		var to_e: Vector3 = enemy.global_position - origin
		var dist: float = to_e.length()
		var to_e_flat: Vector3 = Vector3(to_e.x, 0.0, to_e.z)
		var dist_flat: float = to_e_flat.length()
		if dist > magnetic_pulse_enemy_range:
			continue
		var dot: float = fwd_flat.dot(to_e_flat / maxf(dist_flat, 0.001))
		# Cone frontal amplo ou proximidade imediata (< 2.5m em toda a volta)
		if dot < magnetic_pulse_cone_dot and dist > 2.5:
			continue

		var push_dir: Vector3 = to_e.normalized() if dist > 0.05 else fwd
		push_dir.y = 0.35
		push_dir = push_dir.normalized()

		if enemy.has_method("request_hit") and not (enemy.has_method("has_simulation_authority") and enemy.call("has_simulation_authority")):
			enemy.call("request_hit", magnetic_pulse_damage, origin)
		elif enemy.has_method("take_damage"):
			enemy.call("take_damage", magnetic_pulse_damage, origin)
		_register_hit(enemy, magnetic_pulse_damage)

		if enemy.has_method("request_stun") and not (enemy.has_method("has_simulation_authority") and enemy.call("has_simulation_authority")):
			enemy.call("request_stun", magnetic_pulse_stun)
		elif enemy.has_method("stun"):
			enemy.call("stun", magnetic_pulse_stun)

		if enemy.has_method("apply_knockback"):
			enemy.call("apply_knockback", push_dir * magnetic_pulse_knockback + Vector3.UP * 3.5, 0.1)
		if enemy is CharacterBody3D:
			var cb: CharacterBody3D = enemy as CharacterBody3D
			cb.velocity += push_dir * magnetic_pulse_knockback + Vector3.UP * 3.0
			cb.move_and_collide(push_dir * (magnetic_pulse_knockback * 0.15))

		enemy_hits += 1

	# 2. Puxa todos os itens metálicos ItemPickup num raio de ~12m
	for n: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var pickup: ItemPickup = n as ItemPickup
		if pickup == null or not is_instance_valid(pickup):
			continue
		var to_p: Vector3 = pickup.global_position - origin
		var dist_p: float = to_p.length()
		if dist_p > magnetic_pulse_pickup_range or dist_p < 0.2:
			continue

		var pull_dest: Vector3 = global_position + Vector3.UP * 0.35 - fwd_flat * 0.3
		pickup.linear_velocity = (pull_dest - pickup.global_position).normalized() * 12.0 + Vector3.UP * 2.5
		var t_p: Tween = pickup.create_tween()
		t_p.tween_property(pickup, "global_position", pull_dest, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pulled_pickups += 1

	_shake_camera(0.04, 0.22)
	SFX.play_ui(SFX.STONE_IMPACT, 2.0, 0.15)
	if enemy_hits > 0 or pulled_pickups > 0:
		_show_temporary_message("⚡ Pulso Magnético! (%d repelidos, %d atraídos)" % [enemy_hits, pulled_pickups], Color(0.65, 0.85, 1.0), 1.1)
	else:
		_show_temporary_message("⚡ Pulso Magnético disparado!", Color(0.6, 0.8, 1.0), 0.8)

	return enemy_hits + pulled_pickups


func _fire_magnetic_pulse() -> void:
	fire_magnetic_pulse()


func _spawn_magnetic_wave(origin: Vector3, forward: Vector3) -> void:
	var parent: Node = get_parent() if get_parent() != null else self
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.25
	torus.outer_radius = 0.45
	ring.mesh = torus
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.35, 0.95, 1.0, 0.8)
	ring.material_override = mat

	ring.global_position = origin
	var up_target: Vector3 = forward.normalized()
	if not up_target.is_zero_approx():
		ring.quaternion = Quaternion(Vector3.UP, up_target)

	parent.add_child(ring)
	var t: Tween = ring.create_tween()
	t.tween_property(ring, "scale", Vector3(12.0, 1.0, 12.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	t.tween_callback(ring.queue_free)


# ---------------------------------------------------------------------------
# #57: efeitos caóticos dos inimigos (só o dono aplica; o host chama por RPC)
# ---------------------------------------------------------------------------

## Cobra enrolada: anda a 25 % até `seconds` passarem; cada tecla de movimento premida tira
## SNARE_SHAKE_OFF s (abanar para soltar).
const SNARE_SHAKE_OFF: float = 0.3
const SNARE_SPEED_FACTOR: float = 0.25
const INK_FADE: float = 0.6


@rpc("any_peer", "call_local", "reliable")
func apply_snare(seconds: float) -> void:
	if not is_local() or health <= 0.0:
		return
	_snare_time = maxf(_snare_time, clampf(seconds, 0.0, 4.0))
	_show_temporary_message("🐍 Uma cobra enrolou-se em ti! Abana (WASD)!", Color(0.6, 1.0, 0.45), 1.6)


## Corvo-Rei roubou a ferramenta: sem atacar nem usar ferramentas durante `seconds`.
@rpc("any_peer", "call_local", "reliable")
func apply_disarm(seconds: float) -> void:
	if not is_local() or health <= 0.0:
		return
	_disarm_time = maxf(_disarm_time, clampf(seconds, 0.0, 8.0))
	if tool_view != null:
		tool_view.visible = false
	_show_temporary_message("👑 O Corvo-Rei roubou-te a ferramenta! Acerta-lhe!", Color(1.0, 0.55, 0.35), 2.0)


## Corvo-Rei largou a ferramenta (levou um golpe): volta já à mão.
@rpc("any_peer", "call_local", "reliable")
func end_disarm() -> void:
	if is_local() and _disarm_time > 0.0:
		_disarm_time = 0.0
		_update_tool_in_hand()


## Tinta do polvo: manchas pretas a tapar parte do ecrã durante `seconds`.
@rpc("any_peer", "call_local", "reliable")
func apply_ink(seconds: float) -> void:
	if not is_local() or health <= 0.0:
		return
	_ink_time = maxf(_ink_time, clampf(seconds, 0.0, 6.0))
	_build_ink_overlay()
	_shake_camera(0.04, 0.3)


func is_snared() -> bool:
	return _snare_time > 0.0


func is_disarmed() -> bool:
	return _disarm_time > 0.0


func is_inked() -> bool:
	return _ink_time > 0.0


## Corre no _physics_process do dono: conta os tempos e trava o andar enquanto enrolado.
func _apply_chaos_effects(direction: Vector3, delta: float) -> Vector3:
	if _disarm_time > 0.0:
		_disarm_time -= delta
		if _disarm_time <= 0.0:
			_update_tool_in_hand()
	if _ink_time > 0.0:
		_ink_time -= delta
		if _ink_layer != null:
			_ink_layer.get_child(0).modulate.a = clampf(_ink_time / INK_FADE, 0.0, 1.0)
			if _ink_time <= 0.0:
				_ink_layer.queue_free()
				_ink_layer = null
	if _snare_time <= 0.0:
		return direction
	_snare_time -= delta
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_backward"]:
		if Input.is_action_just_pressed(action):
			_snare_time -= SNARE_SHAKE_OFF
	if _snare_time <= 0.0:
		_show_temporary_message("Soltaste-te!", Color(0.8, 1.0, 0.7), 0.8)
	return direction * SNARE_SPEED_FACTOR


func _build_ink_overlay() -> void:
	if _ink_layer != null:
		return
	_ink_layer = CanvasLayer.new()
	_ink_layer.name = "InkOverlay"
	_ink_layer.layer = 5
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink_layer.add_child(root)
	var size: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	# Manchas de tinta (#57): ~30-35 % do ecrã, mais para os lados (o centro fica legível).
	var spots: Array[Vector2] = [Vector2(0.18, 0.3), Vector2(0.82, 0.62), Vector2(0.3, 0.78), Vector2(0.7, 0.22)]
	for c01: Vector2 in spots:
		var blot: Polygon2D = Polygon2D.new()
		var c: Vector2 = Vector2((c01.x + randf_range(-0.05, 0.05)) * size.x, (c01.y + randf_range(-0.05, 0.05)) * size.y)
		var r: float = randf_range(0.2, 0.22) * size.y
		var pts: PackedVector2Array = []
		for k: int in 12:
			var ang: float = TAU * float(k) / 12.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * r * randf_range(0.8, 1.15))
		blot.polygon = pts
		blot.color = Color(0.04, 0.02, 0.07, 0.9)
		root.add_child(blot)
	add_child(_ink_layer)
