// Mar da Praia (#150): contínuo até o horizonte, com facetas e reflexos discretos.
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
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	view.xyz /= view.w;
	float water_depth = max(VERTEX.z - view.z, 0.0);
	float depth_mix = clamp(water_depth / depth_fade, 0.0, 1.0);
	vec3 col = mix(shallow_color, deep_color, depth_mix);
	float swell = wave(world_pos.xz * 0.65, TIME * 0.65);
	col *= 0.97 + 0.06 * smoothstep(-0.5, 0.7, swell);
	// Brilhos quebrados no plano da água, desaparecem à distância (sem cintilação no horizonte).
	float crest = sin(world_pos.x * 1.7 + world_pos.z * 0.65 + TIME * 0.7);
	float breaks = sin(world_pos.z * 2.8 - world_pos.x * 0.4 - TIME * 0.3);
	float glint = smoothstep(0.985, 1.0, crest) * smoothstep(0.5, 0.9, breaks);
	float near_water = 1.0 - smoothstep(25.0, 110.0, length(VERTEX));
	col = mix(col, foam_color, glint * near_water * 0.22);
	float band = 0.75 + 0.25 * sin(TIME * 1.8 + world_pos.x * 2.1 + world_pos.z * 1.3);
	float foam = step(0.45, 1.0 - smoothstep(0.0, foam_width * band, water_depth)) * 0.95;
	ALBEDO = mix(col, foam_color, foam);
	ALPHA = max(mix(alpha_shallow, alpha_deep, depth_mix), foam);
	ROUGHNESS = roughness;
	SPECULAR = 0.2;
}
