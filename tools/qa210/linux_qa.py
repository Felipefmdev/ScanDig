"""#210: supervisor QA revisável. Importar este módulo não inicia processos.

Somente --execute permite duas chamadas Godot no máximo; requer Ubuntu24.04,
janela GitHub Actions e hashes explicitamente fixados na revisão. Sem instalação/download.
"""
import argparse
import collections
import shutil
import hashlib
import json
import os
import platform
import re
import signal
import stat
import subprocess
import sys
import time
from pathlib import Path

TREE = "cbfe567ca115c0b536814f5e4a57d771d9e80f71"
OBSERVATION_TREE = 'a500e509407eef37bda6e1cb713a741224d54d8e'
COMMIT = "748e90cee8cd69e68a78b4006e9f512cd18f22d8"
TARGET = "res://tests/unit/test_world_upgrade_shop.gd"
VERSION = "Godot Engine v4.3.stable.official.77dcf97d8"
IMPORT_TIMEOUT = 180
GUT_TIMEOUT = 60
FATAL = r"(?im)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR: Failed to load (?:script|resource)|Segmentation fault|Access violation|CrashHandlerException)"

GENERATED = ("translations/scandig.en.translation", "translations/scandig.pt_BR.translation")
KNOWN_IMPORT_ERRORS = {'ERROR:  Config File "user://gut_temp_directory/gut_editor_config.json" does not exist.': 1,
 "ERROR: Cannot open file 'res://.godot/imported/AnonymousPro-Regular.ttf-856c843fd6f89964d2ca8d8ff1724f13.fontdata'.": 1,
 "ERROR: Cannot open file 'res://.godot/imported/CourierPrime-Regular.ttf-3babe7e4a7a588dfc9a84c14b4f1fe23.fontdata'.": 2,
 "ERROR: Cannot open file 'res://.godot/imported/Kalam-Bold.ttf-612b252b6d06ecd5ccf3d4df1ec5d0f4.fontdata'.": 1,
 "ERROR: Cannot open file 'res://.godot/imported/PatrickHand-Regular.ttf-1d6c3f8e56c805f17996754a182c2037.fontdata'.": 1,
 'ERROR: Failed loading resource: res://.godot/imported/AnonymousPro-Regular.ttf-856c843fd6f89964d2ca8d8ff1724f13.fontdata. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://.godot/imported/CourierPrime-Regular.ttf-3babe7e4a7a588dfc9a84c14b4f1fe23.fontdata. Make sure resources have been imported by opening the project in the editor at least once.': 2,
 'ERROR: Failed loading resource: res://.godot/imported/Kalam-Bold.ttf-612b252b6d06ecd5ccf3d4df1ec5d0f4.fontdata. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://.godot/imported/PatrickHand-Regular.ttf-1d6c3f8e56c805f17996754a182c2037.fontdata. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://.godot/imported/arrow.png-2b5b2d838b5b3467cf300ac2da1630d9.ctex. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://.godot/imported/arrow_down.png-8b49e0e2dda4a7dd04bd525c4b675791.ctex. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://.godot/imported/green.png-e3a17091688e10a7013279b38edc7f8a.ctex. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://.godot/imported/paper_worn.png-cde56479daaf4d7ad51c5fafb18b40f8.ctex. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://.godot/imported/play.png-5c90e88e8136487a183a099d67a7de24.ctex. Make sure resources have been imported by opening the project in the editor at least once.': 2,
 'ERROR: Failed loading resource: res://.godot/imported/radio_checked.png-3f228d96cbbddcefa2e143973bc02ea5.ctex. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://.godot/imported/radio_unchecked.png-ee36e57221249cc6f59d4cfcf66eb372.ctex. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://.godot/imported/red.png-47a557c3922e800f76686bc1a4ad0c3c.ctex. Make sure resources have been imported by opening the project in the editor at least once.': 2,
 'ERROR: Failed loading resource: res://.godot/imported/slider_grabber.png-f4816697a071975cae82ece1fc7ed131.ctex. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://.godot/imported/slider_grabber_disabled.png-a970510e1556f1fe1dc99fc05135eace.ctex. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://.godot/imported/slider_grabber_hover.png-f79909986c6b0ce8af714c33afcf48b3.ctex. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://.godot/imported/yellow.png-b3cf3d463958a169d909273d3d742052.ctex. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://addons/gut/fonts/AnonymousPro-Regular.ttf. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://addons/gut/fonts/CourierPrime-Regular.ttf. Make sure resources have been imported by opening the project in the editor at least once.': 2,
 'ERROR: Failed loading resource: res://addons/gut/gui/arrow.png. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://addons/gut/gui/play.png. Make sure resources have been imported by opening the project in the editor at least once.': 2,
 'ERROR: Failed loading resource: res://addons/gut/images/green.png. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://addons/gut/images/red.png. Make sure resources have been imported by opening the project in the editor at least once.': 2,
 'ERROR: Failed loading resource: res://addons/gut/images/yellow.png. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://ui/theme/fonts/Kalam-Bold.ttf. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://ui/theme/fonts/PatrickHand-Regular.ttf. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://ui/theme/icons/arrow_down.png. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://ui/theme/icons/radio_checked.png. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://ui/theme/icons/radio_unchecked.png. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://ui/theme/icons/slider_grabber.png. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://ui/theme/icons/slider_grabber_disabled.png. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://ui/theme/icons/slider_grabber_hover.png. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Failed loading resource: res://ui/theme/paper_worn.png. Make sure resources have been imported by opening the project in the editor at least once.': 1,
 'ERROR: Unable to open file: res://.godot/imported/arrow.png-2b5b2d838b5b3467cf300ac2da1630d9.ctex.': 1,
 'ERROR: Unable to open file: res://.godot/imported/arrow_down.png-8b49e0e2dda4a7dd04bd525c4b675791.ctex.': 1,
 'ERROR: Unable to open file: res://.godot/imported/green.png-e3a17091688e10a7013279b38edc7f8a.ctex.': 1,
 'ERROR: Unable to open file: res://.godot/imported/paper_worn.png-cde56479daaf4d7ad51c5fafb18b40f8.ctex.': 1,
 'ERROR: Unable to open file: res://.godot/imported/play.png-5c90e88e8136487a183a099d67a7de24.ctex.': 2,
 'ERROR: Unable to open file: res://.godot/imported/radio_checked.png-3f228d96cbbddcefa2e143973bc02ea5.ctex.': 1,
 'ERROR: Unable to open file: res://.godot/imported/radio_unchecked.png-ee36e57221249cc6f59d4cfcf66eb372.ctex.': 1,
 'ERROR: Unable to open file: res://.godot/imported/red.png-47a557c3922e800f76686bc1a4ad0c3c.ctex.': 2,
 'ERROR: Unable to open file: res://.godot/imported/slider_grabber.png-f4816697a071975cae82ece1fc7ed131.ctex.': 1,
 'ERROR: Unable to open file: res://.godot/imported/slider_grabber_disabled.png-a970510e1556f1fe1dc99fc05135eace.ctex.': 1,
 'ERROR: Unable to open file: res://.godot/imported/slider_grabber_hover.png-f79909986c6b0ce8af714c33afcf48b3.ctex.': 1,
 'ERROR: Unable to open file: res://.godot/imported/yellow.png-b3cf3d463958a169d909273d3d742052.ctex.': 1}
CACHE_OUTPUTS = ['res://.godot/imported/AnonymousPro-Regular.ttf-856c843fd6f89964d2ca8d8ff1724f13.fontdata',
 'res://.godot/imported/CourierPrime-Regular.ttf-3babe7e4a7a588dfc9a84c14b4f1fe23.fontdata',
 'res://.godot/imported/Kalam-Bold.ttf-612b252b6d06ecd5ccf3d4df1ec5d0f4.fontdata',
 'res://.godot/imported/PatrickHand-Regular.ttf-1d6c3f8e56c805f17996754a182c2037.fontdata',
 'res://.godot/imported/arrow.png-2b5b2d838b5b3467cf300ac2da1630d9.ctex',
 'res://.godot/imported/arrow_down.png-8b49e0e2dda4a7dd04bd525c4b675791.ctex',
 'res://.godot/imported/green.png-e3a17091688e10a7013279b38edc7f8a.ctex',
 'res://.godot/imported/paper_worn.png-cde56479daaf4d7ad51c5fafb18b40f8.ctex',
 'res://.godot/imported/play.png-5c90e88e8136487a183a099d67a7de24.ctex',
 'res://.godot/imported/radio_checked.png-3f228d96cbbddcefa2e143973bc02ea5.ctex',
 'res://.godot/imported/radio_unchecked.png-ee36e57221249cc6f59d4cfcf66eb372.ctex',
 'res://.godot/imported/red.png-47a557c3922e800f76686bc1a4ad0c3c.ctex',
 'res://.godot/imported/slider_grabber.png-f4816697a071975cae82ece1fc7ed131.ctex',
 'res://.godot/imported/slider_grabber_disabled.png-a970510e1556f1fe1dc99fc05135eace.ctex',
 'res://.godot/imported/slider_grabber_hover.png-f79909986c6b0ce8af714c33afcf48b3.ctex',
 'res://.godot/imported/yellow.png-b3cf3d463958a169d909273d3d742052.ctex']


def digest(path):
    with open(path, "rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest().upper()


def blob_id(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def tree_id(entries):
    directories = {"": []}
    for entry in entries:
        path = Path(entry["path"])
        parent = path.parent.as_posix()
        parent = "" if parent == "." else parent
        directories.setdefault(parent, []).append((path.name, entry["mode"], entry["blob"]))
        while parent:
            ancestor = Path(parent).parent.as_posix()
            ancestor = "" if ancestor == "." else ancestor
            directories.setdefault(ancestor, [])
            parent = ancestor
    hashes = {}
    for directory in sorted(directories, key=lambda p: (p.count("/"), len(p)), reverse=True):
        items = list(directories[directory])
        for child, value in hashes.items():
            parent = Path(child).parent.as_posix()
            if ("" if parent == "." else parent) == directory:
                items.append((Path(child).name, "40000", value))
        items.sort(key=lambda row: (row[0] + ("/" if row[1] == "40000" else "")).encode())
        data = b"".join(mode.encode() + b" " + name.encode() + b"\0" + bytes.fromhex(value)
                        for name, mode, value in items)
        hashes[directory] = hashlib.sha1(b"tree " + str(len(data)).encode() + b"\0" + data).hexdigest()
    return hashes[""]


def verify_snapshot(root, entries, allow_cache=False):
    root = Path(root)
    errors = []
    expected = {entry["path"]: entry for entry in entries}
    for name, entry in expected.items():
        path = root / name
        if path.is_symlink() or any(p.is_symlink() for p in path.parents if p != root.parent):
            errors.append("symlink:" + name)
        elif not path.is_file():
            errors.append("missing:" + name)
        else:
            if digest(path) != entry["sha256"] or blob_id(path.read_bytes()) != entry["blob"]:
                errors.append("changed:" + name)
            if sys.platform == "linux" and bool(path.stat().st_mode & stat.S_IXUSR) != (entry["mode"] == "100755"):
                errors.append("mode:" + name)
    for path in root.rglob("*"):
        name = path.relative_to(root).as_posix()
        if path.is_symlink():
            errors.append("symlink:" + name)
        elif path.is_file() and name not in expected:
            if not (allow_cache and name.startswith(".godot/")):
                errors.append("extra:" + name)
    return errors


def post_import_sources(root, entries):
    # Exceção SOMENTE para conteúdo dos dois gerados, apenas depois do import.
    errors = verify_snapshot(root, entries, allow_cache=True)
    return [e for e in errors if e not in {"changed:" + name for name in GENERATED}]


def generated_state(root):
    result = {}
    for name in GENERATED:
        path = root / name
        if path.is_symlink() or not path.is_file() or path.stat().st_size < 16:
            raise RuntimeError("Generated output missing/invalid: " + name)
        with open(path, "rb") as stream:
            if stream.read(4) not in (b"RSRC", b"RSCC"):
                raise RuntimeError("Generated output not a Godot resource: " + name)
        result[name] = {"sha256": digest(path), "bytes": path.stat().st_size}
    return result


def known_import_errors(stdout, stderr):
    seen = collections.Counter(line for line in (stdout + "\n" + stderr).splitlines() if line.startswith("ERROR:"))
    unexpected = {line: count for line, count in seen.items() if count > KNOWN_IMPORT_ERRORS.get(line, 0)}
    return {"observed": dict(seen), "unexpected": unexpected, "known_only": not unexpected}


def cache_inventory(root):
    rows = []
    for resource in CACHE_OUTPUTS:
        path = root / resource.removeprefix("res://")
        if path.is_symlink() or not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError("Required imported resource missing at import exit: " + resource)
        rows.append({"resource": resource, "sha256": digest(path), "bytes": path.stat().st_size})
    return rows


def capture_sources(root, entries, run, stage_name):
    rows = []
    for entry in entries:
        path = root / entry["path"]
        row = {"path": entry["path"], "input_sha256": entry["sha256"]}
        if path.is_file() and not path.is_symlink():
            row.update(sha256=digest(path), bytes=path.stat().st_size)
        else:
            row["missing_or_symlink"] = True
        rows.append(row)
    output = run / ("sources-after-" + stage_name + ".json")
    save(output, {"input_tree": TREE, "execution_tree": OBSERVATION_TREE, "files": rows})
    for name in GENERATED:
        path = root / name
        if path.is_file() and not path.is_symlink():
            target = run / ("generated-after-" + stage_name) / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
    return {"path": str(output), "sha256": digest(output), "files": len(rows)}


def protected_checkpoint(repo):
    """Somente checkout do workflow no runner, nunca checkout/WIP Windows."""
    repo = Path(repo).resolve(strict=True)
    rows = []
    for path in sorted(repo.rglob("*")):
        relative = path.relative_to(repo)
        if relative.parts[0] == ".git":
            continue
        if path.is_symlink():
            raise RuntimeError("Workflow checkout symlink: " + str(relative))
        if path.is_file():
            rows.append({"path": relative.as_posix(), "sha256": digest(path)})
    return {"files": rows, "index_sha256": digest(repo / ".git/index")}


def classify_gut(stdout, stderr, native):
    text = re.sub(r"\x1b\[[0-9;]*m", "", stdout + "\n" + stderr)
    if re.search(FATAL, text):
        return "fatal_engine_error"
    if native not in (0, 1):
        return "unexpected_exit"
    if "= Run Summary" not in text:
        return "summary_missing"
    summary = text[text.index("= Run Summary"):]
    def number(label):
        found = re.search(r"(?im)^\s*" + label + r"\s+(\d+)\s*$", summary)
        return int(found[1]) if found else None
    if number("Scripts") != 1 or number("Tests") != 15 or number("Asserts") != 371:
        return "unexpected_counts"
    if native == 0 and number("Passing") == 15 and "---- All tests passed! ----" in summary:
        return "passed"
    failed_names = re.findall(r"(?m)^\s*-\s+(test_\w+)\s*$", summary)
    expected = {"test_dead_actor_cannot_open_and_death_while_open_closes",
                "test_counter_free_closes_without_retaining_invalid_reference"}
    if (native == 1 and set(failed_names) == expected and len(failed_names) == 2
            and number("Passing") == 13 and number("Failing") == 2
            and len(re.findall(r"\[Failed\]:", summary)) == 4
            and "---- 2 failing tests ----" in summary):
        return "expected_functional_failure"
    return "unexpected_gut_failure"


def inventory():
    """Inventário local de todo /proc; falha de leitura não vira lista vazia."""
    found = []
    for path in Path("/proc").iterdir():
        if not path.name.isdecimal():
            continue
        try:
            comm = (path / "comm").read_text().strip()
            command = (path / "cmdline").read_bytes().split(b"\0")
        except FileNotFoundError:
            continue  # Processo terminou durante a leitura.
        except (PermissionError, OSError) as error:
            raise RuntimeError("Inventario /proc incompleto: " + path.name) from error
        first = os.fsdecode(command[0]) if command else ""
        if "godot" in comm.lower() or "godot" in Path(first).name.lower():
            found.append({"pid": int(path.name), "comm": comm,
                          "argv": [os.fsdecode(value) for value in command if value]})
    return found


def save(path, value):
    with open(path, "w", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def callback_observations(stdout):
    stdout = re.sub(r"\x1b\[[0-9;]*m", "", stdout)
    expected = {
        "test_dead_actor_cannot_open_and_death_while_open_closes",
        "test_range_loss_closes_and_out_of_range_open_is_rejected",
        "test_counter_free_closes_without_retaining_invalid_reference",
        "test_current_scene_change_closes_even_if_old_counter_still_exists",
    }
    rows = [json.loads(line.removeprefix("QA210_OBSERVATION "))
            for line in stdout.splitlines() if line.startswith("QA210_OBSERVATION ")]
    if len(rows) != 4 or {row.get("test") for row in rows} != expected:
        raise RuntimeError("Missing/duplicate callback observations")
    for row in rows:
        if row.get("schema") != "qa210-callback-v1":
            raise RuntimeError("Unexpected callback schema")
        before, after = row["before"], row["after"]
        delta = after["shop_idle_count"] - before["shop_idle_count"]
        if delta < 0 or after["physics_frame"] < before["physics_frame"]:
            raise RuntimeError("Invalid callback counters")
        row["shop_idle_delta"] = delta
        row["global_process_delta"] = after["process_frame"] - before["process_frame"]
        row["physics_delta"] = after["physics_frame"] - before["physics_frame"]
        row["close_delta"] = after["shop_close_count"] - before["shop_close_count"]
        row["open_delta"] = after["shop_open_count"] - before["shop_open_count"]
        # Observação, nunca substitui classificação das asserções GUT.
        row["observation"] = ("no_shop_idle_callback_in_wait_window" if delta == 0
                              else "shop_idle_callback_observed_in_wait_window")
    return rows


def stage(name, command, limit, env, run, manifest, snapshot, entries):
    result = {"name": name, "argv": command, "timeout_seconds": limit,
              "started_at_unix": time.time(), "native_exit_code": None,
              "exit_after_cleanup": None, "timeout": False, "root_exited": False,
              "stdout_complete": False, "stderr_complete": False}
    manifest["stages"].append(result)
    save(run / "manifest.json", manifest)
    result["inventory_before"] = inventory()
    if result["inventory_before"]:
        raise RuntimeError("Godot externo antes de " + name)
    errors = post_import_sources(snapshot, entries) if name == "gut" else verify_snapshot(snapshot, entries)
    if name == "gut" and generated_state(snapshot) != manifest.get("generated_after_import"):
        raise RuntimeError("Generated translations changed between import and GUT")
    if errors:
        raise RuntimeError("Snapshot invalida antes de " + name + ": " + str(errors[:8]))
    stdout_path, stderr_path = run / (name + ".stdout.log"), run / (name + ".stderr.log")
    process = None
    try:
        # Arquivos binários diretos: sem truncamento, tee, pipe ou decodificação na captura.
        with open(stdout_path, "xb") as out, open(stderr_path, "xb") as err:
            launched_at = time.monotonic()
            process = subprocess.Popen(command, cwd=snapshot, env=env, stdin=subprocess.DEVNULL,
                                       stdout=out, stderr=err, start_new_session=True)
            result["pid"] = process.pid
            try:
                save(run / "manifest.json", manifest)
                result["native_exit_code"] = process.wait(timeout=max(0, limit - (time.monotonic() - launched_at)))
                result["root_exited"] = True
            except subprocess.TimeoutExpired:
                result["timeout"] = True
            finally:
                # Apenas o grupo próprio. Nunca encerra processos de outros agentes.
                if process.poll() is None:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    try:
                        result["exit_after_cleanup"] = process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        result["cleanup_error"] = "owned group did not exit within 10s"
                result["root_exited"] = process.poll() is not None
            out.flush()
            err.flush()
        result["inventory_after"] = inventory()
        result["stdout_complete"] = result["root_exited"] and not result["inventory_after"]
        result["stderr_complete"] = result["stdout_complete"]
        result["stdout_sha256"] = digest(stdout_path)
        result["stderr_sha256"] = digest(stderr_path)
        result["source_errors_after"] = post_import_sources(snapshot, entries)
        result["source_manifest_after"] = capture_sources(snapshot, entries, run, name)
        result["generated_after"] = generated_state(snapshot)
        result["finished_at_unix"] = time.time()
        stdout = stdout_path.read_text(encoding="utf-8", errors="replace")
        stderr = stderr_path.read_text(encoding="utf-8", errors="replace")
        result["fatal_engine_error"] = bool(re.search(FATAL, stdout + "\n" + stderr))
        result["stdout_error_lines"] = len(re.findall(r"(?m)^ERROR:", stdout))
        result["stderr_error_lines"] = len(re.findall(r"(?m)^ERROR:", stderr))
        result["stderr_warning_lines"] = len(re.findall(r"(?m)^WARNING:", stderr))
        result["dummy_null_mesh_count"] = stderr.count('ERROR: Parameter "m" is null.')
        result["engine_header_verified"] = VERSION in stdout
        if name == "import":
            result["import_error_policy"] = known_import_errors(stdout, stderr)
            result["required_cache_at_exit"] = cache_inventory(snapshot)
        if name == "gut":
            result["gut_result"] = classify_gut(stdout, stderr, result["native_exit_code"])
            result["callback_observations"] = callback_observations(stdout)
            save(run / "callback-observations.json", result["callback_observations"])
            reported = re.search(r"using\s+\[([^\]]+)\]\s+for temporary output\.", stdout)
            profile = Path(env["XDG_DATA_HOME"]).resolve()
            result["profile_isolation_verified"] = bool(reported and
                Path(reported[1]).resolve().is_relative_to(profile))
        return result
    finally:
        save(run / "manifest.json", manifest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="Somente apos revisao e janela nova")
    for arg in ("snapshot", "sources-manifest", "workflow-root", "engine", "engine-sha256",
                "supervisor-sha256", "sources-manifest-sha256", "lease-id", "run-dir", "pre-run-hook"):
        parser.add_argument("--" + arg, required=True)
    args = parser.parse_args()
    if not args.execute:
        parser.error("Engine bloqueada sem --execute; preparo nao autoriza execucao")
    if sys.platform != "linux" or platform.machine() != "x86_64":
        parser.error("Requer Linux x86_64")
    release = platform.freedesktop_os_release()
    if release.get("ID") != "ubuntu" or release.get("VERSION_ID") != "24.04":
        parser.error("Requer Ubuntu24.04")
    snapshot = Path(args.snapshot).resolve(strict=True)
    shared = Path(args.workflow_root).resolve(strict=True)
    engine = Path(args.engine).resolve(strict=True)
    run = Path(args.run_dir).resolve()
    source_path = Path(args.sources_manifest).resolve(strict=True)
    # Snapshot/cache/engine/saidas devem estar separados; apenas fontes QA na snapshot.
    if snapshot == shared or snapshot.is_relative_to(shared) and not snapshot.is_relative_to(shared / ".bot_runs/qa210"):
        parser.error("Snapshot nao pode ser checkout compartilhado")
    if run.is_relative_to(snapshot) or engine.is_relative_to(snapshot):
        parser.error("Engine/saidas devem ficar fora da snapshot")
    if run.is_relative_to(shared) and not run.is_relative_to(shared / ".bot_runs/qa210"):
        parser.error("Saidas no repositorio somente em .bot_runs/qa210")
    if digest(__file__) != args.supervisor_sha256.upper() or digest(source_path) != args.sources_manifest_sha256.upper():
        parser.error("Supervisor/manifesto divergem da revisao")
    if digest(engine) != args.engine_sha256.upper():
        parser.error("Engine diverge do SHA256 aprovado")
    with open(engine, "rb") as stream:
        if stream.read(4) != b"\x7fELF":
            parser.error("Engine nao e ELF Linux")
    sources = json.loads(source_path.read_text(encoding="utf-8"))
    entries = sources["files"]
    if (sources["tree"] != OBSERVATION_TREE or sources.get("input_tree") != TREE
            or sources.get("execution_is_ci_identical") is not False
            or sources.get("original_manifest_sha256") != "3A3C84E628CC3CDB8F5E087623897381E19122E443A6FE4305143730DBB70866"
            or sources["commit"] != COMMIT or tree_id(entries) != OBSERVATION_TREE):
        parser.error("Arvore CI invalida")
    errors = verify_snapshot(snapshot, entries)
    if errors:
        parser.error("Fontes extras/alteradas/cache preexistente: " + str(errors[:8]))
    before = protected_checkpoint(shared)
    if inventory():
        parser.error("Godot existente no host Linux; janela nao exclusiva")
    run.mkdir(parents=True, exist_ok=False)
    manifest = {"issue": 210, "lease_id": args.lease_id, "started_at_unix": time.time(),
                "os_release": release, "platform": platform.platform(), "machine": platform.machine(),
                "python": sys.version, "snapshot": str(snapshot), "workflow_root": str(shared),
                "engine": str(engine), "engine_sha256": digest(engine),
                "supervisor_sha256": digest(__file__), "sources_manifest_sha256": digest(source_path),
                "sources": sources, "protected_before": before, "stages": [],
                "diagnostic_valid": False, "wrapper_exit_code": 70}
    save(run / "manifest.json", manifest)
    wrapper = 70
    hook = Path(args.pre_run_hook).resolve(strict=True)
    manifest["hook_sha256_before"] = digest(hook)
    manifest["generated_before_import"] = generated_state(snapshot)
    for name in GENERATED:
        target = run / "generated-before" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(snapshot / name, target)
    try:
        env = os.environ.copy()
        env.pop("GODOT_USER_HOME", None)
        isolated = {"HOME": run / "profile/home", "XDG_DATA_HOME": run / "profile/data",
                    "XDG_CONFIG_HOME": run / "profile/config", "XDG_CACHE_HOME": run / "profile/cache",
                    "TMPDIR": run / "profile/tmp", "TEMP": run / "profile/tmp", "TMP": run / "profile/tmp"}
        for key, path in isolated.items():
            path.mkdir(parents=True, exist_ok=True)
            env[key] = str(path)
        env["QA210_POSTIMPORT_REPORT"] = str(run / "post-import-verification.json")
        env["LANG"] = "C.UTF-8"
        env["LC_ALL"] = "C.UTF-8"
        manifest["profile_environment"] = {key: str(path) for key, path in isolated.items()}
        commands = [
            ("import", [str(engine), "--headless", "--path", str(snapshot), "--import"], IMPORT_TIMEOUT),
            ("gut", [str(engine), "--headless", "--path", str(snapshot), "-s", "addons/gut/gut_cmdln.gd",
                     "-gconfig=", "-gdir=", "-gtest=" + TARGET, "-gexit", "-glog=1",
                     "-gpre_run_script=" + str(hook)], GUT_TIMEOUT),
        ]
        for name, command, limit in commands:
            if protected_checkpoint(shared) != before or digest(__file__) != args.supervisor_sha256.upper() or digest(source_path) != args.sources_manifest_sha256.upper() or digest(engine) != args.engine_sha256.upper() or digest(hook) != manifest["hook_sha256_before"]:
                raise RuntimeError("Workflow checkout/artefatos divergiram antes de " + name)
            result = stage(name, command, limit, env, run, manifest, snapshot, entries)
            if result["timeout"]:
                wrapper = 124 if result["root_exited"] and not result.get("inventory_after", ["unknown"]) else 71
                raise RuntimeError("Timeout " + name)
            if (not result["root_exited"] or result["inventory_after"] or not result["stdout_complete"]
                    or result["fatal_engine_error"] or result["source_errors_after"]
                    or not result["engine_header_verified"]):
                raise RuntimeError("Gate de execucao falhou: " + name)
            if name == "import" and result["native_exit_code"] != 0:
                raise RuntimeError("Import nao passou; GUT proibido")
            if name == "import":
                if not result["import_error_policy"]["known_only"]:
                    raise RuntimeError("Import has unknown/excess ERROR; GUT prohibited")
                manifest["generated_after_import"] = result["generated_after"]
                save(run / "manifest.json", manifest)
            if name == "gut":
                verification = json.loads((run / "post-import-verification.json").read_text(encoding="utf-8"))
                manifest["post_import_verification"] = verification
                if verification.get("schema") != "qa210-post-import-v1" or verification.get("valid") is not True:
                    raise RuntimeError("Post-import runtime verification failed; no diagnostic result")
                if result["generated_after"] != manifest["generated_after_import"]:
                    raise RuntimeError("Generated translations changed during GUT")
            if name == "gut" and (not result["profile_isolation_verified"] or result["gut_result"] not in ("passed", "expected_functional_failure")):
                raise RuntimeError("GUT inesperado ou isolamento nao comprovado")
        manifest["diagnostic_valid"] = True
        wrapper = manifest["stages"][-1]["native_exit_code"]
    except Exception as error:
        manifest["exception"] = str(error)
    finally:
        try:
            manifest["protected_after"] = protected_checkpoint(shared)
            manifest["protected_equal"] = manifest["protected_after"] == before
            manifest["inventory_final"] = inventory()
            manifest["source_errors_final"] = post_import_sources(snapshot, entries)
            manifest["generated_final"] = generated_state(snapshot)
            manifest["hook_sha256_after"] = digest(hook)
            if (manifest["generated_final"] != manifest.get("generated_after_import")
                    or manifest["hook_sha256_after"] != manifest["hook_sha256_before"]):
                manifest["diagnostic_valid"], wrapper = False, 71
            manifest["supervisor_sha256_after"] = digest(__file__)
            manifest["sources_manifest_sha256_after"] = digest(source_path)
            manifest["engine_sha256_after"] = digest(engine)
            if (not manifest["protected_equal"] or manifest["inventory_final"] or manifest["source_errors_final"]
                    or manifest["supervisor_sha256_after"] != args.supervisor_sha256.upper()
                    or manifest["sources_manifest_sha256_after"] != args.sources_manifest_sha256.upper()
                    or manifest["engine_sha256_after"] != args.engine_sha256.upper()):
                manifest["diagnostic_valid"], wrapper = False, 71
        except Exception as error:
            manifest["final_check_exception"] = str(error)
            manifest["diagnostic_valid"], wrapper = False, 71
        manifest["finished_at_unix"] = time.time()
        manifest["wrapper_exit_code"] = wrapper
        save(run / "manifest.json", manifest)
    return wrapper


if __name__ == "__main__":
    sys.exit(main())
