class_name RoomCode
extends RefCounted

## Código de sala online (#30): o OpenID que o noray gera com NORAY_OID_LENGTH=6 e
## NORAY_OID_CHARSET=CHARSET. Utilitário puro, sem estado.
## Mostra "K7Q-3MX" e aceita "k7q3mx", "K7Q-3MX" ou "K7Q 3MX".

const LENGTH: int = 6
## 32 caracteres (2–9 e A–Z sem I e O): sem 0/O nem 1/I, que se confundem ao ditar.
const CHARSET: String = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
## Posição do hífen na exibição: "K7Q-3MX".
const DISPLAY_SPLIT: int = 3


## Tira espaços, hífens e outros separadores, e passa para maiúsculas: "k7q-3mx " -> "K7Q3MX".
static func normalize(text: String) -> String:
	var clean: String = ""
	for i in range(text.length()):
		var c: String = text[i]
		if c == "-" or c == " " or c == "\t" or c == "\n" or c == "\r":
			continue
		clean += c
	return clean.to_upper()


## Depois de normalize: LENGTH caracteres, todos do CHARSET.
static func is_valid(code: String) -> bool:
	var clean: String = normalize(code)
	if clean.length() != LENGTH:
		return false
	for i in range(clean.length()):
		if not CHARSET.contains(clean[i]):
			return false
	return true


## "K7Q3MX" -> "K7Q-3MX". Código fora do padrão volta normalizado, sem hífen.
static func format_for_display(code: String) -> String:
	var clean: String = normalize(code)
	if clean.length() != LENGTH:
		return clean
	return "%s-%s" % [clean.left(DISPLAY_SPLIT), clean.substr(DISPLAY_SPLIT)]
