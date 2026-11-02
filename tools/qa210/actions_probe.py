"""One-shot Actions #210. Downloads oficiais; zero Godot fora do supervisor."""
import argparse
import io
import json
import os
import platform
import subprocess
import sys
import tarfile
import urllib.request
import zipfile
from pathlib import Path

import linux_qa as qa
import observe_snapshot

URL = "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip"
ELF = "Godot_v4.3-stable_linux.x86_64"


def git(repo, *args, **kwargs):
    return subprocess.check_output(["git", "-C", str(repo), *args], **kwargs)


def prepare_sources(repo, work, evidence):
    commit = git(repo, "rev-parse", "HEAD").decode().strip()
    tree = git(repo, "rev-parse", "HEAD^{tree}").decode().strip()
    if commit != qa.COMMIT or tree != qa.TREE:
        raise RuntimeError("Source revision/tree mismatch")
    records = git(repo, "ls-tree", "-rz", "--full-tree", "HEAD").split(b"\0")
    entries = []
    for record in records:
        if not record:
            continue
        meta, name = record.split(b"\t", 1)
        mode, kind, blob = meta.decode().split()
        path = name.decode("utf-8")
        if kind != "blob" or mode not in ("100644", "100755") or Path(path).is_absolute() or ".." in Path(path).parts:
            raise RuntimeError("Unsupported source entry: " + path)
        entries.append({"path": path, "mode": mode, "blob": blob})
    if len(entries) != 1537 or qa.tree_id(entries) != qa.TREE:
        raise RuntimeError("Not the complete clean CI source tree")
    batch = io.BytesIO(git(repo, "cat-file", "--batch", input="".join(e["blob"] + "\n" for e in entries).encode()))
    snapshot = work / "source"
    snapshot.mkdir()
    with tarfile.open(evidence / "ci-source.tar", "w") as archive:
        for entry in entries:
            blob, kind, size = batch.readline().decode().split()
            data = batch.read(int(size))
            if kind != "blob" or blob != entry["blob"] or batch.read(1) != b"\n" or qa.blob_id(data) != blob:
                raise RuntimeError("Blob mismatch: " + entry["path"])
            path = snapshot / entry["path"]
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            mode = 0o755 if entry["mode"] == "100755" else 0o644
            path.chmod(mode)
            entry.update(size=len(data), sha256=qa.digest(path))
            member = tarfile.TarInfo(entry["path"])
            member.size, member.mode = len(data), mode
            archive.addfile(member, io.BytesIO(data))
    if batch.read() or qa.verify_snapshot(snapshot, entries):
        raise RuntimeError("Snapshot integrity failure")
    sources = {"commit": commit, "tree": tree, "file_count": len(entries),
               "total_bytes": sum(e["size"] for e in entries), "files": entries,
               "archive_sha256": qa.digest(evidence / "ci-source.tar")}
    qa.save(evidence / "sources-manifest.json", sources)
    return snapshot


def download_engine(work, report):
    archive = work / "godot.zip"
    # Uma tentativa de download; nenhuma repetição de engine/supervisor.
    with urllib.request.urlopen(URL, timeout=60) as response, open(archive, "xb") as output:
        report["godot_download_final_url"] = response.url
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
    report["godot_download_url"] = URL
    report["godot_archive_sha256"] = qa.digest(archive)
    with zipfile.ZipFile(archive) as bundle:
        if bundle.namelist() != [ELF]:
            raise RuntimeError("Unexpected official Godot zip contents")
        binary = work / ELF
        binary.write_bytes(bundle.read(ELF))
    binary.chmod(0o755)
    with open(binary, "rb") as stream:
        if stream.read(4) != b"\x7fELF":
            raise RuntimeError("Not Linux ELF")
    report["godot_binary_sha256"] = qa.digest(binary)
    report["checksum_provenance"] = "SHA256 computed from official GitHub HTTPS release download; no separately published binary checksum asserted"
    return binary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source-git", "workflow-root", "evidence", "work"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    evidence = Path(args.evidence).resolve(strict=True)
    report = {"issue": 210, "engine_launches_planned_max": 2, "phase": "preparing",
              "environment": {key: os.environ.get(key) for key in (
                  "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT", "GITHUB_SHA", "GITHUB_REF",
                  "GITHUB_EVENT_NAME", "RUNNER_OS", "RUNNER_ARCH", "ImageOS", "ImageVersion")},
              "os_release": platform.freedesktop_os_release(), "python": sys.version}
    qa.save(evidence / "preparation.json", report)
    code = 70
    try:
        if (os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("GITHUB_RUN_ATTEMPT") != "1"
                or os.environ.get("GITHUB_EVENT_NAME") != "push"
                or os.environ.get("GITHUB_REF") != "refs/heads/qa/210-shop-probe-20261102"):
            raise RuntimeError("Not the authorized one-shot Actions push")
        if report["os_release"].get("ID") != "ubuntu" or report["os_release"].get("VERSION_ID") != "24.04" or platform.machine() != "x86_64":
            raise RuntimeError("Runner must be Ubuntu24.04 x86_64")
        work = Path(args.work).resolve()
        workflow = Path(args.workflow_root).resolve(strict=True)
        source_git = Path(args.source_git).resolve(strict=True)
        if work.is_relative_to(workflow) or work.is_relative_to(source_git) or evidence.is_relative_to(work):
            raise RuntimeError("Work/evidence/source/workflow paths must be separate")
        work.mkdir(exist_ok=False)
        report["workflow_checkout_before"] = qa.protected_checkpoint(workflow)
        report["source_checkout_before"] = qa.protected_checkpoint(source_git)
        report["inventory_before"] = qa.inventory()
        if report["inventory_before"]:
            raise RuntimeError("Unexpected Godot before preparation")
        snapshot = prepare_sources(source_git, work, evidence)
        original_source_path = evidence / "sources-manifest.json"
        source_path = observe_snapshot.apply_observation(snapshot, evidence, original_source_path)
        report["source_provenance"] = {"input_tree": qa.TREE, "execution_tree": qa.OBSERVATION_TREE,
                                       "execution_is_ci_identical": False,
                                       "original_manifest_sha256": qa.digest(original_source_path)}
        binary = download_engine(work, report)
        supervisor = Path(__file__).with_name("linux_qa.py")
        report["qa_artifacts"] = [{"path": p.name, "sha256": qa.digest(p)} for p in (Path(__file__), supervisor, Path(__file__).with_name("post_import_hook.gd"), Path(__file__).with_name("observe_snapshot.py"))]
        report["sources_manifest_sha256"] = qa.digest(source_path)
        report["phase"] = "supervisor"
        qa.save(evidence / "preparation.json", report)
        command = [sys.executable, "-B", str(supervisor), "--execute", "--snapshot", str(snapshot),
                   "--pre-run-hook", str(Path(__file__).with_name("post_import_hook.gd")),
                   "--sources-manifest", str(source_path),
                   "--sources-manifest-sha256", report["sources_manifest_sha256"],
                   "--workflow-root", str(workflow), "--engine", str(binary),
                   "--engine-sha256", report["godot_binary_sha256"], "--supervisor-sha256", qa.digest(supervisor),
                   "--lease-id", "github-actions-" + os.environ["GITHUB_RUN_ID"], "--run-dir", str(evidence / "run")]
        report["supervisor_command"] = command
        qa.save(evidence / "preparation.json", report)
        with open(evidence / "supervisor.stdout.log", "xb") as out, open(evidence / "supervisor.stderr.log", "xb") as err:
            # Somente este supervisor. Seus dois limites Godot permanecem 180/60.
            code = subprocess.call(command, stdout=out, stderr=err)
        report["supervisor_exit_code"] = code
        report["phase"] = "completed"
    except Exception as error:
        report["exception"] = str(error)
    finally:
        try:
            report["inventory_final"] = qa.inventory()
            report["workflow_checkout_after"] = qa.protected_checkpoint(Path(args.workflow_root))
            report["source_checkout_after"] = qa.protected_checkpoint(Path(args.source_git))
            report["checkout_equal"] = (report.get("workflow_checkout_before") == report["workflow_checkout_after"]
                                        and report.get("source_checkout_before") == report["source_checkout_after"])
            if report["inventory_final"] or not report["checkout_equal"]:
                code = 71
        except Exception as error:
            report["final_exception"], code = str(error), 71
        report["exit_code"] = code
        qa.save(evidence / "preparation.json", report)
        qa.save(evidence / "evidence-hashes.json", [
            {"path": p.relative_to(evidence).as_posix(), "sha256": qa.digest(p), "bytes": p.stat().st_size}
            for p in sorted(evidence.rglob("*")) if p.is_file() and p.name not in ("setup.stdout.log", "setup.stderr.log", "evidence-hashes.json")])
    return code


if __name__ == "__main__":
    sys.exit(main())
