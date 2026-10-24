extends GutTest

## Prepared RED: observe the production subtitle Label and its real translation.
## No replacement translation, victory signal, source fix or CSV edit is included.
const PT: String = "O Guardião do Sinal foi vencido na Lua.\nA expedição chegou ao destino do sinal.\nAinda há peças, segredos e bichos por achar."
const EN: String = "The Signal Warden was defeated on the Moon.\nThe expedition reached the source of the signal.\nThere are still artifacts, secrets and creatures to discover."
var saved_locale: String = ""
var was_open: bool = false

func before_each() -> void:
	saved_locale = TranslationServer.get_locale()
	was_open = VictoryScreen.is_open()

func after_each() -> void:
	TranslationServer.set_locale(saved_locale)
	if VictoryScreen.instance != null and not was_open: VictoryScreen.instance.close()
	await get_tree().process_frame

func _subtitle(locale: String) -> Label:
	TranslationServer.set_locale(locale)
	var screen: VictoryScreen = VictoryScreen.instance
	assert_not_null(screen,"Production VictoryScreen autoload must exist")
	if screen == null: return null
	# Direct UI open isolates copy/translation. It is not a live-victory proof.
	screen.open()
	assert_true(screen.root_control.is_visible_in_tree())
	assert_not_null(screen.summary_view)
	if screen.summary_view == null: return null
	var labels: Array[Label] = []
	# SummaryView has one direct Label: the subtitle; title/stats are nested.
	# Locate the actual widget independently of whether its copy is old or new.
	for child: Node in screen.summary_view.get_children():
		if child is Label: labels.append(child as Label)
	assert_eq(labels.size(),1,"Expected one real subtitle widget, not a test-created Label")
	return labels[0] if labels.size() == 1 else null

func _assert_no_legacy_claims(text: String) -> void:
	for forbidden: String in ["O Que Dorme","Cratera","Ídolo de Ouro","Sleeper","Crater","Golden Idol","Gold Idol","Idol of Gold"]:
		assert_false(text.to_lower().contains(forbidden.to_lower()),"Legacy victory claim: "+forbidden)

func test_production_subtitle_portuguese_describes_lunar_warden_without_legacy_loot() -> void:
	var label: Label = _subtitle("pt_BR")
	if label == null: return
	await get_tree().process_frame
	assert_true(label.is_visible_in_tree())
	var displayed: String = label.tr(label.text)
	assert_eq(displayed,PT,"Real subtitle must describe the lunar victory in Portuguese")
	_assert_no_legacy_claims(displayed)

func test_production_subtitle_english_uses_registered_translation_for_real_widget() -> void:
	var label: Label = _subtitle("en")
	if label == null: return
	await get_tree().process_frame
	assert_true(label.is_visible_in_tree())
	# Translate the Label's actual source text with the real TranslationServer.
	# Do not translate the expected PT constant: that could hide a stale UI key.
	var displayed: String = label.tr(label.text)
	assert_eq(displayed,EN,"Real subtitle must resolve to the approved English copy")
	_assert_no_legacy_claims(displayed)
