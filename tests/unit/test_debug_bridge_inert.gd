extends GutTest

## #210: o DebugBridge é autoload em todas as cenas. Sem --bot= (ou fora de build de debug) ele
## não pode renovar o "último input" do jogador nem comer a comida da mochila.
##
## Negativo: usa o autoload REAL e deixa a SceneTree processar (sem chamar _process nem criar
## uma segunda instância). O GUT nunca roda com --bot=, então este é o cenário "sem bot".
##
## Controle positivo (com bot ativo), em duas partes. Não dá para passar --bot= em tempo de
## execução e _run não pode rodar num teste unitário (troca o save, muda de cena e encerra o
## processo), então:
##  1. a decisão de ativar vem de DebugBridge.bot_script_for(args, debug_build), testada com
##     argumentos explícitos;
##  2. o que o bot ativo faz a cada frame é testado numa instância nova, com o processamento
##     ligado (o estado que um _ready com bot deixa), sem depender de nenhum nome interno.
## Não coberto aqui: o encaixe real de _ready com --bot= (fica para tools/run_bot.sh).
##
## Ordem do arquivo: tudo até o marcador "# --- Controle positivo" (cabeçalho, helpers e o
## teste negativo) não depende de DebugBridge.bot_script_for. A evidência "antes da correção"
## usa só esse trecho, num arquivo extraído na cópia isolada (ver #210), porque o código antigo
## não tem a função nova e a falha por método inexistente não comprovaria o bug.
##
## Durante os testes, não mexa no mouse nem no teclado com a janela aberta: o jogador de teste
## desliga o input não tratado, mas movimentos reais ainda confundiriam a leitura da fome.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const BRIDGE_SCRIPT: GDScript = preload("res://gameplay/debug/debug_bridge.gd")
const FOOD: ToolData = preload("res://items/tools/batata_esquecida.tres")
## Mais que Player.AFK_SECONDS (60 s).
const STALE_MS: int = 70000
## Abaixo de 40% de max_hunger o auto-comer age; acima não.
const LOW_HUNGER: float = 10.0
const HIGH_HUNGER: float = 90.0
## Pelo menos um disparo do temporizador de 1 s do auto-comer.
const WAIT_SECONDS: float = 1.5

var _saved_paused: bool = false
var _saved_time_scale: float = 1.0
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func before_each() -> void:
	_saved_paused = get_tree().paused
	_saved_time_scale = Engine.time_scale
	_saved_mouse_mode = Input.mouse_mode
	get_tree().paused = false
	Engine.time_scale = 1.0


func after_each() -> void:
	get_tree().paused = _saved_paused
	Engine.time_scale = _saved_time_scale
	Input.mouse_mode = _saved_mouse_mode


func _has_bot_arg() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bot="):
			return true
	return false


## Jogador local único, com uma batata na mochila, fome `hunger_value` e AFK.
## Devolve null (e já falhou o teste) se a preparação não ficou como esperado.
func _spawn_afk_player(hunger_value: float) -> Player:
	if not get_tree().get_nodes_in_group(&"player").is_empty():
		fail_test("preparação inválida: já existe jogador no grupo 'player'")
		return null
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	# Só o bridge pode mexer no "último input" durante o teste.
	player.set_process_unhandled_input(false)
	if get_tree().get_nodes_in_group(&"player").size() != 1 or not player.is_local():
		fail_test("preparação inválida: o jogador de teste não é o único jogador local")
		return null
	if FOOD.category != ToolData.Category.FOOD:
		fail_test("preparação inválida: batata_esquecida deixou de ser comida")
		return null
	var added: bool = player.inventory.add_item(CarriedItem.create_from_tool_data(FOOD))
	if not added or player.inventory.get_count() != 1:
		fail_test("preparação inválida: a batata não entrou na mochila")
		return null
	player.set_hunger(hunger_value)
	player._last_input_ms = Time.get_ticks_msec() - STALE_MS
	if not player.is_afk():
		fail_test("preparação inválida: o jogador deveria estar AFK")
		return null
	return player


func _fresh_bridge_with_processing() -> Node:
	var bridge: Node = BRIDGE_SCRIPT.new()
	add_child_autofree(bridge)
	# Sem bot, o _ready desliga o processamento; um bot ativo deixa-o ligado.
	bridge.set_process(true)
	return bridge


# --- Sem bot: o autoload real fica inerte ------------------------------------------

func test_autoload_without_bot_leaves_input_inventory_and_hunger_untouched() -> void:
	var bridge: Node = get_tree().root.get_node_or_null(^"DebugBridge")
	assert_not_null(bridge, "autoload DebugBridge precisa existir (project.godot)")
	assert_false(_has_bot_arg(), "este teste só vale sem --bot=")
	if bridge == null or _has_bot_arg():
		return
	var player: Player = _spawn_afk_player(LOW_HUNGER)
	if player == null:
		return
	var stale: int = player._last_input_ms

	await wait_seconds(WAIT_SECONDS)

	assert_eq(player._last_input_ms, stale, "sem --bot: não renova o último input")
	assert_true(player.is_afk(), "sem --bot: o jogador segue AFK")
	assert_eq(player.inventory.get_count(), 1, "sem --bot: não consome comida")
	assert_almost_eq(player.hunger, LOW_HUNGER, 0.5, "sem --bot: a fome não muda")


# --- Controle positivo: ativação e comportamento com bot -----------------------------

func test_bot_script_for_activates_only_with_arg_in_debug_build() -> void:
	var args: PackedStringArray = PackedStringArray(["--x", "--bot=tools/bot/a.json"])
	assert_eq(BRIDGE_SCRIPT.bot_script_for(args, true), "tools/bot/a.json", "debug + --bot=: ativa")
	assert_eq(BRIDGE_SCRIPT.bot_script_for(args, false), "", "release: não ativa")
	assert_eq(BRIDGE_SCRIPT.bot_script_for(PackedStringArray(["--x"]), true), "", "sem --bot=: não ativa")
	assert_eq(BRIDGE_SCRIPT.bot_script_for(PackedStringArray(), true), "", "sem argumentos: não ativa")
	assert_eq(BRIDGE_SCRIPT.bot_script_for(PackedStringArray(["--bot="]), true), "", "--bot= vazio: não ativa")


func test_bot_processing_keeps_player_present_and_eats_when_hungry() -> void:
	var player: Player = _spawn_afk_player(LOW_HUNGER)
	if player == null:
		return
	_fresh_bridge_with_processing()

	await wait_seconds(WAIT_SECONDS)

	assert_lt(Time.get_ticks_msec() - player._last_input_ms, 2000, "bot: renova o último input")
	assert_false(player.is_afk(), "bot: o jogador deixa de estar AFK")
	assert_eq(player.inventory.get_count(), 0, "bot: come a comida com fome baixa")
	assert_gt(player.hunger, LOW_HUNGER + 20.0, "bot: a fome subiu com a batata")


func test_bot_processing_does_not_eat_when_not_hungry() -> void:
	var player: Player = _spawn_afk_player(HIGH_HUNGER)
	if player == null:
		return
	_fresh_bridge_with_processing()

	await wait_seconds(WAIT_SECONDS)

	assert_lt(Time.get_ticks_msec() - player._last_input_ms, 2000, "bot: renova o último input")
	assert_eq(player.inventory.get_count(), 1, "bot: com fome alta não come")
	assert_almost_eq(player.hunger, HIGH_HUNGER, 0.5, "bot: com fome alta a fome não muda")
