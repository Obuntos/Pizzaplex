#include "res://shaders/luzes_cidade.gdshaderinc"
uniform vec2 tamanho_grade = vec2(32.0, 24.0);
uniform vec2 centro_grade = vec2(128.0, 864.0);
uniform vec4 eixos_visao = vec4(1.0, 0.0, 0.0, 1.0);
uniform int quantidade_luzes = 0;
uniform vec4 luzes_posicao[32];
uniform vec4 luzes_cor[32];
uniform vec4 luzes_direcao[32];
uniform sampler2D bloqueios : filter_nearest, repeat_disable;
uniform sampler2D passagens : filter_nearest, repeat_disable;
uniform sampler2D silhuetas_estruturas : filter_nearest, repeat_disable, hint_default_black;
uniform sampler2D indices_estruturas : filter_nearest, repeat_disable, hint_default_black;
uniform sampler2D indices_estruturas_extra : filter_nearest, repeat_disable, hint_default_black;
uniform sampler2D minimos_estruturas : filter_nearest, repeat_disable, hint_default_black;
uniform sampler2D maximos_estruturas : filter_nearest, repeat_disable, hint_default_black;
uniform float energia_rede = 0.0;
uniform sampler2D variacao_luzes : hint_default_white, filter_nearest, repeat_disable;
uniform sampler2D lanternas : filter_nearest, repeat_disable;
uniform int quantidade_lanternas = 0;
uniform sampler2D luz_janelas : filter_linear, repeat_disable, hint_default_black;
uniform float ambiente = 0.55;
uniform vec3 direcao_solar = vec3(0.7,0.0,0.7);
uniform float energia_solar = 0.0;
uniform vec3 cor_solar = vec3(1.0,0.95,0.80);
uniform vec3 cor_ambiente = vec3(1.0);
uniform float contraste = 0.6;
uniform float influencia_cor = 0.25;

vec2 vetor_mundo(vec2 v) {
	return vec2(dot(eixos_visao.xy, v), dot(eixos_visao.zw, v));
}

vec3 posicao_mundo(vec3 p) {
	vec2 centro = centro_grade;
	return vec3(vetor_mundo(p.xy - centro) + centro, p.z);
}

vec2 grade_fisica(vec3 p) {
	return vec2((p.x + p.y) / 64.0, (p.y - p.x) / 64.0);
}

vec2 grade_mundo(vec3 p) {
	return grade_fisica(posicao_mundo(p));
}

vec2 celula_luz(vec3 p) {
	return floor(grade_fisica(p) + 0.5);
}

float altura_bloqueio(vec2 celula) {
	if (any(lessThan(celula, vec2(0.0))) || any(greaterThanEqual(celula, tamanho_grade))) { return 0.0; }
	return texture(bloqueios, (celula + 0.5) / tamanho_grade).r * 160.0;
}

bool raio_caixa(vec3 a, vec3 b, vec3 minimo, vec3 maximo, float entrada, float saida) {
	vec3 delta = b - a;
	float inicio = entrada;
	float fim = saida;
	for (int eixo = 0; eixo < 3; eixo++) {
		if (abs(delta[eixo]) < 0.000001) {
			if (a[eixo] < minimo[eixo] || a[eixo] > maximo[eixo]) { return false; }
		} else {
			float t1 = (minimo[eixo] - a[eixo]) / delta[eixo];
			float t2 = (maximo[eixo] - a[eixo]) / delta[eixo];
			inicio = max(inicio, min(t1, t2));
			fim = min(fim, max(t1, t2));
			if (fim < inicio + 0.000001) { return false; }
		}
	}
	return fim >= inicio + 0.000001;
}

bool volume_estrutura(vec2 celula, vec3 p, vec3 luz, float entrada, float saida) {
	vec4 indices=texelFetch(indices_estruturas,ivec2(celula),0);
	if (indices.x<.5) { return false; }
	vec3 a=vec3(grade_fisica(p),p.z);
	vec3 b=vec3(grade_fisica(luz),luz.z);
	for (int i=0;i<8;i++) {
		int id=i<4 ? int(round(indices[i])) : int(round(texelFetch(indices_estruturas_extra,ivec2(celula),0)[i-4]));
		if (id<1) { break; }
		vec4 baixo=texelFetch(minimos_estruturas,ivec2(id,0),0);
		vec4 superior=texelFetch(maximos_estruturas,ivec2(id,0),0);
		vec3 alto=superior.xyz;
		if (all(greaterThanEqual(a,baixo.xyz-vec3(.035,.035,1.5))) && all(lessThanEqual(a,alto+vec3(.035,.035,1.5)))) { continue; }
		if (baixo.a>1.5) {
			int rotacao=int(round(superior.a));
			vec2 normal=vec2(0.0,1.0);
			if (rotacao==1) { normal=vec2(-1.0,0.0); }
			else if (rotacao==2) { normal=vec2(0.0,-1.0); }
			else if (rotacao==3) { normal=vec2(1.0,0.0); }
			vec2 centro=(baixo.xy+alto.xy)*.5;
			float divisor=dot(b.xy-a.xy,normal);
			if (abs(divisor)<.000001) { continue; }
			float t=dot(centro-a.xy,normal)/divisor;
			if (t<=max(entrada,.00001) || t>=min(saida,.99999)) { continue; }
			vec3 q=mix(a,b,t);
			float lateral=dot(q.xy-centro,vec2(normal.y,-normal.x));
			ivec2 pixel=ivec2(int(floor(lateral*32.0+32.0)),127-int(round(q.z-baixo.z)));
			if (any(lessThan(pixel,ivec2(0))) || any(greaterThanEqual(pixel,ivec2(64,128)))) { continue; }
			int mascara=int(round(baixo.a))-2;
			ivec2 origem=ivec2((mascara%8)*64,(mascara/8)*128);
			if (texelFetch(silhuetas_estruturas,origem+pixel,0).r>.5) { return true; }
		} else if (baixo.a>.5) {
			vec3 centro=(baixo.xyz+alto)*.5;
			vec3 raio=max(vec3(.001),(alto-baixo.xyz)*.5);
			vec3 origem=(a-centro)/raio;
			vec3 delta=(b-a)/raio;
			float aa=dot(delta,delta);
			float bb=dot(origem,delta);
			float cc=dot(origem,origem)-1.0;
			float d=bb*bb-aa*cc;
			if (d>=0.0 && aa>.000001) {
				float r=sqrt(d);
				if (max(entrada,(-bb-r)/aa)<min(saida,(-bb+r)/aa)-.000001) { return true; }
			}
		} else if (raio_caixa(a,b,baixo.xyz,alto,entrada,saida)) { return true; }
	}
	return false;
}

vec3 local_porta(vec3 ponto, vec4 portal) {
	vec2 grade = grade_fisica(ponto) - portal.xy;
	vec2 frente = vec2(0.0, 1.0);
	if (portal.z > 2.5) { frente = vec2(1.0, 0.0); }
	else if (portal.z > 1.5) { frente = vec2(0.0, -1.0); }
	else if (portal.z > 0.5) { frente = vec2(-1.0, 0.0); }
	return vec3(dot(grade, vec2(frente.y, -frente.x)), dot(grade, frente), ponto.z);
}

bool trecho_bloqueado(vec2 celula, vec3 p, vec3 luz, float entrada, float saida) {
	if (saida <= entrada + 0.000001) { return false; }
	if (any(lessThan(celula, vec2(0.0))) || any(greaterThanEqual(celula, tamanho_grade))) { return false; }
	if (volume_estrutura(celula,p,luz,entrada,saida)) { return true; }
	vec4 portal = texture(passagens, (celula + 0.5) / tamanho_grade);
	if (abs(portal.a) < 0.5) {
		float z = min(mix(p.z, luz.z, entrada), mix(p.z, luz.z, saida));
		return altura_bloqueio(celula) > z + 1.0;
	}
	vec3 a = local_porta(p, portal);
	vec3 b = local_porta(luz, portal);
	if (portal.a > 4.5) {
		float meio_janela=(portal.a-4.0)*.5;
		if (raio_caixa(a,b,vec3(-meio_janela,-.495,0.0),vec3(meio_janela,.495,30.0),entrada,saida)) { return true; }
		if (raio_caixa(a,b,vec3(-meio_janela,-.495,88.0),vec3(meio_janela,.495,160.0),entrada,saida)) { return true; }
		for (int i=0;i<4;i++) {
			if (float(i)>portal.a-4.0) { break; }
			float u=-meio_janela+float(i);
			if (raio_caixa(a,b,vec3(u-.055,-.495,30.0),vec3(u+.055,.495,88.0),entrada,saida)) { return true; }
		}
		return false;
	}
	float meio = abs(portal.a) * 0.5;
	float passagem = meio - (meio > 0.75 ? 0.14 : 0.12);
	if (raio_caixa(a, b, vec3(-meio + 0.005, -0.495, 0.0), vec3(-meio + 0.115, 0.495, 160.0), entrada, saida)) { return true; }
	if (raio_caixa(a, b, vec3(meio - 0.115, -0.495, 0.0), vec3(meio - 0.005, 0.495, 160.0), entrada, saida)) { return true; }
	if (raio_caixa(a, b, vec3(-meio, -0.495, 98.0), vec3(meio, 0.495, 160.0), entrada, saida)) { return true; }
	if (portal.a > 0.0) {
		return raio_caixa(a, b, vec3(-passagem, -0.0325, 0.0), vec3(passagem, 0.0325, 98.0), entrada, saida);
	}
	float folha = meio > 0.75 ? passagem : passagem * 2.0;
	if (raio_caixa(a, b, vec3(-passagem - 0.0325, -folha, 1.0), vec3(-passagem + 0.0325, 0.0, 97.0), entrada, saida)) { return true; }
	return meio > 0.75 && raio_caixa(a, b, vec3(passagem - 0.0325, -folha, 1.0), vec3(passagem + 0.0325, 0.0, 97.0), entrada, saida);
}

float visibilidade_luz(vec3 p, vec3 origem_luz) {
	vec2 a = grade_fisica(p) + 0.5;
	vec2 b = grade_fisica(origem_luz) + 0.5;
	vec2 delta = b - a;
	vec2 celula = floor(a);
	vec2 passo = sign(delta);
	vec2 incremento = vec2(1e20);
	if (abs(delta.x) > 0.000001) { incremento.x = abs(1.0 / delta.x); }
	if (abs(delta.y) > 0.000001) { incremento.y = abs(1.0 / delta.y); }
	vec2 proximos = abs(celula + step(vec2(0.0), delta) - a) * incremento;
	if (passo.x == 0.0) { proximos.x = 1e20; }
	if (passo.y == 0.0) { proximos.y = 1e20; }
	float entrada = 0.0;
	for (int trecho = 0; trecho < 128; trecho++) {
		float saida = min(1.0, min(proximos.x, proximos.y));
		if ((celula.x < 0.0 && passo.x <= 0.0) || (celula.y < 0.0 && passo.y <= 0.0) || (celula.x >= tamanho_grade.x && passo.x >= 0.0) || (celula.y >= tamanho_grade.y && passo.y >= 0.0)) { return 1.0; }
		if (trecho_bloqueado(celula, p, origem_luz, entrada, saida)) { return 0.0; }
		if (saida >= 1.0) { return 1.0; }
		if (abs(proximos.x - proximos.y) < 0.000001) {
			float inicio_quina=max(0.0,saida-0.0001);
			float fim_quina=min(1.0,saida+0.0001);
			if (trecho_bloqueado(celula+vec2(passo.x,0.0),p,origem_luz,inicio_quina,fim_quina) || trecho_bloqueado(celula+vec2(0.0,passo.y),p,origem_luz,inicio_quina,fim_quina)) { return 0.0; }
			celula += passo;
			proximos += incremento;
		} else if (proximos.x < proximos.y) {
			celula.x += passo.x;
			proximos.x += incremento.x;
		} else {
			celula.y += passo.y;
			proximos.y += incremento.y;
		}
		entrada = saida;
	}
	return 0.0;
}

vec3 receptor_superficie(vec3 p, vec3 normal, bool estrutura) {
	vec3 receptor = p + normal * 2.0;
	if (!estrutura) { return receptor; }
	if (normal.z > 0.5) {
		vec2 grade = grade_fisica(receptor);
		vec2 celula = floor(grade + 0.5);
		vec4 portal = texture(passagens, (celula + 0.5) / tamanho_grade);
		if (p.z > 100.0 && abs(portal.a) > 0.5) { return vec3(receptor.xy, max(receptor.z, 161.1)); }
		float altura = altura_bloqueio(celula);
		if (altura <= receptor.z + 1.0) { return receptor; }
		if (p.z > 100.0) { return vec3(receptor.xy, altura + 1.1); }
		vec2 melhor = grade;
		float nota = 1e20;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				if (x == 0 && y == 0) { continue; }
				vec2 vizinha = celula + vec2(float(x), float(y));
				if (altura_bloqueio(vizinha) > p.z + 1.0) { continue; }
				vec2 candidata = clamp(grade, vizinha - 0.49, vizinha + 0.49);
				float n = distance(candidata, grade);
				if (n < nota) { nota = n; melhor = candidata; }
			}
		}
		return vec3((melhor.x-melhor.y)*32.0,(melhor.x+melhor.y)*32.0,receptor.z);
	}
	vec2 grade = grade_fisica(receptor);
	vec2 celula = floor(grade + 0.5);
	if (altura_bloqueio(celula) <= receptor.z + 1.0) { return receptor; }
	vec4 portal = texture(passagens, (celula + 0.5) / tamanho_grade);
	if (abs(portal.a) > 0.5) { return receptor; }
	vec2 direcao = vec2((normal.x + normal.y) / 64.0, (normal.y - normal.x) / 64.0);
	vec2 local = grade - celula;
	float avanco = 1e20;
	if (abs(direcao.x) > 0.000001) { avanco = min(avanco, (0.501 - sign(direcao.x) * local.x) / abs(direcao.x)); }
	if (abs(direcao.y) > 0.000001) { avanco = min(avanco, (0.501 - sign(direcao.y) * local.y) / abs(direcao.y)); }
	return receptor + normal * clamp(avanco, 0.0, 24.0);
}

float interior_receptor(vec3 p, bool estrutura) {
	vec2 celula = celula_luz(p);
	if (any(lessThan(celula, vec2(0.0))) || any(greaterThanEqual(celula, tamanho_grade))) { return 0.0; }
	vec4 recinto = texture(bloqueios, (celula + 0.5) / tamanho_grade);
	float dentro_parede = step(p.z + 1.0, recinto.r * 160.0);
	return max(recinto.g, estrutura ? recinto.b * dentro_parede : 0.0);
}

float sai_por_janela(vec3 p) {
	if (direcao_solar.z<=0.001 || p.z>=103.0) { return 0.0; }
	vec3 teto=p+direcao_solar*((104.0-p.z)/direcao_solar.z);
	vec2 a=grade_fisica(p)+.5;
	vec2 delta=grade_fisica(teto)-grade_fisica(p);
	vec2 celula=floor(a);
	vec2 passo=sign(delta);
	vec2 incremento=vec2(1e20);
	if (abs(delta.x)>.000001) { incremento.x=abs(1.0/delta.x); }
	if (abs(delta.y)>.000001) { incremento.y=abs(1.0/delta.y); }
	vec2 proximos=abs(celula+step(vec2(0.0),delta)-a)*incremento;
	if (passo.x==0.0) { proximos.x=1e20; }
	if (passo.y==0.0) { proximos.y=1e20; }
	for (int i=0;i<40;i++) {
		if (any(lessThan(celula,vec2(0.0))) || any(greaterThanEqual(celula,tamanho_grade))) { return 0.0; }
		vec4 portal=texture(passagens,(celula+.5)/tamanho_grade);
		if (portal.a>4.5) {
			vec3 local_a=local_porta(p,portal);
			vec3 local_b=local_porta(teto,portal);
			float dn=local_b.y-local_a.y;
			if (abs(dn)>.00001) {
				float t=-local_a.y/dn;
				vec3 q=mix(local_a,local_b,t);
				vec2 frente=vec2(0.0,1.0);
				if (portal.z>2.5) { frente=vec2(1.0,0.0); }
				else if (portal.z>1.5) { frente=vec2(0.0,-1.0); }
				else if (portal.z>.5) { frente=vec2(-1.0,0.0); }
				vec2 depois=celula+frente*sign(dn);
				float interior_depois=texture(bloqueios,(depois+.5)/tamanho_grade).g;
				if (t>0.0 && t<1.0 && q.z>30.0 && q.z<88.0 && abs(q.x)<(portal.a-4.0)*.5-.06 && interior_depois<.5) { return .86; }
			}
		}
		float fim=min(proximos.x,proximos.y);
		if (fim>=1.0) { return 0.0; }
		if (proximos.x<proximos.y) { celula.x+=passo.x;proximos.x+=incremento.x; }
		else { celula.y+=passo.y;proximos.y+=incremento.y; }
	}
	return 0.0;
}

float energia_fisica(int i, vec3 p) {
	if (energia_rede <= 0.001 || luzes_cor[i].a <= 0.0001) { return 0.0; }
	vec3 delta = luzes_posicao[i].xyz - p;
	float distancia = max(1.0, length(delta));
	float alcance = luzes_posicao[i].w;
	if (distancia > alcance) { return 0.0; }
	vec3 l = delta / distancia;
	float cone = 1.0;
	if (luzes_direcao[i].w > -0.99) { cone = smoothstep(luzes_direcao[i].w, min(0.99, luzes_direcao[i].w + 0.3), dot(-l, luzes_direcao[i].xyz)); }
	if (cone <= 0.0001) { return 0.0; }
	float queda = (1.0 - smoothstep(alcance * 0.55, alcance, distancia)) / (1.0 + distancia * distancia / (alcance * alcance));
	return texelFetch(variacao_luzes, ivec2(i,0),0).r * energia_rede * max(0.0, luzes_cor[i].a) * queda * cone * visibilidade_luz(p, luzes_posicao[i].xyz);
}

float energia_luz(int i, vec3 p) {
	return energia_fisica(i, posicao_mundo(p));
}

vec3 iluminar_plex(vec3 base, vec3 p, vec3 normal, vec3 material_pixel, float volume_sprite, bool estrutura) {
	p = posicao_mundo(p);
	normal = normalize(vec3(vetor_mundo(normal.xy), normal.z));
	vec3 receptor = receptor_superficie(p, normal, estrutura);
	vec3 acumulada = vec3(0.0);
	vec3 reflexo = vec3(0.0);
	for (int i = 0; i < 32; i++) {
		if (i >= quantidade_luzes) { break; }
		vec3 delta = luzes_posicao[i].xyz - p;
		float alcance = luzes_posicao[i].w;
		if (energia_rede <= 0.001 || dot(delta,delta) > alcance*alcance) { continue; }
		float distancia = max(1.0, length(delta));
		vec3 l = delta / distancia;
		float energia = energia_fisica(i, receptor);
		if (energia <= 0.0001) { continue; }
		vec3 cor = mix(vec3(1.0), luzes_cor[i].rgb / max(0.01, max(luzes_cor[i].r, max(luzes_cor[i].g, luzes_cor[i].b))), influencia_cor);
		float difusa = max(0.0, dot(normal, l));
		float ndl=dot(normal,l);
		float envolvente=clamp((ndl+.45)/1.45,0.0,1.0);
		float borda=pow(1.0-max(0.0,dot(normal,vec3(0.0,.894427,.447214))),2.0)*max(0.0,-ndl)*.30;
		float difusa_sprite = .20+.80*envolvente+borda;
		difusa = mix(difusa, difusa_sprite, clamp(volume_sprite, 0.0, 1.0));
		float reflexao_chao = step(0.8, luzes_direcao[i].z) * step(0.0, l.z) * max(0.0, normal.z) * 0.45;
		difusa = max(difusa, reflexao_chao);
		acumulada += difusa * energia * cor;
		vec3 reflexao = l + vec3(vetor_mundo(vec2(0.0, 0.894427)), 0.447214);
		vec3 metade = reflexao / max(length(reflexao), 0.0001);
		reflexo += pow(max(0.0, dot(normal, metade)), 14.0) * material_pixel.g * energia * cor * 0.30;
	}
	for (int i = 0; i < 4; i++) {
		if (i >= quantidade_lanternas) { break; }
		float x = (float(i) + 0.5) / 4.0;
		vec4 cor = texture(lanternas, vec2(x, 5.0/6.0));
		if (cor.a <= 0.0001) { continue; }
		vec4 origem_lanterna = texture(lanternas, vec2(x, 1.0/6.0));
		vec3 delta = origem_lanterna.xyz - receptor;
		float d2 = dot(delta,delta);
		float alcance = origem_lanterna.w;
		if (d2 > alcance*alcance) { continue; }
		float distancia = max(1.0, sqrt(d2));
		vec3 l = delta/distancia;
		vec4 direcao = texture(lanternas, vec2(x, 0.5));
		float cone = smoothstep(direcao.w, min(0.995,direcao.w+0.14), dot(-l,direcao.xyz));
		if (cone <= 0.0001) { continue; }
		float queda = (1.0-smoothstep(alcance*.5,alcance,distancia))/(1.0+d2/(alcance*alcance));
		float energia = cor.a*queda*cone*visibilidade_luz(receptor,origem_lanterna.xyz);
		float difusa = max(0.0,dot(normal,l));
		difusa = mix(difusa,0.30+0.70*difusa,clamp(volume_sprite,0.0,1.0));
		acumulada += difusa*energia*cor.rgb;
	}
	acumulada += luz_da_cidade(receptor)*(1.0-interior_receptor(receptor,estrutura)*.94);
	float protecao = material_pixel.b;
	float fechada = interior_receptor(receptor, estrutura);
	float ambiente_local = mix(ambiente, max(0.024, ambiente * 0.42), fechada);
	float entrada_janela=texture(luz_janelas,(grade_fisica(receptor)+.5)/tamanho_grade).r;
	ambiente_local+=ambiente*entrada_janela*.72*fechada*(1.0-smoothstep(96.0,108.0,receptor.z));
	vec3 iluminacao_ambiente = cor_ambiente * ambiente_local;
	vec3 solar = vec3(0.0);
	if (energia_solar > 0.001) {
		float interior = interior_receptor(receptor, estrutura);
		float difusa_solar = max(0.0, dot(normal, normalize(direcao_solar)));
		float abertura_solar=interior<.5 ? 1.0 : sai_por_janela(receptor);
		if (abertura_solar>0.001 && difusa_solar > 0.0) {
			float visivel = visibilidade_luz(receptor, receptor + direcao_solar * 1200.0);
			solar = cor_solar * energia_solar * difusa_solar * visivel * abertura_solar;
		}
	}
	vec3 natural = clamp(iluminacao_ambiente + solar, vec3(0.002), vec3(1.0));
	vec3 margem = vec3(1.14) - natural;
	vec3 artificial = max(vec3(0.0), acumulada * material_pixel.r * 1.20);
	vec3 ganho = natural + margem * (vec3(1.0) - exp(-artificial / margem));
	ganho = mix(ganho, vec3(dot(ganho, vec3(0.2126, 0.7152, 0.0722))), protecao * 0.3);
	return clamp(base * ganho + min(vec3(0.08), reflexo) * (1.0 - protecao), vec3(0.0), vec3(1.0));
}

