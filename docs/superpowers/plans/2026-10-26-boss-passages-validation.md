# #186 — Verificação da entrega

Responsável pela integração e execução: Codex. Revisão independente: Bússola e Farol. Antigravity #2 coordenou Sonda e Broca nas auditorias básicas. Checkout exclusivo `365a`, Godot 4.3; trabalhos do checkout principal e PR185 preservados.

## Comportamento entregue

- Quatro ligações terrestres usam a credencial do chefe e um recibo permanente em `unlocked_maps`. O primeiro uso abre e salva; o seguinte solicita viagem. Não há cobrança nem requisito de detector para abrir mapas terrestres. Lua continua exclusiva do foguete.
- Viagem coordenada preserva o payload do jogador, com validação de grupo, ameaça, prontidão e recuperação em memória. Essa recuperação não promete persistência contra encerramento do processo.
- Melhorias são compradas nas bancas físicas. Ferramentas usam pedido contextual correlacionado e entrega no inventário do dono; repetição não duplica débito nem concessão. Mochila cheia conserva a entrega pendente.
- Oito endpoints e cinco bancas foram integrados aos mapas. Abertura de horizonte preserva os interiores; postes compartilhados foram prolongados para apoiar no terreno e placas montadas no poste lateral.

## Evidências locais

Os logs e capturas abaixo ficam em `.bot_runs/`, fora do versionamento. RED e GREEN são mantidos separadamente.

| Recorte | Evidência | Resultado e alcance |
|---|---|---|
| Broker e `ShopOffer.try_buy` | `186_world_item_ledger_GREEN.log` e suites de comércio | 15 testes / 354 asserts na integração de compra; quatro suites, 43 testes / 968 asserts. Inclui resposta tardia e repetição. |
| Compra ENet | `item186_20261026_073949_675419/summary.json` | Host/guest reais, compra, replay e segunda compra; dois processos com saída zero, sem erro nativo. Oito warnings de âncora preservados. Atores posicionados pela fixture. Hashes de entrada inalterados. |
| Passagem ENet | `passage186_v2_20261026_073934_165702/summary.json` | Ida e volta Praia/Campo e payload na revisão final; dois processos com saída zero, sem erro nativo. Oito warnings de âncora preservados. Hashes de entrada inalterados. |
| Modal real | `186_visual_plan_26_batch_20261026_071029_881532/summary.json` e `186_visual_plan_26_batch_20261026_071147_185618/summary.json` | Quatro processos: teclado e joy sintético em janela real 1280×720 e 1920×1080. Compra única, foco, cancelamento, alcance, dano e downed; gates funcional e estrito passaram. |
| Caminhada real | `186_walk_batch26_20261026_071930_096544/summary.json` | Cinco mapas, oito aproximações com controlador do Player, foco, LOS, prompt e validação host. Cinco saídas zero, sem erros/warnings. Sem teleporte, cura ou resgate. Recibos abertos são precondição declarada da fixture. |
| Apoio e placas | `186_support26_before.json`, `186_support26_after.json`, `186_route_sites_after_38400/` | Medição analítica de 16 postes: maior vão +0,289713 m antes, −0,110287 m depois. Hashes dos cinco mapas mantidos durante essa correção do asset compartilhado. Oito fotos revisadas. |
| Lifetime diferido | `186_lifecycle_26_RED.log`, `186_lifecycle_26_GREEN.log` | Reproduzidos Node liberado no deferred de A11y e posição global do anel antes de entrar na árvore. Três testes / 32 asserts após correção, sem erro nativo. |
| Lifetime de partículas | `186_weather_lifetime26_RED.log`, `186_lifecycle26_combined_GREEN.log` | Timer real reproduziu captura de Node liberado. Callback estático com WeakRef conserva o prazo. Seis testes / 99 asserts combinados, sem erro nativo. |
| Fixtures nativas | `186_native26_regression.log` | Material real com uniform de flash e ready único do NPC: 25 testes / 301 asserts, sem erro nativo; aviso de objetos órfãos conservado. |
| Detector de scene save | `186_scene_save_probe_v2.gd` e suite oficial | Fallback de `rotation_degrees` quando radianos ausentes; mantém precedência, basis/XZ, conjuntos de nós e exceção Y imediata de GroundSnap. Cinco testes / 37 asserts. Hipótese de prefixo `./` refutada. |

## Limites de interpretação

Input de joy foi sintético, não certificação de hardware. Caminhada comprova aproximação aos endpoints, não viagem, combate, ENet ou aprovação estética integral. Fotografias desacopladas não contam como caminhada. Em uma foto das Ruínas, um tronco oculta parte do texto de aproximação; a composição não recebe aceite visual geral por essa evidência.

O GUT completo distingue asserts de diagnósticos nativos. O renderer dummy gera muitos diagnósticos de mesh, e ainda há erros de transform fora da árvore e TypedArray em testes legados. As correções de lifetime acima têm repros isolados; não há alegação de log nativo global limpo. Erros intencionais dos testes negativos de save/validação também permanecem registrados.

Gates finais concluídos em 26/10, todos com saída zero:

- GUT completo: 198 scripts, 1174 testes, 1172 passaram e dois dependentes de renderer ficaram pending; 26411 asserts, sem testes falhos ou SCRIPT/PARSE ERROR.
- Esses dois scripts no renderer: sete testes / 315 asserts, todos passaram.
- `tools/run_headless_tests.sh`: `HEADLESS OK`, incluindo pares de rede.
- LSP de `core/` e `ui/`: zero diagnósticos em 99 arquivos; quatro scripts de gameplay adicionais também verificados separadamente sem diagnóstico.
- `git diff --check`: sem problemas. `.gd` e `.py` alterados verificados sem BOM/CRLF.

Comandos e códigos de saída: `186_finalgates26.ps1`, `186_finalgates26.json` e logs `186_final_*26.log`. O teste congelado `test_world_item_purchase.gd` manteve SHA256 `7e6161251010478641d8d233ef40a488faeea30c13c71bce270517bbb0531927`.
