class_name DecoracaoEstudoPlex
extends RefCounted

const MESA="mesa_desenho_inclinada"
const RELOGIO="relogio_antigo"
const CARRINHO="carrinho_baloes"
static var dados:Dictionary={}
static var bases:Dictionary={}
static var cache:Dictionary={}
static var lista_relogios:Array=[]
static var revisao_relogios:=-1
static var ultimo_quarto:=-1
static func eh(tipo:String) -> bool:return EstudosPlex.eh_mesa(tipo) and tipo!=MESA or tipo in [RELOGIO,CARRINHO]
static func catalogar(objetos:Dictionary) -> void:
	objetos[MESA]={"nome":"Mesa de desenho inclinada","pasta":"res://assets/objetos/decoracao/"+MESA,"largura":2,"profundidade":1,"altura":60,"pivo":[96,144],"preco":150,"conforto":2,"categoria":"Oficina","transitavel":false,"sobreposto":false,"apoio":false,"parede_requerida":false,"ambiente_novo":true,"mobilia":true,"uso":"estudo","estados":["blueprints","esbocos","arrumada"],"estado_padrao":"blueprints"}
	objetos[RELOGIO]={"nome":"Relógio antigo com pêndulo","pasta":"res://assets/objetos/estudos/"+RELOGIO,"largura":1,"profundidade":1,"altura":96,"pivo":[96,144],"preco":65,"conforto":2,"categoria":"Decoração","transitavel":true,"sobreposto":true,"apoio":false,"parede_requerida":true}
	objetos[CARRINHO]={"nome":"Carrinho de balões","largura":3,"profundidade":2,"altura":117,"pivo":[96,144],"preco":180,"conforto":6,"categoria":"Decoração","transitavel":false,"sobreposto":false,"apoio":false,"estados":["um","dois","tres","vazio"],"estado_padrao":"tres"}
	for tipo in ["bancada","oficina_bancada_trabalho"]:
		if objetos.has(tipo):objetos[tipo].oculto=true;objetos[tipo].nome="Mesa de desenho inclinada"
static func carregar() -> void:
	if dados.is_empty():dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/decoracoes_estudo.json"))
static func atualizar(planta:PlantaPlex,minutos:float) -> void:
	var assinatura:=hash([planta.get_instance_id(),planta.revisao])
	if assinatura!=revisao_relogios:
		revisao_relogios=assinatura;ultimo_quarto=-1;lista_relogios=planta.objetos.values().filter(func(o):return o.tipo==RELOGIO)
	var quarto:=floori(minutos*4)
	if ultimo_quarto==quarto:return
	ultimo_quarto=quarto
	for item in lista_relogios:item.estado="hora:"+str(quarto);item.relogio_minutos=minutos
static func angulos(minutos:float) -> Vector2:
	return Vector2(fposmod(minutos,720.0)/720.0*TAU,fposmod(minutos,60.0)/60.0*TAU)
static func obter(tipo:String,rotacao:int,minutos:float=610.0,estado:String="") -> Dictionary:
	carregar();tipo=MESA if EstudosPlex.eh_mesa(tipo) else tipo
	var id:=tipo+":"+str(posmod(rotacao,4))+(":"+(estado if estado in ["um","dois","tres","vazio"] else "tres") if tipo==CARRINHO else "")
	if not bases.has(id):
		var fonte:Dictionary=dados[id]
		var pontos:=PackedVector3Array();var cores:=PackedColorArray();var normais:=PackedColorArray()
		for p in fonte.pontos:
			pontos.append(Vector3(p[0],p[1],p[2]));cores.append(Color(float(p[3])/255,float(p[4])/255,float(p[5])/255,float(p[6])/255));normais.append(Color(float(p[7])*.5+.5,float(p[8])*.5+.5,float(p[9])*.5+.5,.2))
		var imagem:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
		for i in pontos.size():
			var xy:=Vector2i(roundi(pontos[i].x)+96,roundi(pontos[i].y)+144)
			if Rect2i(0,0,192,192).has_point(xy):imagem.set_pixelv(xy,cores[i])
		bases[id]={"image":str(fonte.image),"origin":[-96,-144],"textura":ImageTexture.create_from_image(imagem),"pontos":pontos,"cores":cores,"superficies":normais}
	if tipo!=RELOGIO:return bases[id]
	var chave:=id+":"+str(floori(minutos*4))
	if cache.has(chave):return cache[chave]
	var r:Dictionary=bases[id].duplicate(true)
	if posmod(rotacao,4) in [0,3]:
		var angulo:=angulos(minutos)
		for mao in [[angulo.x,5.2,1.15],[angulo.y,7.9,.7]]:
			for passo in range(-2,ceili(float(mao[1])*3)):
				var comprimento:=float(passo)/3.0
				var local:=Vector2(sin(float(mao[0]))*comprimento/32.0,.803).rotated(rotacao*PI*.5)
				var z:=77+cos(float(mao[0]))*comprimento
				var tela:=Vector2((local.x-local.y)*32,(local.x+local.y)*16-z)
				for lateral in [-.25,.25]:
					r.pontos.append(Vector3(roundf(tela.x+lateral),roundf(tela.y),float((local.x+local.y)*32+z+.2)))
					r.cores.append(Color("414e50"));r.superficies.append(Color(.5,1,.5,.2))
	if cache.size()>=16:cache.erase(cache.keys()[0])
	cache[chave]=r;return r
static func previa(tipo:String,rotacao:int,estado:String="") -> Texture2D:
	return obter(tipo,rotacao,610.0,estado).textura
