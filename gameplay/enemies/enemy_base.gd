class_name EnemyBase
extends CharacterBody3D

## Base de todos os inimigos (grupo 'enemies', layer 4). Trata vida, dano com origem,
## atordoamento (stun), fuga (flee), flash de dano, partículas e procura do jogador.
## Subclasses implementam _enemy_physics(delta) e os ganchos _on_*.
##
## API usada pelas armas (Dev_Player):
##   take_damage(amount, from = Vector3.INF)  — from = origem do golpe (INF = desconhecida)
##   stun(seconds)                            — parado e sem atacar, com estrelas por cima
##   flee_from(origin, seconds)               — foge e depois vai-se embora
##   is_alive()
##
## Coop (#5, bloco F; #24): a IA e a física só correm no host. O EnemySpawner cria os
## inimigos por MultiplayerSpawner e chama setup_network(): cada um ganha um
## MultiplayerSynchronizer (position, rotation, net_state, health, stunned, fleeing) visível
## só para peers com o mapa carregado. Num cliente, take_damage/stun/flee_from na réplica
## viram request_hit/request_stun/request_flee para o host, que confere a distância do
## jogador que pediu e a cadência antes de aplicar. Os inimigos perseguem o jogador mais
## próximo entre TODOS (grupo "players") e ferem-no com apply_damage.rpc_id(dono).

signal died()
signal damaged(amount: float, health_left: float)

const GROUP: StringName = &"enemies"
const RETARGET_INTERVAL: float = 0.5
const FLASH_TIME: float = 0.12
const FLASH_COLOR: Color = Color(1.0, 0.25, 0.2)
## Flash quando o golpe foi amortecido (ex.: concha do ermitão).
const BLOCK_FLASH_COLOR: Color = Color(0.55, 0.65, 1.0)
## Grupos de jogadores: "players" (todos, coop) e "player" (só o local; testes/solo antigo).
const PLAYERS_GROUPS: Array[StringName] = [&"players", &"player"]
## Validação no host dos pedidos dos clientes (#5 F; Fase 4 do Dev B endurecida na #48).
## Margem de folga adicionada ao alcance das armas.
const REQUEST_RANGE_MARGIN: float = 2.0
## Alcance máximo por arma (alcance nativo + 2.0 m de folga):
const RANGE_SHOVEL: float = 4.2        # 2.2 + 2.0 (pá)
const RANGE_PITCHFORK: float = 5.2     # 3.2 + 2.0 (forcado)
const RANGE_LANTERN: float = 11.0      # 9.0 + 2.0 (lanterna de magnésio)
const RANGE_SLINGSHOT: float = 24.0    # 22.0 + 2.0 (estilingue / projéteis)
const RANGE_REPELLENT: float = 7.5     # 5.5 + 2.0 (repelente de caranguejo)
const RANGE_NET_TRAP: float = 4.5      # 1.6 + 0.75 + 2.0 (armadilha de rede)
const RANGE_HARPOON: float = 16.0      # 14.0 + 2.0 (arpão de corda)
const RANGE_MAGNETIC_PULSE: float = 10.0 # 8.0 + 2.0 (pulso magnético)
## Teto máximo absoluto de alcance (estilingue) e dano (pá melhorada / forcado).
const REQUEST_MAX_RANGE: float = 24.0
const REQUEST_MAX_DAMAGE: float = 35.0
const REQUEST_MIN_INTERVAL_MS: int = 150
const REQUEST_MAX_STUN: float = 6.0
const REQUEST_MAX_FLEE: float = 10.0

@export var max_health: float = 50.0
## Cor das partículas ao morrer.
@export var death_color: Color = Color(0.95, 0.42, 0.12)
## Altura (local) onde aparecem as estrelas do atordoamento.
@export var stun_fx_height: float = 0.6

var health: float = 50.0
## Origem do último golpe (para a morte voar para o lado certo).
var _last_hit_from: Vector3 = Vector3.INF
var _flung: bool = false
const DEATH_FLING: Script = preload("res://gameplay/enemies/death_fling.gd")
## Posto a true pelo MultiplayerSpawner (fase 3, #24): só o host simula; os clientes só
## recebem position/rotation/state/health/stunned/fleeing.
var replicated: bool = false

## Campos simples para o MultiplayerSynchronizer. No host refletem o estado real; num
## cliente replicado, escrever neles só liga/desliga o efeito visual.
var stunned: bool:
	get:
		return _stun_left > 0.0
	set(value):
		if value == (_stun_left > 0.0):
			return
		_stun_left = 0.25 if value else 0.0
		_set_stun_fx(value)
var fleeing: bool:
	get:
		return _flee_left > 0.0
	set(value):
		_flee_left = maxf(_flee_left, 0.25) if value else 0.0
## `state` da subclasse como int (o synchronizer não conhece os enums). Num cliente, a
## mudança chama _on_remote_state() para acertar o visual (corpo escondido, monte de terra...).
var net_state: int:
	get:
		return int(get("state")) if "state" in self else 0
	set(value):
		if not "state" in self or int(get("state")) == value:
			return
		set("state", value)
		if not has_simulation_authority():
			_on_remote_state(value)

var _net_sync: MultiplayerSynchronizer = null
## Cliente: velocidade estimada a partir da posição replicada (para animar o andar, #31).
var remote_speed: float = 0.0
var _remote_last_pos: Vector3 = Vector3.INF
var _remote_since_move: float = 0.0
## Host: último pedido aceite por peer (cadência).
var _last_request_ms: Dictionary = {}

var _gravity: float = 9.8
var _target: Node3D = null
var _retarget_timer: float = 0.0
var _stun_left: float = 0.0
var _flee_left: float = 0.0
var _flee_origin: Vector3 = Vector3.ZERO
var _dead: bool = false
var _flash_mats: Array[Material] = []
var _flash_base_colors: Array[Color] = []
var _flash_tween: Tween = null
var _stun_fx: Node3D = null
## Alvo de evento (WaveEvent): persegue-o em vez do jogador, salvo se um jogador estiver perto.
## Só no host (a IA corre lá). Um alvo sem take_damage só serve de destino.
var objective_target: Node3D = null
var objective_aggro_radius: float = 3.0


func _ready() -> void:
	add_to_group(GROUP)
	health = max_health
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_connect_expedition_ending()


func _exit_tree() -> void:
	if _net_sync != null and is_instance_valid(_net_sync):
		_net_sync.public_visibility = false
	var sm: SessionManager = SessionManager.instance
	if sm == null and is_inside_tree():
		var node: Node = get_node_or_null("/root/CoreSession")
		if node is SessionManager:
			sm = node
	if sm != null and sm.expedition_ending.is_connected(_on_expedition_ending):
		sm.expedition_ending.disconnect(_on_expedition_ending)


func _connect_expedition_ending() -> void:
	var sm: SessionManager = SessionManager.instance
	if sm == null and is_inside_tree():
		var node: Node = get_node_or_null("/root/CoreSession")
		if node is SessionManager:
			sm = node
	if sm != null and not sm.expedition_ending.is_connected(_on_expedition_ending):
		sm.expedition_ending.connect(_on_expedition_ending)


func _on_expedition_ending(_map_id: String = "") -> void:
	if _net_sync != null and is_instance_valid(_net_sync):
		_net_sync.public_visibility = false


func _physics_process(delta: float) -> void:
	if not has_simulation_authority():
		if not _dead:
			_update_remote_motion(delta)
		# Cliente: a vida replicada chegou a 0 antes do despawn do host; o voo é local.
		if health <= 0.0 and not _flung and _uses_default_death():
			spawn_particles(global_position + Vector3.UP * 0.25, death_color, 28, 3.5)
			death_fling()
		return
	if _dead:
		return
	if _flee_left > 0.0:
		_flee_left -= delta
	if _stun_left > 0.0:
		_stun_left -= delta
		_animate_stun_fx(delta)
		_stunned_physics(delta)
		if _stun_left <= 0.0:
			_set_stun_fx(false)
			_on_stun_ended()
		return
	_enemy_physics(delta)


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

## Verdadeiro onde a IA deve correr: sempre, salvo num cliente com o inimigo replicado.
func has_simulation_authority() -> bool:
	if not replicated or not is_inside_tree():
		return true
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


## Prepara a replicação (EnemySpawner, antes de entrar na árvore, em todos os peers).
func setup_network() -> void:
	replicated = true
	if _net_sync != null:
		return
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	for prop: String in [".:position", ".:rotation"]:
		config.add_property(prop)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
		config.property_set_spawn(prop, true)
	for prop: String in [".:net_state", ".:health", ".:stunned", ".:fleeing"]:
		config.add_property(prop)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		config.property_set_spawn(prop, true)
	_net_sync = MultiplayerSynchronizer.new()
	_net_sync.name = "NetSync"
	_net_sync.replication_config = config
	_net_sync.replication_interval = 0.05
	NetVisibility.watch(_net_sync)
	add_child(_net_sync)
	_connect_expedition_ending()


func get_net_sync() -> MultiplayerSynchronizer:
	return _net_sync


## Subclasses: replica mais um campo (chamar depois de super.setup_network()).
func _add_synced_property(prop: String, always: bool = false) -> void:
	var config: SceneReplicationConfig = _net_sync.replication_config
	if config.has_property(prop):
		return
	config.add_property(prop)
	config.property_set_replication_mode(prop,
		SceneReplicationConfig.REPLICATION_MODE_ALWAYS if always else SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	config.property_set_spawn(prop, true)


## Cliente: a posição chega a ~20 Hz e a física corre a 60 Hz, por isso a velocidade mede-se
## entre mudanças de posição (e cai para 0 se ficar parada mais de 0.25 s).
func _update_remote_motion(delta: float) -> void:
	_remote_since_move += delta
	var pos: Vector3 = global_position
	if not _remote_last_pos.is_finite():
		_remote_last_pos = pos
	var moved: Vector3 = pos - _remote_last_pos
	moved.y = 0.0
	if moved.length_squared() > 0.000001:
		var inst: float = moved.length() / maxf(_remote_since_move, delta)
		remote_speed = lerpf(remote_speed, inst, 0.5)
		_remote_last_pos = pos
		_remote_since_move = 0.0
	elif _remote_since_move > 0.25:
		remote_speed = move_toward(remote_speed, 0.0, delta * 10.0)
	_animate_remote(delta, remote_speed)


## Cliente: anima o andar com a velocidade estimada. Por omissão nada.
func _animate_remote(_delta: float, _speed: float) -> void:
	pass


func is_alive() -> bool:
	return not _dead and health > 0.0 and not is_queued_for_deletion()


func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	if not has_simulation_authority():
		request_hit(amount, from)
		return
	if amount <= 0.0 or not is_alive() or not _can_take_damage():
		return
	var final_amount: float = _modify_damage(amount, from)
	if final_amount <= 0.0:
		return
	health = clampf(health - final_amount, 0.0, max_health)
	if from != Vector3.INF:
		_last_hit_from = from
	_flash(BLOCK_FLASH_COLOR if final_amount < amount else FLASH_COLOR)
	damaged.emit(final_amount, health)
	if health <= 0.0:
		_die()


func stun(seconds: float) -> void:
	if not has_simulation_authority():
		request_stun(seconds)
		return
	if seconds <= 0.0 or not is_alive() or not _can_be_stunned():
		return
	_stun_left = maxf(_stun_left, seconds)
	_set_stun_fx(true)
	_on_stunned()


func is_stunned() -> bool:
	return _stun_left > 0.0


func flee_from(origin: Vector3, seconds: float) -> void:
	if not has_simulation_authority():
		request_flee(origin, seconds)
		return
	if seconds <= 0.0 or not is_alive():
		return
	_flee_origin = origin
	_flee_left = maxf(_flee_left, seconds)
	_on_flee_started()


func is_fleeing() -> bool:
	return _flee_left > 0.0


# ---------------------------------------------------------------------------
# Pedidos dos clientes ao host (contrato #5 F)
# ---------------------------------------------------------------------------

## Golpe de um jogador. No host aplica já; num cliente pede ao host (que valida).
func request_hit(amount: float, from: Vector3 = Vector3.INF) -> void:
	if has_simulation_authority():
		take_damage(amount, from)
		return
	if amount <= 0.0 or not is_alive():
		return
	_flash(FLASH_COLOR)  # resposta imediata no cliente; a vida chega pelo synchronizer
	_rpc_request_hit.rpc_id(1, amount, from)


func request_stun(seconds: float) -> void:
	if has_simulation_authority():
		stun(seconds)
	elif seconds > 0.0 and is_alive():
		_rpc_request_stun.rpc_id(1, seconds)


func request_flee(origin: Vector3, seconds: float) -> void:
	if has_simulation_authority():
		flee_from(origin, seconds)
	elif seconds > 0.0 and is_alive():
		_rpc_request_flee.rpc_id(1, origin, seconds)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_hit(amount: float, from: Vector3) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = 1
	if not accept_request(peer_id, &"hit"):
		return
	var max_damage: float = get_peer_max_damage(peer_id)
	if max_damage <= 0.0 or amount <= 0.0:
		return
	take_damage(clampf(amount, 0.0, max_damage), from)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_stun(seconds: float) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = 1
	if not accept_request(peer_id, &"stun"):
		return
	stun(clampf(seconds, 0.0, REQUEST_MAX_STUN))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_flee(origin: Vector3, seconds: float) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = 1
	if not accept_request(peer_id, &"flee"):
		return
	flee_from(origin, clampf(seconds, 0.0, REQUEST_MAX_FLEE))


## Host: aceita o pedido do peer? O jogador dele tem de estar dentro do alcance da arma
## equipada (+ 2.0 m de folga), o peer tem de ter carregado o mapa e o último pedido
## aceite tem de ter sido há >= REQUEST_MIN_INTERVAL_MS.
func accept_request(peer_id: int, request_type: StringName = &"") -> bool:
	if not has_simulation_authority() or not is_alive():
		return false
	if not is_peer_scene_ready(peer_id):
		return false
	var player: Node3D = _player_of_peer(peer_id)
	if player == null:
		return false
	var max_range: float = get_peer_max_range(peer_id, request_type)
	var d: Vector3 = player.global_position - global_position
	if Vector2(d.x, d.z).length() > max_range:
		return false
	var now: int = Time.get_ticks_msec()
	if _last_request_ms.has(peer_id) and now - int(_last_request_ms[peer_id]) < REQUEST_MIN_INTERVAL_MS:
		return false
	_last_request_ms[peer_id] = now
	return true


## Host: o peer já carregou o mapa? Fora de uma expedição (cena aberta direto, bot,
## testes) não há handshake de cena e conta como pronto.
func is_peer_scene_ready(peer_id: int) -> bool:
	var sm: SessionManager = SessionManager.instance
	if sm == null and is_inside_tree():
		var node: Node = get_node_or_null("/root/CoreSession")
		if node is SessionManager:
			sm = node
	if sm == null or not sm.is_in_expedition():
		return true
	return sm.is_peer_scene_ready(peer_id)


## Devolve o alcance máximo aceitável (no plano) para o tipo de pedido do peer,
## considerando a arma equipada (+ 2.0 m de folga).
func get_peer_max_range(peer_id: int, request_type: StringName = &"") -> float:
	var player: Node3D = _player_of_peer(peer_id)
	if player == null:
		return RANGE_SHOVEL

	var held: StringName = player.held_tool_id if "held_tool_id" in player else &""

	match request_type:
		&"hit":
			if held == &"estilingue":
				return RANGE_SLINGSHOT
			if held == &"arpao_corda":
				return RANGE_HARPOON
			if held == &"forcado":
				return RANGE_PITCHFORK
			if held == &"armadilha_rede":
				return RANGE_NET_TRAP
			if held == &"pulso_magnetico":
				return RANGE_MAGNETIC_PULSE
			if _peer_has_inventory_tool(player, &"estilingue"):
				return RANGE_SLINGSHOT
			if _peer_has_inventory_tool(player, &"arpao_corda"):
				return RANGE_HARPOON
			if _peer_has_inventory_tool(player, &"forcado"):
				return RANGE_PITCHFORK
			if _peer_has_inventory_tool(player, &"armadilha_rede"):
				return RANGE_NET_TRAP
			if _peer_has_inventory_tool(player, &"pulso_magnetico"):
				return RANGE_MAGNETIC_PULSE
			return RANGE_SHOVEL
		&"stun":
			if held == &"arpao_corda":
				return RANGE_HARPOON
			if held == &"lanterna_magnesio":
				return RANGE_LANTERN
			if held == &"forcado":
				return RANGE_PITCHFORK
			if held == &"armadilha_rede":
				return RANGE_NET_TRAP
			if held == &"pulso_magnetico":
				return RANGE_MAGNETIC_PULSE
			if _peer_has_inventory_tool(player, &"arpao_corda"):
				return RANGE_HARPOON
			if _peer_has_inventory_tool(player, &"lanterna_magnesio"):
				return RANGE_LANTERN
			if _peer_has_inventory_tool(player, &"forcado"):
				return RANGE_PITCHFORK
			if _peer_has_inventory_tool(player, &"armadilha_rede"):
				return RANGE_NET_TRAP
			if _peer_has_inventory_tool(player, &"pulso_magnetico"):
				return RANGE_MAGNETIC_PULSE
			return RANGE_SHOVEL
		&"flee":
			if held == &"lanterna_magnesio":
				return RANGE_LANTERN
			if held == &"repelente":
				return RANGE_REPELLENT
			if held == &"pulso_magnetico":
				return RANGE_MAGNETIC_PULSE
			if _peer_has_inventory_tool(player, &"lanterna_magnesio"):
				return RANGE_LANTERN
			if _peer_has_inventory_tool(player, &"repelente"):
				return RANGE_REPELLENT
			if _peer_has_inventory_tool(player, &"pulso_magnetico"):
				return RANGE_MAGNETIC_PULSE
			return RANGE_REPELLENT
		_:
			if held == &"estilingue" or _peer_has_inventory_tool(player, &"estilingue"):
				return RANGE_SLINGSHOT
			if held == &"arpao_corda" or _peer_has_inventory_tool(player, &"arpao_corda"):
				return RANGE_HARPOON
			if held == &"lanterna_magnesio" or _peer_has_inventory_tool(player, &"lanterna_magnesio"):
				return RANGE_LANTERN
			if held == &"repelente" or _peer_has_inventory_tool(player, &"repelente"):
				return RANGE_REPELLENT
			if held == &"forcado" or _peer_has_inventory_tool(player, &"forcado"):
				return RANGE_PITCHFORK
			if held == &"pulso_magnetico" or _peer_has_inventory_tool(player, &"pulso_magnetico"):
				return RANGE_MAGNETIC_PULSE
			return RANGE_SHOVEL


## Devolve o dano máximo permitido para o pedido do peer, baseado na arma equipada
## ou na pá (com melhorias de dano se disponíveis).
func get_peer_max_damage(peer_id: int) -> float:
	var player: Node3D = _player_of_peer(peer_id)
	if player == null:
		return REQUEST_MAX_DAMAGE

	var held: StringName = player.held_tool_id if "held_tool_id" in player else &""

	# Se tiver ferramenta equipada (não pá nem detector), valida catálogo de ferramentas
	if held != &"" and held != &"pa" and held != &"detector":
		var gs: GameState = GameState.instance
		if gs == null and is_inside_tree():
			var node: Node = get_node_or_null("/root/CoreGameState")
			if node is GameState:
				gs = node
		if gs != null:
			if gs.get_tool_data(String(held)) == null:
				return 0.0
		elif not _is_known_tool(held):
			return 0.0

	var shovel_dmg: float = REQUEST_MAX_DAMAGE
	if player.has_method("get_attack_damage"):
		shovel_dmg = float(player.call("get_attack_damage"))

	if held == &"estilingue":
		var d: Vector3 = player.global_position - global_position
		if Vector2(d.x, d.z).length() <= RANGE_SHOVEL:
			return maxf(20.0, shovel_dmg)
		return 20.0
	elif held == &"armadilha_rede":
		return 15.0
	elif held == &"forcado":
		return 35.0
	elif held == &"arpao_corda":
		return 40.0
	elif held == &"pulso_magnetico":
		return 35.0

	return shovel_dmg


func _peer_has_inventory_tool(player: Node3D, tool_name: StringName) -> bool:
	if player == null:
		return false
	if "inventory" in player and player.inventory != null and "slots" in player.inventory:
		for item in player.inventory.slots:
			if item != null and "tool_id" in item and item.tool_id == tool_name:
				return true
	return false


func _is_known_tool(tool_id: StringName) -> bool:
	match tool_id:
		&"", &"pa", &"detector", &"estilingue", &"forcado", &"armadilha_rede", \
		&"lanterna_magnesio", &"repelente", &"kit_medico", &"arpao_corda", &"pulso_magnetico":
			return true
		_:
			return false


func _player_of_peer(peer_id: int) -> Node3D:
	for p: Node3D in _all_players():
		if p.get_multiplayer_authority() == peer_id:
			return p
	return null


# ---------------------------------------------------------------------------
# Ganchos para subclasses
# ---------------------------------------------------------------------------

## Num cliente, net_state mudou (o host mudou de estado). Por omissão nada.
func _on_remote_state(_new_state: int) -> void:
	pass


## Lógica normal do inimigo (não corre enquanto atordoado).
func _enemy_physics(_delta: float) -> void:
	pass


## Enquanto atordoado: por omissão trava, aplica gravidade e não ataca.
func _stunned_physics(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


func _can_take_damage() -> bool:
	return true


func _can_be_stunned() -> bool:
	return true


## Ajusta o dano recebido (armaduras, pontos fracos). from = Vector3.INF se desconhecido.
func _modify_damage(amount: float, _from: Vector3) -> float:
	return amount


func _on_stunned() -> void:
	pass


func _on_stun_ended() -> void:
	pass


func _on_flee_started() -> void:
	pass


## Nos clientes o corpo voa para inimigos comuns; chefes têm morte própria (no host).
func _uses_default_death() -> bool:
	return not is_in_group(&"bosses")


## Chamado uma vez ao morrer, antes de libertar o nó. Por omissão: partículas + queue_free.
func _on_died() -> void:
	spawn_particles(global_position + Vector3.UP * 0.25, death_color, 28, 3.5)
	death_fling()
	queue_free()


## O corpo sai voando e girando (cosmético). Chefes podem chamar no seu _on_died.
func death_fling() -> void:
	if _flung:
		return
	_flung = true
	DEATH_FLING.fling(self, _last_hit_from)


# ---------------------------------------------------------------------------
# Utilitários para subclasses
# ---------------------------------------------------------------------------

## Bichos de carne e osso que podem largar Carne Crua (chance por cena). Pedra, morcego,
## gaivota e criaturas da Cratera não. Chance baixa: comida fácil quebraria a fome.
const MEAT_DROP_CHANCE: Dictionary = {
	"crab": 0.15, "hermit_crab": 0.15, "snake": 0.15, "mole": 0.15, "crow": 0.12,
	"ice_wolf": 0.15, "penguin": 0.15, "walrus": 0.2,
}
const MEAT_ITEM: String = "res://items/tools/carne_crua.tres"


func meat_drop_chance() -> float:
	if scene_file_path.is_empty():
		return 0.0
	return float(MEAT_DROP_CHANCE.get(scene_file_path.get_file().get_basename(), 0.0))


## Só quem simula (host/solo) sorteia; o PickupsRoot replica o item. `roll` para testes.
func try_drop_meat(roll: float = -1.0) -> bool:
	var chance: float = meat_drop_chance()
	if chance <= 0.0 or not is_inside_tree():
		return false
	if roll < 0.0:
		roll = randf()
	if roll >= chance:
		return false
	var td: ToolData = load(MEAT_ITEM) as ToolData
	if td == null:
		return false
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	ItemPickup.spawn(parent, CarriedItem.create_from_tool_data(td), global_position + Vector3.UP * 0.5,
		Vector3(randf_range(-1.0, 1.0), 3.0, randf_range(-1.0, 1.0)))
	return true


func _die() -> void:
	if _dead:
		return
	_dead = true
	if has_simulation_authority():
		try_drop_meat()
	_set_stun_fx(false)
	died.emit()
	_on_died()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0


## Reforço chamado por um chefe: pelo EnemySpawner do mapa (replicado em coop). Sem
## spawner (testes, cenas antigas) devolve null e o chefe cria-o localmente.
func _spawn_minion(kind: StringName, pos: Vector3) -> Node3D:
	var spawner: EnemySpawner = EnemySpawner.find(get_tree()) if is_inside_tree() else null
	if spawner == null or not spawner.can_spawn():
		return null
	return spawner.spawn_from_data(EnemySpawner.make_spawn_data(kind, pos, 0))


## Altura do chão (layer 1) por baixo de (pos.x, pos.z); `fallback` se não houver chão.
## Para inimigos que andam debaixo de terra (sem colisão) em mapas com relevo.
func _ground_height(pos: Vector3, fallback: float) -> float:
	if not is_inside_tree():
		return fallback
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(pos.x, pos.y + 6.0, pos.z), Vector3(pos.x, pos.y - 20.0, pos.z), 1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else fallback


## Jogadores (grupo 'player') a menos de `radius` m de `center` no plano.
func _players_within(center: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node3D in _all_players():
		if n.has_method("take_damage"):
			var p: Vector3 = n.global_position
			if Vector2(p.x - center.x, p.z - center.z).length() <= radius:
				out.append(n)
	return out


## Roda no eixo Y para que o -Z local aponte para dir, mais um desvio angular.
func _turn_towards(dir: Vector3, yaw_offset: float, turn_speed: float, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(-dir.x, -dir.z) + yaw_offset
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))


## Jogador mais próximo do grupo 'player' (reavaliado a cada RETARGET_INTERVAL).
func _update_target(delta: float) -> Node3D:
	_retarget_timer -= delta
	if _retarget_timer > 0.0 and is_instance_valid(_target):
		return _target
	_retarget_timer = RETARGET_INTERVAL

	var best: Node3D = null
	var best_dist: float = INF
	for p: Node3D in _all_players():
		var d: float = global_position.distance_squared_to(p.global_position)
		if d < best_dist:
			best_dist = d
			best = p
	# Objetivo de evento (#39, ex.: o barco na Maré Vermelha): vai a ele salvo se um jogador
	# estiver a menos de objective_aggro_radius.
	if is_instance_valid(objective_target) and best_dist > objective_aggro_radius * objective_aggro_radius:
		best = objective_target
	_target = best
	return _target


## Todos os jogadores da cena (local e remotos), sem repetidos.
func _all_players() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not is_inside_tree():
		return out
	for group: StringName in PLAYERS_GROUPS:
		for n: Node in get_tree().get_nodes_in_group(group):
			var p: Node3D = n as Node3D
			if p != null and p.is_inside_tree() and not out.has(p):
				out.append(p)
	return out


## Aplica dano ao jogador já escalado pela dificuldade (nº de jogadores). Usar sempre isto.
func _deal_damage(target: Node, amount: float) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	var final_amount: float = amount * DifficultyProfile.current(tree).enemy_damage_multiplier
	# Jogador de outro peer: a vida é do dono (contrato #5 B).
	if target.has_method("apply_damage") and NetVisibility.is_online(multiplayer) \
			and target.get_multiplayer_authority() != multiplayer.get_unique_id():
		target.rpc_id(target.get_multiplayer_authority(), &"apply_damage", final_amount, global_position)
		return
	target.call("take_damage", final_amount)


## Empurra o jogador (#57, caos How to Fish): impulso em m/s e tremor da câmara. A física do
## jogador é do dono: num jogador de outro peer vai por RPC (como o apply_damage). Sem
## Player.apply_knockback (versões antigas, testes) não faz nada.
func _knockback(target: Node, impulse: Vector3, shake: float = 0.0) -> void:
	if target == null or not target.has_method(&"apply_knockback"):
		return
	if NetVisibility.is_online(multiplayer) and target.get_multiplayer_authority() != multiplayer.get_unique_id():
		target.rpc_id(target.get_multiplayer_authority(), &"apply_knockback", impulse, shake)
		return
	target.call(&"apply_knockback", impulse, shake)


## Efeito no dono do jogador (#57: apply_ink, apply_disarm, apply_snare, end_disarm...). Como o
## _knockback: num jogador de outro peer vai por RPC. Sem o método não faz nada.
func _player_effect(target: Node, method: StringName, args: Array = []) -> void:
	if target == null or not target.has_method(method):
		return
	if NetVisibility.is_online(multiplayer) and target.get_multiplayer_authority() != multiplayer.get_unique_id():
		target.callv(&"rpc_id", [target.get_multiplayer_authority(), method] + args)
		return
	target.callv(method, args)


## Regista um material para o flash de dano. Toon (ShaderMaterial): anima flash_amount 1 → 0.
## StandardMaterial3D: albedo_color é animado de volta à cor base.
func _register_flash_material(mat: Material) -> void:
	if mat == null:
		return
	_flash_mats.append(mat)
	var std: StandardMaterial3D = mat as StandardMaterial3D
	_flash_base_colors.append(std.albedo_color if std != null else Color.WHITE)


func _flash(color: Color) -> void:
	if _flash_mats.is_empty() or not is_inside_tree():
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel(true)
	for i: int in range(_flash_mats.size()):
		var shader_mat: ShaderMaterial = _flash_mats[i] as ShaderMaterial
		if shader_mat != null:
			shader_mat.set_shader_parameter(&"flash_color", color)
			shader_mat.set_shader_parameter(&"flash_amount", 1.0)
			_flash_tween.tween_property(shader_mat, "shader_parameter/flash_amount", 0.0, FLASH_TIME)
			continue
		var mat: StandardMaterial3D = _flash_mats[i] as StandardMaterial3D
		if mat == null:
			continue
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		_flash_tween.tween_property(mat, "albedo_color", _flash_base_colors[i], FLASH_TIME)
	_flash_tween.chain().tween_callback(_end_flash)


func _end_flash() -> void:
	for m: Material in _flash_mats:
		var mat: StandardMaterial3D = m as StandardMaterial3D
		if mat != null:
			mat.emission_enabled = false


## Partículas one-shot no pai (sobrevivem ao inimigo).
func spawn_particles(pos: Vector3, color: Color, amount: int, speed: float) -> void:
	var parent: Node = get_parent()
	if parent == null or not is_inside_tree():
		return
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -9.8, 0.0)

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material = mat
	p.mesh = mesh

	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)


# ---------------------------------------------------------------------------
# Efeito visual do atordoamento: estrelas amarelas a rodar por cima
# ---------------------------------------------------------------------------

func _set_stun_fx(on: bool) -> void:
	if not on:
		if _stun_fx != null:
			_stun_fx.queue_free()
			_stun_fx = null
		return
	if _stun_fx != null:
		return
	_stun_fx = Node3D.new()
	_stun_fx.name = "StunFx"
	_stun_fx.top_level = true
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in range(4):
		var ang: float = TAU * float(k) / 4.0
		var c: Vector3 = Vector3(cos(ang), 0.0, sin(ang)) * 0.22
		# Estrela simples: dois losangos cruzados
		LowPolyMesh.box(st, c, Vector3(0.07, 0.07, 0.02), Basis(Vector3.FORWARD, PI * 0.25), Color(1.0, 0.9, 0.2))
		LowPolyMesh.box(st, c, Vector3(0.02, 0.07, 0.07), Basis(Vector3.RIGHT, PI * 0.25), Color(1.0, 0.9, 0.2))
	var mat: ShaderMaterial = LowPolyMesh.make_material()
	mat.set_shader_parameter(&"emission_color", Color(0.6, 0.51, 0.12))
	_stun_fx.add_child(LowPolyMesh.commit(st, "Stars", mat))
	add_child(_stun_fx)
	_animate_stun_fx(0.0)


func _animate_stun_fx(delta: float) -> void:
	if _stun_fx == null:
		return
	_stun_fx.global_position = global_position + Vector3.UP * stun_fx_height
	_stun_fx.rotation.y += delta * 5.0
