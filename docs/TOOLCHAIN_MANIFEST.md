# Ferramentas e modelos — #176

Inventário de 23/10/2026. Instalações locais; não certifica saldo nem todos os recursos dos pacotes.

| Componente | Versão/revisão | Uso e limite |
|---|---|---|
| Godot | 4.3 Forward+ | Motor do projeto; não migrar por sugestão de skill |
| Blender | 4.5.15 LTS instalado | Skills 5.2 exigem adaptação e verificação de API |
| Godot MCP koltyakov | `84b9c26bbd7962f89fceca826645ad4d931e72b0` | Servidor canônico local; lease de engine exclusivo |
| REA | 6.7.0, repo `f850b7c894fa5cba370092a3ad9ca3df899d6d6f` | Engenharia reversa/evidências; não julga estética de mapas; Frida nativo não instalado/testado |
| OpenCode | 1.19.4 usado nos terminais | Perfil `fleet-basic`, seis passos e ferramentas delimitadas |
| OpenCode | 2.1.3 instalado isolado | Reserva; integração Maestri ainda não validada |

Executáveis/repos ficam em `C:/Users/felip/.codex/tools/`; OpenCode e REA isolados em `fleet176`.
Backups de configuração ficam em `fleet176/backups/`. Não contêm evidências públicas e não devem ser anexados a issues.
Codex, OpenCode e o arquivo efetivo `~/.gemini/config/mcp_config.json` apontam para Node + servidor Godot local e REA local. Processos existentes podem precisar reiniciar para recarregar.
OpenCode confirmou ambos conectados via `mcp list`. Para tarefas básicas, os schemas `godot_*`/`rea_*` ficam desabilitados no perfil; habilitar apenas sob tarefa e lease específicos, evitando contexto excessivo.

## Skills selecionadas

Instaladas em `~/.agents/skills`; as quinze novas também copiadas para `~/.gemini/skills`. Descoberta após reinício precisa ser conferida pelo runtime, sem imprimir corpos inteiros.

Retomada 23/10: Sonda/Broca autorrelataram 39 skills no contexto nativo e catálogos lazy de 53 schemas Godot/207 REA via `call_mcp_tool`. Nesta sessão root, 53 schemas Godot/207 REA estão expostos e `get_godot_version` respondeu 4.3. Nenhuma chamada Godot/REA foi executada pela célula Gemini nesta checagem; não certifica conectividade de todos os backends, modelo servido ou quota. Relatório local: `.bot_runs/ops176_runtime_resume.md`.

- [founder-skill](https://github.com/Jakeschincariol/founder-skill), MIT, `fd9385b0cfe1b96bebce3898fbd506d73eff5a9d`: onze módulos founder-*; planejamento sob demanda. Não executar cem agentes/compradores sintéticos, nem tratar simulação como validação de mercado.
- [godot-gdscript-patterns](https://github.com/wshobson/agents/tree/main/plugins/game-development/skills/godot-gdscript-patterns), MIT, `0874a27b17a22e2b7c2e2bcd725768e0803cad06`: padrões Godot 4.x, conferir contra 4.3.
- [game-art, game-design, 3d-games](https://github.com/davila7/claude-code-templates), MIT, `c036dcbb0a91a78075ab747b2d25008a4814acd5`: referências de processo; nome do repositório não autoriza executar Claude.
- Skills existentes de token economy, testes e revisão permanecem. Ler somente a skill pertinente; não carregar inventários completos em cada tarefa.
- Skills Scenario para Godot 4.7 e Blender 5.2 são referências com incompatibilidades potenciais; nenhuma atualização do projeto autorizada por elas.

## Seleção de modelo e custo

O [catálogo gratuito OpenCode](https://opencode.ai/v2/docs/console/models/) e rankings atuais orientam candidatos, mas acesso e resultado local decidem uso. Não há vencedor universal comprovado para este projeto.
DeepSeek V4.1 Flash foi candidato forte de programação; o endpoint NVIDIA não respondeu no limite do teste. GLM 5.3 Flash também excedeu 45s. Chave OpenCode expirou (401); chamadas sem autenticação retornaram 403. Nenhum bloqueio foi contornado.
NVIDIA Nemotron 3.5 Lightning respondeu ao smoke v2 em 11,04s com JSON esperado. Isso valida apenas o pequeno teste, não competência de netcode ou design. Continua restrito a inventário/documentação com revisão; falhas reais de shell e contexto do perfil antigo estão preservadas.
Não habilitar fallback pago nem presumir saldo API a partir de assinatura. Quota desconhecida até resposta real do provedor. HTTP 401/403 exige parada imediata, sem alternativa automática. HTTP 429 admite no máximo um retry se Retry-After ≤60s. Indisponibilidade pode admitir uma alternativa gratuita previamente validada. Tudo cabe no mesmo teto global de duas requisições por pacote em dez minutos; ordem de parar retries reduz o teto a zero. Nunca reduzir qualidade silenciosamente em core/rede/save.
O [FAQ oficial NVIDIA](https://docs.api.nvidia.com/nim/docs/product) descreve acesso de desenvolvimento/prototipagem; não oferece capacidade ilimitada nem licença de serviço comercial de inferência. Aqui os terminais auxiliam desenvolvimento/testes locais, sem disponibilizar endpoint a jogadores. Não ativar infraestrutura Enterprise paga.

| Terminal | Observação registrada | Atribuição |
|---|---|---|
| Codex | Orquestrador; identificador servido e saldo não expostos | Arquitetura, integração, engine, revisão final |
| Bússola / Farol | Codex; interface mostrou GPT-6.1-Sol low; isso não autentica o serving ID nem quota | Implementação/revisão técnica conforme reserva |
| Antigravity #2 | Rótulo de interface Gemini 3.8 Flash high e autodeclarações divergentes; identidade efetiva não certificada | Coordena tarefas básicas de Sonda/Broca |
| Sonda / Broca | Gemini 3.8 Flash high declarado/observado no recorte; saldo desconhecido | Inventários e verificações delimitadas |
| OpenCode / OpenCode #2 | Nemotron Lightning NVIDIA; tarefas v2 concluídas em 19,3s/33,7s, interfaces 8,5K/27,4K tokens | Comandos exatos/hashes/docs com revisão Bússola/Farol |

Estes tempos são observações de tarefas diferentes, não benchmark comparativo. Não manter agentes ocupados com auditorias repetidas quando a fila útil estiver vazia.

## Continuidade e evidências

`tools/agent_continuity_gate.py` emite trabalho somente quando checkpoints mudam; execução repetida sem mudanças retorna 1 para não gastar chamadas. A rotina Maestri é limitada e pula terminal ocupado. Não constitui serviço permanente: depende de máquina ligada, Maestri, rede, modelo disponível e tarefas autorizadas.
O gate inclui remoções no diff, preserva estado inválido com diagnóstico em stderr/exit2 e troca o baseline por rename atômico após flush do stdout. Testes isolados: `python tools/test_agent_continuity_gate.py`; não executar o gate real para testar, pois consome seu baseline. Estado vazio sem evidência retorna1.
O baseline registra emissão observada, sem confirmação de conclusão pelo consumidor. Falha após entrega do stdout pode exigir reatribuição manual pelo Codex; não há fila com ack nem lock entre invocações. Usar uma única rotina, sem execuções manuais simultâneas. Skipbusy, teto de disparos e agendamento pertencem ao Maestri, não ao script; verificar com `maestri routine show`.
`docs/RELEASE_ROADMAP.md` e `docs/AGENT_FLEET_POLICY.md` definem fases e responsabilidades. Nota do canvas: **ScanDig — Produção e lançamento**.
Automação visual deve conservar capturas brutas e logs: métricas de pixels localizam alterações, não aprovam beleza ou jogabilidade. Cada mapa precisa câmeras/condições equivalentes e revisão de contato, acesso, oclusão e marcos.

Uso local: Python ≥3.11 e Pillow (verificado com Python3.14/Pillow12.3 já instalados). `python tools/qa_visual_review.py --before DIR --after DIR --output DIR` gera galeria HTML, contact sheet e manifesto; exit0 inclui alertas de imagens, exit2 indica entrada/I/O inválido. `python -m unittest tools.test_agent_continuity_gate tools.test_qa_visual_review` usa diretórios temporários isolados e funciona sem `.bot_runs/` prévia.
Relatórios `.bot_runs/` são evidências locais ignoradas pelo Git; os resumos auditáveis ficam na [issue176](https://github.com/Felipefmdev/ScanDig/issues/176), incluindo revisões e limitações. Não presumir que esses relatórios acompanhem um clone novo.
