"""Tabela e gráfico do teste de resistência (R5, #142).

Uso: python tools/bot/soak_report.py [run_dir] [--label janela|headless] [--svg docs/qa/soak_<label>.svg]
Sem run_dir lê o run mais recente de soak_20 em .bot_runs/. Por ida usa o dump "<ida>_cena"
(FPS méd/mín da ida, tempo de carga, dinheiro) e o "<ida>_base" (memória, objetos, nós, órfãos e
recursos já de volta à Base: é o patamar comparável entre idas). Grava
.bot_runs/soak_logs/report_<label>.md, o SVG (memória e nós × ida) e imprime a tabela.
"""
import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
RUNS = os.path.join(ROOT, ".bot_runs")
LOGS = os.path.join(RUNS, "soak_logs")
MB = 1024.0 * 1024.0
# Idas até cada mapa ter sido visitado uma vez (soak_gen.py roda 5 mapas).
WARM = 5


def latest_run():
	dirs = [d for d in glob.glob(os.path.join(RUNS, "soak_20_*")) if os.path.isdir(d)]
	return max(dirs, key=os.path.getmtime) if dirs else None


def load(path):
	try:
		with open(path, encoding="utf-8") as f:
			return json.load(f)
	except (OSError, ValueError):
		return None


def rows(run_dir):
	base = load(os.path.join(run_dir, "00_base.json"))
	out = []
	if base:
		out.append({"ida": 0, "nome": "Base (início)", "base": base, "cena": None})
	for path in sorted(glob.glob(os.path.join(run_dir, "*_base.json"))):
		m = re.match(r"(\d\d)_(.+)_base\.json$", os.path.basename(path))
		if not m or m.group(1) == "00":
			continue
		cena = load(path[: -len("_base.json")] + "_cena.json")
		out.append({"ida": int(m.group(1)), "nome": m.group(2).replace("_", " "), "base": load(path), "cena": cena})
	return out


def fmt_fps(v):
	return "—" if v is None or v < 0 else "%.0f" % v


def table(data):
	lines = [
		"| ida | mapa / fase | carga (s) | FPS méd | FPS mín | memória (MB) | objetos | nós | órfãos | recursos | dinheiro |",
		"|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
	]
	for r in data:
		b = r["base"]
		pb = b.get("perf", {})
		c = r["cena"] or {}
		pc = c.get("perf", {})
		load_s = pc.get("load_s", -1)
		money = (c or b).get("game_state", {}).get("team_money", "")
		lines.append("| %d | %s | %s | %s | %s | %.1f | %d | %d | %d | %d | %s |" % (
			r["ida"], r["nome"], "—" if load_s is None or load_s < 0 else "%.2f" % load_s,
			fmt_fps(pc.get("fps_avg")), fmt_fps(pc.get("fps_min")),
			pb.get("mem_static", 0) / MB, pb.get("objects", 0), b.get("nodes", 0), b.get("orphans", 0),
			pb.get("resources", 0), money))
	return "\n".join(lines)


def summary(data):
	if len(data) < 2:
		return ""
	first, last = data[0]["base"], data[-1]["base"]
	# Patamar: depois da 1.ª volta pelos mapas (a 1.ª ida a cada mapa carrega caches e recursos).
	warm = min(WARM, len(data) - 1)
	ref = data[warm]["base"]
	fps = [r["cena"]["perf"] for r in data if r["cena"] and r["cena"].get("perf", {}).get("fps_avg", -1) >= 0]
	loads = [p["load_s"] for p in fps if p.get("load_s", -1) >= 0]
	n = len(data) - 1

	def delta(key, perf=False, scale=1.0):
		a = (first.get("perf", {}) if perf else first).get(key, 0) / scale
		b = (ref.get("perf", {}) if perf else ref).get(key, 0) / scale
		c = (last.get("perf", {}) if perf else last).get(key, 0) / scale
		return a, b, c

	m = delta("mem_static", True, MB)
	o = delta("objects", True)
	nd = delta("nodes")
	orph = delta("orphans")
	res = delta("resources", True)
	per_trip = lambda v: (v[2] - v[1]) / max(1, n - warm)
	text = [
		"%d idas. Base início → ida %d (todos os mapas já visitados) → fim; ritmo por ida depois da ida %d:" % (n, warm, warm),
		"- memória %.1f → %.1f → %.1f MB (%+.2f MB/ida)" % (m + (per_trip(m),)),
		"- objetos %d → %d → %d (%+.1f/ida)" % (o + (per_trip(o),)),
		"- nós %d → %d → %d (%+.1f/ida)" % (nd + (per_trip(nd),)),
		"- órfãos %d → %d → %d (%+.1f/ida)" % (orph + (per_trip(orph),)),
		"- recursos %d → %d → %d (%+.1f/ida)" % (res + (per_trip(res),)),
	]
	if fps:
		text.append("- FPS médio por ida %.0f–%.0f; mínimo (janela de 1 s) %.0f" % (
			min(p["fps_avg"] for p in fps), max(p["fps_avg"] for p in fps), min(p["fps_min"] for p in fps if p["fps_min"] >= 0)))
	if loads:
		text.append("- carga %.2f–%.2f s (média %.2f s)" % (min(loads), max(loads), sum(loads) / len(loads)))
	return "\n".join(text)


def polyline(values, x0, w, y0, h, lo, hi):
	pts = []
	for i, v in enumerate(values):
		x = x0 + (w * i / max(1, len(values) - 1))
		y = y0 + h - (h * (v - lo) / max(1e-9, hi - lo))
		pts.append("%.1f,%.1f" % (x, y))
	return " ".join(pts)


def svg(data, title):
	"""Dois painéis (memória MB; nós e órfãos) × ida, com cores fixas legíveis em claro e escuro."""
	W, H, L, R, T = 720, 420, 64, 24, 36
	ph = 140
	idas = [r["ida"] for r in data]
	mem = [r["base"].get("perf", {}).get("mem_static", 0) / MB for r in data]
	nodes = [r["base"].get("nodes", 0) for r in data]
	orph = [r["base"].get("orphans", 0) for r in data]
	w = W - L - R
	parts = [
		'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="sans-serif" font-size="12">' % (W, H, W, H),
		'<rect width="100%" height="100%" fill="#ffffff"/>',
		'<text x="%d" y="22" font-size="14" font-weight="bold" fill="#1f2937">%s</text>' % (L, title),
	]

	def panel(y0, series, label):
		lo = min(min(s[0]) for s in series)
		hi = max(max(s[0]) for s in series)
		pad = max(1.0, (hi - lo) * 0.15)
		lo, hi = max(0.0, lo - pad), hi + pad
		parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="#d1d5db"/>' % (L, y0, w, ph))
		for k in range(3):
			v = lo + (hi - lo) * k / 2
			y = y0 + ph - ph * k / 2
			parts.append('<text x="%d" y="%.1f" text-anchor="end" fill="#4b5563">%.0f</text>' % (L - 6, y + 4, v))
			parts.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#eef0f3"/>' % (L, L + w, y, y))
		parts.append('<text x="%d" y="%d" fill="#4b5563">%s</text>' % (L + 6, y0 + 14, label))
		lx = L + w - 6
		for vals, color, name in series:
			parts.append('<polyline fill="none" stroke="%s" stroke-width="2" points="%s"/>' % (color, polyline(vals, L, w, y0, ph, lo, hi)))
			parts.append('<text x="%d" y="%d" text-anchor="end" fill="%s">%s</text>' % (lx, y0 + 14, color, name))
			lx -= 9 * len(name) + 12

	panel(T + 14, [(mem, "#2563eb", "memória estática (MB)")], "MB")
	y2 = T + 14 + ph + 40
	# Órfãos em escala própria seriam invisíveis ao lado dos nós: painel com os nós e texto dos órfãos.
	panel(y2, [(nodes, "#059669", "nós na Base")], "nós")
	parts.append('<text x="%d" y="%d" fill="#b45309">órfãos na Base por ida: %s</text>' % (
		L, y2 + ph + 34, " ".join(str(v) for v in orph)))
	for i, ida in enumerate(idas):
		if ida % 2 == 0 or len(idas) <= 12:
			x = L + w * i / max(1, len(idas) - 1)
			parts.append('<text x="%.1f" y="%d" text-anchor="middle" fill="#4b5563">%d</text>' % (x, y2 + ph + 16, ida))
	parts.append("</svg>")
	return "\n".join(parts) + "\n"


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("run_dir", nargs="?")
	ap.add_argument("--label", default="janela")
	ap.add_argument("--svg", default=None)
	args = ap.parse_args()
	run_dir = os.path.normpath(args.run_dir) if args.run_dir else latest_run()
	if not run_dir:
		print("nenhum run soak_20 em .bot_runs/")
		return 1
	data = rows(run_dir)
	report = "### %s (%s)\n\n%s\n\n%s\n" % (args.label, os.path.basename(run_dir), table(data), summary(data))
	os.makedirs(LOGS, exist_ok=True)
	with open(os.path.join(LOGS, "report_%s.md" % args.label), "w", encoding="utf-8") as f:
		f.write(report)
	svg_path = args.svg or os.path.join(ROOT, "docs", "qa", "soak_%s.svg" % args.label)
	os.makedirs(os.path.dirname(svg_path), exist_ok=True)
	with open(svg_path, "w", encoding="utf-8", newline="\n") as f:
		f.write(svg(data, "Resistência (%s): memória e nós na Base × ida" % args.label))
	if hasattr(sys.stdout, "reconfigure"):
		sys.stdout.reconfigure(encoding="utf-8")
	print(report)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
