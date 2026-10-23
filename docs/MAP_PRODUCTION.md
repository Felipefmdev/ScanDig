# Oficina de mapas — #175

Ferramentas instaladas para os terminais Maestri em `C:/Users/felip/.codex/tools/map-production/`. A configuração pessoal fica em `toolchain.json`, com caminhos absolutos e versões. Downloads originais e hashes estão em `downloads-manifest.json`.

| Ferramenta | Versão instalada | Uso |
|---|---|---|
| Blender | 4.5.15 LTS, ZIP oficial com SHA256 conferido | Modelar, normalizar pivôs e exportar GLB |
| Kenney Space Kit | 2.0, licença CC0 preservada | Biblioteca de 153 arquivos GLB |
| ProtonScatter | 4.0 + revisão 32e7a0a82e16 com correções Godot 4.3 | Distribuição visual na oficina |
| Terrain3D | 1.0.0, binários específicos Godot 4.3 | Edição de terreno na oficina |

A oficina usa Godot 4.3 **Forward+**, com ambos os plugins habilitados. Os addons ficam no projeto `workshop`, fora do jogo. Os mapas de produção recebem os recursos selecionados/exportados; os terrenos existentes continuam com suas consultas de apoio e colisão. Não instalar uma versão diferente dos addons sobre esta configuração sem repetir a validação.

## Abrir pelo terminal Maestri

```powershell
./tools/map_production.ps1 -Tool Validate
./tools/map_production.ps1 -Tool Blender
./tools/map_production.ps1 -Tool Workshop
./tools/map_production.ps1 -Tool Game
```

O último comando abre o projeto no editor, inclusive num clone sem a integração Lua da #120. Para abrir uma cena específica já presente, passe `-ToolArgs 'res://world/map_lua.tscn'`. `-Background -ToolArgs ...` permite executar Blender/Godot pelo terminal sem abrir uma sessão interativa. Validate e Background rejeitam exits nativos diferentes de zero; a abertura GUI é assíncrona e não verifica o exit futuro da janela. Argumentos com espaços/aspas são preservados nas sessões interativas. O MCP Godot continua disponível para inspeção/aplicação; não foi acrescentado servidor MCP de terceiros.

As fontes editáveis entregues ficam em `assets/models/scandig_space/source/`. Sua `.gdignore` impede autoimportação pela Godot: o runtime usa apenas os GLBs, sem depender de Blender. Exemplo:

```powershell
./tools/map_production.ps1 -Tool Blender -ToolArgs "$PWD/assets/models/scandig_space/source/lunar_rocket.blend"
```

O caminho do Blender também foi configurado nos ajustes pessoais da Godot 4.3 (`filesystem/import/blender/blender3_path`). O pipeline validado usa exportação GLB explícita; a importação automática de `.blend` não foi usada como dependência do jogo.

## Pipeline iniciado na Lua

As cópias de produção estão em `assets/models/scandig_space/`, com licença e manifesto de origem/hashes. O Blender removeu o deslocamento interno (2,0,1.5) dos modelos e montou um foguete a partir de quatro módulos. Exportou também gerador e suprimentos. A entrega #175 de assets é independente de cenas/scripts: `lunar_arrival.gd`, terreno, mapa e integração da campanha pertencem à #120 e permanecem alterações locais separadas.

Antes de substituir um recurso: visualizar a referência, testar apoio/footprint, importar, executar testes e capturar pelo MCP com janela. No checkpoint local #120, LunarArrival aplica ToonKit/terreno, com colisão do foguete derivada das faces e apoios cosméticos; isso não certifica missão, embarque, viagem ou campanha integral neste commit de ferramentas.

## Preparação em outra máquina

O clone contém lançador, testes e assets; os executáveis/addons e configurações pessoais não são instalados automaticamente. Criar `%USERPROFILE%/.codex/tools/map-production/toolchain.json` com caminhos absolutos para `blender`, `godot` (console), `workshop`, `space_kit` e objeto `versions`. O Validate consulta versões dos executáveis e imprime os caminhos; não substitui o smoke dos plugins.
Usar fontes oficiais e versões fixas: [Blender4.5.15](https://download.blender.org/release/Blender4.5/blender-4.5.15-windows-x64.zip), [SpaceKit2.0](https://kenney.nl/assets/space-kit), [ProtonScatter32e7a0a82e166328f590faa999239a42e67e80b8](https://github.com/HungryProton/scatter/tree/32e7a0a82e166328f590faa999239a42e67e80b8) e [Terrain3D1.0.0 para Godot4.3](https://github.com/TokisanGames/Terrain3D/releases/tag/v1.0.0-stable). Preservar as licenças nos pacotes; criar oficina Godot4.3 separada e habilitar seus dois plugins ali, sem copiar addons/terrenos para o jogo. Configurar `renderer=forward_plus`; não usar revisões recentes sem nova validação de compatibilidade.
Testes do lançador: `python -B tools/test_map_production.py` no Windows com PowerShell. São executáveis fake compilados temporariamente por Add-Type, sem iniciar Godot/Blender reais; cobrem falhas nativas, clone sem Lua e argumentos com espaços/aspas.

## QA dos assets entregues — 23/10/2026

Fontes e reimportação dos GLBs passaram no perfil game de blender-asset-qa: foguete607triângulos/4objetos, gerador403/2 e suprimentos268/5. Os suprimentos compartilham2malhas no GLB; `mesh_count` do manifesto conta instâncias.
Foram removidas faces numericamente degeneradas em coordenadas de montagem, corrigidas UVs colapsadas sem textura e afastada a parede do módulo fuel3mm radialmente do casco coincidente. O AABB total e os pivôs foram preservados. Originais do Space Kit permaneceram intactos; fontes corrigidas acompanham os GLBs.
Warnings aceitos: UVs empilhadas/fora de0..1 para cores sólidas sem textura/bake, vértices duplicados em seams/hardedges e faces internas opostas nos encaixes/recipientes (overdraw pequeno). Não são UVs certificadas para bake/lightmap futuro. Sheets atuais material/wire de quatro ângulos e PNGs Forward+ antes/depois foram inspecionados; não há aprovação de campanha/coop por essas imagens. O overlay wire do gerador tem linhas externas finas também presentes antes, sem faces soltas/zfight detectados; origem do overlay não certificada.

## Evidências e limites

Os caminhos `.bot_runs/`, `toolchain.json`, downloads-manifest e proton-update são evidências/configurações locais fora do commit. Resumos auditáveis e responsáveis estão na [issue175](https://github.com/Felipefmdev/ScanDig/issues/175). Os itens abaixo são checkpoints históricos da preparação; não representam estado atual completo da campanha120.

- Blender: import/export executados em `.bot_runs/tools175_blender_{inspect,export}.log`.
- Recursos e terreno: RED/GREEN em `.bot_runs/tools175_{arrival,scene}_*.log`.
- Oficina: `.bot_runs/tools175_smoke.log` confirmou classe Terrain3D, compilação do ProtonScatter e criação dos dois nós. A revisão final passou importação/abertura/encerramento em `tools175_workshop_{import_bootstrap,plugins}.log` e repetição em `tools175_updated_editor_repeat.log`, todos com exit 0. Persistem warnings de UID de origem com fallback por caminho e encerramento da varredura no teste automatizado.
- A versão original ca62441 falhou de forma intermitente no encerramento dos probes, inclusive em Forward+. Foi substituída pela revisão oficial `32e7a0a82e166328f590faa999239a42e67e80b8`, que inclui correções para 4.3. Logs anteriores de matriz/crash foram preservados e não representam a validação final. A origem e o hash do pacote final estão em `proton-update.json`.
- A primeira importação exigiu importar imagens/modelos antes dos scripts dos plugins; o cache da oficina foi preparado. Arquivos de recurso do ProtonScatter traziam UIDs de origem com fallback por caminho. Isso é metadado do pacote, não alteração nos modelos do jogo.
- Estes checks não substituem o uso de todas as funções dos addons, testes de rede ou validação de desempenho dos mapas. GUT/headless completos permanecem obrigatórios antes de commit.
- Produção: `.bot_runs/tools175_final_green.log` passou 18/18 testes, 442 asserts, com janela/Vulkan e sem ERROR/WARNING. O lote inclui o controlador de reparo ainda em staging. Headless direcionado: 11 passando, 1 pendente de renderer real, 220 asserts, exit 0 com ruído dummy. O teste fotométrico teve RED real com Environment/Sun da Lua; ajuste local de ponto branco/intensidades preservou a paleta sem modificar o shader compartilhado. Capturas finais em `.bot_runs/tools175_final_07..10*.png`.
