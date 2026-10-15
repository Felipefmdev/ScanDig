// Contorno preto por casco invertido (next_pass do material toon). Original do projeto (CC0).
// A espessura é em píxeis no ecrã (outline_px), limitada a outline_max_world metros para que os
// objetos ao longe não fiquem com contornos gordos. Direção do empurrão: CUSTOM0.xyz quando a malha
// tem normais suavizadas cozidas (ToonKit.bake_outline_normals), senão a NORMAL da face.

uniform vec4 outline_color : source_color = vec4(0.03, 0.02, 0.02, 1.0);
uniform float outline_px : hint_range(0.0, 8.0) = 3.0;
uniform float outline_max_world : hint_range(0.0, 0.5) = 0.06;

void vertex() {
	vec3 dir = CUSTOM0.xyz;
	if (dot(dir, dir) < 0.01) {
		dir = NORMAL;
	}
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dv = normalize(MODELVIEW_NORMAL_MATRIX * dir);
	// Tamanho de 1 píxel (em metros) à profundidade deste vértice.
	// (o Vulkan inverte o Y na projeção: [1][1] é negativo)
	float px_world = 2.0 * max(-pv.z, 0.05) / (abs(PROJECTION_MATRIX[1][1]) * max(VIEWPORT_SIZE.y, 1.0));
	float w = min(outline_px * px_world, outline_max_world);
	pv += dv * w;
#ifdef OUTLINE_CARD
	// Cartões (folhas): o casco é a mesma folha alargada no plano e empurrada para trás,
	// para só se ver a orla.
	pv += normalize(pv) * w * 2.0;
#endif
	POSITION = PROJECTION_MATRIX * vec4(pv, 1.0);
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
