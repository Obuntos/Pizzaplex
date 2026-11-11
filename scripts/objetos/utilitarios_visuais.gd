class_name UtilitariosVisuaisPlex
extends RefCounted

static var cache: Dictionary={}

static func marcador(tipo:String,rotacao:int) -> Dictionary:
	var chave:="marca:"+tipo+":"+str(rotacao)
	if cache.has(chave):return cache[chave]
	var imagem:=Image.create_empty(64,48,false,Image.FORMAT_RGBA8)
	var vetor:=GradePlex.projetar_local(Vector2(GradePlex.frente(rotacao))).normalized()
	var lateral:=Vector2(-vetor.y,vetor.x)
	var triangulo:=PackedVector2Array([vetor*17,vetor*10+lateral*4,vetor*10-lateral*4])
	var cor:=Color("c76962") if tipo=="pose_quebrado" else Color("82b7d8") if tipo=="pose_montagem" else Color("93b5a4")
	var pontos:=PackedVector3Array();var cores:=PackedColorArray();var normais:=PackedColorArray()
	for y in range(-24,24):
		for x in range(-32,32):
			var p:=Vector2(x,y);var eixo:=p.dot(vetor)
			if not (eixo>=-9 and eixo<=17 and absf(p.dot(lateral))<=1) and not Geometry2D.is_point_in_polygon(p,triangulo):continue
			imagem.set_pixel(x+32,y+24,cor);pontos.append(Vector3(x,y,y*2+.6));cores.append(cor);normais.append(Color(.5,.5,1,.2))
	var volume:Dictionary={"image":chave,"origin":[-32,-24],"textura":ImageTexture.create_from_image(imagem),"pontos":pontos,"cores":cores,"superficies":normais}
	cache[chave]=volume;return volume

static func catalogar(objetos: Dictionary) -> void:
	objetos.saco_lixo={"nome":"Saco de lixo","largura":1,"profundidade":1,"pivo":[96,144],"apoio":false,"sobreposto":false,"transitavel":true,"altura":24,"preco":0,"conforto":0,"estados":["fechado"],"estado_padrao":"fechado","oculto":true,"pasta":""}

static func obter(tipo: String, rotacao: int) -> Dictionary:
	var chave:=str([tipo,rotacao])
	if cache.has(chave): return cache[chave]
	var imagem:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	var pontos:=PackedVector3Array()
	var cores:=PackedColorArray()
	var normais:=PackedColorArray()
	for y in range(-36,22):
		for x in range(-34,35):
			var cor:=Color.TRANSPARENT
			var altura:=.12
			var normal:=Color(.5,.5,1,.2)
			if tipo in ["ponto_recebimento","suporte","area_montagem_atracao"]:
				var uv:=GradePlex.inverter_local(Vector2(x,y+altura))
				var u:=absf(uv.x);var v:=absf(uv.y)
				if maxf(u,v)>.45: continue
				if maxf(u,v)<.34: continue
				var faixa:=floori((uv.x+uv.y)*22.0)
				cor=(Color("b2b7b6") if tipo in ["suporte","area_montagem_atracao"] else Color("d8b54f")) if posmod(faixa,6)<3 else Color("302f2c")
				if maxf(u,v)>.435 or maxf(u,v)<.355: cor=Color("596265") if tipo in ["suporte","area_montagem_atracao"] else Color("5e5135")
			else:
				var yy:=float(y)
				var raio:=sqrt(maxf(0.0,1.0-pow((yy+12.0)/12.0,2.0)))*10.0
				if y in range(-28,-22): raio=2.5 if y<-25 else 1.5
				if absf(x)>raio or y>0: continue
				cor=Color("273c40") if x<0 else Color("1e2d34")
				if absf(x)>raio-1: cor=Color("101e27")
				elif x<-3 and y in range(-21,-5): cor=Color("405457")
				elif x==3 and y in range(-15,-2): cor=Color("31454a")
				if y in [-25,-24]: cor=Color("a6a482")
				altura=maxf(.5,-yy*.84)
				normal=Color(clampf(.5+float(x)/28.0,.1,.9),.75,.70,.2)
			if cor.a<.1: continue
			pontos.append(Vector3(x,y,float(y)*2.0+altura*3.0));cores.append(cor);normais.append(normal)
			imagem.set_pixel(x+96,y+144,cor)
	var volume: Dictionary={"image":"utilitario:"+chave,"origin":[-96,-144],"textura":ImageTexture.create_from_image(imagem),"pontos":pontos,"cores":cores,"superficies":normais}
	cache[chave]=volume
	return volume
