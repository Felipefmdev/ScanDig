# Plugin local do Figma — ScanDig UI Kit

Cria no Figma, com um clique, o que o MCP não faz: **estilos de cor e de texto** e os
**frames do kit** numa página nova. Não usa rede, não altera páginas existentes e não
precisa de conta paga.

Gerado por [`tools/make_figma_plugin.py`](../make_figma_plugin.py) a partir de
[`tokens.json`](../../docs/ui/tokens.json) e dos SVGs em [`docs/ui/kit/`](../../docs/ui/kit/).

## Instalar (uma vez)

1. Instala as fontes: abre `ui/theme/fonts/PatrickHand-Regular.ttf` e `Kalam-Bold.ttf` e
   escolhe “Instalar”. Sem isto, os estilos de texto falham com aviso.
2. Abre o **Figma desktop** e um ficheiro teu.
3. Menu **Plugins → Development → Import plugin from manifest…**
4. Escolhe `tools/figma_plugin/manifest.json`.
5. O plugin aparece em **Plugins → Development → ScanDig UI Kit**.

## Correr

**Plugins → Development → ScanDig UI Kit**.

O plugin:

- cria uma página nova `ScanDig Kit` (ou `ScanDig Kit 2`, se já existir);
- cria estilos de pintura `ScanDig/palette/*` e `ScanDig/semantic/*`;
- cria estilos de texto `ScanDig/type/*` (hint, body, subtitle, title, code);
- coloca 5 frames: tokens, HUD, loja, pausa, componentes;
- mostra um resumo e fecha.

Nada do ficheiro existente é apagado. Se algo falhar, a mensagem diz qual fonte ou estilo.

## Limites

- Os frames vêm dos **SVG**, por isso o texto pode entrar como contorno; serve para
  layout e comparação, não para editar copy no Figma.
- Componentes e variantes não são criados automaticamente; a folha `04_componentes.svg`
  mostra os estados para recriares como componente.
- O plugin não lê ficheiros locais em runtime: os tokens e SVGs são embutidos no
  `code.js` na geração.

## Atualizar

```powershell
python tools/make_ui_frames.py        # se mudaram tokens
python tools/make_figma_plugin.py     # reembute tokens + SVGs
node --check tools/figma_plugin/code.js
```

Volta a correr o plugin; ele cria outra página com a versão nova.

## Porque não MCP

Ver [`docs/ui/FIGMA.md`](../../docs/ui/FIGMA.md) §9: o MCP oficial é read-only e exige
desktop + assento Dev; MCPs de terceiros precisam de plugin e bridge, e a política do
projeto não os autoriza sem validação. Este plugin é local, auditável e faz a escrita.
