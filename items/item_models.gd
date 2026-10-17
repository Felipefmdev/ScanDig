class_name ItemModels
extends RefCounted

## Modelos low-poly dos itens de museu (#61), feitos a partir das referências em
## docs/art/reference/<id>.jpg (lista em docs/art/PROMPTS.md, "Itens de museu"). Cada item tem
## ~0.2-0.3 m e assenta em y = 0; ItemPickup desce-o para a base da caixa de colisão.
## build() devolve null para ids sem modelo (o pickup volta ao cubo colorido).

const GOLD: Color = Color("#e0a830")
const GOLD_DARK: Color = Color("#a8761c")
const SILVER: Color = Color("#c4c8cc")
const SILVER_DARK: Color = Color("#7e848c")
const BRONZE: Color = Color("#b07a3a")
const BRONZE_DARK: Color = Color("#7a5226")
const RUST: Color = Color("#9a5428")
const RUST_DARK: Color = Color("#5e3218")
const IRON: Color = Color("#5c5a58")
const WOOD: Color = Color("#7a5030")
const WOOD_DARK: Color = Color("#4e321e")
const LEATHER: Color = Color("#6a4028")
const GLASS: Color = Color("#c8e4ec")
const BOTTLE_GREEN: Color = Color("#6f9a62")
const PAPER: Color = Color("#e6d4a8")
const ALGAE: Color = Color("#5f8a2e")
const RED_GEM: Color = Color("#c8203a")
const CYAN_GLOW: Color = Color("#40e8e0")
const VIOLET_GLOW: Color = Color("#a050ff")
const ICE: Color = Color("#b8e0f0")
const IVORY: Color = Color("#e8dcc0")
const CHOCOLATE: Color = Color("#5a3220")
const FEATHER: Color = Color("#22242c")
const DIAL: Color = Color("#f0ead8")
const INK: Color = Color("#2b2118")
const JADE: Color = Color("#388a58")
const JADE_DARK: Color = Color("#1e5636")
const TURQUOISE: Color = Color("#2ab8a6")
const RED_CLOTH: Color = Color("#9c3032")
const OBSIDIAN: Color = Color("#202028")
const MAGMA_GLOW: Color = Color("#ff6020")
const DEEP_BLUE: Color = Color("#182858")
const RIBBON_BLUE: Color = Color("#4870a8")
const STONE_GREY: Color = Color("#68686e")
const STONE_DARK: Color = Color("#424248")

const BASE_Y: float = -0.12


## Modelo do item `id`, ou null se ainda não tiver um.
static func build(id: String, is_rare: bool = false) -> Node3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow: SurfaceTool = SurfaceTool.new()
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow_color: Color = Color.BLACK
	match id:
		"lata_enferrujada":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.07, 0.0), 0.075, 0.07, 9, RUST)
			LowPolyMesh.prism(st, Vector3(0.0, 0.07, 0.0), Vector3(0.01, 0.13, 0.0), 0.07, 0.078, 9, SILVER_DARK)
			LowPolyMesh.box(st, Vector3(0.0, 0.08, -0.07), Vector3(0.09, 0.05, 0.01), Basis(Vector3.FORWARD, 0.1), PAPER)
			LowPolyMesh.prism(st, Vector3(0.01, 0.13, 0.0), Vector3(0.01, 0.14, 0.0), 0.078, 0.074, 9, RUST_DARK)
		"chave_enferrujada":
			var b: Basis = Basis(Vector3.UP, 0.5)
			LowPolyMesh.prism(st, b * Vector3(-0.1, 0.015, 0.0), b * Vector3(0.08, 0.015, 0.0), 0.014, 0.014, 6, RUST)
			_ring(st, b * Vector3(-0.13, 0.015, 0.0), Vector3.UP, 0.035, 0.012, 8, RUST_DARK)
			LowPolyMesh.box(st, b * Vector3(0.07, 0.015, 0.03), Vector3(0.02, 0.02, 0.045), b, RUST)
			LowPolyMesh.box(st, b * Vector3(0.03, 0.015, 0.025), Vector3(0.015, 0.02, 0.035), b, RUST_DARK)
		"moeda_antiga":
			_coin(st, 0.07, GOLD, GOLD_DARK)
			LowPolyMesh.box(st, Vector3(0.0, 0.027, 0.0), Vector3(0.05, 0.006, 0.04), Basis.IDENTITY, GOLD_DARK)
		"alianca_ouro":
			_ring(st, Vector3(0.0, 0.03, 0.0), Vector3.UP, 0.07, 0.025, 12, GOLD)
		"anel_do_poco":
			_ring(st, Vector3(0.0, 0.03, 0.0), Vector3.UP, 0.07, 0.028, 12, GOLD)
			for k: int in 4:
				var a: float = TAU * float(k) / 4.0 + 0.4
				LowPolyMesh.box(st, Vector3(sin(a) * 0.07, 0.055, cos(a) * 0.07), Vector3(0.04, 0.012, 0.03), Basis(Vector3.UP, a), ALGAE)
		"anel_sinete":
			_ring(st, Vector3(0.0, 0.06, 0.0), Vector3.FORWARD, 0.05, 0.016, 10, GOLD)
			LowPolyMesh.box(st, Vector3(0.0, 0.115, 0.0), Vector3(0.06, 0.025, 0.05), Basis.IDENTITY, GOLD_DARK)
			LowPolyMesh.prism(st, Vector3(0.0, 0.127, 0.0), Vector3(0.0, 0.142, 0.0), 0.02, 0.012, 6, RED_GEM)
		"concha_dourada":
			for k: int in 5:
				var r: float = 0.08 - 0.014 * float(k)
				LowPolyMesh.prism(st, Vector3(0.0, 0.025 * float(k), 0.01 * float(k)), Vector3(0.0, 0.025 * float(k) + 0.04, 0.01 * float(k)), r, r * 0.8, 9, GOLD if k % 2 == 0 else GOLD_DARK)
		"bussola_naufragio":
			_compass(st, BRONZE, BRONZE_DARK)
			LowPolyMesh.box(st, Vector3(0.06, 0.03, 0.05), Vector3(0.06, 0.01, 0.02), Basis(Vector3.UP, 0.6), ALGAE)
		"bussola_antiga":
			LowPolyMesh.box(st, Vector3(0.0, 0.02, 0.0), Vector3(0.2, 0.04, 0.16), Basis.IDENTITY, LEATHER)
			_compass(st, BRONZE, BRONZE_DARK)
			LowPolyMesh.box(st, Vector3(-0.08, 0.045, -0.06), Vector3(0.05, 0.012, 0.03), Basis.IDENTITY, ICE)
		"medalhao_sereia":
			_coin(st, 0.065, SILVER, SILVER_DARK)
			_ring(st, Vector3(0.0, 0.025, -0.08), Vector3.UP, 0.016, 0.006, 6, SILVER_DARK)
			LowPolyMesh.prism(st, Vector3(-0.01, 0.027, 0.03), Vector3(0.01, 0.027, -0.03), 0.012, 0.006, 4, SILVER_DARK)
		"mapa_na_garrafa":
			LowPolyMesh.prism(st, Vector3(0.0, 0.04, 0.09), Vector3(0.0, 0.04, -0.06), 0.045, 0.045, 8, BOTTLE_GREEN)
			LowPolyMesh.prism(st, Vector3(0.0, 0.04, -0.06), Vector3(0.0, 0.04, -0.11), 0.045, 0.018, 8, BOTTLE_GREEN)
			LowPolyMesh.prism(st, Vector3(0.0, 0.04, -0.11), Vector3(0.0, 0.04, -0.14), 0.016, 0.015, 6, WOOD)
			LowPolyMesh.prism(st, Vector3(0.0, 0.04, 0.07), Vector3(0.0, 0.04, -0.04), 0.022, 0.022, 6, PAPER)
		"olho_do_polvo":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.03, 0.0), 0.06, 0.055, 8, BRONZE)
			LowPolyMesh.prism(st, Vector3(0.0, 0.03, 0.0), Vector3(0.0, 0.17, 0.0), 0.075, 0.075, 10, Color("#8cc4c4"))
			LowPolyMesh.prism(st, Vector3(0.0, 0.17, 0.0), Vector3(0.0, 0.2, 0.0), 0.06, 0.05, 8, BRONZE)
			LowPolyMesh.prism(glow, Vector3(0.0, 0.1, -0.07), Vector3(0.0, 0.1, -0.08), 0.04, 0.035, 8, Color("#d8307a"))
			LowPolyMesh.prism(st, Vector3(0.0, 0.1, -0.08), Vector3(0.0, 0.1, -0.083), 0.015, 0.015, 6, INK)
			glow_color = Color(0.35, 0.05, 0.18)
		"moeda_chocolate":
			_coin(st, 0.065, CHOCOLATE, CHOCOLATE.darkened(0.3))
			LowPolyMesh.box(st, Vector3(0.03, 0.02, 0.03), Vector3(0.08, 0.03, 0.07), Basis(Vector3.UP, 0.5), GOLD)
		"coroa_caranguejo_rei":
			_ring(st, Vector3(0.0, 0.03, 0.0), Vector3.UP, 0.07, 0.02, 10, GOLD)
			for k: int in 5:
				var a: float = TAU * float(k) / 5.0
				var p: Vector3 = Vector3(sin(a) * 0.07, 0.04, cos(a) * 0.07)
				LowPolyMesh.prism(st, p, p + Vector3(sin(a) * 0.02, 0.07, cos(a) * 0.02), 0.02, 0.005, 4, GOLD)
				LowPolyMesh.prism(st, p + Vector3(0.0, 0.05, 0.0), p + Vector3(-sin(a) * 0.02, 0.09, -cos(a) * 0.02), 0.012, 0.0, 4, GOLD_DARK)
		"ferradura_velha":
			for k: int in 9:
				var a0: float = PI * 1.2 * float(k) / 9.0 - PI * 0.1
				var a1: float = PI * 1.2 * float(k + 1) / 9.0 - PI * 0.1
				LowPolyMesh.prism(st, Vector3(cos(a0) * 0.07, 0.015, -sin(a0) * 0.07), Vector3(cos(a1) * 0.07, 0.015, -sin(a1) * 0.07), 0.016, 0.016, 4, RUST if k % 2 == 0 else RUST_DARK)
			for k: int in 4:
				var a: float = PI * (0.15 + 0.23 * float(k))
				LowPolyMesh.prism(st, Vector3(cos(a) * 0.07, 0.03, -sin(a) * 0.07), Vector3(cos(a) * 0.07, 0.06, -sin(a) * 0.07), 0.006, 0.004, 4, IRON)
		"colher_prata":
			LowPolyMesh.prism(st, Vector3(0.0, 0.015, -0.08), Vector3(0.0, 0.02, -0.06), 0.035, 0.03, 8, SILVER)
			LowPolyMesh.box(st, Vector3(0.0, 0.015, 0.03), Vector3(0.016, 0.008, 0.16), Basis.IDENTITY, SILVER_DARK)
			LowPolyMesh.box(st, Vector3(0.0, 0.016, 0.11), Vector3(0.03, 0.01, 0.03), Basis(Vector3.UP, 0.78), SILVER)
		"ponta_lanca_ferro":
			LowPolyMesh.prism(st, Vector3(0.0, 0.025, 0.09), Vector3(0.0, 0.025, 0.02), 0.02, 0.018, 6, RUST_DARK)
			LowPolyMesh.prism(st, Vector3(0.0, 0.025, 0.02), Vector3(0.0, 0.025, -0.12), 0.05, 0.0, 4, IRON)
		"medalha_militar":
			LowPolyMesh.box(st, Vector3(0.0, 0.01, -0.05), Vector3(0.06, 0.012, 0.07), Basis.IDENTITY, Color("#3a4a7a"))
			LowPolyMesh.box(st, Vector3(0.0, 0.017, -0.05), Vector3(0.02, 0.004, 0.07), Basis.IDENTITY, Color("#b8402e"))
			for k: int in 4:
				LowPolyMesh.box(st, Vector3(0.0, 0.015, 0.04), Vector3(0.025, 0.012, 0.09), Basis(Vector3.UP, PI * 0.25 * float(k)), BRONZE)
			LowPolyMesh.prism(st, Vector3(0.0, 0.015, 0.04), Vector3(0.0, 0.027, 0.04), 0.022, 0.02, 8, BRONZE_DARK)
		"sino_bronze":
			LowPolyMesh.box(st, Vector3(0.0, 0.01, 0.0), Vector3(0.2, 0.02, 0.06), Basis.IDENTITY, WOOD_DARK)
			for side: float in [-1.0, 1.0]:
				LowPolyMesh.box(st, Vector3(0.085 * side, 0.1, 0.0), Vector3(0.025, 0.18, 0.025), Basis.IDENTITY, WOOD)
			LowPolyMesh.box(st, Vector3(0.0, 0.19, 0.0), Vector3(0.22, 0.03, 0.035), Basis.IDENTITY, WOOD_DARK)
			LowPolyMesh.prism(st, Vector3(0.0, 0.17, 0.0), Vector3(0.0, 0.06, 0.0), 0.025, 0.06, 9, BRONZE)
			LowPolyMesh.prism(st, Vector3(0.0, 0.06, 0.0), Vector3(0.0, 0.05, 0.0), 0.065, 0.065, 9, BRONZE_DARK)
		"moeda_celta":
			_coin(st, 0.07, GOLD, GOLD_DARK)
			_ring(st, Vector3(0.0, 0.027, 0.0), Vector3.UP, 0.04, 0.005, 10, GOLD_DARK)
		"fibula_romana":
			LowPolyMesh.prism(st, Vector3(-0.09, 0.02, 0.0), Vector3(0.06, 0.02, 0.0), 0.006, 0.006, 4, SILVER_DARK)
			LowPolyMesh.prism(st, Vector3(-0.09, 0.03, 0.0), Vector3(-0.02, 0.07, 0.0), 0.016, 0.02, 6, SILVER)
			LowPolyMesh.prism(st, Vector3(-0.02, 0.07, 0.0), Vector3(0.07, 0.03, 0.0), 0.02, 0.014, 6, SILVER)
			LowPolyMesh.prism(st, Vector3(0.07, 0.03, 0.0), Vector3(0.09, 0.02, 0.0), 0.016, 0.01, 6, SILVER_DARK)
		"pena_corvo_rei":
			var bf: Basis = Basis(Vector3.UP, 0.4)
			LowPolyMesh.prism(st, bf * Vector3(0.0, 0.01, 0.13), bf * Vector3(0.0, 0.01, -0.13), 0.006, 0.003, 4, INK)
			for k: int in 6:
				var z: float = 0.08 - 0.035 * float(k)
				LowPolyMesh.box(st, bf * Vector3(0.0, 0.01, z), Vector3(0.07 - 0.006 * float(k), 0.006, 0.04), bf * Basis(Vector3.UP, 0.25), FEATHER)
			LowPolyMesh.box(st, bf * Vector3(0.0, 0.012, -0.12), Vector3(0.03, 0.007, 0.03), bf, GOLD)
		"lanterna_espantalho":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.03, 0.0), 0.06, 0.055, 6, RUST_DARK)
			for k: int in 6:
				var a: float = TAU * float(k) / 6.0
				LowPolyMesh.box(st, Vector3(sin(a) * 0.05, 0.1, cos(a) * 0.05), Vector3(0.01, 0.14, 0.01), Basis.IDENTITY, RUST)
			LowPolyMesh.prism(st, Vector3(0.0, 0.03, 0.0), Vector3(0.0, 0.07, 0.0), 0.015, 0.015, 6, IVORY)
			LowPolyMesh.prism(st, Vector3(0.0, 0.17, 0.0), Vector3(0.0, 0.23, 0.0), 0.065, 0.0, 6, RUST_DARK)
			_ring(st, Vector3(0.0, 0.25, 0.0), Vector3.FORWARD, 0.02, 0.005, 6, IRON)
		"garra_toupeira":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.03), Vector3(0.0, 0.03, 0.03), 0.09, 0.09, 6, WOOD)
			LowPolyMesh.box(st, Vector3(0.0, 0.05, 0.03), Vector3(0.08, 0.05, 0.06), Basis.IDENTITY, Color("#6a5a50"))
			for k: int in 3:
				var x: float = (float(k) - 1.0) * 0.03
				LowPolyMesh.prism(st, Vector3(x, 0.06, 0.0), Vector3(x, 0.07, -0.08), 0.013, 0.008, 4, IVORY)
				LowPolyMesh.prism(st, Vector3(x, 0.07, -0.08), Vector3(x, 0.04, -0.12), 0.008, 0.0, 4, IVORY)
		"fivela_prata":
			LowPolyMesh.box(st, Vector3(0.0, 0.01, 0.0), Vector3(0.17, 0.02, 0.12), Basis.IDENTITY, SILVER_DARK)
			LowPolyMesh.box(st, Vector3(0.0, 0.022, 0.0), Vector3(0.14, 0.008, 0.09), Basis.IDENTITY, SILVER)
			LowPolyMesh.box(st, Vector3(0.0, 0.03, 0.0), Vector3(0.012, 0.012, 0.08), Basis.IDENTITY, SILVER_DARK)
		"relogio_bolso_antigo":
			_watch(st, GOLD, GOLD_DARK)
			for k: int in 4:
				_ring(st, Vector3(0.03 + 0.025 * float(k), 0.01, -0.09 - 0.015 * float(k)), Vector3.UP if k % 2 == 0 else Vector3.RIGHT, 0.01, 0.004, 6, GOLD_DARK)
		"relogio_ouro":
			_watch(st, GOLD, GOLD_DARK)
			for side: float in [-1.0, 1.0]:
				LowPolyMesh.box(st, Vector3(0.0, 0.015, 0.09 * side), Vector3(0.045, 0.02, 0.07), Basis.IDENTITY, GOLD_DARK)
		"idolo_ouro":
			LowPolyMesh.box(st, Vector3(0.0, 0.015, 0.0), Vector3(0.08, 0.03, 0.07), Basis.IDENTITY, GOLD_DARK)
			LowPolyMesh.box(st, Vector3(0.0, 0.08, 0.0), Vector3(0.07, 0.1, 0.06), Basis.IDENTITY, GOLD)
			LowPolyMesh.box(st, Vector3(0.0, 0.165, 0.0), Vector3(0.08, 0.07, 0.065), Basis.IDENTITY, GOLD)
			LowPolyMesh.box(st, Vector3(0.0, 0.205, 0.0), Vector3(0.09, 0.015, 0.07), Basis.IDENTITY, GOLD_DARK)
			for side: float in [-1.0, 1.0]:
				LowPolyMesh.box(glow, Vector3(0.018 * side, 0.172, -0.034), Vector3(0.015, 0.012, 0.006), Basis.IDENTITY, RED_GEM)
			glow_color = Color(0.4, 0.04, 0.06)
		"calice_prata":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.015, 0.0), 0.05, 0.045, 8, SILVER_DARK)
			LowPolyMesh.prism(st, Vector3(0.0, 0.015, 0.0), Vector3(0.0, 0.1, 0.0), 0.012, 0.012, 6, SILVER)
			LowPolyMesh.prism(st, Vector3(0.0, 0.1, 0.0), Vector3(0.0, 0.18, 0.0), 0.02, 0.055, 8, SILVER)
		"fragmento_meteorito":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.02, 0.1, 0.01), 0.08, 0.04, 5, Color("#2e2a34"))
			LowPolyMesh.box(glow, Vector3(0.0, 0.05, -0.06), Vector3(0.012, 0.08, 0.01), Basis(Vector3.FORWARD, 0.5), VIOLET_GLOW)
			LowPolyMesh.box(glow, Vector3(0.05, 0.04, -0.03), Vector3(0.01, 0.06, 0.01), Basis(Vector3.UP, 1.0) * Basis(Vector3.FORWARD, -0.4), VIOLET_GLOW)
			glow_color = Color(0.4, 0.15, 0.8)
		"caixa_musica_bizarra":
			LowPolyMesh.box(st, Vector3(0.0, 0.035, 0.0), Vector3(0.14, 0.07, 0.11), Basis.IDENTITY, WOOD)
			LowPolyMesh.box(st, Vector3(0.0, 0.1, 0.06), Vector3(0.14, 0.08, 0.012), Basis(Vector3.RIGHT, -0.3), WOOD_DARK)
			LowPolyMesh.prism(st, Vector3(0.08, 0.035, 0.0), Vector3(0.11, 0.035, 0.0), 0.006, 0.006, 4, BRONZE)
			LowPolyMesh.prism(glow, Vector3(0.0, 0.07, 0.0), Vector3(0.0, 0.12, 0.0), 0.012, 0.0, 4, CYAN_GLOW)
			glow_color = Color(0.1, 0.5, 0.5)
		"liga_desconhecida":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.05, 0.0), 0.11, 0.08, 4, Color("#c8b8e0"))
			LowPolyMesh.box(st, Vector3(0.0, 0.052, 0.0), Vector3(0.09, 0.004, 0.03), Basis(Vector3.UP, 0.785), Color("#e8d8a0"))
			glow_color = Color(0.12, 0.1, 0.18)
		"engrenagem_alienigena":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.03, 0.0), 0.08, 0.08, 10, RUST_DARK)
			for k: int in 8:
				var a: float = TAU * float(k) / 8.0
				LowPolyMesh.box(glow if k % 2 == 0 else st, Vector3(sin(a) * 0.095, 0.015, cos(a) * 0.095), Vector3(0.035, 0.028, 0.03), Basis(Vector3.UP, a), CYAN_GLOW if k % 2 == 0 else RUST)
			LowPolyMesh.prism(glow, Vector3(0.0, 0.03, 0.0), Vector3(0.0, 0.045, 0.0), 0.025, 0.02, 8, CYAN_GLOW)
			glow_color = Color(0.1, 0.6, 0.55)
		"orbe_vibrante":
			LowPolyMesh.prism(glow, Vector3(0.0, 0.02, 0.0), Vector3(0.0, 0.08, 0.0), 0.04, 0.055, 8, GOLD)
			LowPolyMesh.prism(glow, Vector3(0.0, 0.08, 0.0), Vector3(0.0, 0.14, 0.0), 0.055, 0.035, 8, GOLD)
			_ring(st, Vector3(0.0, 0.08, 0.0), Vector3.FORWARD, 0.08, 0.006, 14, GOLD_DARK)
			_ring(st, Vector3(0.0, 0.08, 0.0), Vector3.RIGHT, 0.09, 0.005, 14, GOLD_DARK)
			glow_color = Color(0.5, 0.35, 0.05)
		"dente_mamute":
			for k: int in 5:
				var a0: float = 0.2 + 0.5 * float(k)
				var a1: float = 0.2 + 0.5 * float(k + 1)
				LowPolyMesh.prism(st, Vector3(cos(a0) * 0.1, 0.03 + sin(a0) * 0.04, 0.0), Vector3(cos(a1) * 0.1, 0.03 + sin(a1) * 0.04, 0.0), 0.035 - 0.005 * float(k), 0.03 - 0.005 * float(k), 6, IVORY)
			LowPolyMesh.box(st, Vector3(0.0, 0.08, 0.0), Vector3(0.05, 0.015, 0.04), Basis.IDENTITY, ICE)
		"machado_viking":
			LowPolyMesh.prism(st, Vector3(0.0, 0.015, 0.12), Vector3(0.0, 0.015, -0.08), 0.014, 0.014, 6, WOOD)
			LowPolyMesh.box(st, Vector3(0.0, 0.015, 0.06), Vector3(0.032, 0.032, 0.05), Basis.IDENTITY, LEATHER)
			LowPolyMesh.box(st, Vector3(0.04, 0.015, -0.08), Vector3(0.08, 0.018, 0.04), Basis.IDENTITY, IRON)
			LowPolyMesh.box(st, Vector3(0.085, 0.015, -0.08), Vector3(0.02, 0.016, 0.08), Basis.IDENTITY, RUST)
		"cenoura_ouro":
			LowPolyMesh.prism(st, Vector3(0.0, 0.035, 0.07), Vector3(0.0, 0.03, -0.11), 0.035, 0.004, 7, GOLD)
			LowPolyMesh.prism(st, Vector3(0.0, 0.035, 0.07), Vector3(0.0, 0.035, 0.08), 0.03, 0.026, 7, GOLD_DARK)
		"fossil_gelo":
			LowPolyMesh.box(st, Vector3(0.0, 0.07, 0.0), Vector3(0.14, 0.14, 0.14), Basis(Vector3.UP, 0.3), ICE)
			for k: int in 4:
				var r: float = 0.05 - 0.011 * float(k)
				LowPolyMesh.prism(st, Vector3(0.0, 0.07, -0.072), Vector3(0.0, 0.07, -0.074 - 0.004 * float(k)), r, r * 0.85, 8, BRONZE if k % 2 == 0 else BRONZE_DARK)
		"adaga_cerimonial":
			LowPolyMesh.prism(st, Vector3(0.0, 0.02, 0.02), Vector3(0.0, 0.025, -0.12), 0.022, 0.0, 4, BRONZE)
			LowPolyMesh.box(st, Vector3(0.0, 0.02, 0.025), Vector3(0.065, 0.014, 0.016), Basis.IDENTITY, BRONZE_DARK)
			LowPolyMesh.prism(st, Vector3(0.0, 0.02, 0.03), Vector3(0.0, 0.02, 0.10), 0.014, 0.012, 6, RED_CLOTH)
			for k: int in 3:
				LowPolyMesh.prism(st, Vector3(0.0, 0.02, 0.045 + 0.018 * float(k)), Vector3(0.0, 0.02, 0.05 + 0.018 * float(k)), 0.015, 0.015, 6, GOLD_DARK)
			LowPolyMesh.prism(st, Vector3(0.0, 0.02, 0.10), Vector3(0.0, 0.02, 0.12), 0.018, 0.015, 6, BRONZE)
			LowPolyMesh.prism(glow, Vector3(0.0, 0.02, 0.12), Vector3(0.0, 0.02, 0.13), 0.01, 0.006, 6, TURQUOISE)
			glow_color = Color(0.05, 0.35, 0.3)
		"bussola_congelada":
			LowPolyMesh.box(st, Vector3(0.0, 0.045, 0.0), Vector3(0.16, 0.09, 0.15), Basis(Vector3.UP, 0.2), ICE)
			_compass(st, BRONZE, BRONZE_DARK)
			LowPolyMesh.prism(st, Vector3(-0.06, 0.08, 0.04), Vector3(-0.04, 0.11, 0.03), 0.03, 0.0, 4, ICE)
			LowPolyMesh.prism(glow, Vector3(0.0, 0.05, 0.0), Vector3(0.0, 0.06, 0.0), 0.05, 0.05, 8, Color("#80d0ff"))
			glow_color = Color(0.1, 0.3, 0.5)
		"crampon_enferrujado":
			LowPolyMesh.box(st, Vector3(0.0, 0.025, 0.0), Vector3(0.11, 0.012, 0.19), Basis.IDENTITY, RUST)
			LowPolyMesh.box(st, Vector3(0.0, 0.025, 0.0), Vector3(0.06, 0.014, 0.12), Basis.IDENTITY, RUST_DARK)
			for side: float in [-1.0, 1.0]:
				for k: int in 4:
					var z: float = -0.07 + 0.045 * float(k)
					LowPolyMesh.prism(st, Vector3(0.048 * side, 0.02, z), Vector3(0.052 * side, 0.0, z), 0.012, 0.0, 4, IRON)
			LowPolyMesh.box(st, Vector3(0.0, 0.04, -0.04), Vector3(0.13, 0.01, 0.025), Basis.IDENTITY, LEATHER)
			LowPolyMesh.box(st, Vector3(0.0, 0.04, 0.05), Vector3(0.13, 0.01, 0.025), Basis.IDENTITY, LEATHER)
			_ring(st, Vector3(0.065, 0.04, 0.05), Vector3.RIGHT, 0.012, 0.004, 6, BRONZE)
			LowPolyMesh.box(st, Vector3(-0.03, 0.032, 0.02), Vector3(0.035, 0.008, 0.04), Basis.IDENTITY, ICE)
		"cristal_eco":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.035, 0.0), 0.08, 0.075, 7, STONE_DARK)
			LowPolyMesh.prism(glow, Vector3(0.0, 0.02, 0.0), Vector3(0.01, 0.19, 0.0), 0.04, 0.0, 6, VIOLET_GLOW)
			LowPolyMesh.prism(glow, Vector3(-0.03, 0.02, 0.02), Vector3(-0.04, 0.13, 0.025), 0.025, 0.0, 5, VIOLET_GLOW)
			LowPolyMesh.prism(glow, Vector3(0.035, 0.02, -0.02), Vector3(0.045, 0.11, -0.025), 0.022, 0.0, 5, VIOLET_GLOW)
			LowPolyMesh.prism(st, Vector3(0.0, 0.03, 0.035), Vector3(0.0, 0.08, 0.045), 0.018, 0.0, 4, Color("#4a2068"))
			_ring(glow, Vector3(0.01, 0.11, 0.0), Vector3.UP, 0.05, 0.004, 12, CYAN_GLOW)
			glow_color = Color(0.45, 0.15, 0.65)
		"cronometro_explorador":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.032, 0.0), 0.065, 0.065, 12, SILVER)
			LowPolyMesh.prism(st, Vector3(0.0, 0.032, 0.0), Vector3(0.0, 0.037, 0.0), 0.065, 0.055, 12, SILVER_DARK)
			LowPolyMesh.prism(st, Vector3(0.0, 0.036, 0.0), Vector3(0.0, 0.038, 0.0), 0.054, 0.054, 12, DIAL)
			LowPolyMesh.box(st, Vector3(0.0, 0.04, -0.015), Vector3(0.004, 0.003, 0.025), Basis.IDENTITY, INK)
			LowPolyMesh.box(st, Vector3(0.01, 0.04, 0.0), Vector3(0.02, 0.003, 0.003), Basis.IDENTITY, RED_GEM)
			LowPolyMesh.prism(st, Vector3(0.0, 0.015, -0.065), Vector3(0.0, 0.015, -0.082), 0.012, 0.012, 8, SILVER_DARK)
			_ring(st, Vector3(0.0, 0.015, -0.09), Vector3.UP, 0.012, 0.004, 6, SILVER)
			for k: int in 3:
				_ring(st, Vector3(0.018 * float(k), 0.01, -0.10 - 0.016 * float(k)), Vector3.UP if k % 2 == 0 else Vector3.RIGHT, 0.009, 0.003, 6, SILVER_DARK)
		"escaravelho_jade":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.035, 0.0), 0.065, 0.06, 8, JADE_DARK)
			LowPolyMesh.prism(st, Vector3(0.0, 0.02, 0.01), Vector3(0.0, 0.055, 0.02), 0.055, 0.045, 7, JADE)
			LowPolyMesh.box(st, Vector3(0.0, 0.025, -0.055), Vector3(0.04, 0.02, 0.025), Basis.IDENTITY, JADE_DARK)
			LowPolyMesh.box(st, Vector3(0.0, 0.057, 0.01), Vector3(0.005, 0.004, 0.07), Basis.IDENTITY, GOLD)
			LowPolyMesh.box(st, Vector3(0.0, 0.056, 0.0), Vector3(0.06, 0.004, 0.005), Basis.IDENTITY, GOLD)
			_ring(st, Vector3(0.0, 0.02, -0.075), Vector3.UP, 0.01, 0.004, 6, GOLD_DARK)
		"geodo_estrelar":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.08, 0.0), 0.085, 0.08, 9, STONE_GREY)
			LowPolyMesh.prism(st, Vector3(0.0, 0.08, 0.0), Vector3(0.0, 0.09, 0.0), 0.08, 0.07, 9, STONE_DARK)
			LowPolyMesh.prism(glow, Vector3(0.0, 0.04, 0.0), Vector3(0.0, 0.085, 0.0), 0.068, 0.065, 8, DEEP_BLUE)
			for k: int in 6:
				var a: float = TAU * float(k) / 6.0 + 0.3
				var r: float = 0.035 if k % 2 == 0 else 0.02
				LowPolyMesh.box(glow, Vector3(sin(a) * r, 0.086, cos(a) * r), Vector3(0.008, 0.008, 0.008), Basis.IDENTITY, CYAN_GLOW)
			glow_color = Color(0.1, 0.2, 0.45)
		"idolo_jade":
			LowPolyMesh.box(st, Vector3(0.0, 0.015, 0.0), Vector3(0.09, 0.03, 0.08), Basis.IDENTITY, JADE_DARK)
			LowPolyMesh.box(st, Vector3(0.0, 0.065, 0.0), Vector3(0.075, 0.07, 0.065), Basis.IDENTITY, JADE)
			LowPolyMesh.box(st, Vector3(0.0, 0.06, -0.032), Vector3(0.065, 0.02, 0.015), Basis.IDENTITY, JADE_DARK)
			LowPolyMesh.box(st, Vector3(0.0, 0.13, 0.0), Vector3(0.07, 0.06, 0.06), Basis.IDENTITY, JADE)
			LowPolyMesh.box(st, Vector3(-0.045, 0.13, 0.0), Vector3(0.015, 0.04, 0.02), Basis.IDENTITY, JADE_DARK)
			LowPolyMesh.box(st, Vector3(0.045, 0.13, 0.0), Vector3(0.015, 0.04, 0.02), Basis.IDENTITY, JADE_DARK)
			LowPolyMesh.box(glow, Vector3(-0.018, 0.135, -0.032), Vector3(0.01, 0.008, 0.005), Basis.IDENTITY, GOLD)
			LowPolyMesh.box(glow, Vector3(0.018, 0.135, -0.032), Vector3(0.01, 0.008, 0.005), Basis.IDENTITY, GOLD)
			glow_color = Color(0.2, 0.15, 0.05)
		"lanterna_expedicao":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.04, 0.0), 0.065, 0.06, 8, SILVER_DARK)
			LowPolyMesh.prism(glow, Vector3(0.0, 0.04, 0.0), Vector3(0.0, 0.14, 0.0), 0.045, 0.045, 8, GLASS)
			for k: int in 4:
				var a: float = TAU * float(k) / 4.0
				LowPolyMesh.box(st, Vector3(sin(a) * 0.05, 0.09, cos(a) * 0.05), Vector3(0.006, 0.10, 0.006), Basis.IDENTITY, IRON)
			LowPolyMesh.prism(st, Vector3(0.0, 0.14, 0.0), Vector3(0.0, 0.18, 0.0), 0.055, 0.03, 8, SILVER)
			LowPolyMesh.box(st, Vector3(0.0, 0.182, 0.0), Vector3(0.035, 0.006, 0.035), Basis.IDENTITY, ICE)
			_ring(st, Vector3(0.0, 0.20, 0.0), Vector3.FORWARD, 0.025, 0.005, 8, IRON)
			glow_color = Color(0.1, 0.2, 0.25)
		"ligaduras_mumia":
			LowPolyMesh.prism(st, Vector3(-0.08, 0.035, 0.0), Vector3(0.07, 0.035, 0.0), 0.045, 0.042, 8, PAPER)
			LowPolyMesh.prism(st, Vector3(-0.06, 0.035, 0.0), Vector3(0.05, 0.035, 0.0), 0.052, 0.048, 8, Color("#dcd0b0"))
			LowPolyMesh.box(st, Vector3(0.02, 0.015, 0.055), Vector3(0.07, 0.006, 0.05), Basis(Vector3.UP, 0.3), PAPER)
			LowPolyMesh.box(st, Vector3(0.0, 0.06, 0.035), Vector3(0.025, 0.015, 0.01), Basis.IDENTITY, BRONZE)
		"mascara_ouro":
			LowPolyMesh.prism(st, Vector3(0.0, 0.01, 0.0), Vector3(0.0, 0.04, 0.0), 0.07, 0.065, 8, GOLD)
			LowPolyMesh.box(st, Vector3(0.0, 0.048, -0.01), Vector3(0.014, 0.016, 0.04), Basis.IDENTITY, GOLD_DARK)
			LowPolyMesh.box(st, Vector3(-0.025, 0.042, -0.02), Vector3(0.02, 0.004, 0.008), Basis(Vector3.FORWARD, 0.1), DEEP_BLUE)
			LowPolyMesh.box(st, Vector3(0.025, 0.042, -0.02), Vector3(0.02, 0.004, 0.008), Basis(Vector3.FORWARD, -0.1), DEEP_BLUE)
			LowPolyMesh.box(st, Vector3(0.0, 0.042, 0.03), Vector3(0.024, 0.004, 0.008), Basis.IDENTITY, GOLD_DARK)
			LowPolyMesh.box(st, Vector3(-0.07, 0.025, -0.02), Vector3(0.025, 0.03, 0.09), Basis.IDENTITY, DEEP_BLUE)
			LowPolyMesh.box(st, Vector3(0.07, 0.025, -0.02), Vector3(0.025, 0.03, 0.09), Basis.IDENTITY, DEEP_BLUE)
			LowPolyMesh.box(st, Vector3(0.0, 0.03, -0.07), Vector3(0.12, 0.03, 0.025), Basis.IDENTITY, GOLD_DARK)
		"medalha_polar":
			LowPolyMesh.box(st, Vector3(0.0, 0.01, -0.06), Vector3(0.065, 0.01, 0.07), Basis.IDENTITY, RIBBON_BLUE)
			LowPolyMesh.box(st, Vector3(0.0, 0.015, -0.06), Vector3(0.02, 0.006, 0.07), Basis.IDENTITY, Color("#f0f4f8"))
			_ring(st, Vector3(0.0, 0.015, -0.015), Vector3.UP, 0.012, 0.004, 6, GOLD_DARK)
			_coin(st, 0.06, GOLD, GOLD_DARK)
			for k: int in 3:
				LowPolyMesh.box(st, Vector3(0.0, 0.03, 0.045), Vector3(0.008, 0.004, 0.05), Basis(Vector3.UP, PI * float(k) / 3.0), GOLD_DARK)
		"nucleo_adormecido":
			LowPolyMesh.prism(st, Vector3(0.0, 0.01, 0.0), Vector3(0.0, 0.07, 0.0), 0.075, 0.08, 8, OBSIDIAN)
			LowPolyMesh.prism(st, Vector3(0.0, 0.07, 0.0), Vector3(0.0, 0.13, 0.0), 0.08, 0.065, 8, OBSIDIAN)
			LowPolyMesh.box(glow, Vector3(0.0, 0.07, 0.0), Vector3(0.09, 0.014, 0.01), Basis(Vector3.UP, 0.4), MAGMA_GLOW)
			LowPolyMesh.box(glow, Vector3(0.02, 0.07, 0.0), Vector3(0.01, 0.014, 0.09), Basis(Vector3.FORWARD, 0.3), MAGMA_GLOW)
			LowPolyMesh.box(glow, Vector3(-0.02, 0.09, 0.03), Vector3(0.04, 0.04, 0.01), Basis(Vector3.RIGHT, 0.5), MAGMA_GLOW)
			glow_color = Color(0.6, 0.2, 0.05)
		"nucleo_guardiao":
			LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.045, 0.0), 0.085, 0.078, 6, STONE_DARK)
			LowPolyMesh.prism(st, Vector3(0.0, 0.04, 0.0), Vector3(0.0, 0.10, 0.0), 0.068, 0.072, 8, STONE_GREY)
			LowPolyMesh.prism(st, Vector3(0.0, 0.10, 0.0), Vector3(0.0, 0.15, 0.0), 0.072, 0.055, 8, STONE_GREY)
			_ring(glow, Vector3(0.0, 0.10, 0.0), Vector3.UP, 0.073, 0.005, 10, CYAN_GLOW)
			LowPolyMesh.box(glow, Vector3(0.0, 0.10, -0.074), Vector3(0.025, 0.025, 0.006), Basis.IDENTITY, CYAN_GLOW)
			LowPolyMesh.box(glow, Vector3(0.0, 0.10, 0.074), Vector3(0.025, 0.025, 0.006), Basis.IDENTITY, CYAN_GLOW)
			LowPolyMesh.box(st, Vector3(0.04, 0.03, 0.04), Vector3(0.04, 0.015, 0.035), Basis(Vector3.UP, 0.5), ALGAE)
			glow_color = Color(0.1, 0.45, 0.45)
		_:
			return null

	var root: Node3D = Node3D.new()
	root.name = "ItemModel"
	root.position.y = BASE_Y
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	if is_rare:
		mat.set_shader_parameter(&"emission_color", Color(0.35, 0.28, 0.08))
	root.add_child(LowPolyMesh.commit(st, "Mesh", mat))
	var glow_mesh: ArrayMesh = glow.commit()
	if glow_mesh.get_surface_count() > 0:
		var gmat: ShaderMaterial = ToonKit.vertex_material(true, true)
		gmat.set_shader_parameter(&"emission_color", glow_color)
		var gmi: MeshInstance3D = MeshInstance3D.new()
		gmi.name = "Glow"
		gmi.mesh = ToonKit.bake_outline_normals(glow_mesh)
		gmi.material_override = gmat
		root.add_child(gmi)
	elif glow_color != Color.BLACK:
		mat.set_shader_parameter(&"emission_color", glow_color)
	return root


## Anel (toro facetado) à volta de `axis`, centrado em `center`.
static func _ring(st: SurfaceTool, center: Vector3, axis: Vector3, radius: float, thick: float, segments: int, color: Color) -> void:
	var u: Vector3 = axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	var v: Vector3 = axis.cross(u).normalized()
	for k: int in segments:
		var a0: float = TAU * float(k) / float(segments)
		var a1: float = TAU * float(k + 1) / float(segments)
		LowPolyMesh.prism(st, center + (u * cos(a0) + v * sin(a0)) * radius, center + (u * cos(a1) + v * sin(a1)) * radius, thick, thick, 5, color)


## Moeda/medalhão deitado: disco com rebordo.
static func _coin(st: SurfaceTool, radius: float, face: Color, rim: Color) -> void:
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.024, 0.0), radius, radius, 10, rim)
	LowPolyMesh.prism(st, Vector3(0.0, 0.024, 0.0), Vector3(0.0, 0.027, 0.0), radius * 0.85, radius * 0.8, 10, face)


## Bússola: caixa redonda, mostrador, vidro e agulha.
static func _compass(st: SurfaceTool, body: Color, rim: Color) -> void:
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.045, 0.0), 0.075, 0.075, 10, body)
	LowPolyMesh.prism(st, Vector3(0.0, 0.045, 0.0), Vector3(0.0, 0.05, 0.0), 0.075, 0.068, 10, rim)
	LowPolyMesh.prism(st, Vector3(0.0, 0.05, 0.0), Vector3(0.0, 0.052, 0.0), 0.062, 0.062, 10, DIAL)
	LowPolyMesh.box(st, Vector3(0.0, 0.055, 0.0), Vector3(0.012, 0.004, 0.09), Basis(Vector3.UP, 0.6), RED_GEM)


## Relógio: caixa, mostrador e ponteiros.
static func _watch(st: SurfaceTool, body: Color, rim: Color) -> void:
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.03, 0.0), 0.06, 0.06, 10, body)
	LowPolyMesh.prism(st, Vector3(0.0, 0.03, 0.0), Vector3(0.0, 0.034, 0.0), 0.06, 0.05, 10, rim)
	LowPolyMesh.prism(st, Vector3(0.0, 0.034, 0.0), Vector3(0.0, 0.036, 0.0), 0.05, 0.05, 10, DIAL)
	LowPolyMesh.box(st, Vector3(0.0, 0.039, -0.015), Vector3(0.005, 0.003, 0.03), Basis.IDENTITY, INK)
	LowPolyMesh.box(st, Vector3(0.01, 0.039, 0.0), Vector3(0.02, 0.003, 0.005), Basis.IDENTITY, INK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.015, -0.06), Vector3(0.0, 0.015, -0.075), 0.01, 0.01, 6, rim)
