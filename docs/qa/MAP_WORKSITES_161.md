# Composição interna dos mapas — #161

Passe cosmético da direção aprovada na auditoria #158. Integração e capturas atuais pelo MCP Godot 4.3, em 21/10/2026. Codex integrou; Bússola preparou Praia/Campo; Farol preparou os três mapas regionais; Antigravity #2 coordenou Sonda e Broca. Issue: https://github.com/Felipefmdev/ScanDig/issues/161.

## Composição

| Mapa | Conjuntos em X/Z | Preservação |
| --- | --- | --- |
| Praia | Apoio com tecido junto ao posto (10.8,-3.8); madeira em reparo (13.5,1); estrado vazio de secagem (23,-0.4) | Mar +X, maré, conchas, arena e acessos ao cais. O reparo foi recuado da proposta (14,4), que invadia o corredor. |
| Campo | Bancada rural (-10.5,11.5); reserva de madeira (-10,-3.7); feixe de palha (8,-20) | Árvore reativa, fardos existentes, sino, poço e vista torre–círculo. Quintal recuado para evitar árvore/fardos. Folga conservadora da cerca junto à palha ≥0.10 m, verificada por Bússola em código e imagem. |
| Ruínas | Bancada de estudo/prancheta sem escrita e bolsa (8.2,-2.5); pedras examinadas (-18,10.5) | Inês, templo, cripta, placas e arenas. |
| Geleira | Lenheiro lateral à cabana (-16.15,9.59); provisões (-19.5,8) | Porta local -Z, Björn, fogueira e pinheiros. Nenhum marcador novo sobre gelo fino. |
| Cratera | Painel técnico fosco aderente à parede oeste do módulo (~-15.7,10.7); caixas junto a Beta (-8.5,-24) e Gama (-23,-4) | Estação, antenas/enigma, rotas e arenas. Sem tela luminosa, texto ou prompt novo. |

Modelagem com a gramática procedural existente de madeira, corda, palha, pedra e equipamentos. Referências de linguagem consultadas pelos autores: pescador_ze, dona_lurdes, arqueologa_ines, velho_bjorn e dra_vega. Não há JPG específico dos novos apoios; não são reproduções de novos itens colecionáveis.

## Contratos

`decoration_scatter.gd` adiciona `MapWorksites` em runtime. Cada mapa recebe uma malha/superfície com material ToonKit sRGB, sem sombras nem GI. Helpers `RefCounted` com `build()` estático, sem `class_name`; não há processamento por frame, colisores, owner, RPC, interativos ou alterações de loot, terreno e cenas. Geometria determinística, sem consumo do RNG global. Reconstrução remove o grupo antigo antes de reservar novamente seu nome.

A proteção automatizada de corredores usa larguras por rota: 3.6 m nos corredores de Praia/Campo; 3.2–3.6 m nas rotas regionais e 2 m na aproximação da porta da cabana. Não comprova largura universal de 3.6 m. O teste de rebuild cobre substituição de MapWorksites; não corrige nem valida o ciclo legado de AmbientLife/Backdrop, recriados apenas em `_ready()`.

Pés da Praia/Campo apoiados em cada canto pela altura analítica do terreno. Regionais conformados por vértice; o plano da estação tem teste específico de coplanaridade com a parede existente. Ruínas 360 triângulos, Geleira 564, Cratera 372, uma superfície cada. Orçamentos são verificados automaticamente; não foi realizado benchmark comparativo de frame time.

## Evidências locais

Todas as pastas abaixo ficam em `.bot_runs/`, ignoradas pelo git. Requests/results MCP e logs ficam ao lado. Capturas com janela, 1280×720, seed 161, posições/olhar registrados nos dumps. A mesma sequência e configuração foi usada nos pares. Variações de atores/itens ambientais não são tratadas como mudanças da malha.

| Mapa | Antes | Depois | Detalhes antes → depois |
| --- | --- | --- | --- |
| Praia | praia_161_before_2026-10-21_18-31-54 | praia_161_after_2026-10-21_18-44-10 | 18-33-27 → 18-44-27 |
| Campo | campo_161_before_2026-10-21_18-32-12 | campo_161_after_2026-10-21_18-44-54 | 18-33-41 → 18-45-20 |
| Ruínas | ruinas_161_before_2026-10-21_18-32-34 | ruinas_161_after_2026-10-21_18-48-35 | 18-41-38 → 18-48-53 |
| Geleira | geleira_161_before_2026-10-21_18-32-51 | geleira_161_after_2026-10-21_18-49-05 | 18-41-56 → 18-49-22 |
| Cratera | cratera_161_before_2026-10-21_18-33-08 | cratera_161_after_2026-10-21_18-49-37 | 18-42-10 → 18-49-55 |

Prefixos dos detalhes: `<mapa>_161_detailbefore_2026-10-21_` e `detailafter`. Todos esses tours são teleportados: servem para comparação visual estática, não para provar acessibilidade. Os enquadramentos originais de quintal/reparo foram mantidos mesmo após recuar os conjuntos.

`walk161.gd`, lançado pelo MCP, usa entrada real de movimento e interrompe no primeiro alvo não alcançado; não contém salto nem fallback de teleporte. `walk161_praia.json`: spawn → (0,4) → (7,5) → (12,7) → (18,12), quatro alvos alcançados. `walk161_campo.json`: spawn → (0,4) → (-2.5,6.5) → (-5,5) → (-7,1) → (-6,-2), cinco alvos alcançados. Logs e PNG finais ao lado. São amostras de rotas, sem auditoria integral de perímetro/coop.

## Verificação

- RED integração antes da fonte: `161_integration_red.log`, 2 testes falhando pela ausência de MapWorksites.
- RED Praia/Campo: `worksites_161_red.log`, 6 falhas esperadas por builders ausentes e 1 calibração passando; GREEN 7/7, 7245 asserts.
- RED regional válido: `regional_worksites_161_red_valid.log`, 0/5, gerador ausente. A tentativa anterior teve API Color incompatível e não conta. RED adicional de CUSTOM0: `regional_worksites_161_outline_red.log`; corrigido com ToonKit.commit.
- GREEN integrado em produção, janela OpenGL: `161_integrated_green.log`, 3 scripts, 14/14 testes, 7377 asserts, exit 0, sem ERROR/WARNING. Inclui suporte, corredores/triângulos, clareiras/objetivos, determinismo, orçamento, outline, painel, pines/porta, owner/colisão e rebuild sem alteração de RNG.

- GUT completo via `tools/run_tests.sh`: `161_gut_final.log`, 145 scripts, 918 testes, 917 passando e 1 pendente por exigir renderer real, 17567 asserts, exit 0. O log contém mensagens `mesh_get_surface_count` do renderer dummy e avisos ObjectDB/recursos na saída, já presentes nas verificações anteriores; não é um log limpo.

- Headless completo via `tools/run_headless_tests.sh`: `161_headless_final.log`, 48 verificações passando (36 avulsas e 12 resultados de peers), `HEADLESS OK`, exit 0. Inclui pares de rede funcionais; não equivale a inspeção visual dos novos conjuntos em partida coop.

Pareceres visuais independentes de Bússola e Farol favoráveis; revisão cruzada de lifecycle/factory/regional por Bússola sem bloqueador. Limitações dos testes registradas acima. Aceite visual diurno não cobre cintilação em movimento, noite/clima completo ou reconhecimento humano em coop.
