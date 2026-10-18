extends GutTest

## Prompts com o botão do comando (#102): "[E]"/"[Q]"/"{ação}" viram a tecla configurada ou o
## botão do dispositivo em uso (dicas, aviso de interação, interativos das missões, mensagens) e
## se atualizam quando o dispositivo troca com o texto na tela.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const HINTS: Script = preload("res://gameplay/player/player_hints.gd")
const HINTS_PATH: String = "user://test_saves/devb_pad_hints.cfg"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	if FileAccess.file_exists(HINTS_PATH):
		DirAccess.remove_absolute(HINTS_PATH)
	HINTS.set_hints_path(HINTS_PATH)
	InputDevice.instance.set_using_gamepad(false)


func after_each() -> void:
	InputDevice.instance.set_using_gamepad(false)
	Engine.remove_meta(HINTS.PATH_META)


func _labels(player: Player) -> Array[String]:
	var out: Array[String] = []
	for child: Node in player.message_stack.get_children():
		if child is Label and not child.is_queued_for_deletion():
			out.append((child as Label).text)
	return out


func test_fill_key_prompts_per_device() -> void:
	assert_eq(InputDevice.fill_key_prompts("[E] Apanhar"), "[E] Apanhar", "teclado nos padrões: igual")
	InputDevice.instance.set_using_gamepad(true)
	assert_eq(InputDevice.fill_key_prompts("[E] Reanimar | [Q] Largar"), "[X] Reanimar | [B] Largar")
	assert_eq(InputDevice.fill_key_prompts("[F] atacar"), "[RB] atacar")
	assert_eq(InputDevice.fill_key_prompts("Segure [{drop}]"), "Segure [B]")


func test_hint_uses_pad_button() -> void:
	InputDevice.instance.set_using_gamepad(true)
	var text: String = HINTS.take("throw")
	assert_string_contains(text, "[B]", "dica de arremesso com o botão do comando")


func test_player_labels_and_open_hint_update() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	assert_eq(player._get_interact_key_label(), "E")
	assert_true(player.show_hint("throw"))
	assert_true(_labels(player).any(func(t: String) -> bool: return t.contains("[Q]")), "dica aberta com [Q]")
	InputDevice.instance.set_using_gamepad(true)
	assert_eq(player._get_interact_key_label(), "X", "resgate/interação com o botão")
	assert_true(_labels(player).any(func(t: String) -> bool: return t.contains("[B]")), "trocou para o comando: a dica aberta mostra [B]")
	player._show_temporary_message("🎒 Mochila cheia! Largue um item [Q].")
	assert_true(_labels(player).any(func(t: String) -> bool: return t.contains("item [B]")), "mensagens temporárias também")


func test_interactable_prompt_follows_device() -> void:
	var item: Interactable = Interactable.new()
	item.prompt = "[E] Tocar o sino"
	add_child_autofree(item)
	item._set_focused(true)
	var label: Label3D = item.get_node(^"Prompt") as Label3D
	assert_eq(label.text, "[E] Tocar o sino")
	InputDevice.instance.set_using_gamepad(true)
	assert_eq(label.text, "[X] Tocar o sino", "interativo focado atualiza na troca de dispositivo")
	InputDevice.instance.set_using_gamepad(false)
	assert_eq(label.text, "[E] Tocar o sino")
