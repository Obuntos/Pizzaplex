class_name ItensPlex
extends RefCounted

static var dados: Dictionary = {}
static var imagens: Dictionary = {}
static var alturas: Dictionary = {}

static func carregar() -> void:
	if dados.is_empty(): dados = JSON.parse_string(FileAccess.get_file_as_string("res://dados/manuseio.json"))

static func escala(tipo: String) -> float:
	carregar()
	return float(dados.escalas.get(tipo,1.0))

static func altura(tipo: String) -> float:
	if not alturas.has(tipo):
		var volume := GeometriaPlex.obter(tipo,0)
		var valor := 0.0
		for p in volume.pontos: valor = maxf(valor,(p.z-p.y*2.0)/3.0)
		alturas[tipo] = maxf(1.0,valor)
	return alturas[tipo]

static func categoria(tipo: String) -> String:
	carregar()
	return dados.categorias.get(tipo,"balde")

static func personalizado(tipo: String) -> bool:
	carregar()
	return tipo == "ponto_recebimento" or dados.escalas.has(tipo) or dados.caixas.has(tipo)

static func ajustar(volume: Dictionary, tipo: String) -> void:
	var fator := escala(tipo)
	var pontos: PackedVector3Array = volume.pontos
	var cores: PackedColorArray = volume.cores
	for i in pontos.size():
		var p := pontos[i]
		if dados.caixas.has(tipo) and p.x >= 0 and p.x <= 5 and p.y >= -7 and p.y <= -2:
			cores[i] = Color(dados.caixas[tipo]).darkened(.18 if int(p.x+p.y)%3==0 else 0.0)
		if tipo == "ponto_recebimento":
			var altura_marca := (p.z-2.0*p.y)/3.0
			var u := p.x/64.0+(p.y+altura_marca)/32.0
			var v := (p.y+altura_marca)/32.0-p.x/64.0
			if int(volume.get("rotacao_marca",0))%2 == 0: u *= .5
			else: v *= .5
			p = Vector3(roundf((u-v)*32.0),roundf((u+v)*16.0-altura_marca),(u+v)*32.0+altura_marca)
		var y := roundf(p.y*fator)
		var altura_local := (p.z-p.y*2.0)/3.0*fator
		pontos[i] = Vector3(roundf(p.x*fator),y,y*2.0+altura_local*3.0)
	volume.pontos = pontos
	volume.cores = cores

static func compor(componentes: Array) -> Dictionary:
	var imagem := Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	var normais := Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	var profundidades := PackedFloat32Array()
	profundidades.resize(192*192)
	profundidades.fill(-10000)
	for componente in componentes:
		var v: Dictionary = componente.volume
		var p: Vector3 = componente.get("posicao",Vector3.ZERO)
		var tela := GradePlex.projetar_vetor(Vector2(p.x,p.y),p.z)
		var base := GradePlex.projetar_vetor(Vector2(p.x,p.y)).y*2.0+p.z+2.0*(roundf(tela.y)-tela.y)
		for i in v.pontos.size():
			var q: Vector3 = v.pontos[i]
			var x := roundi(q.x+tela.x)+96
			var y := roundi(q.y+tela.y)+144
			if x<0 or x>=192 or y<0 or y>=192: continue
			var indice := y*192+x
			var d: float = q.z+base
			if d<profundidades[indice]-.05: continue
			profundidades[indice] = maxf(d,profundidades[indice])
			imagem.set_pixel(x,y,v.cores[i])
			normais.set_pixel(x,y,v.superficies[i] if v.superficies.size()==v.pontos.size() else Color(.5,.8,.8,.125))
	return {"textura":ImageTexture.create_from_image(imagem),"normais":ImageTexture.create_from_image(normais),"profundidade":ImageTexture.create_from_image(Image.create_from_data(192,192,false,Image.FORMAT_RF,profundidades.to_byte_array()))}

static func sprite(tipo: String, rotacao: int, estado: String) -> Texture2D:
	var chave := str([tipo,rotacao,estado])
	if not imagens.has(chave): imagens[chave] = GeometriaPlex.obter(tipo,rotacao,4,0,false,estado).textura
	return imagens[chave]

