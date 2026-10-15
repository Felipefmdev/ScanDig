// Shader toon de dupla face (folhas das palmeiras, relva): igual ao toon.gdshader com cull_disabled.
// O contorno destas peças é o toon_outline_card.gdshader. Original do projeto (CC0).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert;

#include "res://world/shaders/toon_common.gdshaderinc"
