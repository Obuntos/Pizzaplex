class_name CamerasVigilanciaPlex
extends RefCounted
const VISTAS=[6,0,6,12]
const GIRO:=24.0
static var areas:Dictionary={}
static func area(jogo:Node,o:Dictionary) -> Dictionary:
	var chave:=str(o.id)+":"+str(quadro(o))
	var revisao:=hash([jogo.planta.revisao,o.celula,o.rotacao])
	var guardado:Dictionary=areas.get(chave,{})
	if int(guardado.get("revisao",0))==revisao and guardado.has("celulas"):return guardado.celulas
	var celulas:Dictionary={}
	var origem:=lente(o);var direcao:=frente(o);var base:Vector2i=o.celula
	for y in range(-9,10):
		for x in range(-9,10):
			var alvo:=base+Vector2i(x,y)
			if GradePlex.dentro(alvo) and VisaoNPCPlex.cone(jogo.planta,origem,direcao,Vector2(alvo),8,84):celulas[alvo]=true
	areas[chave]={"revisao":revisao,"celulas":celulas}
	return celulas
static func quadro_visual(o:Dictionary) -> int:return clampi(int(o.get("camera_quadro",6)),0,12)
static func quadro(o:Dictionary) -> int:
	var q:=quadro_visual(o)
	return 0 if q<=3 else 12 if q>=9 else 6
static func angulo(o:Dictionary) -> float:return deg_to_rad(-45.0+quadro(o)*7.5)
static func frente(o:Dictionary) -> Vector2:return Vector2(GradePlex.frente(int(o.rotacao))).rotated(angulo(o))
static func lente(o:Dictionary) -> Vector2:return Vector2(o.celula)+Vector2(GradePlex.frente(int(o.rotacao)))*.85+frente(o)*.445
static func ligada(o:Dictionary,energia:float) -> bool:return energia>.05 and not o.get("camera_quebrada",false)
static func volume(o:Dictionary) -> Dictionary:
	var estado:="ativa" if o.get("camera_ligada",true) else "desligada"
	return AssetsSistemasPlex.obter(str(o.tipo),GradePlex.rotacao_visual(int(o.rotacao)),estado+"_"+str(quadro_visual(o)))

static func instalacao_permitida(jogo:Node,o:Dictionary) -> bool:
	var c:Vector2i=o.celula+GradePlex.frente(int(o.rotacao))
	if not TerrenoPlex.contem(jogo.planta,c) or not EncaixesMobiliaPlex.camera_livre(jogo.planta,o):return false
	var sala:Dictionary=jogo.ambientes.em(c)
	return sala.get("fechada",false) and str(sala.get("tipo",""))!="banheiro"

static func alcance_total(jogo:Node,o:Dictionary,c:Vector2) -> bool:
	if not ligada(o,jogo.iluminacao.rede.fator) or not instalacao_permitida(jogo,o):return false
	var origem:=Vector2(o.celula)+Vector2(GradePlex.frente(int(o.rotacao)))*1.0
	var vetor:=c-origem
	return vetor.length()<=8.0 and (vetor.length()<.5 or Vector2(GradePlex.frente(int(o.rotacao))).dot(vetor.normalized())>=cos(deg_to_rad(85.0))) and VisaoNPCPlex.linha(jogo.planta,origem,c)

static func porta_banheiro_coberta(jogo:Node,sala:Dictionary) -> bool:
	for id in sala.get("portas",[]):
		var porta:Dictionary=jogo.planta.objetos.get(int(id),{})
		if porta.is_empty():continue
		for c in jogo.planta.celulas(porta.tipo,porta.celula,porta.rotacao):
			for d in [GradePlex.frente(int(porta.rotacao)),-GradePlex.frente(int(porta.rotacao))]:
				var fora:Vector2i=c+d
				if sala.celulas.has(fora) or not jogo.planta.transitavel(fora):continue
				for camera in jogo.planta.objetos.values():
					if MobiliaPlex.dados(camera).get("camera",false) and alcance_total(jogo,camera,Vector2(fora)):return true
	return false

static func nome(jogo:Node,o:Dictionary) -> String:
	jogo.animatronicos.palcos.atualizar()
	var grupos:Dictionary={}
	for c in jogo.animatronicos.palcos.grupos:
		var grupo:=int(jogo.animatronicos.palcos.grupos[c])
		if not grupos.has(grupo):grupos[grupo]=[]
		grupos[grupo].append(c)
	var vistos:Array=[];var numeros:Array=grupos.keys();numeros.sort()
	for grupo in numeros:
		if grupos[grupo].any(func(c):return alcance_total(jogo,o,Vector2(c))):vistos.append(numeros.find(grupo)+1)
	if vistos.size()==1:return "Palco "+str(vistos[0])
	var frente_c:Vector2i=o.celula+GradePlex.frente(int(o.rotacao))
	var sala:Dictionary=jogo.ambientes.em(frente_c)
	if sala.is_empty():return "Entrada"
	var tipo:=str(sala.get("tipo","livre"));var numero:=0
	for ambiente in jogo.ambientes.ambientes:
		if ambiente.get("tipo","")!=tipo:continue
		numero+=1
		if int(ambiente.id)==int(sala.id):break
	var nomes:Dictionary={"salao":"Salão","salao_festas":"Festas","cozinha":"Cozinha","oficina":"Manutenção","descanso":"Sala de descanso","escritorio":"Escritório","vestiario":"Vestiário","limpeza":"Limpeza","deposito":"Depósito","banheiro":"Porta do banheiro"}
	return str(nomes.get(tipo,tipo.capitalize()))+" "+str(maxi(1,numero))
