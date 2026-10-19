"""Gera o roteiro de resistência (R5, #142) em tools/bot/soak_20.json.

Uso: python tools/bot/soak_gen.py [idas]   (padrão 22)
Cada ida sai da Base para um mapa desbloqueado (a Ilha fica de fora), alternando dia/noite e
clima forçado; cava, apanha, vende no SellPoint e volta. Um dump no fim da cena e outro na Base
depois de cada ida: os dumps trazem orphans/nodes e "perf" (memória, objetos, recursos, FPS
méd/mín da ida, tempo de carga). tools/bot/soak_report.py transforma tudo em tabela + SVG.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LOBBY = "res://world/lobby_base.tscn"
# Espelha core/night_mode.gd (NIGHT_BY_MAP) e core/weather_manager.gd (WEATHER_BY_MAP).
MAPS = [
	("praia", True, [-23, -23, 23, 23]),
	("campo", True, [-25, -25, 25, 25]),
	("ruinas", False, [-25, -25, 25, 25]),
	("geleira", True, [-25, -25, 25, 25]),
	("cratera", True, [-25, -25, 25, 25]),
]
STATE = {
	"unlocked_maps": [m[0] for m in MAPS],
	"defeated_bosses": ["king_crab", "giant_mole", "ancient_guardian", "frozen_mammoth"],
	"upgrade_levels": {"detector": 5, "backpack": 2, "shovel": 2},
	"team_money": 5000,
	"map_fragments": ["praia_frag_1", "campo_frag_1"],
}
RADIUS = 13
DIG_SECONDS = 30


def dig_loop(bounds):
	return {"loop": [
		{"explore": 10, "bounds": bounds, "stop_near_spot": RADIUS, "timeout": 8, "if": ["free_slots>=1", "nearest_spot>%d" % RADIUS]},
		{"goto_spot": "nearest", "walk": True, "radius": RADIUS, "timeout": 15, "if": ["free_slots>=1", "nearest_spot<=%d" % RADIUS]},
		{"dig_spot": True, "mode": "fast", "timeout": 15, "if": ["free_slots>=1", "nearest_spot<=1.8"]},
		{"pickup": True, "radius": 6, "timeout": 6, "if": ["free_slots>=1", "pickup_dist<=6"]},
	], "until": "deliverable>=2", "timeout": DIG_SECONDS}


def trip(i):
	map_id, has_weather, bounds = MAPS[i % len(MAPS)]
	night = i % 2 == 1
	weather = has_weather and i % 3 == 2
	label = "%02d_%s_%s%s" % (i + 1, map_id, "noite" if night else "dia", "_clima" if weather else "")
	start = {"t": 0, "start_expedition": map_id, "timeout": 60}
	if night:
		start["night"] = True
	steps = [start, {"sleep": 1.5}, {"t": 0, "pickup": True, "radius": 8, "timeout": 8, "if": "pickup_dist<=8"}]
	if weather:
		steps.append({"t": 0, "call": "CoreWeather", "method": "force_weather"})
	steps += [
		dig_loop(bounds),
		{"t": 0, "goto_sell": True, "timeout": 40, "if": "deliverable>=1"},
		{"t": 0, "sell": True, "timeout": 5, "if": ["deliverable>=1", "sell_dist<=2"]},
		{"t": 0, "dump": label + "_cena"},
		{"t": 0, "call": "CoreSessionUI", "method": "request_return_to_base"},
		{"wait_until": "in_expedition==0", "timeout": 40},
		{"sleep": 3.0},
		{"t": 0, "ui_press": "SummaryCloseButton"},
		{"sleep": 2.0},
		{"t": 0, "dump": label + "_base"},
	]
	return steps


def soak_script(trips):
	steps = [{"t": 0.3, "set_state": STATE}, {"t": 3.0, "dump": "00_base"}]
	for i in range(trips):
		steps += trip(i)
	steps.append({"t": 0, "quit": True})
	return {"scene": LOBBY, "steps": steps}


def main():
	trips = int(sys.argv[1]) if len(sys.argv) > 1 else 22
	path = os.path.join(HERE, "soak_20.json")
	with open(path, "w", encoding="utf-8", newline="\n") as f:
		json.dump(soak_script(trips), f, ensure_ascii=False, indent="\t")
		f.write("\n")
	print("%s: %d idas" % (os.path.relpath(path), trips))


if __name__ == "__main__":
	main()
