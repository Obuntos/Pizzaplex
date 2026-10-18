class_name CatalogoPlex
extends RefCounted

static var objetos: Dictionary = {}
static var personagens: Dictionary = {}
static var texturas: Dictionary = {}
static var imagens: Dictionary = {}
const DIRECOES = ["frente", "direita", "costas", "esquerda"]

static func carregar() -> void:
	if not objetos.is_empty():
		return
	objetos = JSON.parse_string(FileAccess.get_file_as_string("res://dados/objetos.json"))
	objetos.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/assets_salas.json")), true)
	personagens = JSON.parse_string(FileAccess.get_file_as_string("res://dados/personagens.json"))

static func textura(caminho: String) -> Texture2D:
	if not texturas.has(caminho):
		texturas[caminho] = load(caminho)
	return texturas[caminho]

static func textura_iluminada(caminho: String) -> Texture2D:
	var chave := "iluminada:" + caminho
	if not texturas.has(chave):
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = textura(caminho)
		var mapa := caminho.replace("res://assets/deterioracao/","res://assets/iluminacao/deterioracao/").replace("res://assets/personagens/", "res://assets/iluminacao/personagens/").replace("res://assets/modelos/","res://assets/iluminacao/modelos/").replace("res://assets/aparencias/","res://assets/iluminacao/aparencias/")
		if not ResourceLoader.exists(mapa) and caminho.begins_with("res://assets/aparencias/uniformes/"):
			var relativo := caminho.trim_prefix("res://assets/aparencias/uniformes/")
			mapa = "res://assets/iluminacao/personagens/"+relativo.substr(relativo.find("/")+1)
		if ResourceLoader.exists(mapa):
			canvas.normal_texture = textura(mapa)
			canvas.specular_texture = textura(mapa.replace(".png", "_material.png"))
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texturas[chave] = canvas
	return texturas[chave]

static func imagem(caminho: String) -> Image:
	if not imagens.has(caminho):
		imagens[caminho] = textura(caminho).get_image()
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
			var base: int = maxi(base_coluna(original, x), base_coluna(referencia, x))
			for y in range(0, maxi(0, base - altura)):
				corte.set_pixel(x, y, Color.TRANSPARENT)
		texturas[chave] = ImageTexture.create_from_image(corte)
	return texturas[chave]

static func sprite(tipo: String, rotacao: int, estado: String = "", nivel: int = 4, mascara: int = 0) -> Texture2D:
	carregar()
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
	var base: String = objetos[tipo].pasta + "/sprites/"
	var direcao: String = DIRECOES[posmod(rotacao, 4)]
	var caminho: String = base + direcao + ".png"
	if tipo == "parede":
		if nivel == 4:
			caminho = base + "conexoes/" + str(mascara) + ".png"
		else:
			caminho = base + "vistas/" + str(nivel) + "/" + direcao + ".png"
	elif tipo in ["porta", "porta_dupla"]:
		if estado == "aberta":
			caminho = base + "aberta/" + direcao + ".png"
			return porta_recortada(caminho, base + direcao + ".png", nivel)
		elif nivel < 4:
			caminho = base + "vistas/" + str(nivel) + "/" + direcao + ".png"
	elif tipo == "caixa" and estado != "":
		caminho = base + estado + "/" + direcao + ".png"
	return textura(caminho)

static func superficies(tipo: String, rotacao: int, conexoes: int = 0, ligada: bool = false) -> Array[Texture2D]:
	var base: String = objetos[tipo].pasta + "/sprites/"
	var caminho: String = base + DIRECOES[rotacao] + ".png"
	if tipo == "escada" and ligada:
		caminho = base + "palco/" + str(conexoes) + "/" + DIRECOES[rotacao] + ".png"
	elif tipo == "escada" and conexoes != 0:
		caminho = base + "conexoes/" + str(conexoes) + "/" + DIRECOES[rotacao] + ".png"
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

static func camadas_suporte(rotacao: int) -> Array[Texture2D]:
	var chave := "suporte:" + str(rotacao)
	if not texturas.has(chave):
		var original := sprite("suporte", rotacao).get_image()
		var base := original.duplicate() as Image
		var coluna := original.duplicate() as Image
		base.convert(Image.FORMAT_RGBA8)
		coluna.convert(Image.FORMAT_RGBA8)
		var frente := Vector2(GradePlex.frente(rotacao))
		var lado := Vector2(frente.y, -frente.x)
		var pontos: PackedVector2Array = []
		for altura in [0.0, 2.0]:
			for u in [-0.265, 0.265]:
				for v in [-0.18, 0.18]:
					pontos.append(Vector2(96, 144) + GradePlex.projetar_local(lado * u + frente * v, altura))
		var poligono := Geometry2D.convex_hull(pontos)
		for x in original.get_width():
			for y in original.get_height():
				if original.get_pixel(x, y).a == 0.0:
					continue
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poligono):
					coluna.set_pixel(x, y, Color.TRANSPARENT)
				else:
					base.set_pixel(x, y, Color.TRANSPARENT)
		texturas[chave] = ImageTexture.create_from_image(base)
		texturas[chave + ":coluna"] = ImageTexture.create_from_image(coluna)
	return [texturas[chave], texturas[chave + ":coluna"]]

static func dimensoes(tipo: String, rotacao: int) -> Vector2i:
	carregar()
	var item: Dictionary = objetos[tipo]
	if rotacao % 2 == 1:
		return Vector2i(item.profundidade, item.largura)
	return Vector2i(item.largura, item.profundidade)
