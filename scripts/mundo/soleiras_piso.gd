class_name SoleirasPisoPlex
extends RefCounted

static var cache: Dictionary={}

static func acabamento(planta: PlantaPlex, celula: Vector2i) -> Array:
	return [str(planta.pisos.get(celula,"")),int(planta.cores.get(celula,0)),int(planta.rotacoes_pisos.get(celula,0))]

static func textura(dados: Array) -> Image:
	var origem:=Vector2i(-96,-144)
	var fonte:Image
	if not str(dados[0]).is_empty():
		var tipo:=str(dados[0]);var rotacao:=PinturaPisosPlex.rotacao_visual(tipo,int(dados[2]))
		if AssetsSistemasPlex.eh(tipo):
			var volume:=AssetsSistemasPlex.obter(tipo,rotacao);origem=Vector2i(volume.origin[0],volume.origin[1]);fonte=SilhuetasPlex.imagem(volume.textura)
		else:fonte=SilhuetasPlex.imagem(CatalogoPlex.sprite(tipo,rotacao))
	else:
		var cor:=clampi(int(dados[1]),0,ChaoPlex.CORES.size()-1)
		var caminho:="res://assets/objetos/chao/sprites/"+("frente.png" if cor==0 else "cores/"+str(ChaoPlex.CORES[cor])+".png")
		if not ResourceLoader.exists(caminho):caminho="res://assets/objetos/chao/sprites/frente.png"
		fonte=CatalogoPlex.imagem(caminho)
	if fonte==null or fonte.is_empty():return null
	var resultado:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	resultado.blit_rect(fonte,Rect2i(Vector2i.ZERO,fonte.get_size()),origem+Vector2i(96,144))
	return resultado

static func obter(planta: PlantaPlex, c: Vector2i) -> Texture2D:
	var porta:=planta.em(c)
	if porta.get("tipo","") not in CatalogoPlex.PORTAS: return null
	var normal:=GradePlex.frente(porta.rotacao)
	var a:=acabamento(planta,c+normal)
	var b:=acabamento(planta,c-normal)
	var chave:=str([a,b,normal,GradePlex.visao])
	if cache.has(chave): return cache[chave]
	var primeira:=textura(a)
	var segunda:=textura(b)
	if primeira==null or segunda==null: return null
	var imagem:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	for y in range(128,161):
		for x in range(64,129):
			var local:=GradePlex.inverter_vetor(Vector2(x-96,y-144))
			if absf(local.x)>.5 or absf(local.y)>.5: continue
			var fonte: Image=primeira if local.dot(Vector2(normal))>=0.0 else segunda
			imagem.set_pixel(x,y,fonte.get_pixel(x,y))
	if cache.size()>192: cache.clear()
	cache[chave]=ImageTexture.create_from_image(imagem)
	return cache[chave]
