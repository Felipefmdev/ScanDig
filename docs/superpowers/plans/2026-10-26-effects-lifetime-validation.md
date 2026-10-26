# #188 — Ciclo de vida de efeitos e luzes

Correções isoladas após a auditoria nativa da #186. Codex executou e integrou; Farol revisou NightFx e Bússola revisou chefes/fixture. Checkout exclusivo `365a`, sobre a #177; nenhum arquivo pendente do main ou da PR185 foi incorporado.

## Causas reproduzidas

- `NightFx._free_lights`: após o Player liberar seus filhos, a iteração tipada convertia a referência liberada antes do guard. Agora itera Variant, valida e só então converte para Node. Mantém remoção/queue_free dos filhos vivos e limpeza dos três campos.
- Eco e Mamute: criavam o efeito com `top_level`, atribuíam posição global e só depois adicionavam à árvore. A adição agora precede a atribuição. Mesh, material, registro, dano, knockback, movimento, thresholds e timers permanecem iguais. As posições do baseline já coincidiam; esta correção elimina acesso inválido à árvore, sem alegar deslocamento corrigido.
- Fixture de pedidos: o Player também recebia posição global fora da árvore. O novo teste com parent traduzido reproduziu `(39,8,-15)` em vez de `(22,5,-4)`. A fixture agora adiciona antes de posicionar, preservando os asserts de autoridade, alcance, dano e rate limit.

## RED/GREEN e limites

Evidências em `.bot_runs/`, com stdout/stderr separados e watchdogs externos:

| Recorte | RED | GREEN |
|---|---|---|
| NightFx real | `188_night_RED26`: 3/3 e 135 asserts, mas par TypedArray nativo | `188_night_GREEN26`: 6/6, 147 asserts incluindo suite original, saída zero, sem erros/warnings |
| Ataques reais | `188_boss_RED26_r2`: 4/4, 83 asserts, mas nove erros `!is_inside_tree` | Incluído na regressão abaixo, sem erro nativo |
| Fixture de pedidos | `188_fixture_RED26`: falha de posição e nove erros nativos (incluindo o novo caso) | Incluído na regressão abaixo, sem erro nativo |
| Sete suites dirigidas | Logs RED anteriores preservados | `188_targeted_GREEN26`: 66/66, 457 asserts, saída zero, zero erros nativos; sete warnings QuestRewards e um ObjectDB preservados |

A primeira versão do repro dos chefes usava tolerância float em asserts Vector3 e ignorava o deslocamento Y de entrada EMERGE do Mamute. Esses erros da fixture foram corrigidos antes de alterar produção; `188_boss_RED26` fica como diagnóstico de fixture, não como prova de deslocamento do jogo. O RED válido é o sufixo `r2`.

Os ensaios usam scripts/cenas e timers reais, com stepping unitário declarado dos ataques e observador de dano. Não comprovam luta natural, coop, estética ou causa dos objetos órfãos. Os marcadores ajudam a localizar fronteiras, mas stdout/stderr separados não garantem ordenação temporal exata entre streams. Nenhum erro é removido por whitelist.

## Gate completo

GUT: 201 scripts, 1190 testes, 1180 passaram e dez ficaram pending por renderer, 26630 asserts, sem falhas. A busca no log final encontrou zero ocorrências de `!is_inside_tree` e do erro de referência inválida em TypedArray. Headless terminou com `HEADLESS OK`, incluindo pares de rede.

O renderer dummy, os testes negativos intencionais e os avisos de objetos/recursos na saída continuam registrados; não há alegação de log nativo global limpo. Comandos e códigos finais em `188_finalgates26.ps1`, `188_finalgates26.json` e logs correspondentes. As suites que exigem renderer são verificadas separadamente.

Todos os cinco códigos do gate completo retornaram zero; os dois scripts de iluminação passaram 7/7, 315 asserts, e o LSP core/UI ficou em zero diagnósticos/99 arquivos. A checagem adicional de cinco scripts (`188_extra_lsp26.log`) encontrou dois warnings preexistentes de parâmetro `delta` não usado em `_animate` do Mamute e `_process_sonic_ring` do Eco; esses métodos não foram alterados. Nenhum diagnóstico nos três testes verificados. Encoding e `git diff --check` conferidos.
