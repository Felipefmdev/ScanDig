extends GutTest

var _locale: String = ""
var _snapshot: Dictionary = {}

func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_snapshot = GameState.instance.get_snapshot().duplicate(true)
	GameState.instance.reset_state()

func after_each() -> void:
	TranslationServer.set_locale(_locale)
	GameState.instance.load_snapshot(_snapshot)

func test_compiled_english_translates_passage_prompt_and_key_use_reason() -> void:
	TranslationServer.set_locale("en")
	var passage: Interactable = (load("res://gameplay/environment/boss_passage.gd") as Script).new()
	passage.set("route_id", "campo")
	passage.set("source_map", "praia")
	GameState.instance.unlocked_maps.assign(["campo"])
	assert_eq(passage.get_prompt(), "[E] Travel to Old Fields")
	GameState.instance.unlocked_maps.clear()
	GameState.instance.defeated_bosses.assign(["king_crab"])
	assert_eq(GameState.instance.get_map_unlock_block_reason("campo"), "Use the boss key at the passage to Old Fields.")
	passage.free()

func test_compiled_shop_and_recovery_keys_have_english_translations_and_placeholders() -> void:
	TranslationServer.set_locale("en")
	assert_eq(TranslationServer.translate("Melhorias"), "Upgrades")
	assert_eq(TranslationServer.translate("[E] Melhorias"), "[E] Upgrades")
	assert_eq(TranslationServer.translate("Saldo da equipe: %s") % "R$ 100", "Team balance: R$ 100")
	assert_eq(TranslationServer.translate("%s  •  %d pontos") % ["Beach", 60], "Beach  •  60 spots")
	assert_eq(TranslationServer.translate("O destino não terminou de carregar. Tente novamente pela base."), "The destination did not finish loading. Try again from the base.")

func test_portuguese_passage_remains_localized_after_live_language_switch() -> void:
	TranslationServer.set_locale("en")
	TranslationServer.set_locale("pt_BR")
	assert_eq(TranslationServer.translate("[E] Viajar para %s") % "Praia", "[E] Viajar para Praia")
	assert_eq(TranslationServer.translate("Melhorias"), "Melhorias")
