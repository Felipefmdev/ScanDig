# Gate dirigido das fontes nas cinco lojas (#216)

Entry com renderer real, fora da descoberta `*_test.gd` do runner headless.
Sua execução por Root/revisor é obrigatória antes do merge; o rename não dispensa o gate.
Não usar `--headless` ou renderer dummy como aceite. A assertiva que exige display
real permanece no script e não deve ser removida para obter aprovação headless.

Somente após inventário atual de processos Godot vazio e transferência explícita da
lease por Root, executar com Godot 4.3, perfil de usuário isolado e projeto importado.
Não encerrar processos do usuário. A partir da raiz do candidato (PowerShell):

```powershell
& $Godot --path . --windowed --resolution 2560x1440 --script res://ui/tests/shop_maps_praia_fonts_renderer.gd
```

`$Godot` deve apontar para o binário aprovado por Root. Depende de
`shop_distance_legibility.gd`, `world_shop_typography.gd`, `upgrade_counter.tscn`,
ShopOffer/ToolData/Interactable, Theme e fontes importados. O candidato inclui o
bootstrap/autoload do commit pai `d646e46`; não aplicar somente `eb91932` sobre main.

Gate obrigatório antes do merge: saída nativa e wrapper 0, sem timeout, sem
`SCRIPT ERROR`, `Parse Error` ou linhas `FAIL`, e linhas finais exatas
`CHECKS count=63` e `RESULT fails=0`. Preservar stdout/stderr completos; diagnóstico
de shader cache não autoriza chamar o log de limpo ou ignorar falhas.

Antes da execução, congelar no manifesto o HEAD completo do candidato e SHA256
das fontes executadas, incluindo este entry e documento, driver, `project.godot`
e dependências, além de comando, binário/versão, renderer, resolução e perfil.
Após a execução, conferir HEAD/fontes iguais e registrar saídas e hashes dos logs.
Mudança de fonte invalida o aceite para o novo estado; evidência histórica não o substitui.

As cinco fixtures usam ofertas e contador reais, sem carregar os cinco mapas reais.
O gate verifica fontes, restauração, foco e fade; não certifica nitidez visual,
oclusões, proporções autoradas, compras, entrada em expedição, coop ou hardware físico.
