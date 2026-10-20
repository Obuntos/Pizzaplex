shader_type canvas_item;
uniform float desgaste_plex = 0.0;
render_mode unshaded;
#include "res://shaders/iluminacao.gdshaderinc"

uniform sampler2D profundidade : filter_nearest, repeat_disable;
uniform vec2 origem;
uniform vec2 tamanho;
uniform float plano;
uniform float inicio_cabeca = 40.0;
uniform bool em_escada = false;
uniform bool apoiar_degraus = false;
uniform bool apoiar_solas = false;
uniform float altura_apoio = 0.0;
uniform float raio = 3.5;
uniform vec4 pernas[6];
uniform bool normal_automatica=false;
uniform bool volume_fantasia=false;
uniform vec2 quadro_nativo=vec2(64.0,100.0);
uniform bool usar_bracos=false;
uniform vec4 bracos[6];
varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (COLOR.a <= 0.0) { discard; }
	float distancia = plano - mundo.y;
	if (usar_bracos && (distancia-mundo.y*2.0)/3.0<inicio_cabeca) {
		float perto=19.36;
		for (int braco=0;braco<2;braco++) {
			for (int trecho=0;trecho<2;trecho++) {
				vec3 a=bracos[braco*3+trecho].xyz;
				vec3 b=bracos[braco*3+trecho+1].xyz;
				vec2 segmento=b.xy-a.xy;
				float t=clamp(dot(mundo-a.xy,segmento)/max(dot(segmento,segmento),.001),0.0,1.0);
				vec3 ponto=mix(a,b,t);
				float d=dot(mundo-ponto.xy,mundo-ponto.xy);
				if (d<perto) { perto=d; distancia=ponto.z+ponto.y-mundo.y; }
			}
		}
	}
	if (em_escada) {
		float perto = raio * raio;
		for (int perna = 0; perna < 2; perna++) {
			for (int trecho = 0; trecho < 2; trecho++) {
				vec3 a = pernas[perna * 3 + trecho].xyz;
				vec3 b = pernas[perna * 3 + trecho + 1].xyz;
				vec2 segmento = b.xy - a.xy;
				float t = clamp(dot(mundo - a.xy, segmento) / max(dot(segmento, segmento), 0.001), 0.0, 1.0);
				vec3 ponto = mix(a, b, t);
				float d = dot(mundo - ponto.xy, mundo - ponto.xy);
				if (d < perto) {
					perto = d;
					distancia = ponto.z + ponto.y - mundo.y;
				}
			}
			vec4 pe = pernas[perna * 3 + 2];
			vec2 sola = mundo - pe.xy;
			if (apoiar_degraus && abs(sola.x) <= raio + 1.0 && sola.y >= -raio && sola.y <= raio) {
				distancia = max(distancia, mundo.y * 2.0 + pe.w * 3.0 + 0.15);
			}
		}
	}
	if (apoiar_solas) {
		float altura_pixel = (distancia - mundo.y * 2.0) / 3.0;
		if (altura_pixel >= altura_apoio - 5.0 && altura_pixel <= altura_apoio + 3.0) {
			distancia = max(distancia, mundo.y * 2.0 + altura_apoio * 3.0 + 0.15);
		}
	}
	vec2 uv = (mundo - origem) / tamanho;
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
		float obstaculo = texture(profundidade, uv).r;
		if (distancia < obstaculo - 1.25) {
			COLOR.a = 0.0;
		}
	}
	vec3 n = texture(NORMAL_TEXTURE, UV).rgb * 2.0 - 1.0;
	n = normalize(vec3(n.xy * 1.35, max(0.05, n.z)));
	vec3 normal = vec3(n.x, -0.447214 * n.y + 0.894427 * n.z, 0.894427 * n.y + 0.447214 * n.z);
	vec3 dados = texture(SPECULAR_SHININESS_TEXTURE, UV).rgb;
	if (volume_fantasia) {
		vec2 pixel = mod(UV / TEXTURE_PIXEL_SIZE, quadro_nativo);
		vec2 esfera = (pixel - vec2(23.5, 34.5)) / vec2(12.0, 12.5);
		float mascara = 1.0 - smoothstep(0.88, 1.15, length(esfera));
		vec2 curva = clamp(vec2(esfera.x, -esfera.y) * 0.65, vec2(-0.72), vec2(0.72));
		vec3 cabeca = normalize(vec3(curva, sqrt(max(0.12, 1.0-dot(curva,curva)))));
		n = normalize(mix(n,cabeca,mascara));
		dados = mix(dados,vec3(0.82,0.025,0.0),mascara);
		normal = vec3(n.x,-0.447214*n.y+0.894427*n.z,0.894427*n.y+0.447214*n.z);
	}
	if (normal_automatica) {
		vec2 pixel=mod(UV/TEXTURE_PIXEL_SIZE,quadro_nativo);
		float nx=clamp((pixel.x-quadro_nativo.x*.5)/(quadro_nativo.x*.23),-.7,.7);
		float ny=clamp((quadro_nativo.y*.34-pixel.y)/(quadro_nativo.y*.18),-.45,.45);
		if (pixel.y>quadro_nativo.y*.5) {ny=0.0;}
		n=normalize(vec3(nx,ny,sqrt(max(.08,1.0-nx*nx-ny*ny))));
		normal=vec3(n.x,-.447214*n.y+.894427*n.z,.894427*n.y+.447214*n.z);
		dados=vec3(.72,.055,0.0);
	}
	float z = (distancia - mundo.y * 2.0) / 3.0;
	if (z < inicio_cabeca) {
		normal = normalize(vec3(n.x, n.z, n.y));
	}
	COLOR.rgb *= mix(vec3(1.0),vec3(.83,.80,.75),clamp(desgaste_plex,0.0,1.0));
	COLOR.rgb = iluminar_plex(COLOR.rgb, vec3(mundo.x, distancia - z, z), normal, dados, 1.0, false);

}

