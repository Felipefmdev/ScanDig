// Núcleo do shader toon do ScanDig (docs/GAME_DESIGN.md §2). Incluído por toon.gdshader
// (cull_back) e toon_double.gdshader (cull_disabled: folhas, relva). Original do projeto (CC0).
// - Luz em 3 degraus (luz, meio-tom, sombra) sem gradientes; a sombra projetada conta como sombra.
// - Cor: albedo_color × cor por vértice (opcional) × textura (opcional, modelos Kenney).
// - Desgaste em espaço do objeto, por parâmetro: pintas, ferrugem, tinta lascada e veio de madeira.
//   O alfa da cor por vértice é a máscara do desgaste (0 = olhos, boca... ficam limpos).
// - Flash de dano (flash_amount 1 → 0) e emissão fixa.

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_vertex_color = true;
// Cores por vértice escritas em sRGB (como vertex_color_is_srgb do StandardMaterial3D).
uniform bool vertex_color_srgb = true;
uniform bool use_texture = false;
// Os Kenney usam uma textura-paleta (colormap): nearest e sem mipmaps, senão as cores misturam-se.
uniform sampler2D albedo_texture : source_color, filter_nearest, hint_default_white;

// Degraus da luz direta: fator de cada tom e limiares de N·L × sombra.
uniform float band_lit : hint_range(0.0, 2.0) = 1.0;
uniform float band_mid : hint_range(0.0, 2.0) = 0.6;
uniform float band_shadow : hint_range(0.0, 2.0) = 0.3;
uniform float threshold_lit : hint_range(0.0, 1.0) = 0.42;
uniform float threshold_mid : hint_range(0.0, 1.0) = 0.06;
// Cor aplicada ao tom de sombra (sombras quentes/arroxeadas em vez de cinzento).
uniform vec4 shadow_tint : source_color = vec4(0.86, 0.68, 0.7, 1.0);
// Brilho duro (metal): 0 = sem brilho.
uniform float specular_amount : hint_range(0.0, 1.0) = 0.0;

// Pintas (carapaça do caranguejo, salpicos).
uniform float spots_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 spots_color : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform float spots_scale = 14.0;
uniform float spots_size : hint_range(0.05, 0.3) = 0.16;
// Ferrugem em manchas (fbm com recorte duro).
uniform float rust_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rust_color : source_color = vec4(0.55, 0.24, 0.09, 1.0);
uniform float rust_scale = 3.5;
// Tinta lascada: mostra chip_color (metal por baixo) com uma orla escura.
uniform float chip_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 chip_color : source_color = vec4(0.32, 0.33, 0.36, 1.0);
uniform float chip_scale = 5.0;
// Veio de madeira: riscas esticadas ao longo de grain_axis (espaço do objeto).
uniform float grain_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 grain_axis = vec3(0.0, 1.0, 0.0);
uniform float grain_scale = 9.0;

uniform vec4 flash_color : source_color = vec4(1.0, 0.25, 0.2, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

varying vec3 obj_pos;
varying vec4 vcolor;

float toon_hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float toon_vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = toon_hash13(i);
	float n100 = toon_hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = toon_hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = toon_hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = toon_hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = toon_hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = toon_hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = toon_hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z);
}

float toon_fbm(vec3 p) {
	return toon_vnoise(p) * 0.55 + toon_vnoise(p * 2.07 + 17.3) * 0.3 + toon_vnoise(p * 4.31 + 41.7) * 0.15;
}

// Pintas redondas: um ponto por célula (centro afastado das bordas para não cortar).
float toon_spots(vec3 p, float amount, float size) {
	vec3 cell = floor(p);
	float h = toon_hash13(cell + 7.7);
	if (h > amount) {
		return 0.0;
	}
	vec3 c = cell + 0.3 + 0.4 * vec3(toon_hash13(cell + 1.3), toon_hash13(cell + 5.1), toon_hash13(cell + 9.4));
	float r = size * (0.55 + 0.45 * toon_hash13(cell + 3.9));
	return 1.0 - step(r, length(p - c));
}

vec3 toon_srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	obj_pos = VERTEX;
	vcolor = COLOR;
}

void fragment() {
	vec3 base = albedo_color.rgb;
	float wear_mask = 1.0;
	if (use_vertex_color) {
		vec3 vc = vertex_color_srgb ? toon_srgb_to_linear(vcolor.rgb) : vcolor.rgb;
		base *= vc;
		wear_mask = vcolor.a;
	}
	if (use_texture) {
		base *= texture(albedo_texture, UV).rgb;
	}

	if (wear_mask > 0.01) {
		if (grain_amount > 0.0) {
			vec3 ax = normalize(grain_axis);
			vec3 q = obj_pos - ax * dot(obj_pos, ax) * 0.92;
			float g = toon_vnoise(q * grain_scale + ax * dot(obj_pos, ax) * 0.6);
			float streak = smoothstep(0.55, 0.62, g) * 0.6 + smoothstep(0.78, 0.82, g) * 0.4;
			base = mix(base, base * 0.68, streak * grain_amount * wear_mask);
		}
		if (spots_amount > 0.0) {
			float s = toon_spots(obj_pos * spots_scale, spots_amount, spots_size);
			base = mix(base, spots_color.rgb, s * wear_mask);
		}
		if (chip_amount > 0.0) {
			float n = toon_fbm(obj_pos * chip_scale + 3.1);
			float cut = 1.0 - chip_amount * 0.45;
			float chip = step(cut, n);
			float rim = step(cut - 0.035, n) - chip;
			base = mix(base, base * 0.55, rim * wear_mask);
			base = mix(base, chip_color.rgb, chip * wear_mask);
		}
		if (rust_amount > 0.0) {
			float n = toon_fbm(obj_pos * rust_scale + 11.0);
			float cut = 1.0 - rust_amount * 0.5;
			float rust = smoothstep(cut, cut + 0.015, n);
			float tone = 0.75 + 0.5 * toon_vnoise(obj_pos * rust_scale * 6.0);
			base = mix(base, rust_color.rgb * tone, rust * wear_mask);
		}
	}

	base = mix(base, flash_color.rgb, flash_amount);
	ALBEDO = base;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = emission_color.rgb + flash_color.rgb * flash_amount * 0.6;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = clamp(ndl, 0.0, 1.0) * ATTENUATION;
	float tone = band_shadow;
	tone = mix(tone, band_mid, smoothstep(threshold_mid - 0.01, threshold_mid + 0.01, lit));
	tone = mix(tone, band_lit, smoothstep(threshold_lit - 0.01, threshold_lit + 0.01, lit));
	vec3 tint = mix(shadow_tint.rgb, vec3(1.0), clamp((tone - band_shadow) / max(band_lit - band_shadow, 0.001), 0.0, 1.0));
	DIFFUSE_LIGHT += LIGHT_COLOR * tone * tint / PI;
	if (specular_amount > 0.0) {
		float rv = dot(reflect(-LIGHT, NORMAL), VIEW);
		SPECULAR_LIGHT += LIGHT_COLOR * step(0.93, rv) * specular_amount * ATTENUATION / PI;
	}
}
