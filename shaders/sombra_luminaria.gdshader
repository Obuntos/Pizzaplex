shader_type canvas_item;
render_mode unshaded, blend_mul;
#include "res://shaders/iluminacao.gdshaderinc"
#include "res://shaders/mapa_cena.gdshaderinc"
uniform int indice_luz = -1;
uniform bool sombra_solar = false;
uniform sampler2DArray profundidade : filter_nearest, repeat_disable;
uniform sampler2DArray superficies : filter_nearest, repeat_disable;
uniform vec2 origem;
uniform vec2 tamanho;
uniform vec3 apoio;
uniform vec2 direcao;
uniform float altura_destino;
uniform float altura_luz;
uniform vec3 posicao_luz;
uniform float opacidade = 0.42;
uniform float peso_sombra = 0.8;
varying vec2 mundo_sombra;
varying float altura_fonte;
void vertex() {
	vec2 fonte = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	altura_fonte = apoio.y * 0.5 - fonte.y;
	float avanco = max(0.0, altura_fonte - altura_destino);
	vec2 base_fonte=vec2(fonte.x,apoio.y);
	vec2 projetado=base_fonte+direcao*avanco;
	if (!sombra_solar) {
		float escala=avanco/max(12.0,posicao_luz.z-altura_fonte);
		projetado=base_fonte+(base_fonte-posicao_luz.xy)*escala;
	}
	mundo_sombra = vec2(projetado.x,projetado.y*.5-altura_destino);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(mundo_sombra, 0.0, 1.0)).xy;
}
void fragment() {
	if (COLOR.a <= 0.0) { discard; }
	if (altura_fonte <= altura_destino || altura_fonte >= altura_luz) { discard; }
	vec2 uv = (mundo_sombra - origem) / tamanho;
	if (amostrar_cena(superficies, uv, tamanho).a > 0.75) { discard; }
	float d = amostrar_cena(profundidade, uv, tamanho).r;
	float altura = d < -9999.0 ? 0.0 : (d - mundo_sombra.y * 2.0) / 3.0;
	vec2 celula = grade_mundo(vec3(mundo_sombra.x, 2.0 * (mundo_sombra.y + altura_destino), altura_destino));
	if (abs(altura - altura_destino) > 1.3 || any(lessThan(celula, vec2(-0.5))) || any(greaterThan(celula, (tamanho_grade - vec2(0.5))))) { discard; }
	if (!sombra_solar && (indice_luz < 0 || indice_luz >= quantidade_luzes)) { discard; }
	vec3 receptor=posicao_mundo(vec3(mundo_sombra.x,2.0*(mundo_sombra.y+altura_destino),altura_destino+1.6));
	if (sombra_solar) {
		if (energia_solar<=.001 || visibilidade_luz(receptor,receptor+direcao_solar*1200.0)<.5) { discard; }
		if (interior_receptor(receptor,false)>.5 && sai_por_janela(receptor)<.001) { discard; }
	} else if (energia_fisica(indice_luz,receptor)<.001) { discard; }
	float mascara=texture(TEXTURE,UV).a;
	float ganho=1.0-clamp(mascara*opacidade*peso_sombra,0.0,.65);
	COLOR=vec4(vec3(ganho),1.0);
}
