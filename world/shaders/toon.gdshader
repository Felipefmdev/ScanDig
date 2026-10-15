// Shader toon partilhado do ScanDig (cel shading em degraus + desgaste por parâmetro).
// Peças fechadas (cull_back). O contorno preto vem em next_pass (toon_outline.gdshader).
// Variante de dupla face: toon_double.gdshader. Original do projeto (CC0).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert;

#include "res://world/shaders/toon_common.gdshaderinc"
