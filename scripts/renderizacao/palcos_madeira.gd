class_name PalcosMadeiraPlex
extends RefCounted

const MODULO="antigo_palco_madeira_pequeno"
static var cache: Dictionary={}
static var previas: Dictionary={}

static func eh(tipo: String) -> bool:
	return tipo.begins_with("antigo_palco_madeira_")

static func catalogar(objetos: Dictionary) -> void:
	for tipo in objetos:
		if not eh(tipo): continue
		objetos[tipo].pacote=[1,1]
		objetos[tipo].nome="Palco de madeira"

static func obter(estado: String, ligacoes: int) -> Dictionary:
	var acabamento:=estado if estado in ["gasto","partido"] else "gasto"
	var chave:=str([acabamento,ligacoes])
	if cache.has(chave): return cache[chave]
	var base:=GeometriaPlex.obter("palco",0,4,ligacoes).duplicate()
	var fonte:=GeometriaPlex.obter(MODULO,0,4,0,false,acabamento)
	var original: Image=CatalogoPlex.imagem(fonte.image)
	var imagem:=Image.create_empty(base.textura.get_width(),base.textura.get_height(),false,Image.FORMAT_RGBA8)
	var cores:=PackedColorArray()
	for ponto in base.pontos:
		var altura: float=(ponto.z-ponto.y*2.0)/3.0
		var topo: bool=altura>=17.5
		var local:=GradePlex.inverter_local(Vector2(ponto.x,ponto.y+altura))
		var amostra:=GradePlex.projetar_local(local*(.8 if topo else 1.04),18.0 if topo else altura)
		var pixel:=Vector2i(amostra.round())-Vector2i(fonte.origin[0],fonte.origin[1])
		pixel=pixel.clamp(Vector2i.ZERO,original.get_size()-Vector2i.ONE)
		var cor:=original.get_pixelv(pixel)
		if cor.a<.9: cor=Color("b5a17c") if topo else Color("8a7c60") if ponto.x<0 else Color("756b55")
		cores.append(Color(cor,1.0))
		imagem.set_pixelv(Vector2i(ponto.x,ponto.y)-Vector2i(base.origin[0],base.origin[1]),Color(cor,1.0))
	base.cores=cores
	base.textura=ImageTexture.create_from_image(imagem)
	cache[chave]=base
	return base

static func previa(estado: String, ligacoes: int) -> Texture2D:
	var chave:=str([estado,ligacoes])
	if previas.has(chave): return previas[chave]
	var volume:=obter(estado,ligacoes)
	var imagem:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	imagem.blit_rect(volume.textura.get_image(),Rect2i(Vector2i.ZERO,volume.textura.get_size()),Vector2i(volume.origin[0]+96,volume.origin[1]+144))
	previas[chave]=ImageTexture.create_from_image(imagem)
	return previas[chave]


static func mapa(imagem: Image, origem: Vector2i) -> PackedFloat32Array:
	var valores:=PackedFloat32Array();valores.resize(imagem.get_width()*imagem.get_height());valores.fill(-10000.0)
	for y in imagem.get_height():
		for x in imagem.get_width():
			if imagem.get_pixel(x,y).a<=0.0: continue
			var px:=float(x+origem.x)+.5
			var py:=float(y+origem.y)+.5
			var altura:=clampf(16.0-absf(px)*.5-py,0.0,18.0)
			valores[y*imagem.get_width()+x]=2.0*py+3.0*altura
	return valores
