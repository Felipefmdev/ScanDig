"""Warnings e erros do GDScript (os mesmos do painel do editor) via LSP do editor Godot headless.

Uso: python3 tools/gd_warnings.py <godot> [pasta ou arquivo .gd ...]   (padrão: core ui)
Sai com 0 sem diagnóstico, 1 com warning/erro e 2 se o LSP não respondeu (ver docs/TOOLS.md).
O projeto já precisa estar importado (--import), como no CI.
"""
import json
import os
import socket
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
SEVERITY = {1: "ERROR", 2: "WARNING"}


def collect(args: list[str]) -> list[str]:
    files: set[str] = set()
    for arg in args or ["core", "ui"]:
        path = PROJECT / arg
        found = sorted(path.rglob("*.gd")) if path.is_dir() else [path]
        files.update(p.relative_to(PROJECT).as_posix() for p in found if p.suffix == ".gd")
    return sorted(files)


def free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class Lsp:
    def __init__(self, sock: socket.socket) -> None:
        self.sock = sock
        self.buf = b""

    def send(self, obj: dict) -> None:
        body = json.dumps(obj).encode()
        self.sock.sendall(b"Content-Length: %d\r\n\r\n" % len(body) + body)

    def recv(self, timeout: float) -> dict | None:
        self.sock.settimeout(timeout)
        while True:
            if b"\r\n\r\n" in self.buf:
                head, rest = self.buf.split(b"\r\n\r\n", 1)
                length = next(int(line.split(b":")[1]) for line in head.split(b"\r\n")
                              if line.lower().startswith(b"content-length"))
                if len(rest) >= length:
                    self.buf = rest[length:]
                    return json.loads(rest[:length])
            try:
                chunk = self.sock.recv(65536)
            except socket.timeout:
                return None
            if not chunk:
                return None
            self.buf += chunk


def stop(proc: subprocess.Popen) -> None:
    # No Windows o *_console.exe abre o executável da Godot como filho: mata a árvore só deste PID.
    if os.name == "nt":
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True)
    else:
        proc.kill()
    proc.wait(timeout=30)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    godot, files = sys.argv[1], collect(sys.argv[2:])
    port = free_port()
    proc = subprocess.Popen([godot, "--headless", "--editor", "--path", str(PROJECT), "--lsp-port", str(port)],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        sock = None
        for _ in range(240):
            time.sleep(0.5)
            try:
                sock = socket.create_connection(("127.0.0.1", port))
                break
            except OSError:
                if proc.poll() is not None:
                    break
        if sock is None:
            print("gd_warnings: o LSP da Godot não abriu na porta %d" % port)
            return 2
        lsp = Lsp(sock)
        lsp.send({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                  "params": {"processId": None, "rootUri": PROJECT.as_uri(), "rootPath": str(PROJECT), "capabilities": {}}})
        while True:
            msg = lsp.recv(60)
            if msg is None or msg.get("id") == 1:
                break
        lsp.send({"jsonrpc": "2.0", "method": "initialized", "params": {}})

        diags: dict[str, list] = {}
        for rel in files:
            uri = (PROJECT / rel).as_uri()
            text = (PROJECT / rel).read_text(encoding="utf-8")
            lsp.send({"jsonrpc": "2.0", "method": "textDocument/didOpen",
                      "params": {"textDocument": {"uri": uri, "languageId": "gdscript", "version": 1, "text": text}}})
            deadline = time.time() + 20
            while time.time() < deadline:
                msg = lsp.recv(20)
                if msg is None:
                    break
                if msg.get("method") == "textDocument/publishDiagnostics":
                    got = urllib.parse.unquote(msg["params"]["uri"]).lower()
                    if got.endswith("/" + rel.lower()):
                        diags[rel] = msg["params"]["diagnostics"]
                        break
            lsp.send({"jsonrpc": "2.0", "method": "textDocument/didClose", "params": {"textDocument": {"uri": uri}}})
        sock.close()
    finally:
        stop(proc)

    total = 0
    for rel in files:
        for d in diags.get(rel, []):
            sev = SEVERITY.get(d.get("severity"), str(d.get("severity")))
            print("%s:%d: %s %s" % (rel, d["range"]["start"]["line"] + 1, sev, d["message"]))
            total += 1
    missing = [rel for rel in files if rel not in diags]
    for rel in missing:
        print("SEM RESPOSTA %s" % rel)
    print("TOTAL %d diagnósticos em %d arquivos (sem resposta: %d)" % (total, len(files), len(missing)))
    if missing:
        return 2
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
