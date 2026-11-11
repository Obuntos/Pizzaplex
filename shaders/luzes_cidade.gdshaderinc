uniform sampler2D mapa_luzes_cidade : filter_linear, repeat_disable, hint_default_black;
uniform float noite_cidade = 0.0;
uniform vec2 tamanho_luzes_cidade = vec2(80.0,64.0);
uniform vec2 centro_luzes_cidade = vec2(256.0,2272.0);
uniform vec4 eixos_luzes_cidade = vec4(1.0,0.0,0.0,1.0);

vec3 ponto_cidade(vec3 p) {
	vec2 local = p.xy-centro_luzes_cidade;
	return vec3(vec2(dot(eixos_luzes_cidade.xy,local),dot(eixos_luzes_cidade.zw,local))+centro_luzes_cidade,p.z);
}

vec3 luz_da_cidade(vec3 p) {
	if (noite_cidade <= 0.001) { return vec3(0.0); }
	vec2 grade = vec2((p.x+p.y)/64.0,(p.y-p.x)/64.0);
	vec2 uv = (grade+0.5)/tamanho_luzes_cidade;
	if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) { return vec3(0.0); }
	float altura = 1.0+0.22*smoothstep(0.0,90.0,p.z);
	return texture(mapa_luzes_cidade,uv).r*vec3(1.0,0.84,0.58)*noite_cidade*altura;
}
