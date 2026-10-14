// Céu stylized de dia para o ScanDig (estilo "How to Fish"): gradiente azul, nuvens suaves
// por fbm projetadas numa abóbada, disco do sol com halo. Original do projeto (CC0).
// Sem TIME: as nuvens são estáticas para o radiance do céu não ser recalculado a cada frame.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.22, 0.48, 0.86);
uniform vec3 horizon_color : source_color = vec3(0.7, 0.85, 0.97);
uniform vec3 ground_color : source_color = vec3(0.6, 0.72, 0.82);
uniform float gradient_curve : hint_range(0.05, 1.0) = 0.45;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade_color : source_color = vec3(0.78, 0.85, 0.94);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.52;
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.16;
uniform float cloud_scale = 1.4;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.92;
uniform vec2 cloud_offset = vec2(3.7, 1.3);
uniform vec3 sun_color : source_color = vec3(1.0, 0.97, 0.88);
uniform float sun_size_deg = 2.2;
uniform float sun_glow : hint_range(0.0, 1.0) = 0.35;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), gradient_curve));
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 6.0, 0.0, 1.0));
	}

	// Nuvens numa abóbada (mais densas e achatadas perto do horizonte)
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.18) * cloud_scale + cloud_offset;
		float n = fbm(uv);
		float c = smoothstep(cloud_coverage, cloud_coverage + cloud_softness, n);
		c *= smoothstep(0.0, 0.12, h);
		float shade = smoothstep(0.35, 0.85, fbm(uv * 1.6 + vec2(0.21, 0.13)));
		vec3 cc = mix(cloud_color, cloud_shade_color, shade * 0.8);
		col = mix(col, cc, c * cloud_opacity);
	}

	// Sol
	if (LIGHT0_ENABLED) {
		float cosang = clamp(dot(d, LIGHT0_DIRECTION), -1.0, 1.0);
		float ang = degrees(acos(cosang));
		float disc = 1.0 - smoothstep(sun_size_deg * 0.8, sun_size_deg, ang);
		float glow = pow(max(cosang, 0.0), 180.0) * sun_glow;
		col += sun_color * (disc * 2.5 + glow);
	}

	COLOR = col;
}
