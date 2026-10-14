// Água stylized low-poly para o ScanDig (estilo "How to Fish"). Original do projeto (CC0).
// - Ondas por vértice (soma de senos em espaço do mundo) e normais por face (dFdx/dFdy) → facetas.
// - Cor por profundidade: turquesa na orla → azul no fundo (lê o depth buffer).
// - Espuma branca onde a água toca a areia, com bandas a ondular.
// - Leve transparência na orla.
// A malha precisa de subdivisões (PlaneMesh subdivide_width/depth) para as facetas se verem.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.16, 0.78, 0.78);
uniform vec3 deep_color : source_color = vec3(0.03, 0.33, 0.62);
uniform vec3 foam_color : source_color = vec3(0.97, 0.99, 1.0);
uniform float depth_fade = 2.5;
uniform float foam_width = 0.35;
uniform float wave_height = 0.07;
uniform float wave_scale = 0.45;
uniform float wave_speed = 0.9;
uniform float alpha_shallow : hint_range(0.0, 1.0) = 0.55;
uniform float alpha_deep : hint_range(0.0, 1.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.35;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 world_pos;

float wave(vec2 p, float t) {
	return sin(p.x * wave_scale + t * wave_speed) * 0.5
		+ sin((p.x * 0.6 + p.y * 0.9) * wave_scale * 1.7 + t * wave_speed * 1.3) * 0.35
		+ sin((p.y * 1.1 - p.x * 0.4) * wave_scale * 2.3 - t * wave_speed * 0.9) * 0.25;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += wave(world_pos.xz, TIME) * wave_height;
}

void fragment() {
	// Normal plana por triângulo → aspeto facetado
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));

	// Profundidade da água: distância entre a superfície e o que está por trás
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	view.xyz /= view.w;
	float water_depth = max(VERTEX.z - view.z, 0.0);

	float t = clamp(water_depth / depth_fade, 0.0, 1.0);
	vec3 col = mix(shallow_color, deep_color, t);

	// Espuma na orla, com bandas que avançam e recuam
	float band = 0.75 + 0.25 * sin(TIME * 1.8 + world_pos.x * 2.1 + world_pos.z * 1.3);
	float foam = 1.0 - smoothstep(0.0, foam_width * band, water_depth);
	foam = step(0.45, foam) * 0.95;

	ALBEDO = mix(col, foam_color, foam);
	ALPHA = max(mix(alpha_shallow, alpha_deep, t), foam);
	ROUGHNESS = roughness;
	SPECULAR = 0.2;
	METALLIC = 0.0;
}
