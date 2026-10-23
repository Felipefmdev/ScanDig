# ScanDig — Roadmap de Lançamento e Quality Gates
Milestones no GitHub: [Pre-alpha](https://github.com/Felipefmdev/ScanDig/milestone/1), [Alpha](https://github.com/Felipefmdev/ScanDig/milestone/2), [Beta](https://github.com/Felipefmdev/ScanDig/milestone/3), [RC](https://github.com/Felipefmdev/ScanDig/milestone/4), [Release](https://github.com/Felipefmdev/ScanDig/milestone/5). Sem prazos fictícios; não equivalem a tags ou builds aprovados.
**Versão no projeto:** 0.1.0; fase pre-alpha. Padrão proposto para a próxima tag verificada: `v0.1.0-prealpha.N`. **Motor:** Godot 4.3 (Forward+). **Tags Git:** nenhuma registrada nesta auditoria.
**Diretriz Orçamentária:** Custo incremental de SOFTWARE planejado R$ 0; saldo/gasto real em APIs desconhecido (não significa custo operacional total zero); teto orçamentário planejado < R$ 500 sem novas compras ou assinaturas pagas.
Os checkpoints lunares abaixo descrevem a integração local da #120, ainda não versionada junto desta entrega operacional #176; não certificam o código de um clone limpo nem uma release.

---

## 1. Estado Atual e Diretrizes Gerais

- **Baseline Operacional:** Estágio pré-alpha (`0.1.0-prealpha.N`) na branch `main`. Sem prazos cronológicos fictícios; a progressão é governada estritamente pelo cumprimento dos quality gates.
- **Teto Financeiro:** Custo incremental de software planejado em R$ 0. Saldo e consumo real de quotas/APIs desconhecido (não representa custo operacional total zero). Teto orçamentário estrito abaixo de R$ 500, vedada qualquer compra de assets, ferramentas ou assinaturas.
- **Ferramental e Runtimes:** Instalação/configuração e descoberta efetiva são verificações separadas. As 15 skills Gemini estão em `C:/Users/felip/.gemini/skills`. Root confirmou Godot MCP 4.3 nesta retomada; OpenCode registrou dois MCPs conectados no checkpoint anterior. Sonda/Broca autorrelataram 39 skills no contexto e schemas lazy Godot/REA disponíveis; sem chamadas aos backends nesta checagem. Ver `TOOLCHAIN_MANIFEST.md` para fontes e limites.
- **Critério de Severidade:** P0 (crash/perda de dados), P1 (bloqueio de fluxo/regressão de rede ou save), P2 (defeito com contorno), P3 (polimento).
- **Validação Dupla:** Testes automatizados (GUT/scripts) atestam lógica e contratos; aceite humano atesta legibilidade visual, silhueta e experiência.

---

## 2. Fases Formais de Lançamento e Critérios de Entrada/Saída

### 2.1 Pre-alpha (Fase Corrente — 0.1.0-prealpha.N)
- **Escopo:** Estabilização do core loop básico e consolidação dos sistemas de exploração e transição inter-mapas (#120/#173).
- **Pendências para Fechamento:**
  - Formalização do contrato MD da viagem de foguete (#120) e saneamento de `docs/CORE_AND_NETWORK.md`.
  - Validação factual da transição nominal Cratera -> Lua sem injeção artificial de estado.
  - Regressão da quiescência já implementada no embarque: suspensão de ações/física com revalidação Host, sem imunidade genérica ou congelamento global; ampliar prova no percurso contínuo real.
- **Quality Gates para Avançar:**
  - Loop solo completo: spawn → procurar → escavar → coletar → vender/doar → persistir/reabrir sem falhas.
  - Zero bugs P0/P1 no loop básico; todos os casos da matriz GUT direcionada executados com resultado registrado.
  - Validação física por cápsula real (sem teleporte) nas rotas de teste dos mapas autorados.
  - Persistência pré-embarque isolada e validada em disco antes do prepare de transição para a Lua.

### 2.2 Alpha (Fechamento de Conteúdo — 0.2.0-alpha.N)
- **Escopo:** Os 6 mapas integrados (Praia, Campo, Ruínas, Geleira, Cratera e Lua), NPCs, chefes e cadeia narrativa de reparo do foguete.
- **Pendências para Fechamento:**
  - Validar a cadeia já implementada da Dra. Vega (`vega_sinal` e `vega_foguete`) em campanha contínua na Cratera.
  - Validar a batalha integrada contra `lunar_warden` no fluxo contínuo, incluindo coop. O ensaio isolado DD7D registrou conclusão false→true, callback único e UI aberta; a copy PT/EN passou 10/10 testes, 209 asserts, com warning ObjectDB. Isso não comprova campanha integral nem log limpo.
- **Quality Gates para Avançar:**
  - Conteúdo completo: 6 mapas funcionais; executar apenas as condições suportadas na matriz abaixo. N/A é ausência de modo no produto, não teste omitido.
  - Derrota nominal do chefe final (`lunar_warden`) validada em fluxo contínuo a partir da Cratera.
  - Zero bugs P0/P1 nos caminhos críticos de progressão e missões secundárias.
  - Suíte GUT completa e testes headless executados com exit code 0 e zero `SCRIPT/PARSE ERROR`.
  - Matriz visual: contatos de solo validados (gap < 0,15m), câmeras desobstruídas e ausência de z-fighting nos marcos dos 6 mapas.

### 2.3 Beta (Congelamento de Features — 0.9.0-beta.N)
- **Escopo:** Feature freeze estrito. Foco exclusivo em estabilidade de rede cooperativa, desempenho, ergonomia de UI e robustez.
- **Pendências para Fechamento:**
  - Resiliência a jitter e pacotes desordenados no handshake de 3 fases da viagem espacial.
  - Isolamento de late-join via `HostSpawnSync` (#173) até prontidão total do cliente.
- **Quality Gates para Avançar:**
  - Zero bugs P0/P1 abertos; limite de no máximo 10 bugs P2 abertos (todos documentados com contorno e responsável).
  - Coop resiliente: alvo proposto a validar capacidade (sessão de 2h e soak test de 20 ciclos; proposta técnica a validar, não requisito decidido por Felipe nem execução atual).
  - Transação de 3 fases (#120) validada sob latência com cancelamento limpo e rollback em caso de desconexão.
  - Robustez de save: todos os casos da matriz de teste nos slots 1 a 3 executados com resultado registrado contra corrupção e falhas de I/O forçadas.
  - Input & Acessibilidade: todos os fluxos da matriz operáveis via teclado/mouse e gamepad; textos adaptados em PT-BR e EN; 4 modos daltônicos.

### 2.4 Release Candidate — RC (1.0.0-rc.N)
- **Escopo:** Validação formal dos binários finais de distribuição (builds exportados para Windows Desktop).
- **Pendências para Fechamento:**
  - Empacotamento do instalador e executável exportado para Windows Desktop em ambiente limpo.
  - Homologação estética formal e aceite de produto registrado por Felipe.
- **Quality Gates para Avançar:**
  - Zero bugs P0, P1 ou P2 abertos; zero erros nativos não catalogados; zero vazamentos cumulativos de ObjectDB/RID após warmup.
  - Duas rodadas consecutivas de testes completos aprovadas no mesmo artefato congelado sem alterações de código.
  - Smoke test do instalador/executável em ambiente Windows limpo (first-run, novo jogo, continue e rollback).
  - Aceite estético e de produto formalmente registrado por Felipe para todos os biomas e interface.

### 2.5 Versão 1.0 (Lançamento Oficial — 1.0.0)
- **Escopo:** Publicação do artefato aprovado no RC, documentação final, créditos completos e tagging Git formal.
- **Pendências para Fechamento:**
  - Revisão final de `CREDITS.md` e conferência de licenças de assets de terceiros.
  - Aplicação de tag Git anotada sobre commit limpo e verificado.
- **Quality Gates de Entrega:**
  - Artefato binário idêntico ao RC aprovado (verificação por hash SHA-256).
  - Metadados, versão em `project.godot`, créditos e licenças totalmente atualizados.
  - Tag Git anotada obrigatória; assinatura GPG/SSH estritamente se chave já estiver configurada no ambiente (sem custos/contas novas).
  - Proibida aplicação de tags sobre checkout sujo ou working tree com arquivos pendentes.

---

## 3. Matriz Dimensional de Quality Gates

| Dimensão | Quality Gate Mensurável (Critério de Aceite) | Ferramenta / Evidência |
| :--- | :--- | :--- |
| **Solo & Gameplay** | Loop completo sem teleporte de resgate; inventário, vida e fome consistentes; zero P0/P1. | Walkthroughs gravados, logs GUT unitários. |
| **Multiplayer / Rede** | Handshake de 3 fases (#120); `HostSpawnSync` (#173) retendo late-join até ready; zero cache errors. | Logs brutos de subprocessos ENet, headless coop. |
| **Persistência / Save** | Gravação atômica `.tmp` → `.old`; save pré-embarque preservado; todos casos da matriz executados com resultado registrado. | `test_save_robustness.gd`, `save_flow_test.gd`. |
| **Input & Acessibilidade** | Ações alcançáveis por gamepad e teclado; suporte bilíngue (PT/EN); legendas e paletas ativas. | `tools/bot/qa_nav_keyboard.json`, `tools/bot/qa_nav_pad.json`, `tests/dev_b/test_accessibility.gd`, `tests/dev_b/a11y_snapshots.gd`. |
| **Colisão & Câmeras** | Vértices inferiores apoiados (gap < 0,15m); rota com cápsula contínua; sem colisores invisíveis. | `test_terrain_ground_contact.gd`, capturas MCP. |
| **Iluminação & Arte** | Estilo toon legível; sem oclusão de alvos em noite/chuva/nevasca/cinzas; marcos identificáveis. | Amostras PNG antes/depois, checklist visual Bússola. |
| **Estabilidade & Build** | Zero `SCRIPT/PARSE ERROR`; export Windows limpo; leaks de memória controlados após warmup. | `run_headless_tests.sh`, logs de soak test. |

---

Condições atuais (`core/night_mode.gd`, `core/weather_manager.gd`):

| Mapa | Noite | Evento climático |
|---|---|---|
| Praia | Sim | Chuva |
| Campo | Sim | Chuva |
| Ruínas | Sim | N/A |
| Geleira | Sim | Nevasca |
| Cratera | Sim | Cinzas |
| Lua | N/A | N/A |

## 4. Governança e Regras de Evidência

1. **Evidência Factual Obrigatória:** Aprovações exigem logs brutos, identificador de build e asserts verificados; `exit 0` isolado não basta.
2. **Imutabilidade de Gates:** Nenhum critério pode ser afrouxado ou renomeado para contornar falhas de validação.
3. **Custo Incremental de Software Planejado R$ 0:** Scripts e Godot CLI usam recursos locais; inferência remota já registrada depende de APIs/quotas cujo saldo e custo operacional são desconhecidos. Nenhuma nova compra ou cobrança automática autorizada.
4. **Política de Tags Git:** Tag anotada obrigatória gerada exclusivamente em commits verificados da branch principal; assinatura GPG/SSH apenas se já configurada; terminantemente vedado taguear checkout sujo.
