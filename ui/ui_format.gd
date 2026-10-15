class_name UiFormat
extends RefCounted

## Formatação de valores da UI (#51): "R$" nunca fica separado do número numa quebra de linha.

## Espaço que não quebra (U+00A0).
const NBSP: String = MoneyFormat.NBSP


## 3200 -> "3.200"; -1234567 -> "-1.234.567". Mesma regra do core (MoneyFormat).
static func thousands(amount: int) -> String:
	return MoneyFormat.thousands(amount)


## 3200 -> "R$ 3.200" (com NBSP). Mesma regra do core (MoneyFormat).
static func money(amount: int) -> String:
	return MoneyFormat.money(amount)


## Mensagens prontas do core ("R$ 300"): troca o espaço depois de "R$" por NBSP.
static func fix_money_spaces(text: String) -> String:
	return text.replace("R$ ", "R$" + NBSP)


# --- Segredos por mapa -----------------------------------------------------------------------

## Grupo dos segredos cujo id não tem prefixo de mapa ("algo" sem "_"): contam em "Outros",
## para nada sumir da soma nem quebrar a UI.
const OTHER_SECRET_GROUP: String = "outros"


## "praia_reliquia_navio" -> "praia" (prefixo até o primeiro "_"); sem prefixo -> "outros".
static func secret_map_id(secret_id: String) -> String:
	var cut: int = secret_id.find("_")
	return secret_id.left(cut) if cut > 0 else OTHER_SECRET_GROUP


## {"praia": {"found": 3, "total": 6}, "campo": {...}} na ordem de GameState.SECRETS
## (ou de all_secrets, nos testes). Ids encontrados que não estão na lista são ignorados.
static func secret_counts_by_map(found: Array, all_secrets: Array = []) -> Dictionary:
	var secrets: Array = all_secrets if not all_secrets.is_empty() else Array(GameState.SECRETS)
	var counts: Dictionary = {}
	for secret: Variant in secrets:
		var id: String = str(secret)
		var map_id: String = secret_map_id(id)
		if not counts.has(map_id):
			counts[map_id] = {"found": 0, "total": 0}
		var entry: Dictionary = counts[map_id]
		entry["total"] = int(entry["total"]) + 1
		if found.has(id):
			entry["found"] = int(entry["found"]) + 1
	return counts


## Nome do mapa pelo MapData.display_name (maps = SessionManager.get_available_maps());
## sem o mapa, o id com a primeira letra maiúscula ("outros" -> "Outros").
static func map_display_name(map_id: String, maps: Array) -> String:
	for map: Variant in maps:
		var data: MapData = map as MapData
		if data != null and data.id == map_id and not data.display_name.is_empty():
			return data.display_name
	return map_id.left(1).to_upper() + map_id.substr(1)


## "Praia 3/6" sem quebra de linha dentro (NBSP no lugar dos espaços).
static func secret_count_text(map_id: String, entry: Dictionary, maps: Array) -> String:
	var text: String = "%s %d/%d" % [map_display_name(map_id, maps), int(entry.get("found", 0)), int(entry.get("total", 0))]
	return text.replace(" ", NBSP)
