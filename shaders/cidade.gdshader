shader_type canvas_item;
render_mode unshaded;
uniform float ambiente = .55;
uniform float energia_solar = .4;
uniform vec3 cor_solar = vec3(1.0);
uniform vec3 cor_ambiente = vec3(1.0);
uniform bool cortar = false;
uniform vec4 lote = vec4(33.0,25.0,45.0,37.0);
uniform vec2 centro_grade = vec2(39.5,31.5);
uniform int vista = 0;
uniform bool emissiva = false;
uniform float balanco = 0.0;
uniform float fase = 0.0;
uniform float altura_textura = 100.0;
varying vec2 mundo;

void vertex() {
	VERTEX.x += round(sin(fase)*balanco)*clamp(1.0-VERTEX.y/max(altura_textura,1.0),0.0,1.0);
	mundo = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
}

bool dentro(vec2 p) {
	vec2 c = vec2(p.x/64.0+p.y/32.0,p.y/32.0-p.x/64.0)-centro_grade;
	if (vista==1) c=vec2(c.y,-c.x);
	else if (vista==2) c=-c;
	else if (vista==3) c=vec2(-c.y,c.x);
	c+=centro_grade;
	return c.x>lote.x-.5 && c.y>lote.y-.5 && c.x<lote.z-.5 && c.y<lote.w-.5;
}

void fragment() {
	vec4 tint=COLOR;
	vec4 base=texture(TEXTURE,UV);
	if (cortar && (dentro(mundo)||dentro(mundo+vec2(0.0,40.0))||dentro(mundo+vec2(0.0,80.0)))) {
		if (mod(floor(mundo.x)+floor(mundo.y)*2.0,5.0)>0.5) discard;
		base.a*=.45;
	}
	vec3 luz=cor_ambiente*max(.16,ambiente)+cor_solar*energia_solar*.55;
	vec3 cor=base.rgb*luz;
	if (emissiva && base.r>.55 && base.g>.45 && base.b<base.r*.85) cor=max(cor,base.rgb*.95);
	COLOR=vec4(cor,base.a)*tint;
}
