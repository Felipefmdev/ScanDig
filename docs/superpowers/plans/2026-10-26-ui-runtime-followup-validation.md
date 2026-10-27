# #199 — validação das regressões de interface

Base: `main` em `303ea94`. Responsável: Codex/Root. Revisões read-only: Farol e Bússola, engineOFF. A #180 já estava fechada e suas PRs integradas; este acompanhamento preserva a UI compacta atual.

## Alteração e gatilhos

- R3 abre a inspeção por padrão. Um binding antigo explícito em R3 mantém prioridade; `none` e remapeamentos explícitos continuam válidos, sem dupla ação.
- A ficha usa o rótulo do dispositivo ativo e atualiza enquanto aberta após troca teclado/comando ou remapeamento de `controls_pad`. A conexão do jogador local acontece no ready, independentemente das dicas.
- Clique na aba seguido de Tab/Shift+Tab mantém foco visível e volta à barra. A cadeia inclui a página atual e TabBar, inclusive página vazia; Loja continua oculta. O auditor drena a restauração de abas antes da próxima aresta.
- Hotbar, ficha, conquistas e metadados dos slots usam piso nominal de 15px onde necessário. Diário quebra linhas em vez de reduzir até 10px. A medida efetiva é feita no runtime, não deduzida apenas do tamanho nominal.
- Duas chaves traduzem as abas de rede: `Online (código)` / `Online (code)` e `Rede local (IP)` / `Local network (IP)`. Os recursos de tradução foram reimportados.

Não foram reaplicadas as cenas, o tema ou a composição da árvore local antiga. O checkpoint integral anterior permanece no stash identificado e em `.bot_runs/180_pre_main_refresh26.json`; as evidências #180 anteriores são históricas.

## RED e regressões dirigidas

`199_main_RED26`: cinco casos, 489 asserts, nenhum passou; exit1, native0/warnings0. Há falhas de foco e rótulo, e os casos de abertura R3 também falham no setup por ausência de binding: não se atribui cada falha a texto desatualizado.

`199_main_GREEN26`: quatro suítes,20 testes e 609 asserts, exit0/native0/warnings0. Os testes oficiais usam Base/Player/Inventory reais e eventos sintéticos via Input.parse_input_event; não emitem sinais de UI nem chamam refresh manual para produzir o resultado.

## Capturas atuais

| Família | Bateria | Passaram | Limite de monitor | PNGs | Menor fonte efetiva |
|---|---|---:|---:|---:|---:|
| Menus |199_core_matrix26_20261026_233052_367623|8|4|192|16,374px|
| Mundo |199_world_matrix26_20261026_233455_745876|8|4|112|16,667px|
| Rede |199_network_matrix26_20261026_233727_256392|8|4|24|20px|

As combinações executáveis são PT720/1080×teclado/comando/mouse e EN720/1080×teclado. São 328 PNGs, com SHA256 e IHDR conferidos; os hashes dos arquivos monitorados coincidem. Rollup: `.bot_runs/199_final_render_rollup26.json`.

Os runners renderizados não registraram erros nativos. Foram preservados12 avisos em Menus (inclui quatro tentativas sem capacidade),24 em Mundo e 0 em Rede. Isto não significa logs globais limpos.

Bússola revisou oito capturas atuais: slots/PT720, pausa/EN720, Base/Diário/EN720, ficha/R3 em720/1080 e rede Online/LAN EN720. Sem bloqueador visual na amostra; textos e layout compacto confirmados. Descrição quebrando `0.8`/`s.` é detalhe tipográfico, não truncamento. Listas parcialmente visíveis continuam sujeitas a rolagem; a amostra não valida todos os conteúdos ocultos.

## Verificações finais

Bateria final `199_finalgates26.json`: todos os exits0. GUT:203 scripts,1196 testes,1186 passaram e10 ficaram pendentes por requisitos de renderer,27130 asserts. HEADLESS OK; renderer7/7 e315 asserts; LSP0 diagnósticos em99 arquivos core/ui; diff-check0. Os logs completos preservam diagnósticos históricos do modo headless, casos negativos e recursos pendentes; não se alega full nativo limpo. Auditoria de contraste:14 pares, 0 falhas; o texto desativado mantém o critério de3:1 adotado na main atual.

Comandos reproduzíveis no checkout:

```powershell
& '<godot4.3_console>' --headless --path . -s addons/gut/gut_cmdln.gd -gexit
& 'C:/Program Files/Git/bin/bash.exe' tools/run_headless_tests.sh '<godot4.3_console>'
python tools/ui_contrast_audit.py --strict
```

## Limites

Comando é sintético; não certifica hardware. Capturas720/1080 usam janela/viewport reais;2560x1080 foi reprovado como capability_fail antes de capturar estados, por falta de monitor adequado. Testes headless de layout não substituem essa prova física. O ensaio humano de cinco segundos ainda não tem respostas reais, e a prévia de navegador não foi validada. Nenhum desses limites é ocultado como aceite geral da #180.

A preparação de rolagem do fixture é declarada setup; não prova uso da roda. A compra do item no ensaio do mundo é estímulo público do broker, não input de compra de ferramenta; entrega, ID, débito e replay são verificados separadamente. A UI de rede não executa Host/Join e suspende apenas callbacks de persistência de nome da instância de ensaio, com sentinela de disco.
Ensaio humano opcional preparado em `.bot_runs/199_human_5s26.html`:82 imagens/PT41 eEN41, sem respostas produzidas. Hash do HTML799990ee8f6396f65be1fc319e6fa2e101b184ab131f3347e88515369325488b. Sintaxe JavaScript conferida com node --check; isso não valida o navegador nem cria aceite humano.
