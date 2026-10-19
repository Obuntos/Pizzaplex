shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/iluminacao.gdshaderinc"
uniform sampler2D profundidade : filter_nearest, repeat_disable;
uniform sampler2D superficies : filter_nearest, repeat_disable;
uniform vec2 origem;
uniform vec2 tamanho;
varying vec2 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	if (COLOR.a <= 0.0) { discard; }
	vec2 uv = (mundo - origem) / tamanho;
	vec4 superficie = texture(superficies, uv);
	if (superficie.a > 0.75) {
		float ganho = mix(1.0 + (ambiente - 1.0) * contraste, 1.0, 0.06);
		COLOR.rgb *= ganho;
	} else {
		float d = texture(profundidade, uv).r;
		float z = (d - mundo.y * 2.0) / 3.0;
		vec3 normal = vec3(0.0, 0.894427, 0.447214);
		if (superficie.a > 0.05) { normal = normalize(superficie.rgb * 2.0 - 1.0); }
		COLOR.rgb = iluminar_plex(COLOR.rgb, vec3(mundo.x, d - z, z), normal, vec3(0.85, 0.05, 0.1), 0.0, superficie.a > 0.25);
	}
}

