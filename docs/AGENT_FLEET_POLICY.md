# Política da frota de agentes — ScanDig (#176)
Data: 23/10/2026. Responsável pela redação: Farol; orquestração: Codex; prioridade, orçamento e aceite de produto: Felipe.
Aplicar junto de [AGENT_ONBOARDING.md](AGENT_ONBOARDING.md) e `CONTEXT.md`. Atribuições explícitas de Felipe/Codex prevalecem sobre defaults de skills.

## Responsabilidades e limites
| Papel | Entrega principal | Limite |
|---|---|---|
| Codex / root | Divide issues, atribui reservas, revisa contratos, integra produção, coordena MCP/engine e gates finais | Não presume aprovação visual, créditos ou sucesso pelo relato de outro agente |
| Farol / Bússola | Diagnóstico e revisão independente, física/apoio/oclusão, testes e staging conforme atribuição | Não altera arquivo compartilhado/produção nem executa engine sem reserva explícita |
| OpenCode / executor simples | Leitura localizada, comparação de logs/hashes, inventário curto, documentação/fixture simples em caminho autorizado | Sem arquitetura/rede/save crítico autônomo, core/UI, produção compartilhada, instalação, compra ou commit |
| Antigravity #2 / ajudantes existentes | Tarefas básicas conforme onboarding; coordenação de Sonda/Broca e revisão do retorno | Sem recrutar substitutos, ampliar equipe ou mudar liderança |
| Felipe | Decide escopo, gasto, identidade visual, cortes de fase e lançamento | Evidência técnica e opinião estética devem vir separadas |

Resultado barato é candidato, não aprovação. Código de rede/save/transição exige revisão de responsável com contexto completo, independentemente do modelo usado.
Não recrutar, usar Claude ou disparar founder/100 agentes por iniciativa própria. Reutilizar terminais já autorizados.

## Kanban e pacote curto obrigatório
Antes de editar: issue no Project #1, responsável, estado, escopo e reserva publicados. Não duplicar issue existente para a mesma causa.
Cada pacote contém: issue; um objetivo; arquivos permitidos/proibidos; base/hash; contexto mínimo; aceite; verificação; engine ON/OFF; prazo e condição de parada.
Preferir uma saída revisável em um arquivo e até 10 minutos de trabalho ativo. Mudança maior vira fatias dependentes, não prompt ilimitado.
Entregar: resultado/finding, arquivo:linha, diff/hash, comandos/logs, falhas/pending, limites e próximo passo. Enviar ao root por `maestri ask Codex`.
Avançar dentro da autorização já dada; não pedir confirmação repetida para passos incluídos. Mudança de escopo volta ao root.
Não despejar onboarding inteiro, catálogos de ferramentas/skills e históricos em cada pacote: fornecer referências e apenas os trechos necessários.

## Exclusão de arquivos e engine
- Um escritor por arquivo. Reserva explícita de caminho inclui testes/staging; diretório compartilhado não dá posse de todos os filhos.
- Root mantém arquivos centrais e integra cenas compartilhadas por patch mínimo/hash esperado, quando a issue assim atribuir.
- Nunca sobrescrever staging congelado, descartar trabalho alheio, executar reset/clean ou commitar fora da atribuição.
- Engine tem uma lease por vez, com dono, finalidade, prazo e devolução explícita. Coop pode usar processos coordenados dentro dessa única lease.
- Preparação offline não retém engine. Devolver entre RED e escrita; GREEN só no lease seguinte quando coordenado.
- MCP `create_script`/executor pode iniciar Godot: não tratar todo MCP como filesystem. Confirmar o efeito antes da chamada.
- Não duplicar GUT full/headless/capturas enquanto outro responsável executa. Timeout deve encerrar os processos próprios e liberar a lease.
- No encerramento/interrupção, salvar checkpoint de arquivos/hashes, último RED/GREEN real, pendências e reservas; informar devolução de engine.

## Fallback gratuito e término finito
Root mantém allowlist de provedores/modelos comprovadamente gratuitos para a configuração usada, com fallback pago desabilitado.
Rótulo “free”, conexão disponível ou assinatura não comprovam saldo/quota/API grátis. Se a cobrança for desconhecida, não rotear automaticamente.
Nenhuma compra, assinatura, cartão, top-up ou consumo pago é ativado pelo executor. O teto operacional < R$500 não é crédito disponível para gastar.
| Situação | Ação e teto por pacote |
|---|---|
| Resposta normal | Um executor; validar saída antes de aceitar ou delegar outra etapa |
| Timeout | Até 90s por requisição; no máximo 1 retry, apenas se idempotente e sem efeito parcial desconhecido |
| HTTP 401/403 | Parar imediatamente; reportar provedor/erro sem segredo; não repetir credenciais nem trocar conta/modelo em loop |
| HTTP 429 | No máximo 1 retry respeitando Retry-After se ≤60s; espera maior/quota esgotada vira checkpoint e retorno ao root |
| Provedor indisponível | No máximo 1 troca para alternativa gratuita já validada; continua dentro do teto global de 2 tentativas de requisição |
| Conteúdo vazio/inválido | Uma correção curta apenas se couber nas mesmas 2 tentativas; depois preservar saída e reportar |
| Contexto excessivo | Parar retries; resumir checkpoint e reduzir ferramentas/skills/contexto antes de nova sessão autorizada |

Limite global: 2 tentativas de requisição por pacote, incluindo retries e troca de provedor; até 10 minutos totais. Vale o limite que chegar primeiro.
Se já recebeu ordem de parar retries, o limite passa a zero até nova atribuição. Não reiniciar sessão automaticamente para contornar quota/contexto.
Antes de repetir operação de escrita/engine, verificar efeitos e hashes; erro de transporte não comprova que nada foi aplicado.
Não prometer agente trabalhando indefinidamente em background, disponibilidade gratuita infinita ou retomada automática após limite/reinício.
Trabalho assíncrono autorizado tem dono, deadline, saída observável e término; sem daemon/retry perpétuo ou multiplicação de agentes para contornar falha.

## Identidade, crédito e skills compartilhadas
Relatar separadamente: modelo declarado pela interface, identificador realmente observado, runtime/versão e quota visível, com data e método.
Observação de Farol em 23/10: CLI local retornou `codex-cli 0.163.0`; modelo exato servido e crédito/saldo desta sessão não estão expostos.
Executável instalado não comprova modelo ativo, processo que atende a conversa, preço ou saldo API. Não adivinhar esses campos.
Nunca registrar chaves, tokens, arquivos de autenticação ou payloads privados para demonstrar crédito; ausência de informação deve constar como desconhecida.
Catálogo compartilhado: `~/.agents/skills` (`C:/Users/felip/.agents/skills` nesta máquina); root configura os runtimes para o mesmo catálogo revisado.
Na leitura desta entrega, `.agents/skills` do repositório não existe; não alegar sincronização instalada. Root decide link/configuração, sem cópias divergentes silenciosas.
Carregar apenas SKILL.md pertinente e dependências mínimas; registrar fonte/versão e revisar comandos/permissões antes de executar uma skill externa.
Skills para **Godot 4.7** e **Blender 5.2** são referência: o jogo permanece **Godot 4.3** e o pipeline designado **Blender 4.5**.
Não copiar APIs/enums/shaders/export presets novos sem checar compatibilidade nas versões do projeto; skill não autoriza migração nem instalação.
Modelagem exige JPG correspondente, inspeção visual, escala/apoio/collider, materiais e QA do asset conforme contrato; exemplos de skill não substituem evidência.
Founder é on-demand, com pergunta, orçamento e saída delimitados. Não executar pack, painel padrão de 100 compradores ou subagentes automaticamente.
Simulação de compradores é hipótese, não pesquisa de mercado, venda real ou validação financeira. Quantidade e custo precisam caber na atribuição explícita.

## Checklist de revisão de resultados simples/baratos
- [ ] Issue/objetivo/reserva correspondem ao pedido; nenhuma alteração fora da lista nem artefato alheio sobrescrito.
- [ ] Fontes atuais e trechos citados foram lidos; observação, inferência e hipótese estão identificadas.
- [ ] Arquivos existem; base/hash e diff conferidos pelo revisor, não apenas pela mensagem do executor.
- [ ] Teste exercita comportamento real, falhou por motivo válido no RED e passou no GREEN executado; ausência/parse não vira aprovação.
- [ ] Logs brutos e exits de todos os processos conferidos; ERROR/WARNING/pending não somem por resumo filtrado.
- [ ] Fixture não atribui estado no cliente para “provar rede”, não simula commit que deveria observar, nem amplia tolerância para mascarar suporte.
- [ ] Captura corresponde à versão/pose/renderer reais; aprovação de pixels não foi chamada de estética ou prova de rota.
- [ ] Dependências/API de versões novas não entraram; fonte/fixture/asset e limitações estão reproduzíveis.
- [ ] Responsável decidiu integrar, pedir correção curta ou rejeitar; nenhuma saída barata entra automaticamente em produção.

## Pipeline QA mínimo e gates
Base detalhada local: `.bot_runs/ops176_farol_quality_gates.md` (#176, Farol); é proposta de gates, não certificado de build atual. `.bot_runs/` é ignorada pelo Git e não acompanha clones; o resumo persistente está nesta seção, no roadmap e nos registros da [issue176](https://github.com/Felipefmdev/ScanDig/issues/176).
Ordem: contrato + RED significativo → staging mínimo → GREEN direcionado → revisão independente → integração root → regressões proporcionais → gates finais.
Prioridade: posição/rota/cápsula real → apoio e offsets sem flutuação → oclusão de objetivo/porta/núcleo → composição/paleta/acabamento.
Reusar GUT, `tools/run_headless_tests.sh`, DebugBridge/tools/bot e MCP existentes. Config direcionado com dirs vazio evita suíte inteira acidental.
Solo exige loop jogável; coop exige host/client/late reais e cancel/retry; save exige legado/atual/roundtrip/falha; input exige teclado/gamepad/PT/EN/A11y.
Capturas: manifest de build/scripts/estado/seed por gerador, câmera/FOV/viewport/resolução medida, renderer/GPU, save/role e before/after equivalentes.
Headless/dummy não prova cor/MultiMesh; bot com teleport fallback não prova rota; altar+hits não prova derrota; state seed não prova campanha.
Diff pixel sinaliza regressão sob condições equivalentes; estética/legibilidade e identidade têm aceite humano de Felipe, registrado separadamente.
Pre-alpha: fatia solo sem P0/P1. Alpha: escopo prometido e matriz crítica cobertos. Beta: feature freeze, campanhas reais e soak sem perda de progresso.
RC: duas rodadas completas no mesmo candidato, export Windows e saves legados, nenhum erro crítico inexplicado. 1.0: exato artefato aceito, hash e rollback.
Antes de commit, root cumpre GUT/headless exigidos pelo onboarding; contagens, skips/pending e warnings ficam explícitos. Esta política não executa esses gates.
Wrappers atuais têm limites: QA gerado ainda referencia Ilha/fragmentos; relatório filtra ruído/saída; CI “every scene” cobre Praia+sandbox. Conferir logs/cobertura reais.
Não declarar log limpo com ObjectDB/RID/texture leaks, nem garantia formal de drenagem UDP por um GREEN. Perf compara mesma máquina/config, não FPS de headless.

## Continuidade e fontes
Em #120, RED root e derrota real já têm checkpoints registrados: DD7D observou conclusão false→true, callback único e UI aberta; copy PT/EN GREEN 10/10/209 com warning ObjectDB. A integração local ainda não versionada da #120 usa `lunar_warden`; campanha contínua Cratera→Lua e vitória coop no mapa ainda exigem validação própria. Esses checkpoints não certificam um clone limpo da entrega #176. Preservar evidências `lua120_victory*`; novas alterações dependem de atribuição/reserva na issue, não desta política.
Reportar bloqueio/cota/contexto como estado observável, preservando trabalho. Root decide a próxima atribuição; executor não cria substitutos ou gastos para “continuar a qualquer custo”.
Fontes locais: `docs/AGENT_ONBOARDING.md`, `CONTEXT.md`, `docs/ARCHITECTURE.md`, `docs/TOOLS.md`, `.github/workflows/tests.yml`, `tools/bot/*`, relatório QA #176 acima.
