class_name CabeloChapeuPlex
extends RefCounted

static var cache: Dictionary = {}

static func imagem(arquivo: String, uniforme: String) -> Image:
	return textura(arquivo,uniforme).diffuse_texture.get_image()

static func textura(arquivo: String, uniforme: String) -> CanvasTexture:
	var chave := arquivo+":"+uniforme
	if cache.has(chave): return cache[chave]
	var original := CatalogoPlex.textura_iluminada(arquivo) as CanvasTexture
	if uniforme=="nenhum": return original
	var cor := original.diffuse_texture.get_image().duplicate() as Image
	cor.convert(Image.FORMAT_RGBA8)
	var normal := original.normal_texture.get_image().duplicate() as Image
	var material := original.specular_texture.get_image().duplicate() as Image
	normal.convert(Image.FORMAT_RGBA8)
	material.convert(Image.FORMAT_RGBA8)
	var cabeca := CatalogoPlex.imagem("res://assets/personagens/humano/parado_cabeca.png")
	var chapeu := CatalogoPlex.imagem("res://assets/aparencias/uniformes/"+uniforme+"/chapeu.png")
	for d in 8:
		for y in range(0,14):
			var esquerda := 48
			var direita := -1
			for x in 48:
				if cabeca.get_pixel(x,d*60+mini(y,22)).a>.2:
					esquerda = mini(esquerda,x)
					direita = maxi(direita,x)
			for x in 48:
				var fora := x<esquerda or x>direita
				var coberto := chapeu.get_pixel(x,d*80+y+20).a>.8
				if not fora and not coberto: continue
				for f in cor.get_width()/48:
					var ponto := Vector2i(f*48+x,d*68+y+8)
					cor.set_pixelv(ponto,Color.TRANSPARENT)
					normal.set_pixelv(ponto,Color.TRANSPARENT)
					material.set_pixelv(ponto,Color.TRANSPARENT)
	var resultado := CanvasTexture.new()
	resultado.diffuse_texture = ImageTexture.create_from_image(cor)
	resultado.normal_texture = ImageTexture.create_from_image(normal)
	resultado.specular_texture = ImageTexture.create_from_image(material)
	resultado.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cache[chave] = resultado
	return resultado
