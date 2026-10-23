# Ferramentas — o que usar, para quê, e o que já está instalado

Estado a 23/10/2026. Binários grandes ficam **fora** do repositório; o que é livre e
pequeno pode ser descarregado para `docs/learning/_refs/` (ignorado pelo Git) com
`tools/fetch_study_refs.ps1`.

## 1. Já instalado / já no projeto

| Ferramenta | Onde | Para quê | Limite |
|---|---|---|---|
| Godot 4.3 Forward+ | `C:/Users/felip/Downloads/Godot_v4.3-stable_win64.exe/` | motor, editor, capturas | não migrar por causa de skills |
| Blender 4.5.15 LTS | `%USERPROFILE%/.codex/tools/map-production` (via `toolchain.json`) | modelar, kit, exportar GLB | API 4.5, não 5.2 |
| Terrain3D 1.0.0 | oficina (`workshop`), plugin | esculpir terreno | só entra na produção o que for exportado |
| ProtonScatter 4.0 | oficina | scatter visual | idem |
| Kenney Space Kit 2.0 | `assets/models/` | kit CC0 | estilo espacial, não serve a praia |
| Kenney Pirate/Nature | `assets/models/` | props do dia a dia | material toon por override |
| Godot MCP (koltyakov) | sessão local | inspeção/aplicação/capturas | lease de engine exclusivo |
| GUT | `addons/gut` | testes | headless |

Abre a oficina e o jogo por `./tools/map_production.ps1 -Tool Workshop|Game`.

## 2. A acrescentar (livres)

| Ferramenta | Licença | Para quê | Como |
|---|---|---|---|
| [Cyclops Level Builder](https://github.com/blackears/cyclopsLevelBuilder) | MIT | blockout dentro do editor, com medidas e colisão | addon na **oficina**, nunca no jogo |
| [TrenchBroom](https://trenchbroom.github.io/) + [tbloader](https://github.com/codecat/godot-tbloader) | GPL / MIT | arquitetura brush (Ruínas, interiores) | só se o kit modular não chegar |
| [PureRef](https://www.pureref.com/) | donativo | prancha de referências por mapa | instalar no sistema |
| [Figma](https://www.figma.com/) / [Penpot](https://penpot.app/) | free / MPL | maquetar ecrãs antes do tema | browser |
| [Krita](https://krita.org/) / [Aseprite](https://www.aseprite.org/) | GPL / pago | 9-slice, ícones, texturas | sistema |
| [Fontsource](https://fontsource.org/) / [Google Fonts](https://fonts.google.com/) | OFL | fontes com acentos | já usas Kalam/Patrick Hand |

**Cyclops — instalação segura**

1. Descarrega o zip da release para `docs/learning/_refs/tools/`.
2. Copia a pasta do addon para `%USERPROFILE%/.codex/tools/map-production/workshop/addons/`
   (a oficina), não para `res://addons/` do jogo.
3. Ativa o plugin na oficina e valida com uma cena de teste.
4. Produção recebe **malhas exportadas**, não a dependência do addon.

## 3. Referências web (não se instalam)

| Sítio | Para quê | Nota |
|---|---|---|
| [Level Design Book](https://book.leveldesignbook.com) | blockout, métricas, marcos | livro aberto; capítulos por tema |
| [Game UI Database](https://www.gameuidatabase.com) | procurar ecrãs por tipo | filtra por género/ecrã |
| [Interface In Game](https://interfaceingame.com) | HUD, menus, lojas | bom para comparar densidade |
| [HUDS+GUIS](https://hudsandguis.com) | HUD diegética | inspiração, não cópia |
| [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com) | mínimo de acessibilidade | checklist |
| [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/) | medir contraste | usa os valores da paleta |
| [Practical Typography](https://practicaltypography.com) | escala e hierarquia | gratuito |
| [Refactoring UI](https://www.refactoringui.com) | regras práticas de interface | pago, mas o resumo público serve |
| [GMTK](https://www.youtube.com/@GMTK) | análise de níveis | *Boss Keys*, *Design Club* |

## 4. Medição e QA

| Ferramenta | Para quê |
|---|---|
| `tools/map_layout_audit.py` | contar nós/transforms e medir âncoras dos mapas |
| `tools/ui_contrast_audit.py` | contraste WCAG dos pares da paleta |
| `tools/qa_visual_review.py` | galeria antes/depois com manifesto |
| Godot Movie Maker | capturas determinísticas, mesmo frame |
| OBS | sessões de playtest, voz e reação |
| `ui/ui_nav_audit.gd` | percurso de foco por teclado/comando |

## 5. Orçamento de tempo (sugestão)

- **1 h** — ler `LEVEL_DESIGN.md` + um capítulo do Level Design Book.
- **1 h** — ver 3 ecrãs no Game UI Database e escrever 3 regras por ecrã.
- **2 h** — instalar Cyclops na oficina e fazer um greybox de 20×20 m.
- **1 h** — correr o auditor nos 6 mapas e anotar as maiores distâncias.
- **2 h** — auditar um ecrã de UI a 720p/1080p com rato e comando.

## 6. Regras de aquisição

- Preferir **CC0/MIT/OFL**; registar licença e URL em `references.json`.
- Não descarregar livros pagos nem assets sem licença clara.
- Addons de editor ficam na oficina; o jogo só recebe recursos exportados.
- Nada de binários grandes no Git: `docs/learning/_refs/` está ignorado.
