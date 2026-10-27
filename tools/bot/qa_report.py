"""Junta os runs de QA (#126) numa tabela Markdown.

Uso: python tools/bot/qa_report.py   (depois de tools/bot/run_qa.sh)
Lê o run mais recente de cada qa_*.json em .bot_runs/ (summary.json + dumps) e o log do
Godot em .bot_runs/qa_logs/<roteiro>.log. Grava .bot_runs/qa_logs/report.md e imprime-o.
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
RUNS = os.path.join(ROOT, ".bot_runs")
LOGS = os.path.join(RUNS, "qa_logs")
# Ruído conhecido (headless, dummy renderer, saída do Godot): não conta.
NOISE = [
	'Parameter "m" is null',
	"ObjectDB instances leaked",
	"leaked at exit",
	"captura",
	"screenshot",
	"[DebugBridge]",
]
MAP_ORDER = ["praia", "campo", "ruinas", "geleira", "cratera", "lua"]
PHASES = [("10_dia", "dia"), ("10_dia_clima", "dia + clima"), ("20_noite", "noite")]


def latest_run(name):
	dirs = [d for d in glob.glob(os.path.join(RUNS, name + "_*")) if os.path.isdir(d)]
	dirs = [d for d in dirs if re.fullmatch(re.escape(name) + r"_\d[\d_-]*", os.path.basename(d))]
	return max(dirs, key=os.path.getmtime) if dirs else None


def load(path):
	try:
		with open(path, encoding="utf-8") as f:
			return json.load(f)
	except (OSError, ValueError):
		return None


def log_issues(name):
	path = os.path.join(LOGS, name + ".log")
	script_errors, errors, warnings = [], [], []
	try:
		with open(path, encoding="utf-8", errors="replace") as f:
			lines = f.read().splitlines()
	except OSError:
		return None
	exit_count = 0
	at_exit = False
	for i, line in enumerate(lines):
		# Depois do "fim:" do bot só vem o desligar do Godot (vazamentos de RID/ObjectDB à saída).
		if line.startswith("[DebugBridge] fim:"):
			at_exit = True
		if at_exit and (line.startswith("WARNING") or line.startswith("ERROR")):
			exit_count += 1
			continue
		if any(n in line for n in NOISE):
			continue
		where = lines[i + 1].strip() if i + 1 < len(lines) else ""
		entry = line.strip() + ((" | " + where) if where.startswith("at:") else "")
		if "SCRIPT ERROR" in line:
			script_errors.append(entry)
		elif line.startswith("ERROR") or "push_error" in line:
			errors.append(entry)
		elif line.startswith("WARNING"):
			warnings.append(entry)
	return script_errors, errors, warnings, exit_count


def fps_stats(run_dir, prefix):
	fps = []
	for p in sorted(glob.glob(os.path.join(run_dir, prefix + "_w[0-9][0-9].json"))):
		d = load(p)
		if d is not None:
			fps.append(float(d.get("fps", 0)))
	# A 1.ª amostra ainda traz o carregamento da cena.
	fps = fps[1:] if len(fps) > 2 else fps
	if not fps:
		return "-"
	return "%.0f / %.0f" % (sum(fps) / len(fps), min(fps))


def orphans(run_dir, label):
	d = load(os.path.join(run_dir, label + ".json"))
	return "?" if d is None else str(d.get("orphans", "?"))


def uniq(items, limit=6):
	seen = []
	for it in items:
		if it not in seen:
			seen.append(it)
	return seen[:limit]


NAV_NAMES = {
	"titulo": "título", "slots": "slots (vazios)", "config_video": "configurações: Vídeo",
	"config_audio": "configurações: Áudio", "config_controles": "configurações: Controles",
	"config_jogabilidade": "configurações: Jogabilidade", "menu_coop": "menu Multiplayer (lobby coop)",
	"base_loja": "Base: Loja", "base_museu": "Base: Museu", "base_expedicoes": "Base: Expedições",
	"base_diario": "Base: Diário", "ver_museu": "Ver museu",
	"pausa": "pausa", "pausa_sair": "pausa: confirmar sair", "pausa_config": "pausa: configurações",
	"pausa_fecha": "pausa (fechar)", "vitoria": "vitória", "creditos": "créditos", "vitoria_fecha": "vitória (fechar)",
	"resumo": "resumo do dia", "slots_save": "slots (com save)", "apagar": "apagar slot",
}


def nav_section():
	"""#135: qa_nav_keyboard / qa_nav_pad (passo nav_audit do DebugBridge)."""
	runs = {}
	for device in ("keyboard", "pad"):
		run = latest_run("qa_nav_" + device)
		summary = load(os.path.join(run, "summary.json")) if run else None
		runs[device] = {r["label"]: r for r in (summary or {}).get("nav", [])}
	if not any(runs.values()):
		return ["", "## Navegação", "", "sem runs de qa_nav_keyboard/qa_nav_pad"]
	out = ["", "## Navegação", "",
		"Alcançados/total = controles interativos visíveis e ativos alcançados só com setas/Tab (teclado) ou o "
		"direcional (comando), a partir do foco inicial. Armadilhas = foco perdido, em controle oculto/desativado, "
		"fora da camada ou sem volta. Esc/B: \"—\" quando a tela é a camada de baixo (título, Base, menu de rede).", "",
		"| tela | teclado | comando | armadilhas | Esc/B ok |", "|---|---|---|---|---|"]
	labels = list(runs["keyboard"]) or list(runs["pad"])
	for label in labels:
		cols, traps, cancel = [], [], []
		for device in ("keyboard", "pad"):
			r = runs[device].get(label)
			res = (r or {}).get(device)
			if not res:
				cols.append("sem run")
				continue
			total = len(res["existing"])
			reached = total - len(res["missing"])
			cell = "%d/%d" % (reached, total)
			if not res["initial_ok"]:
				cell += " (foco inicial errado)"
			if res["no_focus_style"]:
				cell += " (%d sem borda)" % len(res["no_focus_style"])
			cols.append(cell)
			traps += res["traps"]
			if r.get("cancel"):
				cancel.append(bool(r["cancel"].get("closed")) and bool(r["cancel"].get("focus_ok")))
		esc = "—" if not cancel else ("ok" if all(cancel) else "falhou")
		out.append("| %s | %s | %s | %s | %s |" % (NAV_NAMES.get(label, label), cols[0], cols[1], len(traps), esc))
	return out


def main():
	sys.stdout.reconfigure(encoding="utf-8")
	out = ["# Runs de QA (gerado por tools/bot/qa_report.py)", ""]
	out.append("| mapa | fase | SCRIPT ERROR | erros | warnings | órfãos lobby→fim cena→lobby | FPS méd/mín |")
	out.append("|---|---|---|---|---|---|---|")
	details = []
	for m in MAP_ORDER:
		name = "qa_" + m
		run = latest_run(name)
		issues = log_issues(name)
		if run is None:
			out.append("| %s | - | sem run | | | | |" % m)
			continue
		se, er, wa, ex = issues if issues else ([], [], [], 0)
		summary = load(os.path.join(run, "summary.json")) or {}
		bridge_errors = summary.get("errors", [])
		first = True
		for prefix, phase in PHASES:
			if not glob.glob(os.path.join(run, prefix + "_w00.json")):
				continue
			base = prefix.replace("_clima", "")
			orf = "%s→%s→%s" % (orphans(run, "00_lobby_antes" if base == "10_dia" else "10_dia_lobby_depois"),
				orphans(run, base + "_fim_cena"), orphans(run, base + "_lobby_depois"))
			if prefix.endswith("_clima"):
				orf = "(igual ao dia)"
			cols = (len(se), len(er), "%d (+%d à saída)" % (len(wa), ex)) if first else ("〃", "〃", "〃")
			out.append("| %s | %s | %s | %s | %s | %s | %s |" % (m, phase, cols[0], cols[1], cols[2], orf, fps_stats(run, prefix)))
			first = False
		out.append("| %s | 3.ª ida | | | | %s→%s | |" % (m, orphans(run, "30_repete_fim_cena"), orphans(run, "30_repete_lobby_depois")))
		if se or er or wa or bridge_errors:
			details.append((name, se, er, wa, bridge_errors, summary.get("metrics", {}).get("step_failures", 0)))
	out += ["", "## Telas", "", "| roteiro | SCRIPT ERROR | erros | warnings | erros do bot | avisos de passo | órfãos (dumps) |", "|---|---|---|---|---|---|---|"]
	for name in ["qa_base", "qa_pause", "qa_title_slots", "qa_victory", "qa_nav_keyboard", "qa_nav_pad"]:
		run = latest_run(name)
		issues = log_issues(name)
		if run is None or issues is None:
			out.append("| %s | sem run | | | | | |" % name)
			continue
		se, er, wa, ex = issues
		summary = load(os.path.join(run, "summary.json")) or {}
		dumps = sorted(glob.glob(os.path.join(run, "*.json")))
		orf = " → ".join("%s" % (load(p) or {}).get("orphans", "?") for p in dumps
			if not p.endswith("summary.json") and not os.path.basename(p).startswith("nav_"))
		out.append("| %s | %d | %d | %d (+%d à saída) | %d | %s | %s |" % (name, len(se), len(er), len(wa), ex, len(summary.get("errors", [])),
			summary.get("metrics", {}).get("step_failures", 0), orf))
		if se or er or wa or summary.get("errors"):
			details.append((name, se, er, wa, summary.get("errors", []), summary.get("metrics", {}).get("step_failures", 0)))
	out += nav_section()
	out += ["", "## Detalhes", ""]
	for name, se, er, wa, be, sf in details:
		out.append("### %s" % name)
		for title, items in (("SCRIPT ERROR", se), ("ERROR", er), ("WARNING", wa), ("erros do bot", be)):
			for it in uniq(items):
				out.append("- %s: `%s`" % (title, it[:300]))
		out.append("")
	text = "\n".join(out) + "\n"
	os.makedirs(LOGS, exist_ok=True)
	with open(os.path.join(LOGS, "report.md"), "w", encoding="utf-8") as f:
		f.write(text)
	print(text)


if __name__ == "__main__":
	main()
