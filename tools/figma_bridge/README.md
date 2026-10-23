# Ponte local — comandar o Figma pelo terminal

O Figma não permite escrita sem um plugin em execução. Esta ponte é o mais perto de
automação real: abres o plugin **uma vez** e, a partir daí, eu (ou tu) enfileiramos
comandos no terminal.

```
terminal                              Figma
python tools/figma_agent.py serve  <--  plugin "ScanDig Bridge" (polling 1,5 s)
python tools/figma_agent.py build      -> cria página, estilos e frames
python tools/figma_agent.py export ... -> PNG gravado em docs/ui/exports/
```

Sem MCP, sem conta paga, sem rede externa: só `127.0.0.1:8765`.

## Instalar

1. Fontes: instala `ui/theme/fonts/PatrickHand-Regular.ttf` e `Kalam-Bold.ttf`.
2. Figma desktop → **Plugins → Development → Import plugin from manifest…** →
   `tools/figma_bridge/manifest.json`.
3. Abre o plugin **ScanDig Bridge**. A UI mostra “sem servidor” até o passo 4.

## Usar

Janela 1:

```powershell
python tools/figma_agent.py serve
```

Janela 2:

```powershell
python tools/figma_agent.py build
python tools/figma_agent.py ping
python tools/figma_agent.py export --node "01 hud 1152x648"
python tools/figma_agent.py results --wait 30
python tools/figma_agent.py status
```

O plugin cria a página `ScanDig Kit` (ou `ScanDig Kit 2`) e os 5 frames. `export` procura
o frame em todas as páginas e grava `docs/ui/exports/<nome>.png` (ignorado pelo Git).

## Comandos suportados

| Comando | Efeito |
|---|---|
| `build` | página nova + estilos + frames |
| `export` | PNG 1× do frame indicado |
| `ping` | confirma ligação e devolve a página atual |

## Se o Figma bloquear localhost

A UI tem um campo manual: cola `{"type":"build"}` e carrega em **Executar comando**.
O manifesto declara `networkAccess` só para `127.0.0.1`/`localhost`; não há acesso externo.

## Limites

- O plugin tem de estar aberto na sessão do Figma (é uma regra da plataforma).
- Os frames vêm dos SVG: texto pode entrar como contorno.
- O servidor é local e sem autenticação; não expões a porta.
- Isto não é um MCP: é uma fila HTTP simples, auditável no repo.

## Verificação

```powershell
node --check tools/figma_bridge/code.js
python tools/make_figma_plugin.py --check
python tools/figma_agent.py serve   # e, noutra janela:
python tools/figma_agent.py ping
```
