class_name Interactable
extends Node3D

## Objeto do cenário com que se interage a olhar + [E] (#39). Genérico e reutilizável:
## conchas, garrafas, pedras, NPC, relíquias... Todo o estado decide-se no host (contrato #5):
##   - o jogador local olha para ele (cone da câmara, alcance) e vê "[E] ..." por cima;
##   - [E] chama request_interact(): em solo/host corre já; num cliente vira RPC ao host, que
##     confere a distância do jogador que pediu;
##   - o host corre _on_interact(peer_id) (subclasses) e emite `interacted(peer_id)`;
##   - `state` (int) e `active` são do host e replicam-se a todos (e a quem entra tarde).
## Não mexe no Player: o foco e o [E] são tratados aqui, uma vez por frame, para todos os
## interativos (grupo GROUP). Mensagens para um jogador: say_to(); para todos: say_all().

signal interacted(peer_id: int)
signal state_changed(new_state: int)

const GROUP: StringName = &"interactables"
## Cone de mira (produto escalar mínimo entre a frente da câmara e a direção ao alvo).
const AIM_DOT: float = 0.9
## Folga (m) na verificação de distância do host (latência).
const RANGE_SLACK: float = 1.5
const PROMPT_COLOR: Color = Color(1.0, 0.92, 0.55)
const SAY_COLOR: Color = Color(0.1, 0.08, 0.06)

@export var prompt: String = "[E] Interagir"
@export var interact_range: float = 2.6
## Ponto (local) para onde se olha e onde aparece o texto.
@export var focus_offset: Vector3 = Vector3(0.0, 0.6, 0.0)
## Começa ativo? (inativo = não aceita [E] e não mostra o texto)
@export var start_active: bool = true
## Depois da primeira interação fica inativo.
@export var once: bool = false
## Esconde o nó inteiro enquanto inativo (ex.: relíquia que só aparece com a maré baixa).
@export var hide_when_inactive: bool = false

## Estado do host (significado definido pela subclasse).
var state: int = 0
var active: bool = true

var _prompt_label: Label3D = null
var _say_label: Label3D = null
var _say_left: float = 0.0
var _focused: bool = false

static var _focus: Interactable = null
static var _focus_frame: int = -1


func _ready() -> void:
	add_to_group(GROUP)
	active = start_active
	_prompt_label = _make_label(PROMPT_COLOR, Color(0.05, 0.04, 0.03), 34)
	_prompt_label.name = "Prompt"
	_prompt_label.position = focus_offset + Vector3.UP * 0.45
	_prompt_label.visible = false
	add_child(_prompt_label)
	_say_label = _make_label(SAY_COLOR, Color(1.0, 0.98, 0.92), 30)
	_say_label.name = "Say"
	_say_label.pixel_size = 0.003
	_say_label.outline_size = 24
	_say_label.position = focus_offset + Vector3.UP * 1.0
	_say_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_say_label.visible = false
	_say_label.width = 520.0
	_say_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_say_label)
	if HostSync.is_host(self):
		HostSync.on_peer_ready(self, _send_full_state)
	_apply_visibility()


func _process(delta: float) -> void:
	if _focus_frame != Engine.get_process_frames():
		_focus_frame = Engine.get_process_frames()
		_update_focus(get_tree())
	if _say_left > 0.0:
		_say_left -= delta
		if _say_left <= 0.0:
			_say_label.visible = false
			_prompt_label.visible = _focused


# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------

## Texto mostrado ao jogador que olha (as subclasses podem mudar conforme o estado).
func get_prompt() -> String:
	return prompt


## Jogador local carregou [E] a olhar para este nó.
func request_interact() -> void:
	if not active:
		return
	if HostSync.is_host(self):
		_host_interact(HostSync.local_peer(self))
	else:
		_rpc_request_interact.rpc_id(1)


## Host: muda o estado e replica-o.
func set_state(new_state: int) -> void:
	if not HostSync.is_host(self):
		return
	state = new_state
	_on_state_applied()
	HostSync.broadcast(self, &"_rpc_state", [state, active])


## Host: liga/desliga a interação (e a visibilidade, com hide_when_inactive).
func set_active(on: bool) -> void:
	if not HostSync.is_host(self):
		return
	active = on
	_apply_visibility()
	HostSync.broadcast(self, &"_rpc_state", [state, active])


## Host: mostra um texto por cima deste nó só ao jogador `peer_id`.
func say_to(peer_id: int, text: String, seconds: float = 4.0) -> void:
	if peer_id == HostSync.local_peer(self):
		show_say(text, seconds)
	else:
		HostSync.send_to(self, peer_id, &"_rpc_say", [text, seconds])


## Host: mostra um texto por cima deste nó a todos.
func say_all(text: String, seconds: float = 4.0) -> void:
	show_say(text, seconds)
	HostSync.broadcast(self, &"_rpc_say", [text, seconds])


## Local: balão de texto por cima do nó.
func show_say(text: String, seconds: float) -> void:
	_say_label.text = text
	_say_label.visible = true
	_say_left = seconds
	_prompt_label.visible = false


func get_focus_point() -> Vector3:
	return global_transform * focus_offset


func is_focused() -> bool:
	return _focused


## Interativo para onde o jogador local olha agora (ou null).
static func get_focused() -> Interactable:
	return _focus if is_instance_valid(_focus) else null


# ---------------------------------------------------------------------------
# Ganchos das subclasses
# ---------------------------------------------------------------------------

## Host: alguém interagiu (já validado). Por omissão só emite `interacted`.
func _on_interact(peer_id: int) -> void:
	interacted.emit(peer_id)


## Todos os peers: o estado mudou (atualizar o visual aqui; chamar super).
func _on_state_applied() -> void:
	if _focused:
		_prompt_label.text = get_prompt()
	state_changed.emit(state)


# ---------------------------------------------------------------------------
# Rede
# ---------------------------------------------------------------------------

func _host_interact(peer_id: int) -> void:
	if not active:
		return
	var player: Node3D = HostSync.player_of(get_tree(), peer_id)
	if player != null and player.global_position.distance_to(get_focus_point()) > interact_range + RANGE_SLACK + 1.0:
		return
	if once:
		set_active(false)
	_on_interact(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_interact() -> void:
	if multiplayer.is_server():
		_host_interact(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func _rpc_state(new_state: int, is_active: bool) -> void:
	active = is_active
	_apply_visibility()
	if new_state != state:
		state = new_state
		_on_state_applied()


@rpc("authority", "call_remote", "reliable")
func _rpc_say(text: String, seconds: float) -> void:
	show_say(text, seconds)


func _send_full_state(peer_id: int) -> void:
	HostSync.send_to(self, peer_id, &"_rpc_state", [state, active])


# ---------------------------------------------------------------------------
# Foco do jogador local (uma vez por frame para todos os interativos)
# ---------------------------------------------------------------------------

static func _update_focus(tree: SceneTree) -> void:
	var best: Interactable = null
	var cam: Camera3D = tree.root.get_viewport().get_camera_3d() if tree != null else null
	var player: Node3D = tree.get_first_node_in_group(&"player") as Node3D if tree != null else null
	# O [E] do próprio jogador (apanhar, banca, entregar) tem prioridade: com esse alvo, os
	# interativos nem mostram o texto, para o mesmo toque não fazer duas coisas.
	if player != null and player_has_own_target(player):
		player = null
	if cam != null and player != null:
		var from: Vector3 = cam.global_position
		var fwd: Vector3 = -cam.global_basis.z
		var best_dot: float = AIM_DOT
		for n: Node in tree.get_nodes_in_group(GROUP):
			var it: Interactable = n as Interactable
			if it == null or not it.active or not it.is_visible_in_tree():
				continue
			var to_it: Vector3 = it.get_focus_point() - from
			var dist: float = to_it.length()
			if dist < 0.01 or player.global_position.distance_to(it.get_focus_point()) > it.interact_range:
				continue
			var d: float = fwd.dot(to_it / dist)
			if d > best_dot:
				best = it
				best_dot = d
	if best != _focus:
		if is_instance_valid(_focus):
			_focus._set_focused(false)
		_focus = best
		if best != null:
			best._set_focused(true)
	if best != null and Input.is_action_just_pressed(&"interact"):
		best.request_interact()


## O jogador local tem um alvo do seu próprio [E]? Usa player.has_own_interact_target() se
## existir; senão lê o estado do Player (oferta da banca, item no chão, entrega na base).
static func player_has_own_target(player: Node) -> bool:
	if player.has_method(&"has_own_interact_target"):
		return bool(player.call(&"has_own_interact_target"))
	for field: String in ["_target_offer", "_target_pickup"]:
		if field in player:
			var o: Variant = player.get(field)
			if o is Object and is_instance_valid(o):
				return true
	if player.has_method(&"_get_sell_point_in_range") and player.has_method(&"_count_deliverable"):
		if player.call(&"_get_sell_point_in_range") != null and int(player.call(&"_count_deliverable")) > 0:
			return true
	return false


func _set_focused(on: bool) -> void:
	_focused = on
	_prompt_label.text = get_prompt()
	_prompt_label.visible = on and not _say_label.visible


func _apply_visibility() -> void:
	if hide_when_inactive:
		visible = active
	if not active and _prompt_label != null:
		_prompt_label.visible = false


static func _make_label(color: Color, outline: Color, size: int) -> Label3D:
	var l: Label3D = Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.004
	l.font_size = size
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = outline
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
