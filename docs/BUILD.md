# ScanDig: build do Windows (#101)

## Preset
`export_presets.cfg`, preset **"Windows Desktop"**:
- x86_64, PCK embutido no `.exe` (`binary_format/embed_pck=true`), saída `build/windows/ScanDig.exe` (`build/` está no `.gitignore`).
- `exclude_filter`: `tests/*, core/tests/*, ui/tests/*, addons/gut/*, tools/*, docs/*, _ext/*, .bot_runs/*, build/*, *.md, *.py, *.sh, *.bat`. Nada de runtime carrega dessas pastas. O `DebugBridge` (autoload) **fica** no build: só roda em build de debug com `--bot=`, então no release não faz nada.
- Console wrapper (`ScanDig.console.exe`) só no export de **debug**; o release publicado é só o `.exe`.
- Ícone e metadados (`application/modify_resources=true`): `assets/icon/scandig.ico`, versão `0.1.0.0` (arquivo e produto), empresa "ScanDig Team", produto "ScanDig". A Godot grava isso no `.exe` com o **rcedit**; sem ele configurado, o export sai com o ícone e os dados da Godot.

## Ícone
- Fonte: `assets/icon/scandig_icon.svg` (também é o `config/icon` do projeto, o ícone da janela).
- `.ico` (16, 32, 48, 64, 128 e 256 px, entradas PNG): depois de mudar o SVG, rode `$G --headless --path . --script res://tools/make_icon.gd` e commite `assets/icon/scandig.ico`.

## Versão (#138)
- Fonte única: `application/config/version` no `project.godot` (formato `a.b.c`, só números).
- `tools/sync_version.sh` copia para `application/file_version`/`product_version` do `export_presets.cfg` (`0.1.0` vira `0.1.0.0`); `--check` só confere. O GUT (`tests/dev_b/test_build_version.gd`), o build do CI e o release falham se divergir.
- Tela inicial: `v0.1.0` no release; no build de **debug** (editor ou `--export-debug`) acrescenta o commit, `v0.1.0 (a1b2c3d)`. O commit vem de `res://build_info.json`, gerado por `tools/write_build_info.sh` (o CI roda antes do export; fora do git, levado pelo `include_filter`). Sem ele aparece `v0.1.0 (dev)`. O jogo não chama git em runtime.

## Local (Windows)
1. Templates da 4.3 (uma vez): baixe `Godot_v4.3-stable_export_templates.tpz` (~1 GB, é um zip) da página de releases da Godot e extraia `templates/*` para `%APPDATA%/Godot/export_templates/4.3.stable/`. Para este preset bastam `version.txt` e os `windows_*_x86_64*.exe`.
2. rcedit (ícone e metadados): baixe o `rcedit-x64.exe` (release oficial do electron/rcedit; o CI usa a v2.0.0) e aponte o editor para ele em *Editor → Configurações do Editor → Exportar → Windows → rcedit* (`export/windows/rcedit` em `%APPDATA%/Godot/editor_settings-4.3.tres`).
3. Exportar:
   ```bash
   G=/c/Godot/Godot_v4.3-stable_win64_console.exe
   $G --headless --path . --import
   mkdir -p build/windows
   $G --headless --path . --export-release "Windows Desktop" build/windows/ScanDig.exe
   ```
   Uma linha `ERROR: Config File "user://gut_temp_directory/gut_editor_config.json" does not exist.` é do plugin GUT do editor, não do jogo.
4. Conferir: `(Get-Item build/windows/ScanDig.exe).VersionInfo` no PowerShell mostra a versão e a empresa; o Explorer mostra o ícone do ScanDig.
5. O `.exe` abre na tela inicial. **Ele é o jogo de verdade**: na 1ª vez migra o `scandig_save.json` do `user://` para o slot 1 (#100). Faça backup antes, se for só testar.
6. Para conferir gameplay pelo pacote exportado, use um export de **debug** (`--export-debug "Windows Desktop" build/windows_debug/ScanDig.exe`) e rode `ScanDig.console.exe --headless -- --bot=<roteiro.json>` (ex.: com `{"start_expedition": "praia"}`). No release, `--bot=` é ignorado.

## CI
Job `export-windows` em `.github/workflows/ci.yml`, com os passos no workflow reutilizável `.github/workflows/build-windows.yml` (o mesmo do release; runner **windows-latest**, por causa do rcedit):
- roda depois do `tests`, só em push no `main` ou `workflow_dispatch` (PR não exporta);
- confere a versão (`tools/sync_version.sh --check`) e grava o `build_info.json` com o commit;
- Godot win64; templates em cache (`actions/cache`, chave `godot-export-templates-4.3-stable-windows-x86_64-win`); no cache miss, baixa o `.tpz` e extrai só os do Windows x86_64;
- baixa o rcedit v2.0.0 (SHA-256 conferido) e escreve `export/windows/rcedit` no `editor_settings-4.3.tres` do runner;
- confere `VersionInfo` do `.exe` (empresa e a versão do `project.godot`) e falha se o rcedit não tiver gravado;
- falha sem o `.exe`, com `SCRIPT ERROR` ou com `ERROR: ` no log (fora a linha do GUT acima);
- publica o artifact **ScanDig-windows** (`ScanDig-windows.zip`, 14 dias). O GitHub entrega o artifact dentro de outro zip.

## Lançar uma versão (#138)
`.github/workflows/release.yml` reusa o `build-windows.yml`, gera o CHANGELOG (`tools/changelog.sh`: commits convencionais desde a tag `v*` anterior, agrupados em feat/fix/perf/docs/test/chore e "Outros") e cria a GitHub Release em **draft** com o `ScanDig-windows.zip`.
1. **Ensaio (dry-run)**, opcional: `gh workflow run release.yml -f dry_run=true` (ou *Actions → Release → Run workflow*). Não cria release: os artifacts `ScanDig-windows` (zip) e `release-notes` (`CHANGELOG.md`) ficam no run (`gh run view <id>`), e o changelog aparece no resumo do run.
2. **Bump**: suba `application/config/version` no `project.godot` (ex.: `0.2.0`), rode `tools/sync_version.sh` e commite os dois arquivos (`chore(release): v0.2.0`). Espere o CI verde no `main`.
3. **Tag** no commit do bump, igual à versão: `git tag -a v0.2.0 -m "ScanDig v0.2.0"` e `git push origin v0.2.0`. O release falha se a tag não bater com o `config/version`.
4. **Revisar o draft** em *Releases*: baixe o zip, abra o jogo (título mostra `v0.2.0`) e ajuste as notas (o changelog sai dos títulos dos commits).
5. **Publicar**: *Edit → Publish release* (ou `gh release edit v0.2.0 --draft=false`).
- Sem tag, `gh workflow run release.yml -f dry_run=false` cria o draft da tag `v<config/version>` no commit atual; o GitHub só cria a tag ao publicar.
- O release não roda o GUT: marque a tag só num commit do `main` com o CI verde.

## Pendências
- Assinatura de código (`codesign/*`): sem certificado; o Windows SmartScreen avisa na 1ª execução.
