class_name CabeloChapeuPlex
extends RefCounted

static var cache: Dictionary = {}
static var chapeus: Dictionary = {}

static func possui(uniforme: String) -> bool:
	if uniforme in ["nenhum", "automatico"]: return false
	if not chapeus.has(uniforme):
		var arquivo := "res://assets/aparencias/uniformes/"+uniforme+"/chapeu.png"
		chapeus[uniforme] = ResourceLoader.exists(arquivo) and CatalogoPlex.imagem(arquivo).get_used_rect().has_area()
	return bool(chapeus[uniforme])

static func imagem(arquivo: String, uniforme: String,cor:String="",modelo:String="") -> Image:
	return textura(arquivo,uniforme,cor,modelo).diffuse_texture.get_image()

static func textura(arquivo: String, uniforme: String, cor_cabelo: String = "", modelo: String = "") -> CanvasTexture:
	var chave := arquivo+":"+uniforme+":"+cor_cabelo+":"+modelo
	if cache.has(chave): return cache[chave]
	var original := CoresCabeloPlex.textura(arquivo,cor_cabelo,modelo)
	if not possui(uniforme): return original
	var cor := original.diffuse_texture.get_image().duplicate() as Image
	cor.convert(Image.FORMAT_RGBA8)
	var normal := original.normal_texture.get_image().duplicate() as Image if original.normal_texture!=null else Image.create_empty(cor.get_width(),cor.get_height(),false,Image.FORMAT_RGBA8)
	var material := original.specular_texture.get_image().duplicate() as Image if original.specular_texture!=null else Image.create_empty(cor.get_width(),cor.get_height(),false,Image.FORMAT_RGBA8)
	normal.convert(Image.FORMAT_RGBA8)
	material.convert(Image.FORMAT_RGBA8)
	if original.normal_texture==null: normal.fill(Color(.5,.5,1,1))
	var cabeca := CatalogoPlex.imagem("res://assets/personagens/humano/parado_cabeca.png")
	var chapeu := CatalogoPlex.imagem("res://assets/aparencias/uniformes/"+uniforme+"/chapeu.png")
	for d in 8:
		var aba := -1
		for y in 80:
			for x in 48:
				if chapeu.get_pixel(x,d*80+y).a>.8: aba=maxi(aba,y)
		for y in range(0,14):
			var esquerda := 48
			var direita := -1
			for x in 48:
				if cabeca.get_pixel(x,d*60+mini(y,22)).a>.2:
					esquerda = mini(esquerda,x)
					direita = maxi(direita,x)
			for x in 48:
				var fora := x<esquerda or x>direita
				var coberto := chapeu.get_pixel(x,d*80+y+20).a>.8 or y+20<=aba-2
				if not fora and not coberto: continue
				for f in floori(float(cor.get_width())/48.0):
					var ponto := Vector2i(f*48+x,d*68+y+8)
					if ponto.y>=cor.get_height(): continue
					cor.set_pixelv(ponto,Color.TRANSPARENT)
					normal.set_pixelv(ponto,Color.TRANSPARENT)
					material.set_pixelv(ponto,Color.TRANSPARENT)
	var resultado := CanvasTexture.new()
	resultado.diffuse_texture = ImageTexture.create_from_image(cor)
	resultado.normal_texture = ImageTexture.create_from_image(normal)
	resultado.specular_texture = ImageTexture.create_from_image(material)
	resultado.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if cache.size()>=48: cache.erase(cache.keys()[0])
	cache[chave] = resultado
	return resultado


