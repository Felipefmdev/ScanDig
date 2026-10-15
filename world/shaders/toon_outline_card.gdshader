// Contorno preto de cartões de dupla face (folhas): a folha alargada no próprio plano
// (CUSTOM0 = direção do centro do triângulo para o vértice) e empurrada para trás.
// Original do projeto (CC0).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#define OUTLINE_CARD
#include "res://world/shaders/toon_outline_common.gdshaderinc"
