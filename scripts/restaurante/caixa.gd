class_name CaixaPlex
extends RefCounted

var jogo: Node
var espera := 0.0

func _init(cena: Node) -> void:
	jogo=cena

func funcionario(id: int) -> PersonagemPlex:
	for a in jogo.personagens:
		if not a.robo and a.cargo=="funcionario" and a.funcao=="caixa" and a.automatico and int(a.visita.get("registradora",-1))==id: return a
	return null

func ponto(id: int, operador: bool, fila: int = 0) -> Vector2i:
	var item: Dictionary=jogo.planta.objetos.get(id,{})
	if item.is_empty(): return Vector2i(-1,-1)
	var pos:=ApoiosPlex.posicao(jogo.planta,item)
	var centro:=Vector2i(pos.x,pos.y)
	var frente:=GradePlex.frente(item.rotacao)*(1 if operador else -1)
	var lado:=Vector2i(frente.y,-frente.x)
	for offset in [frente*(fila+1),frente*(fila+1)+lado,frente*(fila+1)-lado]:
		var c: Vector2i=centro+offset
		if jogo.clientes.chao(c): return c
	return Vector2i(-1,-1)

func mover(a: PersonagemPlex, alvo: Vector2i) -> bool:
	if a.ocupado() or not GradePlex.dentro(alvo): return false
	if a.celula==alvo: return true
	var rota: Array[Vector2i]=jogo.clientes.caminho(a.origem_rota(),alvo)
	if rota.is_empty(): return false
	a.assento=-1
	a.trabalho="ir_caixa"
	a.andar(rota)
	return false

func aproximar(a: PersonagemPlex, id: int, operador: bool) -> bool:
	var alvo:=ponto(id,operador)
	if not mover(a,alvo): return false
	var pos:=ApoiosPlex.posicao(jogo.planta,jogo.planta.objetos[id])
	var centro:=Vector2(pos.x,pos.y)
	var fino:=centro+(Vector2(alvo)-centro).normalized()*.75
	if a.local.distance_to(fino)>.025:
		a.movimento.aproximar(a,fino)
		return false
	jogo.tarefas.orientar(a,centro)
	return true

func solicitar(grupo: Dictionary) -> void:
	if grupo.get("pago",false): return
	grupo.estado="pagamento"
	var a: PersonagemPlex=jogo.clientes.ator(grupo.adulta)
	if not is_instance_valid(a): return
	a.assento=-1
	a.visita.etapa="pagamento"
	if a.trabalho=="sentar_mesa": a.trabalho="fila_caixa"

func atualizar(delta: float) -> void:
	espera+=delta
	if espera<.25: return
	var tempo:=espera
	espera=0.0
	var caixas: Array=jogo.planta.objetos.values().filter(func(o): return o.tipo=="registradora" and int(o.get("carregada_por",0))==0)
	for a in jogo.personagens:
		if a.robo or a.cargo!="funcionario" or a.funcao!="caixa" or not a.automatico: continue
		if jogo.servicos.trabalhos.has(a.identificador): jogo.servicos.cancelar(a)
		if jogo.tarefas.trabalhos.has(a.identificador): jogo.tarefas.liberar(a)
		if a.carga_item>=0: jogo.servicos.inventario.devolver(a)
		a.carregando=false
		a.assento=-1
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
		if aproximar(a,id,true): a.trabalho="caixa"
	for grupo in jogo.clientes.grupos.values():
		if grupo.get("estado","")!="pagamento": continue
		var existente:=int(grupo.get("caixa",-1))
		if jogo.planta.objetos.has(existente) and funcionario(existente)!=null: continue
		grupo.caixa=-1
		var cliente: PersonagemPlex=jogo.clientes.ator(grupo.adulta)
		if not is_instance_valid(cliente): continue
		var menor:=1000000
		for caixa in caixas:
			if funcionario(caixa.id)==null: continue
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
			if not is_instance_valid(a): continue
			if indice>0:
				if mover(a,ponto(caixa.id,false,indice)): a.trabalho="fila_caixa"
				continue
			if not is_instance_valid(atendente) or not aproximar(atendente,caixa.id,true): continue
			if not aproximar(a,caixa.id,false): continue
			a.trabalho="pagar"
			atendente.trabalho="usar_caixa"
			if a.carga_item<0:
				var dinheiro: int=jogo.servicos.inventario.criar("dinheiro",a.celula)
				jogo.servicos.inventario.pegar(a,dinheiro)
				grupo.dinheiro_pagamento=dinheiro
			grupo.tempo_pagamento=float(grupo.get("tempo_pagamento",0.0))+tempo
			if grupo.tempo_pagamento<2.5: continue
			grupo.pago=true
			grupo.estado="pago"
			var valor: int=25*maxi(1,jogo.servicos.pedidos.filter(func(p): return int(p.get("familia",-1))==int(grupo.id) and p.estado=="consumido").size())
			grupo.recibo={"registradora":caixa.id,"valor":valor}
			jogo.servicos.saldo+=valor
			caixa.saldo=int(caixa.get("saldo",0))+valor
			if jogo.planta.objetos.has(int(grupo.get("dinheiro_pagamento",-1))): jogo.planta.remover(int(grupo.dinheiro_pagamento))
			a.carga_item=-1
			grupo.erase("dinheiro_pagamento")
			var livres: Array=jogo.clientes.vagas(a.celula,1,3)
			if not livres.is_empty(): mover(a,livres[0])
			a.trabalho="aguardar_familia"
			atendente.trabalho="caixa"

