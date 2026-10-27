# #186 — Passagens e comércio no mundo: Implementation Plan

> **For agentic workers:** Use executing-plans para integração root e tarefas independentes nos ajudantes Maestri existentes. Etapas usam checkbox para registrar execução.

**Goal:** Avançar por passagens permanentes abertas com a chave do chefe e comprar melhorias nas bancas, com bordas visualmente abertas.

**Architecture:** `defeated_bosses` fornece credencial; `unlocked_maps` registra uso permanente da passagem. A transição coordenada preserva payload owner-local e a loja contextual delega economia ao host.

**Tech Stack:** Godot 4.3 Standard Forward+, GDScript tipado, GUT, MCP Godot.

**Spec:** `docs/superpowers/specs/2026-10-24-boss-passages-design.md`.

## Global Constraints

- Checkout exclusivo `C:/Users/felip/.codex/worktrees/365a/scandig`, branch `codex/boss-passages-186`, base `b5b73b1`; não alterar PR185 nem shared.
- `.gd`/`.py` UTF-8 sem BOM e LF; autoridade host; sender capturado antes de deferir RPC.
- Somente root inicia engine. Não interferir no Godot do usuário. Sem novos provedores/instalações.
- Save v6, nenhum campo redundante de chaves, nenhum reembolso; Lua só pelo foguete.
- Não commitar etapas parciais: regra local exige um commit por issue, GUT e headless antes dele.

## 1. Progressão e migração — Codex, testes Farol

Arquivos: `core/game_state.gd`, `core/session_manager.gd`, `tests/unit/test_boss_passage_progression.gd` e `tests/unit/test_boss_passage_save.gd`. Estender a tabela canônica existente `MAP_UNLOCK_BOSSES` com `source_map` e `item_id`, sem criar outra tabela redundante.

- [ ] Rodar importação e baseline GUT/headless no isolado; guardar logs `.bot_runs/186_*`.
- [ ] Farol congela testes existentes de acesso/endpoint legado e matriz E1..E4; root executa RED.
- [ ] Tabela canônica de quatro ligações, com recibo fixo nos dois sentidos:

```gdscript
const MAP_UNLOCK_BOSSES: Dictionary = {
    "campo": {"source_map": "praia", "boss_id": "king_crab", "boss_name": "Caranguejo-Rei", "item_id": "coroa_caranguejo_rei"},
    "ruinas": {"source_map": "campo", "boss_id": "giant_mole", "boss_name": "Toupeira Gigante", "item_id": "garra_toupeira"},
    "geleira": {"source_map": "ruinas", "boss_id": "ancient_guardian", "boss_name": "Guardião Ancestral", "item_id": "nucleo_guardiao"},
    "cratera": {"source_map": "geleira", "boss_id": "frozen_mammoth", "boss_name": "Mamute Congelado", "item_id": "dente_mamute"},
}
```

- [ ] `is_map_unlocked` concede Praia explicitamente, Lua por quest, demais terrestres por recibo; não derivar abertura de custo zero/derrota.
- [ ] Endpoint legado responde recusa sem débito/abertura. `can_start_map` mantém cena/abertura e remove requisito de detector terrestre. Reconciliar `get_map_status` e UI de revisão para não continuar exibindo detector como bloqueio.
- [ ] GREEN da suite nova; executar regressões progressão/save/lunar e atualizar testes antigos cujo contrato foi substituído, sem remover cobertura de autoridade.

## 2. Troféu da Toupeira — Bússola, execução root

Arquivos: `gameplay/enemies/boss/giant_mole.gd`, `tests/unit/test_giant_mole_trophy.gd`.

- [ ] Congelar teste do caminho real de morte/drop; root executa RED.
- [ ] Usar o padrão host-only de `QuestRewards.drop_item`, ID `garra_toupeira`, uma vez na resolução real da morte. A credencial independe da coleta.
- [ ] Root executa GREEN e suite de boss/Toupeira; conferir ausência de drop duplicado e preservação do report.

## 3. Interação canônica e save de abertura — Codex + Bússola

Arquivos novos: `gameplay/environment/boss_passage.gd`, `tests/unit/test_boss_passage.gd`. Core: GameState e Session somente Codex.

- [ ] Testes antes da fonte: ator ausente/morto/unready, sender remoto, mapa errado, 2,5 m, LOS, item forjado, quatro gates, retorno usa mesmo recibo, save falho/retry e pedidos repetidos.
- [ ] `BossPassage` deriva de Interactable, exporta `route_id`/`source_map`; destino deriva da tabela. Host resolve a instância pertencente à cena; não aceitar NodePath arbitrário como credencial.
- [ ] Primeiro E apenas abre; sem chave informa boss/item; com chave host adiciona recibo tentativo, `save_game(state)`, remove apenas recibo em erro, publica apenas depois de OK. Não yield na seção de commit do save.
- [ ] Testar reload do arquivo real em testdir e snapshot de peer; confirmar saldo inalterado e nenhum replay de derrota/vitória.

## 4. Viagem genérica coordenada — Codex

Arquivos: `core/session_manager.gd`, `gameplay/player/players_root.gd`, novo `tests/unit/test_biome_transition.gd` e fixture ENet offline prefixo186.

- [ ] Testar ida/volta com payload não vazio, dano/cura após ACK, downed/drop, captura/consumo únicos, cancelamento por roster e timeout10s.
- [ ] Generalizar destino/âncora do mecanismo atual mantendo APIs públicas rocket como adaptadores; autorização lunar segue no station. Entrada por passagem exige recibo, grupoR5/ameaçaR8 e todos vivos/ready.
- [ ] Preservar um dia/início/resumo, preferência noite e clima local. Spawn normal usa âncora com offsets, não teleport pós-spawn. Gate #173 preservado.
- [ ] Testar erro de cena e ready30s: operação de recuperação retém payload pendente em memória, não reutiliza retorno que o descarta; bloqueia recaptura até consumo. Testar late join retido durante COMMITTING.
- [ ] Root executa ENet real e examina logs nativos estritos, sem whitelist; repetir regressões foguete/dano #120.

## 5. Comércio físico — Codex, gameplay Bússola após interface acordada

Arquivos novos: `ui/world_upgrade_shop.gd/.tscn`, `gameplay/environment/upgrade_counter.gd`, `tests/unit/test_world_upgrade_shop.gd`; modificar `core/game_state.gd`, `ui/base_station_ui.gd/.tscn`, `gameplay/player/player.gd`, `items/shop_offer.gd`.

- [ ] RED: compra sem banca/range/LOS recusada, quatro melhorias, saldo/requisito/nível, modal bloqueia input mas não dano/rede, fecha em morte/downed/troca/afastamento.
- [ ] Extrair somente linhas comerciais e feedback. Todas bancas têm quatro melhorias; ferramentas mantêm sortimento local. Remover página LojaBase e validar também chamada direta dos endpoints antigos de compra.
- [ ] Definir correlação de transação por peer/sessão e sequência: host guarda resultado da request, repetições devolvem resultado sem novo débito; grant de ferramenta usa identidade de transação e deduplicação no dono. Não confundir isso com nova chave de progressão.
- [ ] RED/GREEN de resposta tardia, mochila cheia e desconexão; não anunciar entrega comprovada antes de recebimento. Sem garantia nova de persistência de inventário contra encerramento de processo.
- [ ] QA 720p/1080p, teclado/comando, troca idioma, saldo compartilhado e concorrência ENet.

## 6. Mundo e amostra Campo — Codex via MCP, revisão ajudantes

Arquivos: cinco `world/map_*.tscn` terrestres; terrain/scatter/backdrop/surroundings só com recorte identificado. Lua em revisão própria, sem alterar PR185.

- [ ] Capturar estado atual MCP/renderizado e contar nós/transforms antes de editar. Inspecionar quests/segredos e selecionar endpoints/âncoras fora de arena/serviço; corredor3m, reuniãoR5/ameaçaR8.
- [ ] Aplicar primeiro ligação Praia↔Campo via MCP, com E deliberado e barreiras adjacentes coerentes; testar ida/volta e chegada sem ping-pong. Depois outras três ligações e bancas.
- [ ] Amostra Campo trata em conjunto terreno, `Deco_border`, backdrop e apoios. Reduzir fechamento e abrir setores de céu sem muro de árvores ou colisão invisível em caminho aparente.
- [ ] Capturas comparáveis na altura do Player, cantos/saltos/knockback/queda/LOS/segredos/rotas com controller real; revisar visualmente antes de propagar direção aos demais biomas.

## 7. Entrega

- [ ] Atualizar GDD/arquitetura/rede/pacing e traduções para progressão/lojas reais, sem inventar tempos econômicos.
- [ ] Revisão independente de diff e escopo; GUT completo + headless; guardar evidência e limites na issue186.
- [ ] Conferir diff --check, staging explícito, um commit `Closes #186`, publicar branch e PR dependente da base120 sem incorporar UI180.
