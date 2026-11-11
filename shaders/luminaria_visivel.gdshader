shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/mapa_cena.gdshaderinc"
uniform sampler2DArray profundidade : filter_nearest, repeat_disable;
uniform vec2 origem;
uniform vec2 tamanho;
uniform bool horizontal = true;
uniform float altura = 0.0;
uniform vec2 centro_fisico;
uniform float inclinacao = 1.0;
uniform bool destaque_exclusao = false;
varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float distancia = mundo.y * 2.0 + altura * 3.0;
	if (!horizontal) {
		float y = centro_fisico.y + inclinacao * (mundo.x - centro_fisico.x);
		distancia = 1.5 * y - mundo.y;
	}
	if (destaque_exclusao) { COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.025, 0.015), 0.9); }
	vec2 uv = (mundo - origem) / tamanho;
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
		if (distancia < amostrar_cena(profundidade, uv, tamanho).r - 1.25) { discard; }
	}
}


