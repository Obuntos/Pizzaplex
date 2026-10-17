shader_type canvas_item;
render_mode unshaded;
uniform sampler2D profundidade : filter_nearest, repeat_disable;
uniform vec2 origem;
uniform vec2 tamanho;
uniform bool horizontal = true;
uniform float altura = 0.0;
uniform vec2 centro_fisico;
uniform float inclinacao = 1.0;
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
	vec2 uv = (mundo - origem) / tamanho;
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
		if (distancia < texture(profundidade, uv).r - 1.25) { discard; }
	}
}
