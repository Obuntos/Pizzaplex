uniform vec2 tamanho_grade = vec2(32.0, 24.0);
uniform vec2 centro_grade = vec2(128.0, 864.0);
uniform vec4 eixos_visao = vec4(1.0, 0.0, 0.0, 1.0);
uniform int quantidade_luzes = 0;
uniform vec4 luzes_posicao[32];
uniform vec4 luzes_cor[32];
uniform vec4 luzes_direcao[32];
uniform sampler2D bloqueios : filter_nearest, repeat_disable;
uniform sampler2D passagens : filter_nearest, repeat_disable;
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

vec3 local_porta(vec3 ponto, vec4 portal) {
	vec2 grade = grade_fisica(ponto) - portal.xy;
	vec2 frente = vec2(0.0, 1.0);
	if (portal.z > 2.5) { frente = vec2(1.0, 0.0); }
	else if (portal.z > 1.5) { frente = vec2(0.0, -1.0); }
	else if (portal.z > 0.5) { frente = vec2(-1.0, 0.0); }
	return vec3(dot(grade, vec2(frente.y, -frente.x)), dot(grade, frente), ponto.z);
}

bool trecho_bloqueado(vec2 celula, vec3 p, vec3 luz, float entrada, float saida) {
	if (any(lessThan(celula, vec2(0.0))) || any(greaterThanEqual(celula, tamanho_grade))) { return false; }
	vec4 portal = texture(passagens, (celula + 0.5) / tamanho_grade);
	if (abs(portal.a) < 0.5) {
		float z = min(mix(p.z, luz.z, entrada), mix(p.z, luz.z, saida));
		return altura_bloqueio(celula) > z + 1.0;
	}
	vec3 a = local_porta(p, portal);
	vec3 b = local_porta(luz, portal);
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
	for (int trecho = 0; trecho < 80; trecho++) {
		float saida = min(1.0, min(proximos.x, proximos.y));
		if (trecho_bloqueado(celula, p, origem_luz, entrada, saida)) { return 0.0; }
		if (saida >= 1.0) { return 1.0; }
		if (abs(proximos.x - proximos.y) < 0.000001) {
			if (trecho_bloqueado(celula + vec2(passo.x, 0.0), p, origem_luz, max(0.0, saida - 0.00001), min(1.0, saida + 0.00001)) || trecho_bloqueado(celula + vec2(0.0, passo.y), p, origem_luz, max(0.0, saida - 0.00001), min(1.0, saida + 0.00001))) { return 0.0; }
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

float energia_fisica(int i, vec3 p) {
	vec3 delta = luzes_posicao[i].xyz - p;
	float distancia = max(1.0, length(delta));
	float alcance = luzes_posicao[i].w;
	if (distancia > alcance) { return 0.0; }
	vec3 l = delta / distancia;
	float cone = smoothstep(luzes_direcao[i].w, min(0.99, luzes_direcao[i].w + 0.3), dot(-l, luzes_direcao[i].xyz));
	float queda = (1.0 - smoothstep(alcance * 0.8, alcance, distancia)) / (1.0 + distancia * distancia / (alcance * alcance));
	return luzes_cor[i].a * queda * cone * visibilidade_luz(p, luzes_posicao[i].xyz);
}

float energia_luz(int i, vec3 p) {
	return energia_fisica(i, posicao_mundo(p));
}

vec3 iluminar_plex(vec3 base, vec3 p, vec3 normal, vec3 material_pixel, float volume_sprite, bool estrutura) {
	p = posicao_mundo(p);
	normal = normalize(vec3(vetor_mundo(normal.xy), normal.z));
	vec3 acumulada = vec3(0.0);
	vec3 reflexo = vec3(0.0);
	for (int i = 0; i < 32; i++) {
		if (i >= quantidade_luzes) { break; }
		vec3 delta = luzes_posicao[i].xyz - p;
		float distancia = max(1.0, length(delta));
		float alcance = luzes_posicao[i].w;
		if (distancia > alcance) { continue; }
		vec3 l = delta / distancia;
		float energia = energia_fisica(i, p + normal * 2.0);
		vec3 cor = mix(vec3(1.0), luzes_cor[i].rgb / max(0.01, max(luzes_cor[i].r, max(luzes_cor[i].g, luzes_cor[i].b))), influencia_cor);
		float difusa = max(0.0, dot(normal, l));
		float luz_subindo = step(0.8, luzes_direcao[i].z) * max(0.0, -l.z);
		float envolvimento = max(0.0, 0.20 - normal.z * 0.30);
		difusa = max(difusa, luz_subindo * envolvimento * volume_sprite);
		float arandela = step(-0.85, luzes_direcao[i].z) * step(luzes_direcao[i].z, 0.0);
		difusa = max(difusa, (1.0 - step(0.8, luzes_direcao[i].z)) * (0.08 + arandela * 0.10) * volume_sprite);
		acumulada += difusa * energia * cor;
		vec3 reflexao = l + vec3(vetor_mundo(vec2(0.0, 0.894427)), 0.447214);
		vec3 metade = reflexao / max(length(reflexao), 0.0001);
		reflexo += pow(max(0.0, dot(normal, metade)), 14.0) * material_pixel.g * energia * cor * 0.30;
	}
	float protecao = material_pixel.b;
	vec2 celula = celula_luz(p);
	if (estrutura) { celula = clamp(celula, vec2(0.0), (tamanho_grade - vec2(1.0))); }
	float fechada = 0.0;
	if (all(greaterThanEqual(celula, vec2(0.0))) && all(lessThan(celula, tamanho_grade))) {
		vec4 recinto = texture(bloqueios, (celula + 0.5) / tamanho_grade);
		fechada = estrutura ? recinto.b : recinto.g;
	}
	float ambiente_local = mix(ambiente, max(0.006, ambiente * 0.32), fechada);
	vec3 iluminacao_ambiente = cor_ambiente * ambiente_local;
	vec3 solar = vec3(0.0);
	if (energia_solar > 0.001) {
		vec3 receptor = p + normal * 2.0;
		vec2 celula_sol = celula_luz(receptor);
		float interior = 0.0;
		if (all(greaterThanEqual(celula_sol, vec2(0.0))) && all(lessThan(celula_sol, tamanho_grade))) {
			interior = texture(bloqueios, (celula_sol + 0.5) / tamanho_grade).g;
		}
		float difusa_solar = max(0.0, dot(normal, normalize(direcao_solar)));
		if (interior < 0.5 && difusa_solar > 0.0) {
			float visivel = visibilidade_luz(receptor, receptor + direcao_solar * 1200.0);
			solar = cor_solar * energia_solar * difusa_solar * visivel;
		}
	}
	vec3 ganho = clamp(iluminacao_ambiente + solar + acumulada * material_pixel.r * 0.95, vec3(0.002), vec3(1.14));
	ganho = mix(ganho, vec3(dot(ganho, vec3(0.2126, 0.7152, 0.0722))), protecao * 0.3);
	return clamp(base * ganho + min(vec3(0.08), reflexo) * (1.0 - protecao), vec3(0.0), vec3(1.0));
}
