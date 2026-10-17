shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/iluminacao.gdshaderinc"
varying vec2 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	if (COLOR.a <= 0.0) { discard; }
	COLOR.rgb = iluminar_plex(COLOR.rgb, vec3(mundo.x, mundo.y * 2.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.85, 0.04, 0.0), 0.0, false);
}
