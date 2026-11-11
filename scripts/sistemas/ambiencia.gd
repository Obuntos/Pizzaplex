class_name AmbienciaRestaurantePlex
extends RefCounted

var jogo:Node
var ar:Dictionary={}
var entradas:Dictionary={}
var fontes_ar:Dictionary={}
var base_ar:Dictionary={}
var poluicao:Dictionary={}
var fontes_poluidoras:Array=[]
var revisao_ar:=0
var sons:Dictionary={}
var espera:=0.0
var espera_som:=.37
var portas_cache:Array=[]
var revisao_portas:=-1
const ABAFAMENTO={"musica":[.35,.6,.5,.9],"motor":[.3,.55,.45,.9],"grito":[.22,.48,.36,.9],"voz":[.14,.4,.3,.85],"risos":[.14,.4,.3,.85],"mexer":[.1,.3,.2,.82],"passos":[.06,.25,.15,.8]}
const ABAFAMENTO_PADRAO=[.16,.48,.28,.8]
func _init(cena:Node) -> void:jogo=cena
static func parede_ruim(item:Dictionary) -> bool:
	var estado:=MobiliaPlex.estado(item)
	return estado in ["lascada","danificada","buraco","partido","topo-partido","velha","rachada"] or MobiliaPlex.visual(item).contains("velha")
func reta(a:Vector2,b:Vector2,materiais:Array) -> float:
	var fator:=1.0;var vistos:Dictionary={};var passos:=maxi(1,ceili(a.distance_to(b)*2))
	for i in range(1,passos):
		var c:=Vector2i(a.lerp(b,float(i)/passos).round());var o:Dictionary=jogo.planta.em(c)
		if o.is_empty() or vistos.has(o.id):continue
		vistos[o.id]=true
		if o.tipo in CatalogoPlex.PORTAS:fator*=float(materiais[3]) if o.get("aberta",false) else float(materiais[2])
		elif CatalogoPlex.base(str(o.tipo))=="parede":fator*=float(materiais[1]) if parede_ruim(o) else float(materiais[0])
	return fator
func portas() -> Array:
	if revisao_portas!=jogo.planta.revisao:
		revisao_portas=jogo.planta.revisao
		portas_cache=jogo.planta.objetos.values().filter(func(o):return o.tipo in CatalogoPlex.PORTAS)
	return portas_cache
func transmissao(a:Vector2,b:Vector2,tipo:String="") -> float:
	var materiais:Array=ABAFAMENTO.get(tipo,ABAFAMENTO_PADRAO)
	var direto:=reta(a,b,materiais);var distancia:=a.distance_to(b)
	if direto>=.5 or distancia>16:return maxf(.012,direto)
	var melhor:=direto
	for porta in portas():
		if not porta.get("aberta",false):continue
		var p:=Vector2(porta.celula);var volta:=a.distance_to(p)+p.distance_to(b)
		if volta>distancia+10:continue
		melhor=maxf(melhor,reta(a,p,materiais)*reta(p,b,materiais)*float(materiais[3])*(1.0+distancia*.22)/(1.0+volta*.22))
	return maxf(.012,melhor)
func fontes() -> Array:
	var lista:Array=[]
	for a in jogo.personagens:
		if a.visita.get("morto",false) or not a.visible:continue
		if a.robo and (a.robotica.get("estado","")=="ligado" or jogo.controle_robo.tocando(a)):lista.append({"chave":"robo:"+str(a.identificador),"p":a.local,"tipo":"musica","forca":1.0})
		elif a.visita.get("brincando",false):lista.append({"chave":"riso:"+str(a.identificador),"p":a.local,"tipo":"risos","forca":.4})
	for o in jogo.planta.objetos.values():
		if o.tipo=="geladeira":lista.append({"chave":"geladeira:"+str(o.id),"p":Vector2(o.celula),"tipo":"motor","forca":.28 if parede_ruim(o) or MobiliaPlex.estado(o)!="nova" else .15})
		elif MobiliaPlex.dados(o).get("alto_falante",false) and o.get("som_ligado",false) and jogo.operacao.aberto:lista.append({"chave":"caixa:"+str(o.id),"p":Vector2(o.celula),"tipo":"musica","forca":.85})
	return lista
func nivel(c:Vector2) -> float:
	var valor:=0.0
	for f in fontes():valor+=float(f.forca)*transmissao(Vector2(f.p),c,str(f.tipo))/(1.0+Vector2(f.p).distance_to(c)*.22)
	return clampf(valor,0,1)
func atualizar_sons() -> void:
	for player in sons.values():
		if is_instance_valid(player):player.stop();player.queue_free()
	sons.clear()
func calcular_ar() -> void:
	jogo.ambientes.atualizar();ar.clear();entradas.clear();fontes_ar.clear();poluicao.clear();fontes_poluidoras.clear();base_ar.clear();revisao_ar+=1
	var dutos:Dictionary={};var grades:Array=[];var cozinhas:Dictionary={}
	for o in jogo.planta.objetos.values():
		var tipo:=MobiliaPlex.visual(o)
		if tipo.begins_with("oficina_duto"):
			for c in jogo.planta.celulas(o.tipo,o.celula,o.rotacao):dutos[c]=true
			if tipo=="oficina_duto_grade":grades.append(o)
	var grupos:Array=[];var vistos:Dictionary={}
	for c in dutos:
		if vistos.has(c):continue
		var fila:Array=[c];vistos[c]=true;var indice:=0
		while indice<fila.size():
			var atual:Vector2i=fila[indice];indice+=1
			for d in GradePlex.VIZINHOS:
				if dutos.has(atual+d) and not vistos.has(atual+d):vistos[atual+d]=true;fila.append(atual+d)
		grupos.append(fila)
	for sala in jogo.ambientes.ambientes:
		if not sala.fechada:continue
		cozinhas[sala.id]=0.0;ar[sala.id]=95.0;ar[sala.id]-=minf(8,float(sala.celulas.size())*.08)
		for id in sala.get("portas",[]):
			var porta:Dictionary=jogo.planta.objetos.get(id,{})
			if porta.is_empty():continue
			var externa:=false
			for d in GradePlex.VIZINHOS:
				var vizinha:Dictionary=jogo.ambientes.em(porta.celula+d)
				if not vizinha.is_empty() and not vizinha.get("fechada",false):externa=true
			if externa:
				if not entradas.has(sala.id):entradas[sala.id]=[]
				entradas[sala.id].append(porta.celula)
	var tratamentos:Dictionary={}
	var agora:float=jogo.calendario.dias*1440.0+jogo.calendario.minutos
	for o in jogo.planta.objetos.values():
		var sala:Dictionary=jogo.ambientes.do_objeto(int(o.id))
		if not sala.get("fechada",false):continue
		var tipo:=MobiliaPlex.visual(o);var carga:=0.0;var motivo:=""
		if MobiliaPlex.dados(o).get("gerador",false):
			var funcionando:bool=o.get("ligada",true) and float(o.get("combustivel",100))>0
			var velho:bool=parede_ruim(o) or (str(o.tipo).contains("velho") or str(o.tipo).contains("antigo")) or str(MobiliaPlex.estado(o)) in ["gasto","velho","avariado"]
			carga=(58.0 if velho else 34.0) if funcionando else 0.0;motivo="Gases do gerador"
		elif FornoPlex.eh(o):
			var ativo:bool=float(o.get("tempo_assar",0))>0 or str(o.get("estado","")) in ["funcionando","aceso"] or jogo.personagens.any(func(a):return a.trabalho=="preparar" and a.local.distance_to(Vector2(o.celula))<3)
			if ativo:o.ar_cozinha_ate=agora+45.0
			carga=38.0 if ativo else 20.0*clampf((float(o.get("ar_cozinha_ate",0))-agora)/45.0,0,1);motivo="Frituras e preparo"
		elif str(o.tipo)=="geladeira" or tipo.contains("geladeira"):
			carga=18.0 if parede_ruim(o) else 10.0 if MobiliaPlex.estado(o)!="nova" else 6.0;motivo="Geladeira: calor / odor"
		elif o.get("sujo",false) or tipo.contains("poca") or tipo.contains("lixo") or int(o.get("lixo",0))>0:
			if not o.has("ar_sujo_em"):o.ar_sujo_em=agora
			carga=minf(12,2+maxf(0,agora-float(o.ar_sujo_em))/360);motivo="Restos, sujeira e lixo"
		if carga>0:
			var perfil:=PoluicaoArPlex.potencial(str(o.tipo));var raio:int=perfil.get("raio",2)
			fontes_poluidoras.append({"id":"objeto:"+str(o.id),"celula":o.celula,"origens":jogo.planta.celulas(o.tipo,o.celula,o.rotacao),"raio":raio,"carga":carga,"motivo":motivo,"sala":sala.id})
			cozinhas[sala.id]=float(cozinhas.get(sala.id,0))+carga
			if not fontes_ar.has(sala.id):fontes_ar[sala.id]=[]
			fontes_ar[sala.id].append(motivo)
	for a in jogo.personagens:
		var carga:=0.0
		if a.visita.get("morto",false) and int(a.visita.get("oculto_em",-1))<0:
			if not a.visita.has("morto_em"):a.visita.morto_em=agora
			carga=minf(65,16+maxf(0,agora-float(a.visita.morto_em))/1440*18)
		elif a.robo:carga=float(a.robotica.get("cheiro",0))*.55
		var sala:Dictionary=jogo.ambientes.em(a.celula)
		if carga>0 and sala.get("fechada",false):
			fontes_poluidoras.append({"id":"pessoa:"+str(a.identificador),"celula":a.celula,"origens":[a.celula],"raio":clampi(4+floori(carga/30),4,6),"carga":carga,"motivo":"Corpo / decomposição","sala":sala.id})
			cozinhas[sala.id]=float(cozinhas.get(sala.id,0))+carga
			if not fontes_ar.has(sala.id):fontes_ar[sala.id]=[]
			fontes_ar[sala.id].append("Corpo / decomposição")
	for rede in grupos:
		var exterior:=false;var ligadas:Dictionary={};var bocas:Dictionary={}
		for grade in grades:
			if not rede.has(grade.celula):continue
			var alcance:Array=[grade.celula]
			for d in GradePlex.VIZINHOS:alcance.append(grade.celula+d)
			for c in alcance:
				var sala:Dictionary=jogo.ambientes.em(c)
				if sala.is_empty():continue
				if not sala.get("fechada",false):exterior=true
				elif not bocas.get(sala.id,[]).has(grade.id):
					if not bocas.has(sala.id):bocas[sala.id]=[]
					bocas[sala.id].append(grade.id);ligadas[sala.id]=true
		var odor:=0.0
		for id in ligadas:odor+=float(cozinhas.get(id,0))
		for id in ligadas:
			if exterior:
				ar[id]=clampf(float(ar.get(id,60))+minf(18,bocas[id].size()*10),5,100);tratamentos[id]=minf(.92,.65+float(bocas[id].size())*.12)
			else:ar[id]=maxf(5,float(ar.get(id,60))-maxf(0,odor-float(cozinhas.get(id,0)))*.65)
	base_ar=ar.duplicate()
	for fonte in fontes_poluidoras:
		var tiles:=PoluicaoArPlex.area(jogo.planta,fonte.origens,int(fonte.raio));fonte.tiles=tiles
		for c in tiles:
			var sala:Dictionary=jogo.ambientes.em(c)
			var reducao:float=tratamentos.get(sala.get("id",-1),0.0)
			poluicao[c]=float(poluicao.get(c,0))+float(fonte.carga)*float(tiles[c])*(1.0-reducao)
	for sala in jogo.ambientes.ambientes:
		if not sala.get("fechada",false):continue
		var total:=0.0
		for c in sala.celulas:total+=qualidade(c)
		ar[sala.id]=total/maxi(1,sala.celulas.size())
	for a in jogo.personagens:
		a.visita.qualidade_ar=qualidade(a.celula)
		var calor:bool=jogo.calendario.temperatura()>=30 and jogo.ambientes.em(a.celula).get("fechada",false)
		if not a.robo and not a.visita.get("morto",false) and (float(a.visita.qualidade_ar)<55 or calor):
			a.visita.motivo_insatisfacao="Muito calor na sala." if calor else "Ar ruim na sala."
			if a.relogio>=float(a.visita.get("reacao_ar_apos",0)):a.emocao.exibir("cansado" if float(a.visita.qualidade_ar)>35 else "irritado");a.visita.reacao_ar_apos=a.relogio+22.0
		if a.cargo in ["cliente","crianca","adolescente"] and float(a.visita.qualidade_ar)<45:a.visita.satisfacao=maxf(0,float(a.visita.get("satisfacao",50))-.25)
func qualidade(c:Vector2i) -> float:
	var id:int=jogo.ambientes.em(c).get("id",-1)
	var valor:float=float(base_ar.get(id,ar.get(id,100)))-float(poluicao.get(c,0))
	var proximidade:=0.0
	for porta in entradas.get(id,[]):proximidade=maxf(proximidade,18.0/(1.0+Vector2(porta).distance_to(Vector2(c))*.25))
	return clampf(valor+proximidade,5,100)
func atualizar(delta:float) -> void:
	espera+=delta/maxf(.1,jogo.velocidade_tempo);espera_som+=delta/maxf(.1,jogo.velocidade_tempo)
	if espera>=2:
		espera=0;calcular_ar();return
	if espera_som>=.75:espera_som=0;atualizar_sons()
func limpar() -> void:
	for s in sons.values():if is_instance_valid(s):s.queue_free()
	sons.clear();ar.clear();base_ar.clear();poluicao.clear();fontes_poluidoras.clear();fontes_ar.clear();entradas.clear();espera=2.0;revisao_ar+=1
