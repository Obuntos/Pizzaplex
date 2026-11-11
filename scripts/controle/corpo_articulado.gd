class_name CorpoArticuladoPlex
extends RefCounted

static var cache: Dictionary = {}
static var ordem: Array[String] = []
static var dados: Dictionary = {}
const PIVO := Vector2(56, 83)

static func carregar() -> void:
	if dados.is_empty(): dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/corpos_transportados.json"))

static func aceita(a: PersonagemPlex) -> bool:
	carregar()
	return dados.has(a.modelo)

static func roupa(a: PersonagemPlex) -> Image:
	var pasta:=RoupasVisitantesPlex.pasta(a)
	if not pasta.is_empty(): return CatalogoPlex.imagem(pasta+"/parado_corpo.png").get_region(Rect2i(0,0,48,60))
	var uniforme:=AparenciaPlex.roupa(a)
	PosesHumanasPlex.carregar()
	if uniforme=="nenhum" or not PosesHumanasPlex.dados.uniformes.has(uniforme):
		return CatalogoPlex.imagem("res://assets/personagens/"+a.modelo+"/parado_corpo.png").get_region(Rect2i(0,0,48,60))
	var fonte:=Image.create_empty(48,60,false,Image.FORMAT_RGBA8)
	for parte in ["corpo","bracos","maos"]:
		var imagem:=CatalogoPlex.imagem("res://assets/poses_humanas/"+uniforme+"/"+a.modelo+"/parado_"+parte+".png")
		fonte.blend_rect(imagem,Rect2i(16,12,48,60),Vector2i.ZERO)
	return fonte

static func amostrar(fonte: Image, ponto: Vector2i, amostras: Dictionary) -> Color:
	if amostras.has(ponto): return amostras[ponto]
	var cor:=fonte.get_pixelv(ponto)
	if cor.a<.1:
		var distancia:=INF
		for y in range(maxi(0,ponto.y-3),mini(60,ponto.y+4)):
			for x in range(maxi(0,ponto.x-3),mini(48,ponto.x+4)):
				var q:=Vector2i(x,y)
				var valor:=fonte.get_pixelv(q)
				var d:=float(q.distance_squared_to(ponto))
				if valor.a>.1 and d<distancia:
					distancia=d
					cor=valor
	amostras[ponto]=cor
	return cor

static func camadas(a: PersonagemPlex, direcao: int) -> Dictionary:
	carregar()
	var chave:=str([a.modelo,AparenciaPlex.roupa(a),RoupasVisitantesPlex.pasta(a),AparenciaPlex.cabelo(a),CoresCabeloPlex.cor(a),direcao])
	if cache.has(chave): return cache[chave]
	var fonte:=roupa(a)
	var pasta:="res://assets/poses_humanas/corpo_carregado/rig/"+a.modelo
	var mapa:=CatalogoPlex.imagem(pasta+"_uv.png")
	var base:=CatalogoPlex.imagem(pasta+"_base.png")
	var imagens: Array[Image]=[]
	var amostras: Dictionary={}
	for plano in 2:
		var desenho:=Image.create_empty(112,112,false,Image.FORMAT_RGBA8)
		for y in 112:
			for x in 112:
				var posicao:=Vector2i(direcao*112+x,plano*112+y)
				var uv:=mapa.get_pixelv(posicao)
				if uv.a<.01: continue
				var cor:=amostrar(fonte,Vector2i(roundi(uv.r*255),roundi(uv.g*255)),amostras)
				if cor.a<.1: cor=base.get_pixelv(posicao)
				cor.a=base.get_pixelv(posicao).a
				desenho.set_pixel(x,y,cor)
		imagens.append(desenho)
	var definicao: Dictionary=dados[a.modelo][direcao]
	var cabeca: Dictionary=definicao.cabeca
	var rosto:=CabecaCarregadaPlex.camadas(a,0)
	var destino:=imagens[0 if cabeca.atras else 1]
	var pivo:=Vector2(24,52 if a.modelo in ["crianca","adolescente","adolescente_feminina"] else 48)
	for parte in rosto: CabecaCarregadaPlex.aplicar(destino,parte,Vector2(cabeca.ponto[0],cabeca.ponto[1]),float(cabeca.angulo),pivo)
	var resultado: Dictionary={"tras":ImageTexture.create_from_image(imagens[0]),"frente":ImageTexture.create_from_image(imagens[1]),"centro":Vector2(definicao.centro[0],definicao.centro[1])}
	if ordem.size()>=64: cache.erase(ordem.pop_front())
	ordem.append(chave)
	cache[chave]=resultado
	return resultado

static func textura(a: PersonagemPlex, direcao: int) -> Texture2D:
	var partes:=camadas(a,direcao)
	var imagem: Image=partes.tras.get_image()
	imagem.blend_rect(partes.frente.get_image(),Rect2i(0,0,112,112),Vector2i.ZERO)
	return ImageTexture.create_from_image(imagem)
