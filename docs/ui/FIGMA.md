# Figma → Godot: fluxo de UI

O Figma é onde se decide **layout e hierarquia**; o `Theme` do Godot é onde se decide
**comportamento e escala**. Este documento liga os dois sem duplicar trabalho.

Tokens prontos: [`tokens.json`](tokens.json). Auditoria do tema atual:
[`../UI_REVIEW.md`](../UI_REVIEW.md). Regras: [`../learning/UI_UX.md`](../learning/UI_UX.md).

## 1. Molduras (frames)

O projeto não fixa `viewport_width` no `project.godot`; a base efetiva é a predefinição do
Godot 4 (1152×648) com `stretch/mode=canvas_items` e `aspect=expand`.

| Frame | Uso | Escala |
|---|---|---|
| **1152×648** | base de design (1×) | tamanhos do tema |
| 1280×720 | portátil / mínimo | 1,11× |
| 1920×1080 | desktop | 1,67× |
| 2560×1080 | ultrawide (teste de âncoras) | — |

- Uma página por ecrã; um frame por resolução, agrupados.
- Grelha de **8 px**; margem segura **5%** (58 px na base, 64 a 720p).
- Zona central livre de HUD: mín. 60% da largura.
- Texto: nunca abaixo de 15 px na base; testar com +30% de texto.

## 2. Páginas e organização

```
00 Tokens        swatches, estilos de texto, espaçamentos
01 HUD           chips, prompts, legendas, avisos
02 Menus         título, pausa, definições, multijogador
03 Loja/Base     ofertas, comparação, requisitos
04 Componentes   botões, painéis, abas, toasts, sliders
05 Referências   capturas de jogos (Game UI Database)
```

Cada componente é um **componente principal** em `04`, com variantes; os ecrãs só usam
instâncias. Sem cópias soltas.

## 3. Componentes e estados

| Componente | Variantes |
|---|---|
| `Button/Primary` | Default, Hover, Pressed, Focus, Disabled |
| `Button/Secondary` | idem |
| `Button/Danger` | idem |
| `Panel/Paper` | Default, Worn |
| `Chip` | Default, Alert, Muted |
| `Toast` | Info, Success, Warning, Danger |
| `Tab` | Active, Inactive, Disabled |
| `Field` | Default, Focus, Error, ReadOnly |

Propriedade de variante: `State`. Nome do componente: `Button/Primary`. O nome tem de
sobreviver ao handoff — é o mesmo que vai para o `Theme` como *type variation*.

## 4. Tokens

1. Instala o plugin **Tokens Studio for Figma**.
2. Importa [`tokens.json`](tokens.json) (formato legacy do Tokens Studio).
3. Aplica os tokens a estilos de cor e de texto; não escrevas hex à mão nos ecrãs.
4. Quando um token mudar, muda em `ui/theme/ui_palette.gd` **e** aqui, no mesmo commit.

Cores vêm de `ui_palette.gd`; tipografia vem de `build_theme.gd`. O JSON é uma cópia
declarativa, não a fonte de verdade.

> **Nota:** o título a 26 px é o alvo da #180 (hoje o tema usa 21). Enquanto a issue não
> fechar, o Figma pode mostrar 26, mas a implementação continua a 21 — a diferença tem de
> estar visível na comparação, não escondida.

### Atalho: plugin local

[`tools/figma_plugin/`](../../tools/figma_plugin/README.md) importa os tokens e os SVGs e
cria, numa página nova, os estilos `ScanDig/palette/*`, `ScanDig/type/*` e os 5 frames.
Instala-se uma vez por *Import plugin from manifest* e corre-se por
*Plugins → Development → ScanDig UI Kit*. É local e não usa rede.

## 5. Handoff para o Godot

| Figma | Godot (`Theme`) | Nota |
|---|---|---|
| Frame 1152×648 | base do stretch | 1280/1920 são testes, não novos temas |
| Cor de texto | `Label/colors/font_color` | INK sobre PAPER = 11,57:1 |
| Estilo de texto | `font_size` por type variation | corpo 18, subtítulo 21, título 26 |
| Fonte manuscrita | `default_font` (Patrick Hand) | o jogo usa `FontVariation` para engrossar |
| Código da sala | `CodeLabel` em Kalam Bold 30 | não usar Patrick Hand (M/H confundem) |
| Fundo de painel | `StyleBoxTexture` 9-slice | margem da textura: **14 px** |
| Padding interno | `content_margin_*` | não desenhar padding à mão no Figma |
| Borda 2/3/4 px | `border_width_*` | foco = 3 px |
| Raio 2/3 px | `corner_radius_*` | igual em todos os cantos |
| Espaçamento 8/12/16 | `separation` / margens | grelha 8 |
| Alvo 44×44 | `custom_minimum_size` | 8 px entre alvos |

**9-slice:** no Figma, desenha o painel no tamanho real e marca a área que não pode
deformar (14 px); no Godot, essa área é `texture_margin`. Nunca estiques os cantos.

## 6. Exportar e comparar

- Exporta PNG **1×** do frame exato (1152×648 ou 1280×720), fundo incluído.
- Nome: `<ecra>_<largura>x<altura>_v<NN>.png` (ex.: `hud_1280x720_v02.png`).
- Guarda em `.bot_runs/ui_ref/` para comparação; não commites imagens de trabalho.
- Compara com a captura do jogo na mesma resolução e com o mesmo estado (saldo, mapa,
  itens). `tools/qa_visual_review.py` gera a galeria antes/depois.

## 7. Revisão antes de implementar

- [ ] Teste dos 5 s: a ação primária identifica-se?
- [ ] Três tamanhos de texto, no máximo.
- [ ] Contraste medido com os tokens (não “parece bem”).
- [ ] Estados completos e foco visível em todos os controlos.
- [ ] 1152×648 e 1280×720 legíveis; 2560×1080 sem sobreposição.
- [ ] Texto +30% (inglês) sem cortar.
- [ ] HUD não tapa o centro nem o chão imediato.

Só depois se abre a issue de implementação (ex.: #180) e se altera `build_theme.gd`.

## 8. Não faças

- Desenhar só a 1920×1080 e assumir que 720p resolve.
- Usar branco puro ou preto puro: a paleta é papel/tinta.
- Criar um quarto tamanho de texto “só para este ecrã”.
- Pôr texto dentro de imagens exportadas.
- Inventar cores fora de `ui_palette.gd`.
- Implementar no Figma comportamentos que o Godot não replica (scroll infinito, hover
  em toque) sem marcar como protótipo.

## 9. MCP — o que não resolve

- **MCP oficial (Dev Mode):** servidor local do app Figma, exige desktop e assento
  Dev/Full. Expõe leitura do design para código (metadados, variáveis, imagem, screenshot);
  **não cria nós, estilos nem páginas**. Não é um pacote que se descarregue para o repo.
- **MCPs de terceiros:** ou são read-only sobre a REST API, ou precisam de um plugin
  Figma + bridge local para escrever. A política do projeto
  (`docs/TOOLCHAIN_MANIFEST.md`) não autoriza servidores MCP de terceiros sem validação,
  e esta sessão não consegue registar ferramentas MCP novas.
- **Caminho de escrita:** plugin local (`tools/figma_plugin/`) + tokens. Corre dentro do
  Figma, com a Plugin API, e é auditável no repo.

Se quiseres leitura automática do ficheiro (para comparar com capturas), o caminho é um
token pessoal da REST API e um script `GET /v1/files/...`; isso não substitui o plugin
para criar.
