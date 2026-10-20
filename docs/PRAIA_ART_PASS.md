# Praia: passe de arte e correções visuais (#150)

## Resultado

- Posto de exploração com cobertura de lona, bancada de triagem e marco de retorno.
- Acesso ao cais indicado por cordas baixas e um marco de pano laranja.
- Entrada da arena enquadrada por dois marcos, com o raio de combate livre.
- Novos grupos de palmeiras e moitas, com manchas de vegetação na areia.
- Lanternas quentes no posto e no acesso ao cais.
- Rochas de borda baixas e irregulares, apoiadas no terreno. Antes, o raycast
  acertava o topo de Bounds e colocava parte delas a 5,5 m de altura.
- Barris, caixas e garrafas costeiras apoiados no relevo, preservando os offsets
  de objetos deitados e da pilha de caixas.
- Uma superfície animada de mar até o horizonte, acompanhando a maré e sem a
  emenda entre dois materiais/níveis de água. Reflexos discretos na superfície.
- Corredores e áreas dos interativos livres da decoração espalhada.

As alterações dos scripts compartilhados estão condicionadas ao tema Praia.
O relevo físico e os pontos de missão permanecem iguais. Os novos troncos e
a bancada têm colisão. O mapa passou de 228 para 229 nós serializados, com
as 188 transforms originais preservadas; a decoração adicional é gerada em
execução, sem owner. O PRE/POST_SAVE restaura recursos/transforms originais
durante o empacotamento, inclusive com a cena fora da árvore.

## Evidências locais

Capturas Vulkan/Forward+, em janela de 1280×720:

- Antes: `.bot_runs/art_praia_2026-10-20_10-31-21/`.
- Comparação diurna intermediária: `.bot_runs/art_praia_2026-10-20_10-37-38/`.
- Noite e maré baixa: `.bot_runs/art_praia_polish_2026-10-20_10-39-16/`.
- Interativos de perto: `.bot_runs/praia_secrets_tour_2026-10-20_10-38-51/`.
- Capturas finais: `.bot_runs/art_praia_2026-10-20_10-44-29/`; os seis nomes e
  posições de câmera são os mesmos da captura anterior à mudança.

`01_base_banca`, `02_palmeiras`, `03_naufragio`, `04_barco_doca`,
`05_vista_geral` e `06_altar` permitem comparar os mesmos enquadramentos.

## Validação

- Dois testes de regressão em `test_beach_visual_support.gd` falharam antes
  das correções: apoio das rochas em Bounds e adereços costeiros flutuantes.
- Após corrigir também o empacotamento, os cinco arquivos de teste focados
  passaram: 16 testes, 536 asserts. Incluem apoio no terreno, save limpo,
  backdrop e decoração dos diferentes temas.
- Passeio diurno: 25 passos, zero erros.
- Passeio noturno e maré baixa: 19 passos, zero erros.
- Passeio pelos segredos: 25 passos, zero erros.
- Missão e segredos em `praia_quest_solo`, renderizado: 77 passos, zero erros.
- Exploração de 902,6 segundos de jogo em `pacing_praia`, headless: 54 spots
  cavados, 27 viagens de entrega, nenhuma morte e nenhum teleporte de
  recuperação. O roteiro registrou quatro capturas ignoradas por estar sem
  renderer e encerrou o loop pelo limite de tempo; não é um resultado de
  balanceamento nem uma comparação controlada de economia.

Suíte completa: 138 scripts, 903/903 testes e 9731 asserts aprovados.
Headless: 36 avulsos e os cinco grupos de pares de rede aprovados, `HEADLESS OK`.
Os logs ainda contêm os avisos conhecidos do renderer dummy e de recursos ao
encerrar o GUT; não houve `SCRIPT ERROR` ou `Parse Error`.

Logs de desenvolvimento em `C:/tmp/praia-150-*.log`, especialmente
`praia-150-gut-verified.log`, `praia-150-headless.log` e
`praia-150-quest-render.log`. Logs individuais do headless em `/tmp/tmp.D1mp2M6mUI`
no Git Bash. Revisões estáticas por Farol e Bússola não identificaram
bloqueadores após os ajustes.

## Reprodução

```powershell
& 'C:\Program Files\Git\bin\bash.exe' tools/run_bot.sh '<godot-console>' tools/bot/art_praia.json
& 'C:\Program Files\Git\bin\bash.exe' tools/run_bot.sh '<godot-console>' tools/bot/art_praia_polish.json
& 'C:\Program Files\Git\bin\bash.exe' tools/run_bot.sh '<godot-console>' tools/bot/praia_secrets_tour.json
& 'C:\Program Files\Git\bin\bash.exe' tools/run_tests.sh '<godot-console>'
& 'C:\Program Files\Git\bin\bash.exe' tools/run_headless_tests.sh '<godot-console>'
```
