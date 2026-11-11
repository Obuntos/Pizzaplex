shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/iluminacao.gdshaderinc"
#include "res://shaders/mapa_cena.gdshaderinc"
uniform sampler2DArray profundidade : filter_nearest, repeat_disable;
uniform sampler2DArray superficies : filter_nearest, repeat_disable;
uniform vec2 origem;
uniform vec2 tamanho;
varying vec2 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	if (COLOR.a <= 0.0) { discard; }
	vec2 uv = (mundo - origem) / tamanho;
	vec4 superficie = amostrar_cena(superficies, uv, tamanho);
	if (superficie.a > 0.75) {
		float d = amostrar_cena(profundidade, uv, tamanho).r;
		float z = (d - mundo.y * 2.0) / 3.0;
		COLOR.rgb = iluminar_plex(COLOR.rgb, vec3(mundo.x, d - z, z), vec3(0.0, 0.0, 1.0), vec3(0.85, 0.0, 0.0), 0.0, true);
	} else {
		vec2 receptor_tela=mundo;
		bool vestiario=superficie.a>.23 && superficie.a<.25;
		if (vestiario) { receptor_tela=floor(mundo-origem)+origem; }
		float d = amostrar_cena(profundidade, uv, tamanho).r;
		float z = (d - receptor_tela.y * 2.0) / 3.0;
		vec3 normal = vec3(0.0, 0.894427, 0.447214);
		if (superficie.a > 0.05) { normal = normalize(superficie.rgb * 2.0 - 1.0); }
		vec3 receptor=vec3(receptor_tela.x,d-z,z);
		if (vestiario) { receptor-=normal*1.65; }
		float difusao_objeto=superficie.a>.215 && superficie.a<.225 ? .55 : 0.0;
		COLOR.rgb = iluminar_plex(COLOR.rgb, receptor, normal, vec3(0.85, 0.05, 0.1), difusao_objeto, superficie.a > 0.25);
	}
}


