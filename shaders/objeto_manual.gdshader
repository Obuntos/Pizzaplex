shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/iluminacao.gdshaderinc"
#include "res://shaders/mapa_cena.gdshaderinc"
uniform sampler2DArray profundidade_cena : filter_nearest, repeat_disable;
uniform vec2 origem;
uniform vec2 tamanho;
uniform float altura = 4.0;
varying vec2 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
	vec4 base = COLOR;
	if (base.a<0.01) { discard; }
	float d = mundo.y*2.0+altura*3.0;
	float cena = amostrar_cena(profundidade_cena,(mundo-origem)/tamanho,tamanho).r;
	if (cena>d+0.4) { discard; }
	vec3 luz = iluminar_plex(base.rgb,vec3(mundo.x,mundo.y*2.0+altura*2.0,altura),vec3(0.0,0.0,1.0),vec3(.85,.0,.05),0.0,false);
	COLOR = vec4(luz,base.a);
}
