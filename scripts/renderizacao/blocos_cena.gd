class_name BlocosCenaPlex
extends RefCounted

const LADO := 256
var tamanho: Vector2i
var colunas: int
var linhas: int
var profundidade := Texture2DArray.new()
var superficies := Texture2DArray.new()
var cores: Array[ImageTexture] = []
var partes: Array[Sprite2D] = []
var transferencias := 0
var bytes_enviados := 0

func _init(dimensoes: Vector2i, pai: Sprite2D) -> void:
	tamanho=dimensoes
	colunas=ceili(float(tamanho.x)/LADO)
	linhas=ceili(float(tamanho.y)/LADO)
	var vazio:=Image.create_empty(LADO,LADO,false,Image.FORMAT_RGBA8)
	var fundo:=Image.create_empty(LADO,LADO,false,Image.FORMAT_RF)
	fundo.fill(Color(-10000,0,0))
	var mapas: Array[Image]=[]
	var faces: Array[Image]=[]
	for y in linhas:
		for x in colunas:
			mapas.append(fundo)
			faces.append(vazio)
			var cor: ImageTexture=null
			var parte:=Sprite2D.new()
			parte.centered=false
			parte.position=Vector2(x*LADO,y*LADO)
			parte.texture=cor
			parte.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			parte.use_parent_material=true
			parte.hide()
			pai.add_child(parte)
			cores.append(cor)
			partes.append(parte)
	profundidade.create_from_images(mapas)
	superficies.create_from_images(faces)

func recortar(fonte: Image, origem: Vector2i) -> Image:
	var area:=Rect2i(origem,Vector2i(LADO,LADO)).intersection(Rect2i(Vector2i.ZERO,tamanho))
	if area.size==Vector2i(LADO,LADO): return fonte.get_region(area)
	var imagem:=Image.create_empty(LADO,LADO,false,fonte.get_format())
	if fonte.get_format()==Image.FORMAT_RF: imagem.fill(Color(-10000,0,0))
	imagem.blit_rect(fonte,area,Vector2i.ZERO)
	return imagem

func atualizar(imagem: Image, mapa: Image, faces: Image, regiao: Rect2i) -> void:
	var area:=regiao.intersection(Rect2i(Vector2i.ZERO,tamanho))
	if not area.has_area(): return
	var inicio:=Vector2i(floori(float(area.position.x)/LADO),floori(float(area.position.y)/LADO))
	var fim:=Vector2i(floori(float(area.end.x-1)/LADO),floori(float(area.end.y-1)/LADO))
	for y in range(inicio.y,fim.y+1):
		for x in range(inicio.x,fim.x+1):
			var indice:=y*colunas+x
			var origem:=Vector2i(x*LADO,y*LADO)
			var cor:=recortar(imagem,origem)
			var ocupada:=cor.get_used_rect().has_area()
			if not ocupada and not partes[indice].visible: continue
			if cores[indice]==null:
				cores[indice]=ImageTexture.create_from_image(cor)
				partes[indice].texture=cores[indice]
			else: cores[indice].update(cor)
			partes[indice].visible=ocupada
			profundidade.update_layer(recortar(mapa,origem),indice)
			superficies.update_layer(recortar(faces,origem),indice)
			transferencias+=1
			bytes_enviados+=LADO*LADO*12

