# ScanDig — Ferramentas, sites e addons

Lista curada para Godot 4.3 com foco num jogo 3D low-poly cooperativo. ✅ = já aplicado no projeto.

## 1. Já aplicado no projeto

| O quê | Para quê | Onde |
| :--- | :--- | :--- |
| ✅ **GUT 9.3.0** (testes, MIT) | Testes automáticos de GDScript | `addons/gut/`, testes em `tests/`, config em `.gutconfig.json` |
| ✅ **CI no GitHub Actions** | Cada push importa o projeto, abre as cenas à procura de erros de script e corre os testes | `.github/workflows/ci.yml` |
| ✅ **`tools/gd_warnings.py`** | Warnings do GDScript (os do painel do editor) pelo LSP do editor headless; sai com 1 se houver algum. O CI roda em `core/` e `ui/` | `python3 tools/gd_warnings.py <godot> [pastas ou .gd]` (padrão `core ui`) |
| ✅ `tools/run_tests.sh` | Correr os testes localmente | `tools/run_tests.sh "<caminho do Godot console>"` |
| ✅ `.gitattributes` + `.editorconfig` | Fim dos avisos CRLF/LF; tabs em GDScript em todos os editores | raiz |
| ✅ **Kenney Pirate Kit** (CC0) | Cenário da Praia | `assets/models/kenney_pirate/` |
| ✅ Godot headless pelo terminal | O Claude e os terminais correm cenas e leem erros | `Godot_v4.3-stable_win64_console.exe --headless --path .` |

Correr os testes no Windows (Git Bash):

```
tools/run_tests.sh "/c/Users/felip/Downloads/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe"
```

## 2. Addons do Godot recomendados (instalar quando forem precisos)

| Addon | Para quê no ScanDig | Nota |
| :--- | :--- | :--- |
| **Beehave** (MIT, GDScript puro) | IA dos chefes e inimigos com behavior trees | Bom para o Caranguejo-Rei |
| **LimboAI** (MIT) | Alternativa compilada a Beehave (state machines + BT) | Mais rápido, mas é GDExtension — escolher um dos dois |
| **netfox** (MIT) | Sincronização de rede/rollback para o coop | Decisão do Dev B (dono do `core/network_manager.gd`) |
| **GodotSteam** | Lobbies, conquistas e coop pela Steam | Quando houver página na Steam |
| **Proton Scatter** (MIT) | Espalhar palmeiras, pedras e relva por pincel | Versão 4.0 testada até 4.2; testar no 4.3 antes |
| **Terrain3D** | Terreno esculpido para os mapas grandes (Ruínas, Cratera) | GDExtension; usar a versão para 4.3 |
| **Phantom Camera** | Câmaras de cutscene/apresentação do chefe | Opcional |
| **Dialogic 2** | Diálogos com NPCs e quests | Para o sistema de missões |
| **Debug Draw 3D** | Desenhar raios, áreas e caminhos de IA em debug | Útil para os caranguejos |
| **Godot Jolt** | Física mais estável (torrões, itens a saltar) | No Godot 4.4+ o Jolt já vem incluído |

Instalar: no editor, separador **AssetLib** → procurar → Download → Install; ou copiar a pasta
`addons/<nome>` de um release do GitHub e ativar em *Project → Project Settings → Plugins*.

## 3. Aplicações

| App | Para quê | Grátis? |
| :--- | :--- | :--- |
| **Blender** | Modelar e animar (mãos, caranguejo, chefes). O Godot 4 importa `.blend` diretamente se o Blender estiver instalado | Sim |
| **Blockbench** | Modelação low-poly rápida, muito mais simples que o Blender — ótimo para itens e ferramentas | Sim |
| **Mixamo** (Adobe) | Animações prontas de personagens humanoides | Sim (conta Adobe) |
| **Material Maker** | Materiais/texturas procedurais, feito em Godot | Sim |
| **Figma** (já tens Pro) | HUD, loja, museu, ícones dos itens, arte da Steam | — |
| **Krita** | Pintura 2D, ícones e texturas | Sim |
| **Audacity** | Editar efeitos sonoros | Sim |
| **jsfxr / ChipTone** (web) | Gerar efeitos sonoros (ping do radar, pá, pinçadas) | Sim |
| **VS Code + godot-tools** | Editor de código com autocompletar e debugger do Godot | Sim |
| **gdtoolkit** (`pip install "gdtoolkit==4.*"`) | `gdformat` e `gdlint` para GDScript | Sim |

## 4. Sites de assets

| Site | O que tem | Licença |
| :--- | :--- | :--- |
| kenney.nl | Kits 3D low-poly, UI, áudio, fontes | CC0 |
| kaylousberg.itch.io (KayKit) | Personagens, masmorras, ferramentas, estilo cartoon | Muitos CC0 |
| quaternius.com | Animais, monstros e personagens **animados** | CC0 |
| poly.pizza | Pesquisa em milhares de modelos low-poly | CC0 ou CC-BY (ver cada um) |
| ambientcg.com | Texturas PBR | CC0 |
| polyhaven.com | HDRIs (céus), texturas e modelos | CC0 |
| freesound.org | Efeitos sonoros | CC0/CC-BY (ver cada um) |
| opengameart.org | Música, sons, sprites | Vários |
| game-icons.net | Ícones de itens/habilidades | CC-BY |
| fonts.google.com | Fontes para a UI | OFL |

Regra do projeto: preferir **CC0**; qualquer asset CC-BY precisa de crédito num ficheiro
`CREDITS.md`. Guardar sempre o `License.txt` junto do pacote em `assets/`.

## 5. Repositórios e aprendizagem

- **godotengine/awesome-godot** — lista oficial da comunidade com addons, demos e ferramentas.
- **godotengine/godot-demo-projects** — demos oficiais (3D, rede, física, shaders).
- **GDQuest** (gdquest.com) — tutoriais e projetos abertos de qualidade para Godot 4.
- **Godot Shaders** (godotshaders.com) — shaders prontos (água estilizada, contornos, vento nas palmeiras).
- Documentação oficial: docs.godotengine.org (versão 4.3).

## 6. Integração com IA (Claude Code)

- Hoje: os terminais correm o Godot em headless, leem erros, tiram capturas e correm os testes GUT.
- Existem servidores MCP para Godot (ex.: *godot-mcp-pilot*, *godot-test-mcp*) que dão ao
  Claude ferramentas diretas de "correr o projeto e ler erros". Ainda não foram avaliados
  quanto a segurança e manutenção — não estão instalados.
