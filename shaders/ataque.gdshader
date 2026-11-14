shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/iluminacao.gdshaderinc"
#include "res://shaders/mapa_cena.gdshaderinc"
uniform sampler2DArray profundidade_cena : filter_nearest, repeat_disable;
uniform vec2 origem;
uniform vec2 tamanho;
uniform float altura = 4.0;
uniform float plano = 0.0;
uniform bool deitado = false;
uniform bool usar_mascara = false;
uniform sampler2D mascara : filter_nearest;
uniform vec4 camisa = vec4(0.0);
uniform vec4 calca = vec4(0.0);
uniform vec4 sapato = vec4(0.0);
uniform vec3 pele_origem[64];
uniform vec3 pele_destino[64];
uniform int pele_total = 0;
varying vec2 mundo;

void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }

void fragment() {
	vec4 base = COLOR;
	if (base.a < 0.01) { discard; }
	bool roupa_aplicada = false;
	if (usar_mascara) {
		int regiao = int(round(texture(mascara, UV).r * 255.0 / 80.0));
		vec4 roupa = regiao == 1 ? camisa : regiao == 2 ? calca : regiao == 3 ? sapato : vec4(0.0);
		if (roupa.a > 0.5) {
			float luz_pele = dot(base.rgb, vec3(0.299, 0.587, 0.114)) / 0.76;
			base.rgb = clamp(roupa.rgb * luz_pele, 0.0, 1.0);
			roupa_aplicada = true;
		}
	}
	if (!roupa_aplicada) {
		for (int i = 0; i < 64; i++) {
			if (i >= pele_total) { break; }
			if (distance(base.rgb, pele_origem[i]) < 0.003) { base.rgb = pele_destino[i]; break; }
		}
	}
	float y = deitado ? mundo.y : plano;
	float d = y * 2.0 + altura * 3.0;
	float cena = amostrar_cena(profundidade_cena, (mundo - origem) / tamanho, tamanho).r;
	if (cena > d + 1.25) { discard; }
	vec3 luz = iluminar_plex(base.rgb, vec3(mundo.x, mundo.y * 2.0 + altura * 2.0, altura), vec3(0.0, 0.0, 1.0), vec3(.85, .0, .05), 0.0, false);
	COLOR = vec4(luz, base.a);
}
