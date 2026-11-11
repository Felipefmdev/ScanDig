# Gate dirigido do Museu (#215)

Entry com renderer real, fora da descoberta `*_test.gd` do runner headless.
Sua execução por Root/revisor é obrigatória antes do merge; o rename não dispensa o gate.
Não usar `--headless` ou renderer dummy como aceite deste entry.

Somente após inventário atual de processos Godot vazio e transferência explícita da
lease por Root, executar com Godot 4.3, perfil de usuário isolado e projeto importado.
Não encerrar processos do usuário. A partir da raiz do candidato (PowerShell):

```powershell
& $Godot --path . --windowed --resolution 1280x720 --script res://ui/tests/base_museum_layout_renderer.gd
```

`$Godot` deve apontar para o binário aprovado por Root. Não passar `--dev-ui`:
o fluxo verifica a simulação oculta por padrão. Depende dos autoloads normais,
`lobby_base.tscn`, `BaseStationUI`, `MuseumView`, catálogo e Theme/fontes importados.

Gate obrigatório antes do merge: saída nativa e wrapper 0, sem timeout, sem
`SCRIPT ERROR`, `Parse Error` ou linhas `FAIL`, e linhas finais exatas
`CHECKS count=36` e `RESULT fails=0`. Preservar stdout/stderr completos; diagnóstico
de shader cache não autoriza chamar o log de limpo ou ignorar falhas.

Antes da execução, congelar no manifesto o HEAD completo do candidato e SHA256
das fontes executadas, incluindo este entry e documento, BaseStationUI `.gd`/`.tscn`
e dependências, além de comando, binário/versão, renderer, resolução e perfil.
Após a execução, conferir HEAD/fontes iguais e registrar saídas e hashes dos logs.
Mudança de fonte invalida o aceite para o novo estado; evidência histórica não o substitui.

O entry cobre dados, foco, navegação e vitrine; não gera PNGs nem certifica
acabamento de quebra de palavras, hardware físico, coop ou campanha.
