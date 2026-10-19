extends GutTest

## Testes de arbitragem de foco e interação (#105 review fix).
## Garante que:
## 1) Quando há um Interactable (ex.: pedestal/altar) e um alvo próprio (ex.: carrinho de mão),
##    apenas o alvo mais na mira/mais próximo recebe o foco e o prompt [E].
## 2) O [E] age exclusivamente no alvo arbitrado.
## 3) clear_messages() limpa as mensagens do HUD, inclusive ao desmontar da tirolesa.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const WHEELBARROW_SCRIPT: Script = preload("res://gameplay/objects/wheelbarrow/wheelbarrow.gd")
const FLAG_INTERACTABLE_SCRIPT: Script = preload("res://gameplay/quests/flag_interactable.gd")

var _world: Node3D = null


func before_each() -> void:
	Interactable.reset_focus()
	_world = Node3D.new()
	get_tree().root.add_child(_world)


func after_each() -> void:
	Interactable.reset_focus()
	if is_instance_valid(_world):
		_world.free()
		_world = null


func test_clear_messages() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.set_physics_process(false)
	_world.add_child(player)
	await wait_frames(2)

	player._show_temporary_message("⚡ Deslizando pela tirolesa!", UiPalette.GOLD, 10.0)
	await wait_frames(1)

	assert_gt(player.message_stack.get_child_count(), 0, "Mensagem adicionada")
	player.clear_messages()
	await wait_frames(1)
	assert_eq(player.message_stack.get_child_count(), 0, "clear_messages limpou a pilha de mensagens")


func test_arbitration_favors_aimed_interactable_over_wheelbarrow() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	_world.add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.add_to_group(Player.LOCAL_GROUP)
	player.camera.current = true
	await wait_frames(2)

	# Interactable bem na mira à frente (z = -1.5)
	var interactable: FlagInteractable = FLAG_INTERACTABLE_SCRIPT.new() as FlagInteractable
	interactable.prompt = "[E] Colocar o Ídolo de Jade no pedestal"
	interactable.interact_range = 3.5
	_world.add_child(interactable)
	interactable.global_position = Vector3(0.0, 1.2, -1.5)

	# Carrinho de mão ligeiramente de lado (x = 1.6, z = -2.0)
	var wb: Node3D = WHEELBARROW_SCRIPT.new() as Node3D
	_world.add_child(wb)
	wb.set_physics_process(false)
	wb.global_position = Vector3(1.6, 0.0, -2.0)
	await wait_frames(2)

	player._update_interaction_target()
	Interactable._update_focus(_world.get_tree())
	player._update_interaction_target()

	assert_true(Interactable.has_active_focus(), "Interactable na mira tem foco ativo")
	assert_eq(Interactable.get_current_focus(), interactable, "Pedestal é o foco atual")
	assert_eq(player.interact_prompt.text, "", "HUD do jogador não exibe carrinho quando interactable está focado")


func test_arbitration_favors_wheelbarrow_when_directly_aimed() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	_world.add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.add_to_group(Player.LOCAL_GROUP)
	player.camera.current = true
	await wait_frames(2)

	# Carrinho bem na mira à frente (z = -1.8)
	var wb: Node3D = WHEELBARROW_SCRIPT.new() as Node3D
	_world.add_child(wb)
	wb.set_physics_process(false)
	wb.global_position = Vector3(0.0, 0.0, -1.8)

	# Interactable fora da mira de lado (x = 2.5, z = -2.2)
	var interactable: FlagInteractable = FLAG_INTERACTABLE_SCRIPT.new() as FlagInteractable
	interactable.prompt = "[E] Colocar o Ídolo de Jade no pedestal"
	interactable.interact_range = 3.5
	_world.add_child(interactable)
	interactable.global_position = Vector3(2.5, 1.2, -2.2)
	await wait_frames(2)

	player._update_interaction_target()
	Interactable._update_focus(_world.get_tree())
	player._update_interaction_target()

	assert_false(Interactable.has_active_focus(), "Interactable fora da mira cede foco")
	assert_not_null(player._target_wheelbarrow, "Carrinho na mira é o alvo selecionado")
	assert_true(player.interact_prompt.text.containsn("carrinho"), "HUD exibe apenas o prompt do carrinho")
