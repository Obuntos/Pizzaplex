class_name ParedeCenarioPlex
extends RefCounted

static func obter(tipo: String, rotacao: int, nivel: int, ligacoes: int, estado: String) -> Dictionary:
	var base := GeometriaPlex.obter("parede",rotacao,nivel,ligacoes).duplicate()
	var info: Dictionary = CatalogoPlex.objetos[tipo]
	if not info.estados.has(estado): estado = info.estado_padrao
	var imagem := CatalogoPlex.imagem(info.pasta+"/sprites/"+estado+"/"+str(rotacao)+"_volume.png")
	var origem: Array = info.origens[CatalogoPlex.DIRECOES[rotacao]]
	var cores := PackedColorArray()
	var pontos: PackedVector3Array = base.pontos
	var faces: PackedColorArray = base.superficies
	for i in pontos.size():
		var p := pontos[i]
		var altura := (p.z-p.y*2.0)/3.0
		var lateral := clampf(absf(p.x),3.0,28.0)*(-1.0 if faces[i].r>.5 else 1.0)
		var x := clampi(roundi(lateral)-int(origem[0]),0,imagem.get_width()-1)
		var y := clampi(roundi(16.0-absf(lateral)*.5-altura)-int(origem[1]),0,imagem.get_height()-1)
		var cor := imagem.get_pixel(x,y)
		if faces[i].b>.8: cor = imagem.get_pixel(32,8)
		if cor.a<.5: cor = imagem.get_pixel(clampi(x,12,51),clampi(y,35,95))
		if cor.r+cor.g+cor.b<.15: cor = imagem.get_pixel(clampi(x,12,51),clampi(y,35,95))
		cores.append(Color(cor,1.0) if cor.a>.5 else Color("bab3a6"))
	base.cores = cores
	var previa := Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	for i in pontos.size():
		var local := Vector2i(roundi(pontos[i].x)+96,roundi(pontos[i].y)+144)
		if Rect2i(0,0,192,192).has_point(local): previa.set_pixelv(local,cores[i])
	base.textura = ImageTexture.create_from_image(previa)
	base.origin = [-96,-144]
	return base

static func cor_topo(item: Dictionary) -> Color:
	var info := MobiliaPlex.dados(item)
	var r := GradePlex.rotacao_visual(item.rotacao)
	var estado := MobiliaPlex.estado(item)
	var imagem := CatalogoPlex.imagem(info.pasta+"/sprites/"+estado+"/"+str(r)+"_volume.png")
	return imagem.get_pixel(32,12)
