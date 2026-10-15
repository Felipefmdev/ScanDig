class_name UiFormat
extends RefCounted

## Formatação de valores da UI (#51): "R$" nunca fica separado do número numa quebra de linha.

## Espaço que não quebra (U+00A0).
const NBSP: String = " "


## 3200 -> "3.200"; -1234567 -> "-1.234.567".
static func thousands(amount: int) -> String:
	var digits: String = str(absi(amount))
	var groups: Array[String] = []
	while digits.length() > 3:
		groups.push_front(digits.right(3))
		digits = digits.left(digits.length() - 3)
	groups.push_front(digits)
	return ("-" if amount < 0 else "") + ".".join(groups)


## 3200 -> "R$ 3.200" (com NBSP).
static func money(amount: int) -> String:
	return "R$" + NBSP + thousands(amount)


## Mensagens prontas do core ("R$ 300"): troca o espaço depois de "R$" por NBSP.
static func fix_money_spaces(text: String) -> String:
	return text.replace("R$ ", "R$" + NBSP)
