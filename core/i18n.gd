class_name I18n
extends RefCounted

## Tradução fora de nós (#131): funções estáticas e Resources sem tr() à mão. A chave é o texto
## em PT-BR (translations/scandig.csv); sem tradução, volta o próprio texto. Nos nós, use tr() e
## tr_n() direto (e o auto_translate dos Controls para textos fixos).


static func t(text: String) -> String:
	return String(TranslationServer.translate(text))


## Plural: `singular` quando n == 1, senão `plural` (as duas são chaves do CSV).
static func tn(singular: String, plural: String, n: int) -> String:
	return String(TranslationServer.translate_plural(singular, plural, n))


static func is_english() -> bool:
	return TranslationServer.get_locale().begins_with("en")
