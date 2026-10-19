class_name I18n
extends RefCounted

## Tradução fora de nós (#131): funções estáticas e Resources sem tr() à mão. A chave é o texto
## em PT-BR (translations/scandig.csv); sem tradução, volta o próprio texto. Nos nós, use tr() e
## tr_n() direto (e o auto_translate dos Controls para textos fixos).


## Separa o template dos argumentos num texto de fmt().
const PACK_SEP: String = "\u001f"


static func t(text: String) -> String:
	var cut: int = text.find(PACK_SEP)
	if cut < 0:
		return String(TranslationServer.translate(text))
	var parsed: Variant = JSON.parse_string(text.substr(cut + PACK_SEP.length()))
	var args: Array = parsed if parsed is Array else []
	for i: int in args.size():
		if args[i] is String:
			args[i] = t(args[i])
	return t(text.left(cut)) % args


## Texto com números para mandar a outro peer (RPC): o template em PT-BR e os argumentos vão
## juntos e quem mostra chama t() (o _show_temporary_message do player já chama), cada um no
## seu idioma. Textos nos argumentos também são traduzidos.
static func fmt(template: String, args: Array) -> String:
	return template + PACK_SEP + JSON.stringify(args)


## Plural: `singular` quando n == 1, senão `plural` (as duas são chaves do CSV).
static func tn(singular: String, plural: String, n: int) -> String:
	return String(TranslationServer.translate_plural(singular, plural, n))


static func is_english() -> bool:
	return TranslationServer.get_locale().begins_with("en")
