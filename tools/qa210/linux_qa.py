"""#210: supervisor QA revisável. Importar este módulo não inicia processos.

Somente --execute permite duas chamadas Godot no máximo; requer Ubuntu24.04,
janela GitHub Actions e hashes explicitamente fixados na revisão. Sem instalação/download.
"""
import argparse
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
COMMIT = "748e90cee8cd69e68a78b4006e9f512cd18f22d8"
TARGET = "res://tests/unit/test_world_upgrade_shop.gd"
VERSION = "Godot Engine v4.3.stable.official.77dcf97d8"
IMPORT_TIMEOUT = 180
GUT_TIMEOUT = 60
FATAL = r"(?im)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR: Failed to load (?:script|resource)|Segmentation fault|Access violation|CrashHandlerException)"
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
        elif digest(path) != entry["sha256"] or blob_id(path.read_bytes()) != entry["blob"]:
            errors.append("changed:" + name)
        elif sys.platform == "linux" and bool(path.stat().st_mode & stat.S_IXUSR) != (entry["mode"] == "100755"):
            errors.append("mode:" + name)
    for path in root.rglob("*"):
        name = path.relative_to(root).as_posix()
        if path.is_symlink():
            errors.append("symlink:" + name)
        elif path.is_file() and name not in expected:
            if not (allow_cache and name.startswith(".godot/")):
                errors.append("extra:" + name)
    return errors


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
    errors = verify_snapshot(snapshot, entries, allow_cache=name == "gut")
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
        result["source_errors_after"] = verify_snapshot(snapshot, entries, allow_cache=True)
        result["finished_at_unix"] = time.time()
        stdout = stdout_path.read_text(encoding="utf-8", errors="replace")
        stderr = stderr_path.read_text(encoding="utf-8", errors="replace")
        result["fatal_engine_error"] = bool(re.search(FATAL, stdout + "\n" + stderr))
        result["stdout_error_lines"] = len(re.findall(r"(?m)^ERROR:", stdout))
        result["stderr_error_lines"] = len(re.findall(r"(?m)^ERROR:", stderr))
        result["stderr_warning_lines"] = len(re.findall(r"(?m)^WARNING:", stderr))
        result["dummy_null_mesh_count"] = stderr.count('ERROR: Parameter "m" is null.')
        result["engine_header_verified"] = VERSION in stdout
        if name == "gut":
            result["gut_result"] = classify_gut(stdout, stderr, result["native_exit_code"])
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
                "supervisor-sha256", "sources-manifest-sha256", "lease-id", "run-dir"):
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
    if sources["tree"] != TREE or sources["commit"] != COMMIT or tree_id(entries) != TREE:
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
    try:
        env = os.environ.copy()
        env.pop("GODOT_USER_HOME", None)
        isolated = {"HOME": run / "profile/home", "XDG_DATA_HOME": run / "profile/data",
                    "XDG_CONFIG_HOME": run / "profile/config", "XDG_CACHE_HOME": run / "profile/cache",
                    "TMPDIR": run / "profile/tmp", "TEMP": run / "profile/tmp", "TMP": run / "profile/tmp"}
        for key, path in isolated.items():
            path.mkdir(parents=True, exist_ok=True)
            env[key] = str(path)
        env["LANG"] = "C.UTF-8"
        env["LC_ALL"] = "C.UTF-8"
        manifest["profile_environment"] = {key: str(path) for key, path in isolated.items()}
        commands = [
            ("import", [str(engine), "--headless", "--path", str(snapshot), "--import"], IMPORT_TIMEOUT),
            ("gut", [str(engine), "--headless", "--path", str(snapshot), "-s", "addons/gut/gut_cmdln.gd",
                     "-gconfig=", "-gdir=", "-gtest=" + TARGET, "-gexit", "-glog=1"], GUT_TIMEOUT),
        ]
        for name, command, limit in commands:
            if protected_checkpoint(shared) != before or digest(__file__) != args.supervisor_sha256.upper() or digest(source_path) != args.sources_manifest_sha256.upper() or digest(engine) != args.engine_sha256.upper():
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
            if name == "import" and (result["stdout_error_lines"] or result["stderr_error_lines"]):
                raise RuntimeError("Import tem ERROR nos streams; GUT proibido")
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
            manifest["source_errors_final"] = verify_snapshot(snapshot, entries, allow_cache=True)
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
