shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/mapa_cena.gdshaderinc"
#include "res://shaders/luzes_cidade.gdshaderinc"
uniform sampler2D mascara_emissao : filter_nearest, repeat_disable, hint_default_black;
uniform bool tem_emissao = false;
uniform bool emissao_continua = false;
uniform float balanco = 0.0;
uniform float fase = 0.0;
uniform float altura_textura = 100.0;
uniform float nivel_emissao = 1.0;
uniform vec3 cor_emissao = vec3(1.0,0.8,0.5);
uniform bool janelas_agrupadas = false;
uniform float niveis_janelas[64];
uniform bool recortar_vizinho = false;
uniform vec4 limites_lote;
uniform float recepcao_externa = 1.0;
uniform sampler2DArray profundidade_cena : filter_nearest, repeat_disable;
uniform sampler2D altura_sprite : filter_nearest, repeat_disable;
uniform bool usar_altura = false;
uniform bool altura_aproximada = false;
uniform vec2 apoio_tela;
uniform vec2 origem;
uniform vec2 tamanho;
varying vec2 mundo;
varying vec4 tinta;
uniform float ambiente = 0.55;
uniform float energia_solar = 0.0;
uniform vec3 cor_solar = vec3(1.0);
uniform vec3 cor_ambiente = vec3(1.0);
void vertex() {
	tinta=COLOR;
	VERTEX.x+=round(sin(fase)*balanco*pow(1.0-UV.y,2.0));
	mundo = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy;
}
void fragment() {
	vec4 base = texture(TEXTURE,UV);
	float altura = max(0.0,apoio_tela.y-mundo.y);
	if (usar_altura || altura_aproximada) {
		if (usar_altura) {
			vec2 codificada = floor(texture(altura_sprite,UV).rg*255.0+0.5);
			altura = (codificada.r+codificada.g*256.0)/64.0;
		}
		float profundidade = mundo.y*2.0+altura*3.0;
		float cena = amostrar_cena(profundidade_cena,(mundo-origem)/tamanho,tamanho).r;
		if (cena>profundidade+0.4) { discard; }
	}
	vec3 campo = luz_da_cidade(ponto_cidade(vec3(mundo.x,(mundo.y+altura)*2.0,altura)))*recepcao_externa;
	base.rgb *= cor_ambiente*max(.025,ambiente)+cor_solar*energia_solar*.45+(vec3(1.0)-exp(-campo))*.8;
	if (tem_emissao && (noite_cidade>0.001 || emissao_continua)) {
		vec4 emissao = texture(mascara_emissao,UV);
		float mascara = emissao.r*emissao.a*nivel_emissao;
		if (janelas_agrupadas) { mascara *= niveis_janelas[clamp(int(round(emissao.g*255.0))-1,0,63)]; }
		base.rgb = mix(base.rgb,emissao_continua?texture(TEXTURE,UV).rgb:cor_emissao,mascara*max(noite_cidade,emissao_continua?1.0:0.0));
	}
	if (recortar_vizinho && altura>7.0) {
		vec2 solo = vec2(mundo.x/64.0+mundo.y/32.0,mundo.y/32.0-mundo.x/64.0);
		vec2 entrada = (limites_lote.xy-solo)*32.0;
		vec2 saida = (limites_lote.zw-solo)*32.0;
		float inicio = max(0.0,max(entrada.x,entrada.y));
		float fim = min(110.0,min(saida.x,saida.y));
		if (fim>=inicio && altura>=inicio-0.5) {
			if (mod(floor(mundo.x)+mod(floor(mundo.y/2.0),2.0),2.0)>0.5 || mod(floor(mundo.y),2.0)>0.5) { discard; }
			base.a*=0.2;
		}
	}
	COLOR = base*tinta;
}

