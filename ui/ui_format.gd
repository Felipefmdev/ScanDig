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
