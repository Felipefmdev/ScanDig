# Spike #54 — Multiplayer pela Steam (Fase 0)

Branch `spike/steam-54` (worktree `ScanDig-spike-steam`), base `b083d20`. Experimento isolado: nada disto está no `main`.
Testado em 2026-10-15, Windows 11, Godot **4.3-stable**, Steam aberta com a conta do Dev B, App ID **480** (Spacewar).

## Resumo

| Pergunta | Resposta curta |
| :--- | :--- |
| 1. Versão | **GodotSteam GDExtension 4.15** (build "4.1-4.3") carrega na 4.3 sem erro; `steamInitEx(480)` dá OK. **Nenhuma versão com o MultiplayerPeer roda na 4.3**: o peer integrado começa na 4.16, que só sai para Godot **4.4.1+**. Para a 4.3, escrevi um peer próprio em GDScript (`core/steam_peer.gd`, `MultiplayerPeerExtension`). |
| 2. Lobby e código | Funciona: lobby público (máx. 4) com `game=scandig`, `scandig_code` e `scandig_ver`; a busca pelo código acha exatamente o lobby criado, mesmo com 50+ lobbies de outros jogos no 480. |
| 3. Peer na Godot | `GameState`, `SessionManager` e todos os `@rpc` funcionam **sem mudança**: os 4 pares de testes de rede passam sobre o protocolo do `SteamPeer`. Host = id 1; clientes = id aleatório; o `SteamPeer` mapeia peer id ↔ SteamID. |
| 4. Uma conta só | Validado aqui: init, lobby, busca (inclusive de outro processo), host Steam como peer da árvore e uma expedição solo inteira. **Não dá** para ter dois peers Steam com a mesma conta (o "loopback" para o próprio SteamID entrega 1 mensagem e fecha). Roteiro para 2 PCs abaixo. |
| 5. Convite | `activateGameOverlayInviteDialog(lobby_id)` + sinal `join_requested(lobby_id, friend_id)` (jogo aberto) ou `+connect_lobby <id>` na linha de comando (jogo fechado). Não testável aqui (overlay e segunda conta). |
| 6. Sem Steam | O jogo abre e segue normal: init falho devolve `status 1` em < 100 ms; sem a biblioteca, só `ERROR` de carregamento (sem `SCRIPT ERROR`), GUT 128/128. **Regra:** nunca escrever o identificador `Steam` no código; usar `Engine.get_singleton("Steam")`. |
| 7. Testes e CI | Com o addon: GUT 128/128, 17 testes do core, par ENet e cenas sem `SCRIPT ERROR`. O CI (ubuntu-latest) deve carregar a `.so` (exige `GLIBCXX_3.4.29`, Ubuntu 22.04+); se não carregar, não quebra pela regra acima. Não rodei o CI de verdade (sem push). |
| 8. Peso | Build Windows: **+2,7 MB** (`libgodotsteam…release.dll` 2,4 MB + `steam_api64.dll` 0,3 MB). No repositório: 13 MB (win64 + linux64, debug e release). GodotSteam é MIT; a `steam_api64.dll` é binário redistribuível do SDK da Steam (assinado pela Valve). |

**Recomendação:** ficar na Godot 4.3 com o `SteamPeer` em GDScript para a Fase 1 (cerca de 400 linhas nossas, já validadas com os testes de rede) e só depois validar em 2 PCs. Subir para a 4.4.1/4.5 para usar o peer em C++ do GodotSteam é uma migração do projeto inteiro (ver pergunta 1); fica como plano B se o peer em GDScript der problema de desempenho.

## 1. Versão do GodotSteam

Fontes oficiais: releases em `codeberg.org/godotsteam/godotsteam` (o espelho `github.com/GodotSteam/GodotSteam` está **arquivado** e não tem os builds GDExtension). Builds GDExtension por versão (API do Codeberg, `/api/v1/repos/godotsteam/godotsteam/releases`):

| Release | Godot | Observação |
| :--- | :--- | :--- |
| v4.10-gde … v4.12-gde | 4.1/4.2/4.3 | sem MultiplayerPeer |
| v4.13-gde, v4.14-gde | arquivos `…-4.1-4.3.zip` e `…-4.4.zip` | sem MultiplayerPeer |
| **v4.15-gde** (2025-08-23) | `godotsteam-4.15-gdextension-plugin-4.1-4.3.zip` | **última para a 4.3**; Steamworks 1.62 |
| v4.16-gde (2025-09-22) | só `…-4.4.zip` e `…-4.5.zip` | MultiplayerPeer de Chris Ridenour (FriarTruck) entra no ecossistema |
| v4.17-gde … v4.23.1 | "Godot 4.4+" | peer integrado ao GDExtension principal (conflita com o `expressobits/steam-multiplayer-peer`) |

O repositório `codeberg.org/godotsteam/multiplayerpeer` só publica editores/templates pré-compilados (módulo) para 4.4.1 e 4.5.1, não GDExtension para a 4.3. A página da classe (`godotsteam.com/classes/multiplayer_peer/`) confirma `create_host` (unique_id 1), `create_client(steam_id)`, `host_with_lobby`, `connect_to_lobby`, `get_peer_id_for_steam_id`/`get_steam_id_for_peer_id`.

**Escolhido:** GodotSteam GDExtension **4.15**, build 4.1–4.3.
- URL: `https://codeberg.org/godotsteam/godotsteam/releases/download/v4.15-gde/godotsteam-4.15-gdextension-plugin-4.1-4.3.zip`
- sha256 do zip: `678f67e68b9c4b732c1b6c69b1a9f362b74e80f0a103dc63953583a5de6ee173` (11.547.745 bytes; 33 arquivos, 37 MB descompactado)
- `godotsteam.gdextension`: `entry_symbol = "godotsteam_init"`, `compatibility_minimum = "4.1"`, dependências `steam_api64.dll` / `libsteam_api.so` / `libsteam_api.dylib`.
- Copiados para `addons/godotsteam/` (só win64 e linux64, mais o `.gdextension`, `license.txt` e `readme.md`):

| Arquivo | sha256 |
| :--- | :--- |
| `win64/libgodotsteam.windows.template_debug.x86_64.dll` | `4b188e9848c0d92eef4f529cc90e15238ea9a4a9d7faea7a4daba6691e936342` |
| `win64/libgodotsteam.windows.template_release.x86_64.dll` | `c591649848f6804c3bd7eea4d204f32738bbbc39195f3bff20fc92b6a4077f40` |
| `win64/steam_api64.dll` (assinatura Authenticode **válida, Valve Corp.**) | `e082bf5c9f881c822b1540a76b74f9d15e18019a73ebd206a559595badcb7f65` |
| `linux64/libgodotsteam.linux.template_debug.x86_64.so` | `d922b4accd2233364cb9aef56a35d6e07f105193eb4c5adb620ef55032929c7a` |
| `linux64/libgodotsteam.linux.template_release.x86_64.so` | `88d3c767c2bc75d91c0330567065a3d0b90565b66fa5e2b3a78394a5cba0dd0c` |
| `linux64/libsteam_api.so` | `0f2c41c20644503c17e13498203986493332fc8296dbd78493bc1fed352ec0cc` |

As DLLs do GodotSteam não são assinadas (normal para o projeto).

Saída real (`core/tests/steam_spike_probe.gd`, trecho):
```
PROBE godot=4.3-stable (official)
PROBE class_exists(Steam)=true has_singleton=true
PROBE SteamMultiplayerPeer=false MultiplayerPeerExtension=true
PROBE total_methods=759
PROBE steamInitEx(app_id:int) defaults=[0] -> Dictionary
PROBE createLobby(lobby_type:int, max_members:int) defaults=[2] -> Nil
PROBE addRequestLobbyListStringFilter(key_to_match:String, value_to_match:String, comparison_type:int) defaults=[] -> Nil
PROBE sendMessageToUser(remote_steam_id:int, data:PackedByteArray, flags:int, channel:int) defaults=[] -> int
PROBE receiveMessagesOnChannel(channel:int, max_messages:int) defaults=[] -> Array
PROBE signal join_requested(lobby_id, steam_id)
PROBE signal network_messages_session_request(remote_steam_id)
PROBE RESULT fails=0
```
Init (`core/tests/steam_spike_init.gd`), **sem** `steam_appid.txt` (o `steamInitEx(480)` resolve o App ID sozinho):
```
INIT steamInitEx(480) -> { "status": 0, "verbal": "" } em 963 ms
INIT ok=true isSteamRunning=true getAppID=480
PASS SteamID válido
```
O próprio SDK da Steam imprime `SteamInternal_SetMinidumpSteamID: Caching Steam ID: <SteamID completo>` no stdout: cuidado ao colar logs em issues.

**Custo de subir a Godot para usar o peer do GodotSteam (4.4.1+/4.5):** migração do projeto inteiro (arquivos `.uid` para scripts na 4.4, mudanças de API e de comportamento entre versões, revisar cenas/recursos, `GODOT_VERSION` do CI, os editores dos dois devs, o GUT compatível, e repetir toda a regressão). Ganha-se um peer em C++ mantido pelo GodotSteam; perde-se a estabilidade atual. Não fiz esse teste: é decisão do usuário.

## 2. Lobby e código

`core/tests/steam_spike_lobby.gd` (saída real):
```
LOBBY busca {  } -> 50 lobbies em 328 ms
LOBBY ruído 480: 50 (amostra name|game: ["|", "|", "|", "|", "kzin1|"])
PASS lobby_created connect=1: [[1, 109775240989796482]] em 365 ms
PASS setLobbyData game
PASS setLobbyData scandig_code=UQ46K8
PASS setLobbyData scandig_ver
PASS dono do lobby é o host
PASS 1 membro (o host)
PASS getLobbyData devolve o código
LOBBY busca { "game": "scandig", "scandig_code": "UQ46K8" } -> 1 lobbies em 311 ms
PASS busca pelo código acha o lobby: [109775240989796482]
LOBBY busca { "game": "scandig", "scandig_code": "ZZZZZZ" } -> 0 lobbies em 373 ms
PASS código inexistente não acha nada: []
LOBBY busca { "game": "scandig" } -> 1 lobbies em 379 ms
LOBBY busca { "game": "scandig", "scandig_code": "UQ46K8", "scandig_ver": "999" } -> 0 lobbies em 379 ms
PASS versão de protocolo diferente filtra: []
LOBBY busca { "game": "scandig", "scandig_code": "UQ46K8" } -> 0 lobbies em 310 ms
PASS lobby some da busca depois do leaveLobby: []
RESULT fails=0
```
- **App ID 480:** a busca sem filtro devolve o máximo pedido (50) de lobbies de outros jogos de teste. Com `game=scandig` + `scandig_code=<6>` (+ `scandig_ver`), a busca é **confiável**: o servidor da Steam filtra pela igualdade exata das chaves; 32⁶ ≈ 1,07 bilhão de códigos. Outro jogo de teste só colidiria se usasse as mesmas chaves e o mesmo código. Com o App ID próprio, o ruído some.
- A busca só devolve lobbies **públicos** (`LOBBY_TYPE_PUBLIC = 2`). Entrar pelo código exige lobby público; um lobby "só amigos" só funciona pelo convite. Com o lobby público, quem tiver o código entra (como no noray).
- `setLobbyData` vale na hora no host; a busca feita de outro processo (que começou uns 7 s depois de o lobby ser criado) também achou o lobby (item 4).
- Para mostrar um erro melhor de versão ("atualize o jogo"), a Fase 1 pode buscar sem o `scandig_ver` e comparar depois.

## 3. Peer na Godot (`core/steam_peer.gd`)

`SteamPeer extends MultiplayerPeerExtension` (GDScript, tipado, cerca de 400 linhas), com o transporte injetado:
- `SteamPeer.SteamTransport`: **Steam Networking Messages** (`sendMessageToUser`/`receiveMessagesOnChannel`, sessões por SteamID, relay **SDR** da Steam automático, sem porta aberta). Só aceita pedido de sessão de quem é membro do lobby (`lobby_id`).
- `SteamPeer.UdpTransport`: o **mesmo protocolo** sobre UDP em 127.0.0.1, só para testar dois processos numa conta.
- Topologia estrela, `_is_server_relay_supported() = true`: o cliente só fala com o host; o `SceneMultiplayer` repassa cliente → cliente (igual ao ENet).
- Protocolo: `[tipo:u8][remetente:u32]…`; HELLO (cliente → host, com versão do protocolo), WELCOME, REJECT (cheio/versão), DATA (`[canal][modo][payload]`), BYE e PING (1 s; queda por timeout de 10 s). O host só aceita dados do SteamID registrado para aquele peer id (sem forjar remetente).
- **Ids:** host = `1` (`get_unique_id()` e `is_server()` conferidos com o peer da Steam ativo); clientes = `generate_unique_id()`. `get_remote_for_peer(peer_id)` → SteamID e `get_peer_for_remote(steam_id)` → peer id. No cliente, só o host é conhecido; os SteamIDs dos outros vêm dos membros do lobby.
- `reliable` → envio Reliable|NoNagle (9); `unreliable`/`unreliable_ordered` → Unreliable|NoNagle (1). Limite de 512 KiB por mensagem.
- Gancho só do spike no `NetworkManager`: `--spike-peer=udp` troca o ENet do `host_game`/`join_game` pelo `SteamPeer` + UDP; `spike_install_host(peer)`/`spike_install_client(peer)` instalam qualquer peer com a mesma lista de jogadores e os mesmos sinais do ENet.

Testes de rede **existentes, sem mudar uma linha**, com `-- --spike-peer=udp` (saída real):
```
### net_host / net_client
HOST scene_ready=[1, 785811683] client_id=785811683 ok=true signals=["1:praia", "785811683:praia"]
HOST day=2 money=300
CLIENT scene_after_join=MapPraia in_exp=true
CLIENT summary_entries=[{ "name": "Aliança de Ouro", "action": "donated", "value": 200 }]
CLIENT RESULT fails=0
### net_host_multi + net_client_multi A/B (3 peers, relay cliente -> cliente)
HOST ready=[1, 1721686741, 1915312864] ok=true ...
HOST race pinpointer=1 money=7 now=8 history=[507, 507, 7, 8]
HOST RESULT fails=0
CLIENT_A RESULT fails=0
CLIENT_B rejoin scene=LobbyBase day=2 money=8 pinpointer=1
CLIENT_B RESULT fails=0
### net_names (3 peers)
HOST RESULT fails=0 / CLIENT_A RESULT fails=0 / CLIENT_B RESULT fails=0
### net_host_drop / net_client_drop
CLIENT host_lost=true scene=LobbyBase in_exp=false
```
Host Steam de verdade + expedição solo (`core/tests/steam_spike_host_flow.gd`):
```
PASS lobby criado
FLOW lobby code=6YJ-DEC
PASS SteamPeer host
PASS get_unique_id()=1 e is_server() com o peer da Steam
PASS GameState é autoridade
PASS entrou na Praia
PASS voltou ao lobby com resumo
PASS dia 2, R$ 300, aliança no museu: dia 2 R$ 300
RESULT fails=0
```
Nota para o Dev A: encerrar o mapa no mesmo frame em que ele abre dá `SCRIPT ERROR: Invalid access to property or key 'physics_frame' on a base object of type 'null instance'` em `gameplay/digging/spot_spawner.gd:49` (o `_ready` espera 2 `physics_frame` depois de o nó sair da árvore). O teste espera 2 s antes de encerrar; no jogo é improvável, mas vale um `if not is_inside_tree(): return` depois do `await`.

## 4. O que dá para validar com uma conta

| Item | Resultado |
| :--- | :--- |
| Init (480), SteamID, relay (`initRelayNetworkAccess`) | OK |
| Criar lobby, gravar dados, buscar pelo código | OK (também de outro processo) |
| Peer de host da Steam na árvore + expedição solo | OK |
| Dois peers Steam na mesma conta | **Impossível** |

"Loopback" para o próprio SteamID (saída real): a Steam cria um "pipe", entrega a primeira mensagem e fecha; `acceptSessionWithUser(próprio SteamID)` devolve `false`:
```
D send ch0 -> 1 state=1
D session_request -> accept false
D session_failed 0 4 The remote host closed the connection.
D recv ch0 payload=hi0
D send ch1 -> 35 state=4
```
Segundo processo com a mesma conta (`steam_spike_pc.gd -- join=2JL-GYK`): acha o lobby e o `joinLobby` responde sucesso, mas o P2P para o dono (a própria conta) vira um pipe local e o host nunca recebe o HELLO:
```
PASS busca pelo código achou 1 lobby: [109775240990836638]
PASS entrou no lobby: [109775240990836638, 1]
FAIL conectou ao host em 21236 ms
CLIENT conexão: estado=4 ping=-1 pop_relay=0 remote_pop=0 descr=#1551606692 pipe
```
O mesmo crash na saída apareceu uma vez com lambdas ligadas ao singleton `Steam` depois do `steamShutdown` ("Dumping the backtrace"): desconecte os sinais antes do `steamShutdown`, como o `steam_spike_pc.gd` faz.

### Roteiro para 2 PCs (Dev B e Felipe, contas Steam diferentes)
1. Os dois PCs: Godot 4.3 em `C:\Godot\`, Steam aberta e logada (contas diferentes), o branch `spike/steam-54` (precisa ser publicado, ou copie a pasta da worktree) e o import uma vez: `"C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --editor --quit-after 600`.
2. **PC 1 (host):** `"C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/steam_spike_pc.gd -- host`
   - Aparece `HOST ===== CÓDIGO DA SALA: K7Q-3MX =====`. Mande o código. O host espera até 5 min (`wait=<s>` muda).
3. **PC 2 (cliente):** `"C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/steam_spike_pc.gd -- join=K7Q-3MX`
4. Esperado:
   - cliente: `PASS busca pelo código achou 1 lobby`, `PASS entrou no lobby`, `PASS conectou ao host em <n> ms`, `PASS entrou na Praia`, `PASS voltou ao lobby com o resumo`, `PASS estado do host: dia 2 R$ 300 ["alianca_ouro"]`, `CLIENT RESULT fails=0`;
   - host: `PASS um cliente entrou`, `PASS cliente carregou a Praia (peer_scene_ready)`, `PASS dia 2, R$ 300`, `HOST RESULT fails=0`.
5. Anote as linhas `conexão: estado=… ping=… pop_relay=… remote_pop=…`: `pop_relay`/`remote_pop` diferentes de 0 indicam o relay da Steam (SDR); 0 com ping baixo indica conexão direta.
6. Repita com um dos PCs no **hotspot do celular** (CGNAT) e veja se conecta e qual o ping.
7. Opcional (3–4 jogadores): mais contas rodando o passo 3 com o mesmo código antes de o host começar (o roteiro atual espera 1 cliente; a Fase 1 testa 4).

## 5. Convite pela Steam
- **Convidar:** `Steam.activateGameOverlayInviteDialog(lobby_id)` abre o overlay da Steam com a lista de amigos.
- **Aceitar com o jogo aberto:** a Steam emite `join_requested(lobby_id, friend_steam_id)` → `joinLobby(lobby_id)` → `lobby_joined(lobby, …, response=1)` → `getLobbyOwner(lobby)` → `SteamPeer.create_client(transport, owner)`. O mesmo caminho do código, sem a busca.
- **Aceitar com o jogo fechado:** a Steam abre o jogo com `+connect_lobby <lobby_id>` nos argumentos; o `NetworkManager` lê isso no `_ready` (depois do init da Steam) e entra quando o menu estiver pronto.
- **Limitação:** o overlay geralmente só funciona quando o jogo é aberto pela Steam (a documentação do GodotSteam avisa isso). Com o App ID 480 e o jogo rodando pelo editor, o convite provavelmente não abre. Testar com o App ID próprio ou numa build lançada pela Steam.

## 6. Sem a Steam (testado sem fechar a Steam do usuário)
```
### fake (classe ausente)          INIT has_steam_class=false / INIT steam indisponível: segue sem Steam
### skip (sem init)                ERROR: [STEAM] User class not found when calling: getSteamID
### appid=1                        INIT steamInitEx(1) -> { "status": 1, "verbal": "ConnectToGlobalUser failed." } em 78 ms
### appid=999999999                INIT steamInitEx(999999999) -> { "status": 1, "verbal": "ConnectToGlobalUser failed." } em 53 ms
```
Sem a biblioteca nativa (pasta `win64` tirada temporariamente):
```
ERROR: GDExtension dynamic library not found: …/addons/godotsteam/win64/libgodotsteam.windows.template_debug.x86_64.dll
ERROR: Error loading extension: res://addons/godotsteam/godotsteam.gdextension
INIT has_steam_class=false
SKIP steam (sem GodotSteam)        (steam_spike_host_flow)
flow_test: RESULT fails=0; cenas map_praia/test_sandbox: 0 SCRIPT ERROR; GUT: Passing 128, All tests passed
```
Mas um script que escreve `Steam.isSteamRunning()` direto **quebra** sem a biblioteca:
```
SCRIPT ERROR: Parse Error: Identifier "Steam" not declared in the current scope.
```
Conclusão: o jogo abre com solo, rede local e noray mesmo sem Steam, desde que todo acesso passe por `Engine.get_singleton("Steam")` num único lugar (proposta: `core/steam_service.gd`). Chamadas depois de um init falho só dão `ERROR: [STEAM] … class not found` (sem crash); a Fase 1 deve checar `is_steam_available()` antes.

## 7. Testes sem tela e CI
- Com o addon instalado (Windows, Steam aberta, mas nenhum teste chama o init): GUT **128/128**; `boss_authority`, `campo_flow`, `campo_quest_secret`, `expedition_ending`, `flow`, `leave_session`, `map_pools`, `map_unlock`, `money_format`, `purchase_item`, `quest_secret`, `room_code`, `save_flow`, `scene_ready`, `upgrade_lock`, `upgrade` e `value_cap`: todos `RESULT fails=0`; `net_host`/`net_client` (ENet): `CLIENT RESULT fails=0`, `HOST day=2 money=300`; as cenas do CI sem `SCRIPT ERROR`. O md5 do save do usuário não mudou.
- **CI (ubuntu-latest, sem Steam):** a `.so` do GodotSteam precisa de `libstdc++` com `GLIBCXX_3.4.29` (Ubuntu 22.04+); o runner 24.04 tem. Se ela não carregar, a Godot só imprime `ERROR` (o CI procura `SCRIPT ERROR`) e o resto roda, como no teste sem a biblioteca. **Não rodei o CI** (sem push).
- Para blindar: (a) acesso só por `Engine.get_singleton`; (b) nada chama o init em teste, a não ser os `steam_spike_*`/futuros testes de Steam, que dão `SKIP` sem a Steam; (c) se preferir, `.gitattributes` com `*.dll binary`, `*.so binary`, `*.dylib binary`; (d) opcional: um passo do CI que confere que `addons/godotsteam/linux64/*.so` carrega (`ldd`).

## 8. Peso, distribuição e licença
- Zip oficial: 11,5 MB (37 MB descompactado, todas as plataformas). No repositório deste spike: **13 MB** (win64 5,6 MB + linux64 7,3 MB, debug e release).
- Build Windows exportada: `libgodotsteam.windows.template_release.x86_64.dll` (2,4 MB) e `steam_api64.dll` (0,3 MB) ao lado do `.exe`; o export copia os dois pelo `.gdextension` (`[dependencies]`). Usar os templates normais da Godot (não os do GodotSteam). **Não** distribuir `steam_appid.txt` (a documentação de exportação do GodotSteam diz que a Valve recomenda não enviar).
- Licença do GodotSteam: **MIT** (`addons/godotsteam/license.txt`, "Copyright (c) 2015-Current | GP Garcia and Contributors"): manter o aviso de copyright nos créditos/licenças do jogo.
- `steam_api64.dll`: vem da pasta `redistributable_bin` do SDK da Steam ("Steamworks API redistributable binaries", partner.steamgames.com/doc/sdk). Ela é feita para ir junto com o jogo, sob o acordo de acesso ao SDK da Steam que o estúdio aceita ao virar parceiro (Steam Direct). Não achei o texto público do acordo; conferir no portal de parceiros quando o App ID próprio for comprado.

## Proposta de contrato (Fase 1)
```gdscript
# core/steam_service.gd (autoload novo, único lugar que fala com o singleton "Steam")
signal steam_status_changed(available: bool, message: String)   # depois do init no _ready (e se cair)
func is_steam_available() -> bool                               # init OK com a Steam aberta
func get_persona_name() -> String                               # nome da conta, para preencher o nome do jogador

# core/network_manager.gd (mesma API de sessão; o peer vira SteamPeer)
func host_steam() -> Error           # cria o lobby público (máx. 4), grava game/scandig_code/scandig_ver;
                                     # reusa room_code_ready(code) e online_join_progress("registrando")
func join_steam(code: String) -> Error   # busca pelo código → joinLobby → SteamPeer.create_client;
                                     # online_join_progress: "buscando" → "entrando" → "conectado"
func open_steam_invite() -> void     # activateGameOverlayInviteDialog(lobby atual); só host/cliente em sala Steam
func is_steam_room() -> bool
# Convite: join_requested (jogo aberto) e +connect_lobby (jogo fechado) chegam no NetworkManager:
signal steam_invite_received(friend_name: String)   # a UI confirma se o jogador já está numa sessão
func accept_steam_invite() -> Error                 # entra no lobby do convite (mesmo fluxo e sinais do join_steam)
```
- Mesmos sinais de hoje: `connection_succeeded`, `connection_error(message)` (textos novos: "Steam indisponível.", "Sala não encontrada.", "Sala cheia.", "Versão diferente do jogo.", "Não foi possível conectar ao amigo."), `session_left`, `server_disconnected`. `disconnect_game()` também sai do lobby.
- `host_game`/`join_game` (ENet) e `host_online`/`join_code` (noray) continuam para desenvolvimento e testes sem tela; a UI de lançamento mostra só a Steam quando `is_steam_available()`.
- O peer nunca fica `null`: ao sair, `OfflineMultiplayerPeer`.

## Riscos
1. **Peer em GDScript:** cada pacote passa por GDScript (cópias de `PackedByteArray`). Medir com 4 jogadores na Praia (o spike do noray mediu ~300 pacotes/s com 2). Se pesar, plano B: subir a Godot e usar o peer em C++ do GodotSteam.
2. **`unreliable_ordered` vira `unreliable`:** as Networking Messages não ordenam o não confiável; um pacote de sync antigo pode chegar depois de um novo. Avaliar nos testes de 2 PCs (MultiplayerSynchronizer) e, se precisar, numerar os pacotes por canal no `SteamPeer`.
3. **Queda detectada em até 10 s** (timeout do PING). Dá para reduzir ouvindo `network_messages_session_failed` e `lobby_chat_update` (membro saiu).
4. **Não validado com 2 contas:** handshake real, SDR, CGNAT e convite dependem do roteiro de 2 PCs.
5. **App ID 480:** é compartilhado e público; a busca é confiável pelos filtros, mas o status "jogando Spacewar" aparece para os amigos, e conquistas/estatísticas não são nossas. Trocar pelo App ID próprio antes de qualquer teste aberto.
6. **Lobby público + código:** quem tiver o código entra (como no noray). Para "só amigos", usar convite.
7. **Versão travada na 4.15:** última build GDExtension para a 4.3 (Steamworks 1.62); correções novas do GodotSteam (4.16+) não chegam a ela.
8. **Overlay/convite:** pode não funcionar fora de uma build lançada pela Steam.
9. Crash na saída se sinais do singleton `Steam` ficarem ligados a lambdas depois do `steamShutdown`.

## Arquivos do spike
- `addons/godotsteam/` (GodotSteam 4.15, win64 + linux64), commit separado.
- `core/steam_peer.gd`: `SteamPeer` (+ `SteamTransport`, `UdpTransport`).
- `core/network_manager.gd`: só o gancho `--spike-peer=udp` e `spike_install_host`/`spike_install_client` (nada muda sem a flag).
- `core/tests/steam_spike_probe.gd`, `steam_spike_init.gd` (`-- appid=<n>|skip|fake`), `steam_spike_lobby.gd`, `steam_spike_host_flow.gd`, `steam_spike_pc.gd` (2 PCs).
