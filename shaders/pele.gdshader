shader_type canvas_item;
uniform vec3 pele_origem[64];
uniform vec3 pele_destino[64];
uniform int pele_total = 0;

void fragment() {
	for (int i = 0; i < 64; i++) {
		if (i >= pele_total) { break; }
		if (distance(COLOR.rgb, pele_origem[i]) < 0.003) { COLOR.rgb = pele_destino[i]; break; }
	}
}
