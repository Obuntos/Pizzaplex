class_name CatalogoPlex
extends RefCounted

static var objetos: Dictionary = {}
static var personagens: Dictionary = {}
static var texturas: Dictionary = {}
static var imagens: Dictionary = {}
const PORTAS = ["porta", "porta_dupla", "porta_principal", "porta_servico"]
const DIRECOES = ["frente", "direita", "costas", "esquerda"]

static func carregar() -> void:
	if not objetos.is_empty():
		return
	objetos = JSON.parse_string(FileAccess.get_file_as_string("res://dados/objetos.json"))
	objetos.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/assets_salas.json")), true)
	objetos.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/assets_fachada.json")), true)
	objetos.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/assets_antigos.json")), true)
	objetos.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/assets_cenario.json")),true)
	objetos.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/assets_cidade.json")),true)
	objetos.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/assets_festa.json")),true)
	objetos.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/assets_oficina.json")),true)
	objetos.estante_compacta=objetos.estante.duplicate(true)
	objetos.estante_compacta.merge({"nome":"Estante compacta","largura":1,"familia":"estante","oculto":true},true)
	UtilitariosVisuaisPlex.catalogar(objetos)
	PalcosMadeiraPlex.catalogar(objetos)
	LuminariasPlex.catalogar(objetos)
	ConfortoPlex.catalogar(objetos)
	BalanceamentoPlex.catalogar(objetos)
	var ponto: Dictionary=objetos.ponto_recebimento.duplicate(true)
	ponto.nome="Ponto de recebimento";ponto.oculto=true;ponto.preco=25;ponto.conforto=0;ponto.altura=.12;ponto.transitavel=true;ponto.apoio=false;objetos.suporte=ponto
	objetos.area_montagem_atracao=ponto.duplicate(true)
	objetos.area_montagem_atracao.merge({"nome":"Montagem de animatrônico","preco":0,"sobreposto":true,"temporario":true},true)
	DecoracaoEstudoPlex.catalogar(objetos)
	AssetsSistemasPlex.catalogar(objetos)
	AmbientesAssetsPlex.catalogar(objetos)
	objetos.terminal_ibm.nome="IBM"
	EmbalagensMoveisPlex.catalogar(objetos)
	personagens = JSON.parse_string(FileAccess.get_file_as_string("res://dados/personagens.json"))
	AtracoesCatalogoPlex.registrar(personagens)
	ProfissoesBairroPlex.registrar(personagens)
	personagens.bonnie_visitante={"width":48,"height":60,"pivot":[24,55],"scale":[1.375,1.375],"frames":12,"directions":8,"layered":false,"oculto":true}

static func base(tipo: String) -> String:
	return str(objetos.get(tipo, {}).get("familia", tipo))

static func textura(caminho: String) -> Texture2D:
	if not texturas.has(caminho):
		if ResourceLoader.exists(caminho):texturas[caminho] = load(caminho)
		else:texturas[caminho]=ImageTexture.create_from_image(Image.create_empty(48,60,false,Image.FORMAT_RGBA8))
	return texturas[caminho]

static func textura_iluminada(caminho: String) -> Texture2D:
	var chave := "iluminada:" + caminho
	if not texturas.has(chave):
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = textura(caminho)
		var mapa := caminho.replace("res://assets/personagens/", "res://assets/iluminacao/personagens/").replace("res://assets/aparencias/","res://assets/iluminacao/aparencias/")
		if caminho.begins_with("res://assets/sistemas/"):mapa=caminho.replace("res://assets/sistemas/","res://assets/iluminacao/sistemas/")
		if caminho.begins_with("res://assets/poses_humanas/"): mapa = TexturasPosesPlex.mapa(caminho)
		if not ResourceLoader.exists(mapa) and caminho.begins_with("res://assets/aparencias/uniformes/"):
			var relativo := caminho.trim_prefix("res://assets/aparencias/uniformes/")
			mapa = "res://assets/iluminacao/personagens/"+relativo.substr(relativo.find("/")+1)
		if ResourceLoader.exists(mapa):
			canvas.normal_texture = textura(mapa)
			canvas.specular_texture = textura(TexturasPosesPlex.mapa(caminho,true) if caminho.begins_with("res://assets/poses_humanas/") else mapa.replace(".png", "_material.png"))
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texturas[chave] = canvas
	return texturas[chave]

static func imagem(caminho: String) -> Image:
	if not imagens.has(caminho):
		var fonte:=Image.new()
		if not caminho.ends_with(".png") or not FileAccess.file_exists(caminho) or fonte.load_png_from_buffer(FileAccess.get_file_as_bytes(caminho))!=OK: fonte=textura(caminho).get_image()
		imagens[caminho]=fonte
	return imagens[caminho]

static func base_coluna(imagem_base: Image, x: int) -> int:
	for y in range(imagem_base.get_height() - 1, -1, -1):
		if imagem_base.get_pixel(x, y).a > 0.0:
			return y
	return -1

static func porta_recortada(caminho: String, fechado: String, nivel: int) -> Texture2D:
	if nivel >= 4:
		return textura(caminho)
	var chave := caminho + ":nivel:" + str(nivel)
	if not texturas.has(chave):
		var original := imagem(caminho)
		var referencia := imagem(fechado)
		var corte := original.duplicate() as Image
		corte.convert(Image.FORMAT_RGBA8)
		var altura: int = [6, 22, 52][clampi(nivel - 1, 0, 2)]
		for x in corte.get_width():
			var base_local: int = maxi(base_coluna(original, x), base_coluna(referencia, x))
			for y in range(0, maxi(0, base_local - altura)):
				corte.set_pixel(x, y, Color.TRANSPARENT)
		texturas[chave] = ImageTexture.create_from_image(corte)
	return texturas[chave]

static func sprite(tipo: String, rotacao: int, estado: String = "", nivel: int = 4, mascara: int = 0) -> Texture2D:
	carregar()
	if AmbientesAssetsPlex.eh(tipo):return AmbientesAssetsPlex.obter(tipo,rotacao,estado).textura
	if AssetsSistemasPlex.eh(tipo):return AssetsSistemasPlex.obter(tipo,rotacao,estado).textura
	if DecoracaoEstudoPlex.eh(tipo):return DecoracaoEstudoPlex.previa(tipo,rotacao,estado)
	carregar()
	if CaixasVisuaisPlex.eh(tipo): return CaixasVisuaisPlex.obter(tipo,rotacao,estado).textura
	if tipo in ["ponto_recebimento","suporte","area_montagem_atracao","saco_lixo"]: return UtilitariosVisuaisPlex.obter(tipo,rotacao).textura
	if LuminariasPlex.eh(tipo): return ModeloLuminariaPlex.textura(tipo,rotacao)
	if tipo.begins_with("janela"): return FachadaPlex.previa_janela(tipo,rotacao,estado,nivel)
	if tipo.begins_with("festa_"): return GeometriaPlex.obter(tipo,rotacao,4,0,false,estado).textura
	if objetos.get(tipo,{}).get("cenario_parede",false): return GeometriaPlex.obter(tipo,rotacao,nivel,mascara,false,estado).textura
	if PalcosMadeiraPlex.eh(tipo): return PalcosMadeiraPlex.previa(estado,mascara)
	if tipo == "parede_fachada": return sprite("parede",rotacao,"",nivel,mascara)
	if ItensPlex.personalizado(tipo): return ItensPlex.sprite(tipo,rotacao,estado)
	if objetos[tipo].has("estados"):
		var atual: String = estado if objetos[tipo].estados.has(estado) else objetos[tipo].estado_padrao
		return textura(objetos[tipo].pasta + "/sprites/" + atual + "/" + DIRECOES[posmod(rotacao, 4)] + ".png")
	if tipo in ["palco", "escada"]:
		var chave := "previa:" + tipo + ":" + str(rotacao) + ":" + str(mascara)
		if not texturas.has(chave):
			var volume := GeometriaPlex.obter(tipo, rotacao, 4, mascara)
			var completa := Image.create_empty(192, 192, false, Image.FORMAT_RGBA8)
			var recorte: Image = volume.textura.get_image()
			completa.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), Vector2i(int(volume.origin[0]) + 96, int(volume.origin[1]) + 144))
			texturas[chave] = ImageTexture.create_from_image(completa)
		return texturas[chave]
	var base_local: String = objetos[tipo].pasta + "/sprites/"
	var direcao: String = DIRECOES[posmod(rotacao, 4)]
	var caminho: String = base_local + direcao + ".png"
	if tipo == "parede":
		if nivel == 4:
			caminho = base_local + "conexoes/" + str(mascara) + ".png"
		else:
			caminho = base_local + "vistas/" + str(nivel) + "/" + direcao + ".png"
	elif tipo in ["porta", "porta_dupla"]:
		if estado == "aberta":
			caminho = base_local + "aberta/" + direcao + ".png"
			return porta_recortada(caminho, base_local + direcao + ".png", nivel)
		elif nivel < 4:
			caminho = base_local + "vistas/" + str(nivel) + "/" + direcao + ".png"
	elif tipo == "caixa" and estado != "":
		caminho = base_local + estado + "/" + direcao + ".png"
	return textura(caminho)

static func superficies(tipo: String, rotacao: int, conexoes: int = 0, ligada: bool = false) -> Array[Texture2D]:
	var base_local: String = objetos[tipo].pasta + "/sprites/"
	var caminho: String = base_local + DIRECOES[rotacao] + ".png"
	if tipo == "escada" and ligada:
		caminho = base_local + "palco/" + str(conexoes) + "/" + DIRECOES[rotacao] + ".png"
	elif tipo == "escada" and conexoes != 0:
		caminho = base_local + "conexoes/" + str(conexoes) + "/" + DIRECOES[rotacao] + ".png"
	var chave: String = caminho + ":superficie:" + str(conexoes)
	if not texturas.has(chave):
		var original := imagem(caminho)
		var topo := original.duplicate() as Image
		var lados := original.duplicate() as Image
		topo.convert(Image.FORMAT_RGBA8)
		lados.convert(Image.FORMAT_RGBA8)
		var faces: Array = []
		var frente := Vector2(GradePlex.frente(rotacao))
		var lado := Vector2(frente.y, -frente.x)
		var minimo: float = -0.5 if tipo == "palco" or (conexoes & 1) != 0 else -0.4
		var maximo: float = 0.5 if tipo == "palco" or (conexoes & 2) != 0 else 0.4
		var quantidade: int = 1 if tipo == "palco" else 3
		for nivel in range(1, quantidade + 1):
			var antes: float = 0.5 - (nivel - 1) / float(quantidade)
			var depois: float = 0.5 - nivel / float(quantidade)
			var altura: float = 18.0 if tipo == "palco" else nivel * 6.0
			var poligono: PackedVector2Array = []
			for local in [lado * minimo + frente * antes, lado * maximo + frente * antes, lado * maximo + frente * depois, lado * minimo + frente * depois]:
				poligono.append(Vector2(96, 144) + GradePlex.projetar_local(local, altura))
			faces.append(poligono)
		for x in original.get_width():
			for y in original.get_height():
				if original.get_pixel(x, y).a == 0.0:
					continue
				var ponto := Vector2(x + 0.5, y + 0.5)
				var em_cima: bool = false
				for poligono in faces:
					if Geometry2D.is_point_in_polygon(ponto, poligono):
						em_cima = true
						break
					for i in poligono.size():
						var a: Vector2 = poligono[i]
						var b: Vector2 = poligono[(i + 1) % poligono.size()]
						var segmento := b - a
						var t := clampf((ponto - a).dot(segmento) / segmento.length_squared(), 0.0, 1.0)
						if ponto.distance_squared_to(a + segmento * t) <= 0.65 * 0.65:
							em_cima = true
							break
					if em_cima:
						break
				if em_cima:
					lados.set_pixel(x, y, Color.TRANSPARENT)
				else:
					topo.set_pixel(x, y, Color.TRANSPARENT)
					if tipo == "palco":
						var face: int = 0 if x >= 96 else 1
						if (conexoes & (1 << face)) != 0:
							lados.set_pixel(x, y, Color.TRANSPARENT)
		texturas[chave] = ImageTexture.create_from_image(topo)
		texturas[chave + ":lados"] = ImageTexture.create_from_image(lados)
	return [texturas[chave], texturas[chave + ":lados"]]

static func dimensoes(tipo: String, rotacao: int) -> Vector2i:
	carregar()
	var item: Dictionary = objetos[tipo]
	if rotacao % 2 == 1:
		return Vector2i(item.profundidade, item.largura)
	return Vector2i(item.largura, item.profundidade)



static func atlas_vazio() -> AtlasTexture:
	var atlas:=AtlasTexture.new()
	var chave:="atlas_transparente_inicial"
	if not texturas.has(chave):texturas[chave]=ImageTexture.create_from_image(Image.create_empty(1,1,false,Image.FORMAT_RGBA8))
	atlas.atlas=texturas[chave];atlas.region=Rect2(0,0,1,1)
	return atlas
