vec4 amostrar_cena(sampler2DArray mapa, vec2 uv, vec2 tamanho_mapa) {
	vec2 pixel = clamp(uv * tamanho_mapa, vec2(0.0), tamanho_mapa - vec2(0.001));
	vec2 bloco = floor(pixel / 256.0);
	float indice = bloco.y * ceil(tamanho_mapa.x / 256.0) + bloco.x;
	return texture(mapa, vec3((pixel - bloco * 256.0) / 256.0, indice));
}
