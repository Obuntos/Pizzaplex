shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/iluminacao.gdshaderinc"
uniform int indice_luz = -1;
uniform bool sombra_solar = false;
uniform sampler2D profundidade : filter_nearest, repeat_disable;
uniform sampler2D superficies : filter_nearest, repeat_disable;
uniform vec2 origem;
uniform vec2 tamanho;
uniform vec3 apoio;
uniform vec2 direcao;
uniform float altura_destino;
uniform float altura_luz;
uniform float opacidade = 0.22;
varying vec2 mundo_sombra;
varying float altura_fonte;
void vertex() {
	vec2 fonte = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	altura_fonte = apoio.y * 0.5 - fonte.y;
	float avanco = max(0.0, altura_fonte - altura_destino);
	mundo_sombra = vec2(fonte.x + direcao.x * avanco, apoio.y * 0.5 - altura_destino + direcao.y * avanco * 0.5);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(mundo_sombra, 0.0, 1.0)).xy;
}
void fragment() {
	if (COLOR.a <= 0.0) { discard; }
	if (altura_fonte <= altura_destino || altura_fonte >= altura_luz) { discard; }
	vec2 uv = (mundo_sombra - origem) / tamanho;
	if (texture(superficies, uv).a > 0.75) { discard; }
	float d = texture(profundidade, uv).r;
	float altura = d < -9999.0 ? 0.0 : (d - mundo_sombra.y * 2.0) / 3.0;
	vec2 celula = grade_mundo(vec3(mundo_sombra.x, 2.0 * (mundo_sombra.y + altura_destino), altura_destino));
	if (abs(altura - altura_destino) > 1.3 || any(lessThan(celula, vec2(-0.5))) || any(greaterThan(celula, (tamanho_grade - vec2(0.5))))) { discard; }
	if (!sombra_solar && (indice_luz < 0 || indice_luz >= quantidade_luzes)) { discard; }
	vec3 receptor = vec3(mundo_sombra.x, 2.0 * (mundo_sombra.y + altura_destino), altura_destino + 1.5);
	float energia = 0.0;
	vec3 cor = cor_solar;
	if (sombra_solar) {
		vec3 fisico = posicao_mundo(receptor);
		vec2 celula_sol = celula_luz(fisico);
		if (texture(bloqueios, (celula_sol + 0.5) / tamanho_grade).g > 0.5) { discard; }
		energia = energia_solar * visibilidade_luz(fisico, fisico + direcao_solar * 1200.0);
	} else {
		energia = energia_luz(indice_luz, receptor);
		cor = luzes_cor[indice_luz].rgb;
	}
	energia *= dot(cor, vec3(0.2126, 0.7152, 0.0722));
	vec3 fisico = posicao_mundo(receptor);
	vec2 celula_ambiente = celula_luz(fisico);
	float interior = 0.0;
	if (all(greaterThanEqual(celula_ambiente, vec2(0.0))) && all(lessThan(celula_ambiente, tamanho_grade))) {
		interior = texture(bloqueios, (celula_ambiente + 0.5) / tamanho_grade).g;
	}
	float preenchimento = mix(ambiente, max(0.006, ambiente * 0.32), interior);
	for (int i = 0; i < 32; i++) {
		if (i >= quantidade_luzes) { break; }
		if (!sombra_solar && i == indice_luz) { continue; }
		preenchimento += energia_fisica(i, fisico) * dot(luzes_cor[i].rgb, vec3(0.2126, 0.7152, 0.0722));
	}
	if (!sombra_solar && interior < 0.5 && energia_solar > 0.001) {
		preenchimento += energia_solar * visibilidade_luz(fisico, fisico + direcao_solar * 1200.0) * dot(cor_solar, vec3(0.2126, 0.7152, 0.0722));
	}
	float participacao = energia / max(energia + preenchimento, 0.0001);
	COLOR = vec4(0.09, 0.11, 0.13, texture(TEXTURE, UV).a * opacidade * clamp(energia, 0.0, 1.0) * participacao);
}

