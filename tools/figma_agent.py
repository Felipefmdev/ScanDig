#!/usr/bin/env python3
"""Ponte local Figma <-> terminal: fila de comandos, resultados e export de PNG.

O plugin do Figma faz polling a /next, executa o comando e publica o resultado em
/result. O terminal enfileira em /command e lê /results.

Uso:
    python tools/figma_agent.py serve            # janela 1
    python tools/figma_agent.py build            # janela 2
    python tools/figma_agent.py export --node "01 hud 1152x648"
    python tools/figma_agent.py ping
    python tools/figma_agent.py results --wait 20
"""

from __future__ import annotations

import argparse
import base64
import json
import re
import sys
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
EXPORTS = REPO / "docs/ui/exports"
DEFAULT_PORT = 8765
QUEUE: list[dict] = []
RESULTS: list[dict] = []
NEXT_ID = 1


def _json(handler: BaseHTTPRequestHandler, payload: dict, code: int = 200) -> None:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type")
    handler.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def _save_export(result: dict) -> None:
    if result.get("kind") != "export" or not result.get("png"):
        return
    EXPORTS.mkdir(parents=True, exist_ok=True)
    name = re.sub(r"[^a-z0-9_-]+", "_", result.get("name", "frame").lower()).strip("_")
    target = EXPORTS / f"{name}.png"
    target.write_bytes(base64.b64decode(result["png"]))
    result["saved"] = str(target.relative_to(REPO)).replace("\\", "/")


class Handler(BaseHTTPRequestHandler):
    server_version = "ScanDigFigmaBridge/1.0"

    def log_message(self, *args) -> None:  # silencia o log por pedido
        return

    def _body(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if not length:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return {}

    def do_OPTIONS(self) -> None:  # noqa: N802
        _json(self, {"ok": True})

    def do_GET(self) -> None:  # noqa: N802
        global NEXT_ID
        if self.path.startswith("/health"):
            _json(self, {"ok": True, "queued": len(QUEUE), "results": len(RESULTS)})
            return
        if self.path.startswith("/next"):
            if not QUEUE:
                _json(self, {"type": "idle"})
                return
            command = QUEUE.pop(0)
            _json(self, command)
            return
        if self.path.startswith("/results"):
            since = 0
            match = re.search(r"since=(\d+)", self.path)
            if match:
                since = int(match.group(1))
            _json(self, {"results": RESULTS[since:], "cursor": len(RESULTS)})
            return
        _json(self, {"error": "rota desconhecida"}, 404)

    def do_POST(self) -> None:  # noqa: N802
        global NEXT_ID
        body = self._body()
        if self.path.startswith("/command"):
            command = dict(body)
            command.setdefault("type", "ping")
            command["id"] = NEXT_ID
            NEXT_ID += 1
            QUEUE.append(command)
            _json(self, {"ok": True, "id": command["id"]})
            return
        if self.path.startswith("/result"):
            result = dict(body)
            _save_export(result)
            RESULTS.append(result)
            print(json.dumps({"result": result.get("id"), "ok": result.get("ok", False),
                              "saved": result.get("saved", "")}, ensure_ascii=False))
            _json(self, {"ok": True})
            return
        _json(self, {"error": "rota desconhecida"}, 404)


def send(path: str, payload: dict | None = None) -> dict:
    url = f"http://127.0.0.1:{PORT}{path}"
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def command(args: argparse.Namespace, payload: dict) -> int:
    try:
        reply = send("/command", payload)
    except OSError as error:
        print(f"servidor ausente ({error}); corre: python tools/figma_agent.py serve", file=sys.stderr)
        return 2
    print(f"enfileirado #{reply['id']}: {payload['type']}")
    return 0


def main(argv: list[str] | None = None) -> int:
    global PORT
    parser = argparse.ArgumentParser(description="Ponte local Figma <-> terminal")
    parser.add_argument("action", choices=["serve", "build", "export", "ping", "results", "status"])
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--node", default="")
    parser.add_argument("--wait", type=float, default=0.0)
    args = parser.parse_args(argv)
    PORT = args.port

    if args.action == "serve":
        server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
        print(f"ponte em http://127.0.0.1:{PORT} — abre o plugin 'ScanDig Bridge' no Figma")
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        return 0

    if args.action == "build":
        return command(args, {"type": "build"})
    if args.action == "ping":
        return command(args, {"type": "ping"})
    if args.action == "export":
        if not args.node:
            print("--node em falta", file=sys.stderr)
            return 2
        return command(args, {"type": "export", "name": args.node})
    if args.action == "status":
        try:
            print(json.dumps(send("/health"), indent=2))
        except OSError as error:
            print(f"servidor ausente: {error}", file=sys.stderr)
            return 2
        return 0

    deadline = time.monotonic() + max(args.wait, 1.0)
    try:
        while time.monotonic() < deadline:
            payload = send("/results")
            if payload["results"]:
                for item in payload["results"]:
                    print(json.dumps(item, ensure_ascii=False)[:2000])
                return 0 if all(item.get("ok") for item in payload["results"]) else 1
            time.sleep(0.5)
    except OSError as error:
        print(f"servidor ausente: {error}", file=sys.stderr)
        return 2
    print("sem resultados no prazo", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
