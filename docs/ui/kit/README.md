# Kit de frames para o Figma

Gerado por `python tools/make_ui_frames.py` a partir de [`../tokens.json`](../tokens.json).
São **protótipos de layout e hierarquia**, não arte final: textura de papel, ícones
desenhados e animação ficam no jogo.

## Ficheiros

| Ficheiro | Conteúdo | Tamanho |
|---|---|---|
| `00_tokens.svg` | swatches, escala tipográfica, espaçamentos | 900×700 |
| `01_hud_1152x648.svg` | HUD: chips, toast, mira, prompt | 1152×648 |
| `02_loja_1152x648.svg` | loja: lista, detalhe, compra, foco | 1152×648 |
| `03_pausa_1152x648.svg` | pausa: retomar, definições, sair | 1152×648 |
| `04_componentes.svg` | botões (5 estados), chips, toast, tabs, campo | 760×700 |

## Importar no Figma

1. Instala as fontes do projeto (uma vez): abre `ui/theme/fonts/PatrickHand-Regular.ttf`
   e `Kalam-Bold.ttf` e escolhe “Instalar”. Sem isto, o Figma substitui a fonte e as
   larguras mudam.
2. Arrasta os SVG para a página `04 Componentes` (ou para uma página `06 Kit`).
3. Cada SVG entra como grupo de vetores com texto editável. **Não escalar**: já estão a
   1× (1152×648). Se o frame do Figma for 1920×1080, usa uma instância escalada a 1,67×
   só para ver, nunca para medir.
4. Copia os estilos de cor/texto dos vetores para os tokens (Tokens Studio) e passa a
   usar só os tokens.

## O que está medido e o que é aproximado

- **Medido:** cores da paleta, tamanhos 15/18/20/21/26/30, margem segura 58 px, grelha 8,
  alvo 44 px, raio 3, borda 2, foco 3.
- **Aproximado:** larguras de texto (dependem da fonte instalada), ícones (retângulos
  placeholder), conteúdo de exemplo (“R$ 1.240”, “Nv.3 · 13 m”).
- **Em falta de propósito:** 9-slice da textura de papel, estados hover/pressed reais,
  legendas e localização.

## Comparar com o jogo

1. No Godot, abre o mesmo ecrã a 1152×648 e captura (Movie Maker ou MCP).
2. Exporta o frame do Figma a 1× PNG, com fundo.
3. Põe os dois lado a lado; diferenças aceitáveis: textura, ícones, animação.
   Inaceitáveis: tamanho de texto, contraste, posição dos chips, hierarquia.
4. Guarda em `.bot_runs/ui_ref/` (ignorado pelo Git) e refere na issue.

## Atualizar

```powershell
python tools/make_ui_frames.py          # regenera
python tools/make_ui_frames.py --check  # falha se estiverem desatualizados
```

Se mudares um token, regenera e volta a importar. O SVG é descartável; os tokens e o
`Theme` é que são fonte de verdade.
