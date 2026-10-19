extends GutTest

## Rótulos 3D montados por código trocam de idioma ao vivo (P1, #131): ShopOffer e ItemPickup
## já na cena se refazem no NOTIFICATION_TRANSLATION_CHANGED, sem recarregar.

const TOOL: ToolData = preload("res://items/tools/dinamite.tres")


func after_each() -> void:
	TranslationServer.set_locale("pt_BR")


func _label_of(node: Node) -> Label3D:
	for child: Node in node.get_children():
		if child is Label3D:
			return child as Label3D
	return null


func test_shop_offer_label_follows_locale() -> void:
	TranslationServer.set_locale("pt_BR")
	var offer: ShopOffer = ShopOffer.new()
	offer.tool_data = TOOL
	add_child_autofree(offer)
	var label: Label3D = _label_of(offer)
	assert_not_null(label, "rótulo da banca")
	var pt: String = label.text
	assert_string_starts_with(pt, TOOL.display_name)
	TranslationServer.set_locale("en")
	var en_name: String = TranslationServer.translate(TOOL.display_name)
	assert_ne(en_name, TOOL.display_name, "a ferramenta tem inglês no CSV")
	assert_string_starts_with(label.text, en_name + "\n", "nome em inglês sem recarregar")
	TranslationServer.set_locale("pt_BR")
	assert_eq(label.text, pt, "volta ao PT-BR")


func test_item_pickup_label_follows_locale() -> void:
	TranslationServer.set_locale("pt_BR")
	var carried: CarriedItem = CarriedItem.create_from_tool_data(TOOL)
	var pickup: ItemPickup = ItemPickup.create(carried)
	pickup.freeze = true
	add_child_autofree(pickup)
	var label: Label3D = _label_of(pickup)
	assert_not_null(label, "nome do item no chão")
	var pt: String = label.text
	assert_string_contains(pt, TOOL.display_name)
	TranslationServer.set_locale("en")
	assert_string_contains(label.text, String(TranslationServer.translate(TOOL.display_name)), "nome em inglês sem recarregar")
	assert_eq(label.text, carried.get_display_name())
	TranslationServer.set_locale("pt_BR")
	assert_eq(label.text, pt, "volta ao PT-BR")


## Fala temporária com número (I18n.fmt) visível troca de idioma junto (#137).
func test_interactable_packed_say_follows_locale() -> void:
	TranslationServer.set_locale("pt_BR")
	var item: Interactable = Interactable.new()
	add_child_autofree(item)
	var say: Label3D = item.get_node(^"Say") as Label3D
	item.show_say(I18n.fmt("%d/%d criaturas", [3, 9]), 4.0)
	assert_eq(say.text, "3/9 criaturas")
	TranslationServer.set_locale("en")
	assert_eq(say.text, "3/9 creatures", "fala com número refeita sem esperar sumir")
	item.show_say("Fala fixa", 4.0)
	TranslationServer.set_locale("pt_BR")
	assert_eq(say.text, "Fala fixa", "fala fixa continua com a chave (o Label3D traduz)")
