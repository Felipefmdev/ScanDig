# Onboarding de agentes — ScanDig

Lê isto ao entrares no projeto. Primeiro ganhas contexto e só depois montas a tua equipa.

## 1. Quem deve montar equipa

- **És líder** se acabaste de ser ligado ao canvas e não tens um papel de ajudante: não és `Dev_Detector`, `Dev_Player`, `Sonda`, `Broca` nem um recrutado de outro agente.
  - Como líder, montas a equipa: segue os passos 2 e 3.
- **És ajudante** se tens um desses papéis ou se foste recrutado por outro agente.
  - Como ajudante, **não recrutes ninguém**. Lê só o passo 2 e espera as tarefas do teu líder.

## 2. Contexto obrigatório (ler por esta ordem)

1. `CONTEXT.md`: regras de arquitetura (Godot 4.3, GDScript tipado), divisão Dev A / Dev B e o que cada equipa pode editar.
   - Visão geral do código (autoloads, fluxo da expedição, save, testes): [`docs/ARCHITECTURE.md`](ARCHITECTURE.md).
2. **Antes de tocar em `world/` ou `ui/`:** [`docs/learning/AGENT_CONTEXT.md`](learning/AGENT_CONTEXT.md) (1 página, obrigatório) e, para números, [`docs/MAP_METRICS.md`](MAP_METRICS.md). O resto do pacote está em [`docs/learning/`](learning/README.md).
3. `docs/GAME_DESIGN.md`: a visão do jogo (mapas, armas por mapa, missões, segredos, estilo de arte).
4. `docs/CORE_AND_NETWORK.md`: autoridade do host, RPCs, snapshot e save.
5. `docs/PACING.md` e `docs/TOOLS.md`: economia e ferramentas.
6. O kanban (GitHub Project #1). Usa `gh issue list --state open` e `gh issue view N`.
   - Issues marcadas **NÃO INICIAR** esperam ordem do Felipe.
   - Só pegues no que te for atribuído.
7. `git log --oneline -20`: o que mudou por último.

### Regras da casa

- **Coordenação (Felipe, 21/10/2026):** Codex é o terminal principal; Bússola e Farol são os ajudantes principais e Antigravity #2 fica com tarefas básicas. Não usar Claude nem retomar rotinas antigas de transferência de liderança.
- **Delegação de tarefas básicas (Felipe, 21/10/2026):** Antigravity #2 deve distribuir as tarefas que receber entre Sonda e Broca, seus agentes já conectados, revisar os resultados e reportar ao Codex. Registrar responsáveis e evidências na issue. Não recrutar substitutos nem usar Claude; comunicar indisponibilidade real de algum agente.
- **Kanban obrigatório:** todo trabalho deve estar associado a uma issue no GitHub Project #1 antes de editar. Atualize o status e registre escopo, responsável, verificações e evidências na issue; nunca descarte alterações locais de outro agente para limpar o checkout.
- **Ambientação dos mapas:** usar o MCP Godot para inspeção, aplicação e diagnóstico, com capturas atuais antes/depois. Um roteiro antigo ou leitura de código não substitui validação visual atual.
- **Testes:**
  - O GUT e o `bash tools/run_headless_tests.sh "<godot>"` têm de passar antes de cada commit.
  - O binário é `C:/Users/felip/Downloads/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe`.
  - Cria um `class_name` novo? Corre `--headless --path . --import`.
- **Commits:**
  - Um commit por issue, com `Closes #N`.
  - `git add <arquivo>` **só dos teus arquivos**, nunca `-A` ou `-a`. Confere `git diff --cached --stat` antes de commitar.
- **Coop:** o host decide e os clientes veem. Uma chamada só-do-host dentro de um RPC de cliente passa por `call_deferred`.
- **Ficheiros:** `.gd` e `.py` em UTF-8 sem BOM, com fim de linha LF. Em Python usa `open(..., encoding="utf-8", newline="")` e corre o script a partir de um arquivo, não por heredoc.
- **Mapas:** não regraves `world/map_*.tscn` sem conferir a contagem de nós e de transforms.
- **Validação visual:** prints in-game, com janela, antes e depois de cada mudança.
- **How to Fish:** é só inspiração. Não se portam sistemas dele tal e qual.
- **Steam (#54):** só depois de o jogo estar pronto.

## 3. Montar a tua equipa (só líderes)

1. Corre `maestri list`.
   - Já tens 2 ajudantes ligados? Não recrutes mais: usa-os.
   - Precisas de ver os papéis? Corre `maestri role list`.
2. Recruta **2 ajudantes**, com codinomes que inventas tu (um nome curto e diferente dos que já existem no canvas):

   ```
   maestri recruit "<codinome-1>" --role "Dev_Detector"   # física, sinais, áudio, gameplay de mapas
   maestri recruit "<codinome-2>" --role "Dev_Player"     # jogador, armas, ambiente, escavação
   ```

   Se o teu trabalho for de Dev B (core/ e ui/), escolhe ou cria papéis com esse escopo (`maestri role create`).
3. Liga os dois entre si: `maestri connect "<codinome-1>" "<codinome-2>"`.
4. Apresenta-te ao Lead do projeto (o agente que te ligou, ou o "Antigravity") com `maestri ask`, e diz que equipa montaste.
5. Delega com `maestri ask --batch '{...}'`.
   - Cada tarefa leva o número da issue, os arquivos permitidos e as regras do passo 2.
   - Termina cada tarefa com: `maestri ask "<o teu nome>" "<issue + hash + prints>"`.
   - **Dois agentes nunca editam o mesmo arquivo ao mesmo tempo.** Combinem a ordem antes.
