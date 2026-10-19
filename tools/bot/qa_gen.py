"""Gera os roteiros de QA (#126) em tools/bot/qa_*.json.

Uso: python tools/bot/qa_gen.py
Matriz: 6 mapas x (dia, noite onde houver) x (clima forcado onde houver), mais
Base (abas + Ver museu), pausa, titulo + slots e vitoria. Os dumps trazem fps,
orphans e nodes; tools/bot/qa_report.py junta tudo numa tabela.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
LOBBY = "res://world/lobby_base.tscn"
ALL_MAPS = ["praia", "campo", "ruinas", "geleira", "cratera", "ilha_tesouro"]
# Espelha core/night_mode.gd (NIGHT_BY_MAP) e core/weather_manager.gd (WEATHER_BY_MAP).
MAPS = {
	"praia": {"night": True, "weather": True, "bounds": [-23, -23, 23, 23]},
	"campo": {"night": True, "weather": True, "bounds": [-25, -25, 25, 25]},
	"ruinas": {"night": True, "weather": False, "bounds": [-25, -25, 25, 25]},
	"geleira": {"night": True, "weather": True, "bounds": [-25, -25, 25, 25]},
	"cratera": {"night": True, "weather": True, "bounds": [-25, -25, 25, 25]},
	"ilha_tesouro": {"night": False, "weather": False, "bounds": [-18, -18, 18, 18]},
}
STATE = {
	"unlocked_maps": ALL_MAPS,
	"defeated_bosses": ["king_crab", "giant_mole", "ancient_guardian", "frozen_mammoth"],
	"upgrade_levels": {"detector": 5, "backpack": 2, "shovel": 2},
	"team_money": 5000,
	"map_fragments": ["praia_frag_1", "campo_frag_1"],
}
# A Ilha só abre com o Mapa do Tesouro completo (GameState.has_all_map_fragments).
ALL_FRAGMENTS = ["praia_frag_1", "campo_frag_1", "ruinas_frag_1", "ruinas_frag_2",
	"geleira_frag_1", "geleira_frag_2", "cratera_frag_1", "cratera_frag_2"]
# ~20 s andando: 10 x (explorar 8 m, no maximo 2 s) com um dump de FPS a cada volta.
WALK_ROUNDS = 10


def walk(prefix, bounds, rounds=WALK_ROUNDS):
	steps = []
	for i in range(rounds):
		steps.append({"t": 0, "explore": 8, "bounds": bounds, "timeout": 2.0})
		steps.append({"t": 0, "dump": "%s_w%02d" % (prefix, i)})
	return steps


def trip(map_id, cfg, label, night, weather):
	start = {"t": 0, "start_expedition": map_id, "timeout": 60}
	if night:
		start["night"] = True
	steps = [start, {"sleep": 3.0}, {"t": 0, "screenshot": label + "_inicio"}, {"t": 0, "dump": label + "_inicio"}]
	steps += walk(label, cfg["bounds"])
	if weather:
		steps += [
			{"t": 0, "call": "CoreWeather", "method": "force_weather"},
			{"sleep": 16.0},
			{"t": 0, "screenshot": label + "_clima"},
		]
		steps += walk(label + "_clima", cfg["bounds"], 5)
	steps += [
		{"t": 0, "dump": label + "_fim_cena"},
		{"t": 0, "call": "CoreSessionUI", "method": "request_return_to_base"},
		{"wait_until": "in_expedition==0", "timeout": 40},
		{"sleep": 3.0},
		{"t": 0, "ui_press": "SummaryCloseButton"},
		{"sleep": 2.0},
		{"t": 0, "dump": label + "_lobby_depois"},
	]
	return steps


def map_script(map_id):
	cfg = MAPS[map_id]
	state = dict(STATE, map_fragments=ALL_FRAGMENTS) if map_id == "ilha_tesouro" else STATE
	steps = [{"t": 0.3, "set_state": state}, {"t": 2.0, "dump": "00_lobby_antes"}]
	steps += trip(map_id, cfg, "10_dia", False, cfg["weather"])
	if cfg["night"]:
		steps += trip(map_id, cfg, "20_noite", True, False)
	# 3.a ida curta: confirma se os orfaos voltam ao patamar ou continuam a subir.
	steps += [
		{"t": 0, "start_expedition": map_id, "timeout": 60},
		{"sleep": 5.0},
		{"t": 0, "dump": "30_repete_fim_cena"},
		{"t": 0, "call": "CoreSessionUI", "method": "request_return_to_base"},
		{"wait_until": "in_expedition==0", "timeout": 40},
		{"sleep": 3.0},
		{"t": 0, "ui_press": "SummaryCloseButton"},
		{"sleep": 2.0},
		{"t": 0, "dump": "30_repete_lobby_depois"},
		{"t": 0, "quit": True},
	]
	return {"scene": LOBBY, "steps": steps}


def base_script():
	steps = [{"t": 0.3, "set_state": STATE}, {"t": 2.0, "dump": "00_lobby"}, {"t": 0, "screenshot": "00_lobby"}]
	for i, tab in enumerate(["Loja de Equipamentos", "Museu de Achados", "Expedições", "Diário", "Mapa do Tesouro"]):
		steps += [{"t": 0, "ui_tab": tab}, {"sleep": 0.6}, {"t": 0, "screenshot": "%02d_aba" % (i + 1)}]
	steps += [
		{"t": 0, "ui_tab": "Museu de Achados"},
		{"sleep": 0.5},
		{"t": 0, "ui_press": "ViewMuseumButton"},
		{"sleep": 2.5},
		{"t": 0, "screenshot": "10_ver_museu"},
		{"t": 0, "dump": "10_ver_museu"},
		{"t": 0, "ui_press": "BackButton"},
		{"sleep": 2.0},
		{"t": 0, "screenshot": "11_volta_tenda"},
		{"t": 0, "dump": "11_volta_tenda"},
		{"t": 0, "quit": True},
	]
	return {"scene": LOBBY, "steps": steps}


def pause_script():
	steps = [
		{"t": 0.3, "set_state": STATE},
		{"t": 1.5, "call": "CorePauseMenu", "method": "toggle"},
		{"sleep": 0.5},
		{"t": 0, "screenshot": "01_pausa_lobby"},
		{"t": 0, "ui_press": "Configurações"},
		{"sleep": 0.5},
		{"t": 0, "screenshot": "02_pausa_config"},
		{"t": 0, "ui_press": "Voltar"},
		{"sleep": 0.3},
		{"t": 0, "ui_press": "Continuar"},
		{"sleep": 0.5},
		{"t": 0, "start_expedition": "praia", "timeout": 60},
		{"sleep": 3.0},
		{"t": 0, "dump": "10_praia"},
		{"t": 0, "call": "CorePauseMenu", "method": "toggle"},
		{"sleep": 1.0},
		{"t": 0, "screenshot": "11_pausa_praia"},
		{"t": 0, "dump": "11_pausa_praia"},
		{"t": 0, "call": "CorePauseMenu", "method": "toggle"},
		{"sleep": 0.5},
		{"t": 0, "call": "CorePauseMenu", "method": "toggle"},
		{"sleep": 0.3},
		{"t": 0, "ui_press": "Voltar à base"},
		{"wait_until": "in_expedition==0", "timeout": 40},
		{"sleep": 3.0},
		{"t": 0, "screenshot": "12_resumo"},
		{"t": 0, "ui_press": "SummaryCloseButton"},
		{"sleep": 1.0},
		{"t": 0, "dump": "13_lobby_depois"},
		{"t": 0, "quit": True},
	]
	return {"scene": LOBBY, "steps": steps}


def to_title(label):
	return [
		{"t": 0, "call": "CorePauseMenu", "method": "toggle"},
		{"sleep": 0.5},
		{"t": 0, "ui_press": "Sair para o menu principal"},
		{"sleep": 0.3},
		{"t": 0, "ui_press": "Ir para o menu"},
		{"sleep": 3.0},
		{"t": 0, "screenshot": label},
		{"t": 0, "dump": label},
	]


def title_script():
	# Corre com os slots vazios (tools/bot/run_qa.sh guarda e limpa o user:// antes).
	steps = [
		{"t": 2.0, "screenshot": "00_titulo"},
		{"t": 0, "dump": "00_titulo"},
		{"t": 0, "ui_press": "Novo jogo"},
		{"sleep": 0.5},
		{"t": 0, "screenshot": "01_slots_novo"},
		{"t": 0, "ui_press": "Slot 1"},
		{"sleep": 3.0},
		{"t": 0, "dump": "02_lobby_novo"},
	]
	steps += to_title("03_titulo_continuar")
	steps += [{"t": 0, "ui_press": "Continuar"}, {"sleep": 3.0}, {"t": 0, "dump": "04_lobby_continuar"}]
	steps += to_title("05_titulo")
	steps += [
		{"t": 0, "ui_press": "Carregar"},
		{"sleep": 0.5},
		{"t": 0, "screenshot": "06_slots_carregar"},
		{"t": 0, "ui_press": "Slot 1"},
		{"sleep": 3.0},
		{"t": 0, "dump": "07_lobby_carregar"},
	]
	steps += to_title("08_titulo")
	steps += [
		{"t": 0, "ui_press": "Carregar"},
		{"sleep": 0.5},
		{"t": 0, "ui_press": "Apagar"},
		{"sleep": 0.3},
		{"t": 0, "screenshot": "09_confirma_apagar"},
		{"t": 0, "ui_press": "Confirmar"},
		{"sleep": 0.5},
		{"t": 0, "screenshot": "10_slots_apagado"},
		{"t": 0, "dump": "10_slots_apagado"},
		{"t": 0, "ui_press": "Voltar"},
		{"sleep": 0.5},
		{"t": 0, "screenshot": "11_titulo_fim"},
		{"t": 0, "quit": True},
	]
	return {"scene": "res://world/title_screen.tscn", "steps": steps}


def victory_script():
	steps = [
		{"t": 0.3, "set_state": STATE},
		{"t": 1.5, "dump": "00_lobby"},
		{"t": 0, "call": "CoreVictoryScreen", "method": "open"},
		{"sleep": 2.0},
		{"t": 0, "screenshot": "01_vitoria"},
		{"t": 0, "ui_press": "Créditos"},
		{"sleep": 1.0},
		{"t": 0, "screenshot": "02_creditos"},
		{"t": 0, "call": "CoreVictoryScreen", "method": "close"},
		{"sleep": 1.0},
		{"t": 0, "screenshot": "03_fechada"},
		{"t": 0, "dump": "03_fechada"},
		{"t": 0, "quit": True},
	]
	return {"scene": LOBBY, "steps": steps}


def main():
	scripts = {"qa_%s" % m: map_script(m) for m in MAPS}
	scripts.update({
		"qa_base": base_script(),
		"qa_pause": pause_script(),
		"qa_title_slots": title_script(),
		"qa_victory": victory_script(),
	})
	for name, data in scripts.items():
		with open(os.path.join(HERE, name + ".json"), "w", encoding="utf-8", newline="\n") as f:
			json.dump(data, f, ensure_ascii=False, indent="\t")
			f.write("\n")
	print("\n".join(sorted(scripts)))


if __name__ == "__main__":
	main()
