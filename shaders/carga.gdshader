shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/iluminacao.gdshaderinc"
uniform sampler2D profundidade_cena : filter_nearest, repeat_disable;
uniform sampler2D profundidade_item : filter_nearest, repeat_disable;
uniform sampler2D superficies_item : filter_nearest, repeat_disable;
uniform vec2 origem;
uniform vec2 tamanho;
uniform float base;
varying vec2 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
	if (COLOR.a<=0.0) { discard; }
	float d=base+texture(profundidade_item,UV).r;
	vec2 uv=(mundo-origem)/tamanho;
	if (all(greaterThanEqual(uv,vec2(0.0))) && all(lessThan(uv,vec2(1.0))) && d<texture(profundidade_cena,uv).r-1.25) { discard; }
	float z=(d-mundo.y*2.0)/3.0;
	vec3 normal=normalize(texture(superficies_item,UV).rgb*2.0-1.0);
	COLOR.rgb=iluminar_plex(COLOR.rgb,vec3(mundo.x,d-z,z),normal,vec3(.85,.03,.1),0.0,false);
}
