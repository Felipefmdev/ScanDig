# Radar e explorador — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Melhorar leitura do radar e reconhecimento do explorador/ferramentas remotas.

**Architecture:** Farol prepara detector; Bússola prepara avatar. Cada um trabalha em staging exclusivo em `.bot_runs`, e Codex aplica os scripts pelo MCP Godot com SHA esperado. A cena e os contratos de gameplay continuam como estão. Antigravity #2 coordena Sonda e Broca nas verificações básicas, por determinação do Felipe.

**Tech Stack:** Godot 4.3, GDScript tipado, SurfaceTool/ToonKit, GUT, MCP stdio.

**Spec:** `docs/AUDITORIA_DESIGN_158.md`, seções 2 e 3; issues #159 e #160, já In Progress no Project #1.

## Global Constraints

- Sem Claude. Antigravity #2 usa Sonda e Broca para as tarefas recebidas.
- Nenhum agente altera produção enquanto outro prepara staging do mesmo arquivo.
- Preservar alterações locais anteriores; nenhum reset/restore/clean ou git add amplo.
- Não alterar economia, detecção, alcance, cápsula, velocidade ou autoridade de rede.
- Sem edição de cenas nesta fatia. Novas animações de locomoção ficam para outra etapa.
- Aplicação pelo MCP Godot, capturas com janela e testes antes do commit por issue.

### Task 1: Radar — #159, Farol / Codex

**Files:** `gameplay/detector/detector_radar.gd`, `gameplay/detector/detector_model.gd`; testes novos em `tests/unit/` após entrega staging.

**Interfaces:** Consumir `MetalDetector.get_current_target()`, `get_target_distance()`, `get_detector_level()`, `get_footer_lines()` e métodos existentes de pinpointer. Preservar esses métodos e o material A11y.

- [x] Escrever e executar RED de hierarquia/estado sem alvo e preservação das capacidades por nível.
- [x] Implementar apresentação em staging, sem modificar MetalDetector nem a cena.
- [x] Executar GREEN com janela, regressões de upgrades, clima e acessibilidade; documentar contagens e erros reais.
- [x] Codex inspeciona diff, aplica pelo MCP com SHA esperado e captura níveis 1/3/7, com/sem pinpointer, no mesmo enquadramento anterior.
- [x] Revisar legibilidade e solo visível; corrigir qualquer regressão observada.

### Task 2: Explorador — #160, Bússola / Codex

**Files:** `gameplay/player/player_avatar.gd`, helper visual se justificado; testes novos em `tests/unit/` após staging.

**Interfaces:** Preservar `setup(peer_id, display_name)`, `set_tool(StringName)`, `set_pitch(float)`, `set_downed(bool)`, `is_downed()` e funções estáticas de pitch. Reutilizar ferramentas existentes sem mãos locais, nunca reconstruir modelo a cada frame com mesmo tool_id.

- [x] Escrever e executar RED de ferramentas distinguíveis, troca sem acúmulo e segurança durante downed; preservar regressões de pitch.
- [x] Construir silhueta facetada, vestuário, bolsa e identificação cooperativa em staging.
- [x] Executar GREEN com janela e verificar ausência de colisores cosméticos.
- [x] Codex aplica via MCP, captura frente/lado/costas, quatro peers e ferramentas; repetir pitch/downed/retorno.
- [x] Farol faz revisão visual independente do avatar; Bússola revisa radar, sem editar os arquivos do colega.

### Task 3: Integração — Codex

- [x] Conferir rascunhos Sonda/Broca e registrar atribuições e limites nas issues.
- [x] Atualizar regra persistente de delegação no onboarding.
- [x] Rodar `bash tools/run_tests.sh GODOT` e `bash tools/run_headless_tests.sh GODOT` no estado final; investigar falhas sem atribuir warnings dummy ao patch sem comparação.
- [x] Registrar imagens, logs e limites em cada issue. Não confundir montra estática com validação completa de movimento.
- [x] Conferir `git diff --check`, staged explícito e um commit por issue com `Closes #N`; só encerrar kanban quando verificações forem concluídas.

## Registro de execução

Bússola preparou os testes RED do avatar; Farol preparou os testes do radar. Os dois
terminais atingiram limite de uso antes da implementação. Codex assumiu staging e aplicação
MCP, executou RED/GREEN e manteve os arquivos de produção exclusivos. Quando voltaram,
Bússola e Farol fizeram revisões independentes; as pegas de pá/kit e a obstrução do visor
foram corrigidas. Antigravity #2 utilizou Sonda e Broca para inventário/matriz e revisão,
conforme solicitado. Os pareceres estáticos não substituem testes de rede ou playtest humano.

Entregas e evidências: `docs/RADAR_159.md` e `docs/AVATAR_160.md`.
