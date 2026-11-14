shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/iluminacao.gdshaderinc"
#include "res://shaders/mapa_cena.gdshaderinc"
uniform sampler2DArray profundidade_cena : filter_nearest, repeat_disable;
uniform vec2 origem;
uniform vec2 tamanho;
uniform float altura = 4.0;
uniform float plano = 0.0;
uniform bool usar_mascara = false;
uniform sampler2D mascara : filter_nearest;
uniform bool usar_textura = false;
uniform sampler2D roupa : filter_nearest;
uniform int linha = 0;
uniform vec4 rect_tronco = vec4(0.0);
uniform vec4 rect_perna_e = vec4(0.0);
uniform vec4 rect_perna_d = vec4(0.0);
uniform vec4 camisa = vec4(0.0);
uniform vec4 calca = vec4(0.0);
uniform vec4 manga = vec4(0.0);
uniform float manga_frac = 0.0;
uniform bool usar_saia = false;
uniform sampler2D saia : filter_nearest;
uniform vec2 celula = vec2(0.0);
uniform vec3 quadril = vec3(0.0);
uniform vec2 quadril_parado = vec2(0.0);
uniform vec3 pele_origem[64];
uniform vec3 pele_destino[64];
uniform int pele_total = 0;
varying vec2 mundo;

void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }

bool eh_pele(vec3 c) {
	for (int i = 0; i < 64; i++) {
		if (i >= pele_total) { break; }
		if (distance(c, pele_origem[i]) < 0.003) { return true; }
	}
	return false;
}

void fragment() {
	vec4 base = COLOR;
	vec2 local = floor(UV / TEXTURE_PIXEL_SIZE) - celula;
	int regiao = 0;
	vec4 m = vec4(0.0);
	if (usar_mascara) {
		m = texture(mascara, UV);
		if (m.a > 0.5) { regiao = int(round(m.r * 255.0 / 40.0)); }
	}
	bool vestido = false;
	if (usar_saia && quadril.z > 0.5 && (base.a < 0.01 || regiao == 2 || regiao == 5 || (regiao == 0 && local.y >= quadril.y - 3.0))) {
		vec2 p = floor(local - quadril.xy + quadril_parado);
		if (p.x >= 0.0 && p.x < 48.0 && p.y >= 0.0 && p.y < 60.0) {
			vec4 c = texelFetch(saia, ivec2(int(p.x), linha * 60 + int(p.y)), 0);
			if (c.a > 0.5) { base = vec4(c.rgb, 1.0); vestido = true; }
		}
	}
	if (base.a < 0.01) { discard; }
	if (!vestido && regiao > 0) {
		vec4 alvo = vec4(0.0);
		bool pele_roupa = false;
		if (regiao == 1 || regiao == 2 || regiao == 5) {
			vec4 r = regiao == 1 ? rect_tronco : regiao == 2 ? rect_perna_e : rect_perna_d;
			alvo = regiao == 1 ? camisa : calca;
			if (usar_textura && r.z > 0.0 && r.w > 0.0) {
				float u = r.x + min(r.z - 1.0, floor(m.b * r.z));
				float v = regiao == 1 ? r.y + min(r.w - 1.0, floor((1.0 - m.g) * r.w)) : r.y + min(r.w - 1.0, floor(m.g * r.w));
				int yy = linha * 60 + int(v);
				vec4 c = texelFetch(roupa, ivec2(int(u), yy), 0);
				for (int n = 0; n < 3; n++) {
					if (c.a > 0.5 || yy <= linha * 60 + int(r.y)) { break; }
					yy -= 1;
					c = texelFetch(roupa, ivec2(int(u), yy), 0);
				}
				if (c.a > 0.5) {
					if (eh_pele(c.rgb)) { pele_roupa = true; } else { alvo = vec4(c.rgb, 1.0); }
				}
			}
		} else if (regiao == 4 || regiao == 6) {
			if (m.g < manga_frac) { alvo = manga; }
		}
		if (!pele_roupa && alvo.a > 0.5) {
			float luz_pele = dot(base.rgb, vec3(0.299, 0.587, 0.114)) / 0.76;
			base.rgb = clamp(alvo.rgb * (0.55 + 0.45 * luz_pele), 0.0, 1.0);
			vestido = true;
		}
	}
	if (!vestido) {
		for (int i = 0; i < 64; i++) {
			if (i >= pele_total) { break; }
			if (distance(base.rgb, pele_origem[i]) < 0.003) { base.rgb = pele_destino[i]; break; }
		}
	}
	float d = plano * 2.0 + altura * 3.0;
	float cena = amostrar_cena(profundidade_cena, (mundo - origem) / tamanho, tamanho).r;
	if (cena > d + 1.25) { discard; }
	vec3 luz = iluminar_plex(base.rgb, vec3(mundo.x, mundo.y * 2.0 + altura * 2.0, altura), vec3(0.0, 0.0, 1.0), vec3(.85, .0, .05), 0.0, false);
	COLOR = vec4(luz, base.a);
}
