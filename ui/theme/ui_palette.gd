class_name UiPalette
extends RefCounted

## Paleta da UI do ScanDig (docs/GAME_DESIGN.md §2): bege papel, contorno escuro e cores
## quentes de saturação média. Pares de texto/fundo usados conferidos em ui/tests/theme_test.gd
## (contraste WCAG >= 4.5).

## Fundo dos painéis.
const PAPER: Color = Color("#E8DCC0")
## Fundo de campos, listas e botões comuns (um tom acima do papel).
const PAPER_LIGHT: Color = Color("#F3EAD3")
## Abas não selecionadas, hover e sombreado em degrau.
const PAPER_DARK: Color = Color("#D2BF98")
## Texto e contorno.
const INK: Color = Color("#2B2118")
## Madeira: textos secundários, separadores e barras de rolagem.
const WOOD: Color = Color("#6E4A2D")
## Madeira escura: tela de carregamento e barra de título das janelas.
const WOOD_DARK: Color = Color("#3E2A1B")
## Ação principal.
const ORANGE: Color = Color("#D9772B")
## Perigo e erro.
const RED_BURNT: Color = Color("#9E3B2B")
## Sucesso (avisos de missão e segredo).
const GREEN_BOTTLE: Color = Color("#2F6B4A")
## Desativado (botões e mapas bloqueados).
const METAL: Color = Color("#56636E")
## Destaque: código da sala.
const GOLD: Color = Color("#E0A82E")
## Sombra dura dos painéis (INK com 35% de alfa).
const SHADOW: Color = Color(0.168627, 0.129412, 0.094118, 0.35)
