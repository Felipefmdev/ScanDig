# Fontes da UI (#51)

| Arquivo | Fonte | Uso | Origem | Licença |
|---|---|---|---|---|
| `PatrickHand-Regular.ttf` | Patrick Hand, de Patrick Wagesreiter | Texto da UI inteira (`default_font` do theme) | https://github.com/google/fonts/tree/main/ofl/patrickhand | SIL Open Font License 1.1 (`OFL-PatrickHand.txt`) |
| `Kalam-Bold.ttf` | Kalam Bold, da Indian Type Foundry | Código da sala (`CodeLabel` e `CodeLineEdit`) | https://github.com/google/fonts/tree/main/ofl/kalam | SIL Open Font License 1.1 (`OFL-Kalam.txt`) |

- **Por que usar Kalam no código da sala:** no Patrick Hand, o "M" parece um "H", e as duas letras estão no alfabeto do código (`core/room_code.gd`). O ponto fraco do Kalam é o "1", que parece "l", mas o alfabeto do código não tem 0, O, 1 nem I.
- **Glifos que faltam:** nenhuma das duas fontes tem `→ ★ ✔ 🔒`. O `build_theme.gd` acrescenta um fallback com fontes de símbolos e emoji do sistema (`SystemFont`: Segoe UI Symbol e Segoe UI Emoji, ou as Noto equivalentes).
- **Variantes testadas:** Kalam Regular também foi comparada, em duas variantes: em tudo e só em títulos e botões. As duas estouravam o layout a 960x540 (Loja com 436 e 428 px, acima do limite de 390), e o "1" dela é ambíguo nos preços. Por isso Kalam Regular não está no repositório.
