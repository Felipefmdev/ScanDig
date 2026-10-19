class_name MoneyFormat
extends RefCounted

## Valores em reais nas mensagens do core, no mesmo padrão do UiFormat da UI (#51):
## milhar com ponto e NBSP depois de "R$", para o valor nunca quebrar de linha.
## Utilitário puro, sem estado.

## Espaço que não quebra (U+00A0).
const NBSP: String = " "


## 3200 -> "3.200"; -1234567 -> "-1.234.567". Em inglês (#131) o milhar é com vírgula: "3,200".
static func thousands(amount: int) -> String:
	var digits: String = str(absi(amount))
	var groups: Array[String] = []
	while digits.length() > 3:
		groups.push_front(digits.right(3))
		digits = digits.left(digits.length() - 3)
	groups.push_front(digits)
	return ("-" if amount < 0 else "") + ("," if I18n.is_english() else ".").join(groups)


## 3200 -> "R$ 3.200" (com NBSP).
static func money(amount: int) -> String:
	return "R$" + NBSP + thousands(amount)
