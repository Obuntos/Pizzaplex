class_name RetratoEquipePlex
extends RefCounted

static var cache: Dictionary = {}

static func textura(imagem: Image) -> Texture2D:
	var regiao := imagem.get_used_rect()
	if regiao.has_area():
		regiao = regiao.grow(2).intersection(Rect2i(Vector2i.ZERO,imagem.get_size()))
		imagem = imagem.get_region(regiao)
	return ImageTexture.create_from_image(imagem)

static func modelo(id: String, direcao: int = 0, roupa: String = "nenhum", cabelo: String = "nenhum") -> Texture2D:
	CatalogoPlex.carregar()
	var chave := id+":"+str(direcao)+":"+roupa+":"+cabelo
	if cache.has(chave): return cache[chave]
	if id in ["faxineiro","entregador"]:
		return modelo("humano",direcao,id,"curto")
	var d: Dictionary = CatalogoPlex.personagens.get(id,{})
	if d.is_empty(): return null
	var imagem := Image.create_empty(48,80,false,Image.FORMAT_RGBA8)
	if d.layered:
		var pasta := "res://assets/personagens/"+id+"/"
		if cabelo!="nenhum": imagem.blend_rect(CabeloChapeuPlex.imagem("res://assets/aparencias/cabelos/"+cabelo+"/parado_tras.png",roupa),Rect2i(0,direcao*68,48,68),Vector2i(0,12))
		for arquivo in ["parado_cabeca.png","neutro_olhos.png","neutro_boca.png"]:
			imagem.blend_rect(CatalogoPlex.imagem(pasta+arquivo),Rect2i(0,direcao*int(d.height),int(d.width),int(d.height)),Vector2i(0,20))
		if cabelo!="nenhum": imagem.blend_rect(CabeloChapeuPlex.imagem("res://assets/aparencias/cabelos/"+cabelo+"/parado_frente.png",roupa),Rect2i(0,direcao*68,48,68),Vector2i(0,12))
		if roupa!="nenhum": imagem.blend_rect(CatalogoPlex.imagem("res://assets/aparencias/uniformes/"+roupa+"/chapeu.png"),Rect2i(0,direcao*80,48,80),Vector2i.ZERO)
	else:
		var arquivo := "res://assets/interface/cabecas/"+("endo_01" if id=="endo" else id)+"/"+str(posmod(direcao,8))+".png"
		if ResourceLoader.exists(arquivo):
			cache[chave]=CatalogoPlex.textura(arquivo)
			return cache[chave]
		var fonte := "res://assets/personagens/"+id+"/parado.png"
		if not ResourceLoader.exists(fonte): return null
		imagem = CatalogoPlex.imagem(fonte).get_region(Rect2i(0,direcao*int(d.height),int(d.width),int(d.height*.55)))
	cache[chave] = textura(imagem)
	return cache[chave]

static func criar(ator: PersonagemPlex) -> Texture2D:
	return modelo(ator.modelo,0,AparenciaPlex.roupa(ator),AparenciaPlex.cabelo(ator))

static func icone(id: String) -> Texture2D:
	var fonte := modelo(id)
	if fonte==null: return null
	var imagem := fonte.get_image()
	var tamanho := Vector2(imagem.get_size())
	var fator := 28.0/maxf(tamanho.x,tamanho.y)
	imagem.resize(maxi(1,roundi(tamanho.x*fator)),maxi(1,roundi(tamanho.y*fator)),Image.INTERPOLATE_NEAREST)
	var icone := Image.create_empty(28,28,false,Image.FORMAT_RGBA8)
	icone.blit_rect(imagem,Rect2i(Vector2i.ZERO,imagem.get_size()),(Vector2i(28,28)-imagem.get_size())/2)
	return ImageTexture.create_from_image(icone)
