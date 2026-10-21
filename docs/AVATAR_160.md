# Explorador remoto — #160

Primeira fatia da direção de personagem da auditoria #158: corpo facetado/toon, rosto,
chapéu, botas, roupa com bolso/remendos e bolsa de achados. As cores de peer mantêm o
mapeamento anterior e ganham uma a quatro barras claras para identificação além da cor.

Ferramentas remotas reutilizam os modelos existentes. As mãos locais são desativadas antes
de entrar na árvore. O cache é criado sob demanda, reutiliza cada ID visitado e não refaz
geometria quando `Player` repete `set_tool` a cada frame. IDs desconhecidos ficam ocultos.
Ao cair, a ferramenta some; ao reviver, a atual reaparece mesmo se trocada durante a queda.

Preservados os métodos públicos, limites de cabeça/cintura, pivô do pescoço, rotação/altura
original do estado caído, identificação, cápsula e rede. Só há nós cosméticos. Esta entrega
não implementa marcha articulada, golpes remotos novos nem personalização completa.

## Revisão e evidências

- Aplicação MCP com SHA esperado: `.bot_runs/avatar160_final_{request,result}.json`.
- Baseline atual: `avatar160_before_three_views.png` e `avatar160_before_tool_*.png`.
- Após revisão: `avatar160_checked_three_views.png`, `checked_four_peers.png`,
  `checked_tool_*.png`, `checked_side_*.png`, `checked_pitch.png`,
  `checked_downed.png` e `checked_downed_ground.png`, todos em `.bot_runs/`.
- Pá reduzida para 76% e alinhada pela travessa do punho, sem ponta abaixo do chão em pé.
  Kit alinhado pela alça e cruz voltada para a frente. Corrigidos após revisão da Bússola.
- RED inicial `avatar_160_red.log`: cinco testes falhando. GREEN inicial: cinco/255 asserts.
- RED das pegas `avatar160_grips_red.log`: três asserts falhando. GREEN final
  `avatar160_grips_green.log`: seis testes/262 asserts. Inclui alinhamento e apoio da pá.
- Integração renderizada compartilhada: 64 testes/714 asserts passando; erros legados
  de acessibilidade comparados com baseline, conforme `RADAR_159.md`.
- O primeiro GUT completo identificou os nomes internos Legs/Arms no scanner de tradução.
  Foram marcados como StringName, sem alterar o scanner. A repetição direcionada de avatar,
  pitch e catálogo de traduções passou 18 testes/1398 asserts (`160_nodeids_green_final.log`).
- GUT completo final: `159_160_gut_final.log`, 904 testes, 903 passando, uma pendência
  já conhecida de MultiMesh dummy, 10190 asserts e exit 0, com avisos/erros legados no log.
- Headless final: `159_160_headless_final.log`, `HEADLESS OK`, exit 0, incluindo os pares
  de rede. A suíte funcional de rede não equivale a uma revisão visual cooperativa.

As montras comprovam vistas estáticas e contratos testados, não marcha ou animação completa.
O contato do chapéu no estado caído continua dependente da pose legada; não foi alterada
a altura do avatar caído para acomodar a arte. Pareceres finais ficam registrados na issue;
não se reivindica auditoria de performance ou coop visual completo.
