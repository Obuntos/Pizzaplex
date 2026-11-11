class_name CabecaCarregadaPlex
extends RefCounted

static var encaixes: Dictionary={}

static func encaixe(mapa: Image, modelo: String, direcao: int) -> Dictionary:
	var chave:=modelo+str(direcao)
	if encaixes.has(chave): return encaixes[chave]
	var candidatos: Array=[]
	for y in 80:
		for x in 80:
			var uv:=mapa.get_pixel(direcao*80+x,y)
			if roundi(uv.b*255)!=1 or uv.a<.6: continue
			var origem:=Vector2(uv.r*255,uv.g*255)
			candidatos.append({"ponto":Vector2(x,y),"distancia":origem.distance_squared_to(Vector2(24,30))})
	candidatos.sort_custom(func(a,b): return a.distancia<b.distancia)
	var pescoco:=Vector2.ZERO
	var total:=mini(8,candidatos.size())
	for i in total: pescoco+=candidatos[i].ponto
	pescoco/=maxi(1,total)
	var ponto: Array=PosesHumanasPlex.dados.corpos[modelo][direcao]
	var centro:=Vector2(ponto[0],ponto[1])+Vector2(24,17)
	var angulo:=snappedf((centro-pescoco).angle()+PI*.5,PI/8.0)
	var resultado: Dictionary={"ponto":pescoco+Vector2(16,16),"angulo":angulo}
	encaixes[chave]=resultado
	return resultado

static func camadas(a: PersonagemPlex, direcao: int) -> Array[Image]:
	var tras:=Image.create_empty(48,80,false,Image.FORMAT_RGBA8)
	var frente:=Image.create_empty(48,80,false,Image.FORMAT_RGBA8)
	var uniforme:=AparenciaPlex.roupa(a)
	var cabelo:=AparenciaPlex.cabelo(a)
	if cabelo!="nenhum":
		var origem: String="res://assets/aparencias/cabelos/"+cabelo+"/parado_"
		tras.blend_rect(CabeloChapeuPlex.textura(origem+"tras.png",uniforme,CoresCabeloPlex.cor(a),a.modelo).diffuse_texture.get_image(),Rect2i(0,direcao*68,48,68),Vector2i(0,12))
		frente.blend_rect(CabeloChapeuPlex.textura(origem+"frente.png",uniforme,CoresCabeloPlex.cor(a),a.modelo).diffuse_texture.get_image(),Rect2i(0,direcao*68,48,68),Vector2i(0,12))
	var raiz: String="res://assets/personagens/"+a.modelo+"/"
	var rosto:=Image.create_empty(48,80,false,Image.FORMAT_RGBA8)
	for parte in ["parado_cabeca","cansado_olhos","neutro_boca"]:
		var arquivo: String=raiz+parte+".png"
		var cansado: bool=parte=="cansado_olhos" and ResourceLoader.exists(arquivo)
		if not ResourceLoader.exists(arquivo): arquivo=raiz+parte.replace("cansado","neutro")+".png"
		var fonte:=CatalogoPlex.imagem(arquivo)
		rosto.blend_rect(fonte,Rect2i(480 if cansado else 0,direcao*60,48,60),Vector2i(0,20))
	rosto.blend_rect(frente,Rect2i(0,0,48,80),Vector2i.ZERO)
	if CabeloChapeuPlex.possui(uniforme):
		var chapeu:=CatalogoPlex.imagem("res://assets/aparencias/uniformes/"+uniforme+"/chapeu.png")
		rosto.blend_rect(chapeu,Rect2i(0,direcao*80,48,80),Vector2i.ZERO)
	return [tras,rosto]

static func aplicar(destino: Image, fonte: Image, ponto: Vector2, angulo: float, pivo: Vector2 = Vector2(24,48)) -> void:
	var limites:=Rect2(ponto-pivo.rotated(angulo),Vector2.ZERO)
	for canto in [Vector2(48,0),Vector2(0,80),Vector2(48,80)]: limites=limites.expand(ponto+(canto-pivo).rotated(angulo))
	var inicio:=Vector2i(limites.position.floor()).max(Vector2i.ZERO)
	var fim:=Vector2i(limites.end.ceil()).min(destino.get_size())
	for y in range(inicio.y,fim.y):
		for x in range(inicio.x,fim.x):
			var origem:=Vector2i(((Vector2(x+.5,y+.5)-ponto).rotated(-angulo)+pivo).floor())
			if not Rect2i(Vector2i.ZERO,fonte.get_size()).has_point(origem): continue
			var cor:=fonte.get_pixelv(origem)
			if cor.a>.01: destino.set_pixel(x,y,destino.get_pixel(x,y).blend(cor))
