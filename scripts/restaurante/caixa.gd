class_name CaixaPlex
extends RefCounted

var jogo: Node
var espera := 0.0

func _init(cena: Node) -> void:
	jogo=cena

func disponivel(a: PersonagemPlex) -> bool:
	if not is_instance_valid(a) or a.robo or a.cargo!="funcionario" or not a.automatico: return false
	if not (a.funcao=="caixa" or AdministradorPlex.eh(a) and EquipePlex.permite(a,"caixa")): return false
	if ControleAdministradorPlex.ocupado(a) or FantasiasRestaurantePlex.ocupando(a): return false
	if int(a.visita.get("recepcao_grupo",-1))>=0: return false
	if jogo.servicos.trabalhos.has(a.identificador) or jogo.tarefas.trabalhos.has(a.identificador): return false
	return a.carga_item<0 and not a.carregando and a.carga_extra.is_empty()

func funcionario(id: int) -> PersonagemPlex:
	for a in jogo.personagens:
		if disponivel(a) and int(a.visita.get("registradora",-1))==id: return a
	return null

static func postos(planta: PlantaPlex, item: Dictionary, operador: bool, fila: int = 0) -> Array[Vector2i]:
	if item.is_empty(): return []
	var resultado: Array[Vector2i]=[]
	var pos:=ApoiosPlex.posicao(planta,item)
	var centro:=Vector2i(roundi(pos.x),roundi(pos.y))
	var frente:=GradePlex.frente(item.rotacao)*(1 if operador else -1)
	var raiz:=ApoiosPlex.raiz(planta,item.id)
	var base: Dictionary=planta.objetos.get(raiz,{})
	var ocupadas: Array[Vector2i]=planta.celulas(base.tipo,base.celula,base.rotacao) if not base.is_empty() else []
	var borda:=centro+frente
	for distancia in range(1,5):
		borda=centro+frente*distancia
		if not ocupadas.has(borda): break
	var c: Vector2i=borda+frente*fila
	if planta.transitavel(c) and is_zero_approx(planta.altura(c)): resultado.append(c)
	elif not operador and fila>0:
		var lado:=Vector2i(-frente.y,frente.x)
		for desvio in [lado,-lado,lado*2,-lado*2]:
			var alternativa:Vector2i=c+desvio
			if planta.transitavel(alternativa) and is_zero_approx(planta.altura(alternativa)):
				resultado.append(alternativa)
				break
	elif operador and fila==0 and CatalogoPlex.base(str(planta.em(c).get("tipo","")))=="cadeira":
		var lado:=Vector2i(-frente.y,frente.x)
		for alternativa in [c+lado,c-lado,c+frente]:
			if planta.transitavel(alternativa) and is_zero_approx(planta.altura(alternativa)):
				resultado.append(alternativa)
				break
	return resultado

func ponto(id: int, operador: bool, fila: int = 0) -> Vector2i:
	for c in postos(jogo.planta,jogo.planta.objetos.get(id,{}),operador,fila):
		if jogo.clientes.chao(c) and TerrenoPlex.contem(jogo.planta,c) and not TerrenoPlex.borda(jogo.planta,c): return c
	return Vector2i(-1,-1)

func mover(a: PersonagemPlex, alvo: Vector2i) -> bool:
	if ControleAdministradorPlex.ocupado(a): return false
	if a.cargo=="funcionario" and not disponivel(a): return false
	if a.ocupado() or not GradePlex.dentro(alvo): return false
	if a.celula==alvo: return true
	var rota: Array[Vector2i]=jogo.clientes.caminho(a.origem_rota(),alvo)
	if rota.is_empty(): return false
	a.assento=-1
	a.trabalho="ir_caixa"
	a.andar(rota)
	return false

func aproximar(a: PersonagemPlex, id: int, operador: bool) -> bool:
	if operador and not disponivel(a): return false
	var alvo:=ponto(id,operador)
	if not mover(a,alvo): return false
	var pos:=ApoiosPlex.posicao(jogo.planta,jogo.planta.objetos[id])
	var centro:=Vector2(pos.x,pos.y)
	var fino:=Vector2(alvo)+(centro-Vector2(alvo)).normalized()*.20
	if a.local.distance_to(fino)>.025:
		a.movimento.aproximar(a,fino)
		return false
	jogo.tarefas.orientar(a,centro)
	return true

func cadeira(a: PersonagemPlex, id: int) -> int:
	var posto:=ponto(id,true)
	if not GradePlex.dentro(posto): return -1
	for o in jogo.planta.objetos.values():
		if CatalogoPlex.base(str(o.tipo))!="cadeira" or Vector2(o.celula).distance_to(Vector2(posto))>1.5 or o.celula==posto: continue
		if int(o.get("reserva",0)) not in [0,a.identificador] or int(o.get("carregada_por",0))>0: continue
		if jogo.personagens.any(func(p): return p!=a and p.assento==int(o.id)): continue
		return int(o.id)
	return -1

func sentar(a: PersonagemPlex, id: int) -> void:
	var c:=cadeira(a,id)
	if c<0:
		a.trabalho="caixa"
		return
	a.assento=c;a.visita.caixa_cadeira=c;jogo.planta.objetos[c].reserva=a.identificador
	a.direcao=GradePlex.direcao_suporte(int(jogo.planta.objetos[c].rotacao))
	a.trabalho="caixa_sentado"

func solicitar(grupo: Dictionary) -> void:
	if grupo.get("pago",false): return
	grupo.estado="pagamento"
	var a: PersonagemPlex=jogo.clientes.ator(grupo.adulta)
	if not is_instance_valid(a): return
	a.assento=-1
	a.visita.etapa="pagamento"
	if a.trabalho=="sentar_mesa": a.trabalho="fila_caixa"

func aguardando_pagamento() -> bool:
	for grupo in jogo.clientes.grupos.values():
		if grupo.get("estado","")!="pagamento": continue
		var caixa:=int(grupo.get("caixa",-1))
		if not jogo.planta.objetos.has(caixa): continue
		var cliente: PersonagemPlex=jogo.clientes.ator(int(grupo.adulta))
		if not is_instance_valid(cliente): continue
		var alvo:=ponto(caixa,false)
		if GradePlex.dentro(alvo) and cliente.local.distance_to(Vector2(alvo))<=3.0: return true
	return false

func atualizar(delta: float) -> void:
	espera+=delta
	if espera<.25: return
	var tempo:=espera
	espera=0.0
	var caixas: Array=jogo.planta.objetos.values().filter(func(o): return o.tipo=="registradora" and int(o.get("carregada_por",0))==0)
	var pagamento_pendente: bool=aguardando_pagamento() or jogo.clientes.grupos.values().any(func(g): return g.get("estado","")=="recepcao")
	for a in jogo.personagens:
		if not disponivel(a): continue
		if AdministradorPlex.eh(a) and not pagamento_pendente:
			if a.trabalho in ["caixa","caixa_sentado","ir_caixa","usar_caixa","aguardar_caixa"]:
				a.visita.registradora=-1
				a.movimento.cancelar()
				a.trabalho=""
			continue
		a.assento=-1
		var antiga:Dictionary=jogo.planta.objetos.get(int(a.visita.get("caixa_cadeira",-1)),{})
		if not antiga.is_empty() and int(antiga.get("reserva",0))==a.identificador: antiga.reserva=0
		a.visita.erase("caixa_cadeira")
		var id:=int(a.visita.get("registradora",-1))
		if not jogo.planta.objetos.has(id) or jogo.planta.objetos[id].tipo!="registradora" or (funcionario(id)!=null and funcionario(id)!=a): id=-1
		if id<0:
			a.visita.registradora=-1
			for caixa in caixas:
				if funcionario(caixa.id)==null and GradePlex.dentro(ponto(caixa.id,true)):
					id=caixa.id
					a.visita.registradora=id
					break
		if id<0:
			a.trabalho="aguardar_caixa"
			continue
		if aproximar(a,id,true): sentar(a,id)
	for grupo in jogo.clientes.grupos.values():
		if grupo.get("estado","")!="pagamento": continue
		var existente:=int(grupo.get("caixa",-1))
		if jogo.planta.objetos.has(existente) and jogo.planta.objetos[existente].tipo=="registradora": continue
		grupo.caixa=-1
		var cliente: PersonagemPlex=jogo.clientes.ator(grupo.adulta)
		if not is_instance_valid(cliente): continue
		var menor:=1000000
		for caixa in caixas:
			var alvo:=ponto(caixa.id,false)
			if not GradePlex.dentro(alvo): continue
			var rota: Array[Vector2i]=jogo.clientes.caminho(cliente.origem_rota(),alvo)
			if rota.is_empty(): continue
			var quantidade: int=jogo.clientes.grupos.values().filter(func(g): return g.get("estado","")=="pagamento" and int(g.get("caixa",-1))==caixa.id).size()
			var peso: int=quantidade*8+rota.size()
			if peso<menor:
				menor=peso
				grupo.caixa=caixa.id
	for caixa in caixas:
		var atendente:=funcionario(caixa.id)
		var fila: Array=jogo.clientes.grupos.values().filter(func(g): return g.get("estado","")=="pagamento" and int(g.get("caixa",-1))==caixa.id)
		fila.sort_custom(func(a,b): return int(a.id)<int(b.id))
		for indice in fila.size():
			var grupo: Dictionary=fila[indice]
			var a: PersonagemPlex=jogo.clientes.ator(grupo.adulta)
			if not is_instance_valid(a) or ControleAdministradorPlex.ocupado(a): continue
			if indice>0:
				if mover(a,ponto(caixa.id,false,indice)): a.trabalho="fila_caixa"
				continue
			if not aproximar(a,caixa.id,false): continue
			a.trabalho="fila_caixa"
			if not is_instance_valid(atendente) or not aproximar(atendente,caixa.id,true): continue
			a.trabalho="pagar"
			atendente.trabalho="usar_caixa"
			if a.carga_item<0:
				var dinheiro: int=jogo.servicos.inventario.criar("dinheiro",a.celula)
				jogo.servicos.inventario.pegar(a,dinheiro)
				grupo.dinheiro_pagamento=dinheiro
			grupo.tempo_pagamento=float(grupo.get("tempo_pagamento",0.0))+tempo
			if grupo.tempo_pagamento<2.5: continue
			jogo.livro.atender(grupo)
			registrar_pagamento(grupo,caixa)
			if jogo.planta.objetos.has(int(grupo.get("dinheiro_pagamento",-1))): jogo.planta.remover(int(grupo.dinheiro_pagamento))
			a.carga_item=-1
			grupo.erase("dinheiro_pagamento")
			var livres: Array=jogo.clientes.vagas(a.celula,1,3)
			if not livres.is_empty(): mover(a,livres[0])
			a.trabalho="aguardar_familia"
			atendente.trabalho="caixa"



func registrar_pagamento(grupo: Dictionary, caixa: Dictionary) -> float:
	if grupo.get("pago",false): return 0.0
	var conta:=PartilhaPizzaPlex.conta(jogo.servicos,int(grupo.id))
	var valor:float=maxf(0.0,float(conta.total)-float(grupo.get("valor_pago",0.0)))
	grupo.recibo={"registradora":caixa.id,"valor":conta.total,"base":conta.base,"acrescimo":conta.acrescimo,"pessoas":conta.pessoas}
	grupo.valor_pago=snappedf(float(grupo.get("valor_pago",0.0))+valor,.01)
	grupo.pago=true
	grupo.estado="pago"
	jogo.servicos.receber(valor)
	caixa.saldo=snappedf(float(caixa.get("saldo",0.0))+valor,.01)
	return valor
