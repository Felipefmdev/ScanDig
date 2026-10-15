// Contorno preto (casco invertido) das peças fechadas. Vai no next_pass dos materiais toon.
// Original do projeto (CC0).
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

#include "res://world/shaders/toon_outline_common.gdshaderinc"
