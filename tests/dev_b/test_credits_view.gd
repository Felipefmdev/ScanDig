extends GutTest

## Créditos com os sons CC0 (#149): o core/data/audio_credits.json bate com o
## assets/audio/CREDITS.md, todo autor aparece na CreditsView com link e "CC0 1.0", a área rola
## por teclado/comando sem prender o foco, os rótulos trocam de idioma e a tela de título abre a
## mesma vista (Esc/B volta ao botão Créditos).

const TITLE_SCENE: PackedScene = preload("res://world/title_screen.tscn")
## Autores pedidos na #149 (além dos sons gerados pelo projeto).
const EXPECTED_AUTHORS: Array[String] = ["Kenney", "Ylmir", "zeroisnotnull", "AntumDeluge", "Darsycho",
	"CaveboyTup", "jasinski", "transitking", "Écrivain"]
const DIR: String = "user://test_saves/devb_credits"

var _orig_path: String = ""


func before_all() -> void:
	_orig_path = SaveManager.instance.save_path
	DirAccess.make_dir_recursive_absolute(DIR)
	SaveManager.instance.set_save_path(DIR + "/scandig_save.json")


func after_each() -> void:
	SettingsManager.instance.set_language("pt_BR")
	if InputDevice.instance != null:
		InputDevice.instance.set_using_pointer(true)


func after_all() -> void:
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, file_name])
	SaveManager.instance.set_save_path(_orig_path)


func _view() -> CreditsView:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child_autofree(layer)
	var view: CreditsView = CreditsView.new()
	layer.add_child(view)
	await wait_frames(2)
	return view


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
	await get_tree().process_frame


## Nomes da coluna Autor do CREDITS.md, sem o que vem entre parênteses.
func _md_author_names() -> Array[String]:
	var out: Array[String] = []
	for line: String in FileAccess.get_file_as_string(AudioCredits.SOURCE_PATH).split("\n"):
		if not line.begins_with("| `"):
			continue
		for part: String in line.split("|")[3].split(";"):
			var name: String = part.strip_edges()
			if name.contains(" ("):
				name = name.left(name.find(" ("))
			if not name.is_empty() and not out.has(name):
				out.append(name)
	return out


func test_data_file_matches_credits_md() -> void:
	var md: String = FileAccess.get_file_as_string(AudioCredits.SOURCE_PATH)
	var expected: String = AudioCredits.to_json_text(AudioCredits.parse_markdown(md))
	assert_eq(FileAccess.get_file_as_string(AudioCredits.DATA_PATH), expected,
		"audio_credits.json desatualizado: rode \"$G\" --headless --path . --script res://tools/gen_audio_credits.gd")


func test_every_author_has_link_and_license() -> void:
	var authors: Array[Dictionary] = AudioCredits.load_authors()
	var names: Array[String] = []
	for a: Dictionary in authors:
		names.append(str(a["name"]))
		assert_gt(int(a["files"]), 0, "%s: arquivos" % a["name"])
		assert_false((a["works"] as Array).is_empty(), "%s: obra" % a["name"])
		if not a["generated"]:
			for work: Dictionary in a["works"]:
				assert_string_starts_with(str(work["url"]), "https://", "%s: link" % a["name"])
	for name: String in EXPECTED_AUTHORS + [AudioCredits.PROJECT_AUTHOR]:
		assert_has(names, name)
	assert_eq(names.back(), AudioCredits.PROJECT_AUTHOR, "sons do projeto no fim")
	for name: String in _md_author_names():
		assert_has(names, name, "autor do CREDITS.md na lista")


func test_work_links_follow_the_author() -> void:
	var by_name: Dictionary = {}
	for a: Dictionary in AudioCredits.load_authors():
		by_name[a["name"]] = a
	var url: Callable = func(n: String) -> String: return str(((by_name[n] as Dictionary)["works"] as Array)[0]["url"])
	assert_eq(url.call("jasinski"), "https://opengameart.org/content/beach-ocean-waves")
	assert_eq(url.call("transitking"), "https://opengameart.org/content/water-waves")
	assert_eq(url.call("Écrivain"), "https://opengameart.org/content/icy-heights")
	assert_eq((by_name["Kenney"]["works"] as Array).size(), 3, "três pacotes da Kenney")
	assert_eq(by_name["AntumDeluge"]["recordings"], ["polymorpheva"])
	assert_eq(by_name["ScanDig"]["contributors"], ["Dev B", "Felipe Mayer"])


func test_view_lists_every_author_with_cc0() -> void:
	var view: CreditsView = await _view()
	var text: String = view.sounds_text()
	for name: String in EXPECTED_AUTHORS:
		assert_string_contains(text, name)
		assert_string_contains((view.author_labels[name] as Label).text, "CC0 1.0")
	assert_string_contains(text, "kenney.nl/assets/rpg-audio")
	assert_string_contains(text, "opengameart.org/content/crow-caw")
	assert_string_contains(text, "gravação: polymorpheva")
	assert_string_contains((view.author_labels["ScanDig"] as Label).text, "Sons gerados pelo projeto (Dev B, Felipe Mayer)")
	assert_string_contains(view.team_label.text, "Felipe — Concepção")


func test_keyboard_scroll_without_focus_trap() -> void:
	InputDevice.instance.set_using_pointer(false)
	var view: CreditsView = await _view()
	view.focus_start()
	await wait_frames(1)
	assert_eq(_focus(), view.scroll, "foco começa na área")
	var bar: VScrollBar = view.scroll.get_v_scroll_bar()
	assert_gt(bar.max_value, view.scroll.size.y + 100.0, "conteúdo maior que a área")
	await _key(KEY_DOWN)
	assert_eq(view.scroll.scroll_vertical, CreditsView.SCROLL_STEP, "↓ rola")
	assert_eq(_focus(), view.scroll, "e o foco fica")
	await _key(KEY_PAGEDOWN)
	assert_gt(view.scroll.scroll_vertical, CreditsView.SCROLL_STEP * 2, "PgDn rola uma página")
	await _key(KEY_END)
	var bottom: int = view.scroll.scroll_vertical
	assert_almost_eq(float(bottom), bar.max_value - bar.page, 1.0, "End vai ao fim")
	await _key(KEY_DOWN)
	assert_eq(_focus(), view.back_button, "no fim, ↓ passa ao Voltar")
	await _key(KEY_UP)
	assert_eq(_focus(), view.scroll, "↑ volta à área")
	await _key(KEY_HOME)
	assert_eq(view.scroll.scroll_vertical, 0, "Home vai ao topo")
	await _key(KEY_UP)
	assert_eq(_focus(), view.back_button, "no topo, ↑ também sai (anel)")
	await _key(KEY_TAB)
	assert_eq(_focus(), view.scroll, "Tab alterna")
	assert_true(UiNavAudit.has_focus_style(view.scroll), "área com borda de foco")


func test_back_button_emits() -> void:
	var view: CreditsView = await _view()
	watch_signals(view)
	view.back_button.pressed.emit()
	assert_signal_emitted(view, "back_pressed")


func test_labels_switch_language_live() -> void:
	var view: CreditsView = await _view()
	SettingsManager.instance.set_language("en")
	await wait_frames(1)
	var text: String = view.sounds_text()
	assert_string_contains((view.author_labels["ScanDig"] as Label).text, "Sounds generated by the project (Dev B, Felipe Mayer)")
	assert_string_contains(text, "recording: polymorpheva")
	assert_string_contains(text, "Files: ")
	assert_false(text.contains("Arquivos"), "nada em PT-BR")
	assert_string_contains(text, "Écrivain", "nome de autor não se traduz")
	var title: Label = view.get_child(0) as Label
	assert_eq(title.atr(title.text), "— CREDITS —")
	assert_eq(view.back_button.atr(view.back_button.text), "Back")
	SettingsManager.instance.set_language("pt_BR")
	await wait_frames(1)
	assert_string_contains(view.sounds_text(), "Arquivos: ")


func test_title_credits_button_opens_and_escape_returns() -> void:
	InputDevice.instance.set_using_pointer(false)
	var title: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	title.auto_skip = false
	title.scene_change_enabled = false
	add_child_autofree(title)
	await wait_frames(3)
	assert_true(title.credits_button.visible, "botão Créditos no título")
	title.credits_button.pressed.emit()
	await wait_frames(1)
	assert_true(title.credits_panel.visible and not title.main_card.visible)
	assert_eq(_focus(), title.credits_view.scroll)
	await _key(KEY_ESCAPE)
	assert_false(title.credits_panel.visible, "Esc volta")
	assert_true(title.main_card.visible)
	assert_eq(_focus(), title.credits_button, "foco no botão Créditos")
	title.show_credits()
	title.credits_view.back_button.pressed.emit()
	assert_true(title.main_card.visible, "Voltar também")
