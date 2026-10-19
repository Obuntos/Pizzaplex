class_name AcompanhamentoVisitantesPlex
extends RefCounted

static func salao(clientes: ClientesPlex, pessoa: PersonagemPlex) -> bool:
	return "salao" in clientes.jogo.ambientes.em(pessoa.celula).get("funcoes",[])

static func entrar(clientes: ClientesPlex, grupo: Dictionary) -> bool:
	var lider:=clientes.ator(int(grupo.adulta))
	if not is_instance_valid(lider): return false
	var todos:=salao(clientes,lider) and not lider.ocupado()
	var reservados: Array[Vector2i]=[]
	for id in FamiliasVisitantesPlex.membros(grupo):
		if id==lider.identificador: continue
		var pessoa:=clientes.ator(id)
		if not is_instance_valid(pessoa): continue
		pessoa.visita.correndo=false
		if salao(clientes,pessoa) and not pessoa.ocupado():
			reservados.append(pessoa.celula)
			continue
		todos=false
		if pessoa.ocupado():
			reservados.append(pessoa.origem_rota())
			continue
		var centro:=lider.celula
		if pessoa.local.distance_to(lider.local)<1.5 and not lider.movimento.rota.has(pessoa.celula) and not salao(clientes,lider):
			pessoa.trabalho="seguir_familia"
			continue
		var frente:=Vector2.ZERO
		if lider.ocupado(): frente=Vector2(lider.origem_rota()-lider.celula)
		if frente.is_zero_approx() and not lider.movimento.rota.is_empty(): frente=Vector2(lider.movimento.rota[0]-lider.celula)
		var candidatos: Array[Vector2i]=[]
		for raio in [1,2,3]:
			for d in GradePlex.VIZINHOS:
				var ponto: Vector2i=centro+d*raio
				if reservados.has(ponto) or not clientes.chao(ponto) or lider.movimento.rota.has(ponto): continue
				if not frente.is_zero_approx() and Vector2(ponto-centro).dot(frente)>0: continue
				if salao(clientes,lider) and "salao" not in clientes.jogo.ambientes.em(ponto).get("funcoes",[]): continue
				if clientes.jogo.personagens.any(func(outro): return outro!=pessoa and (outro.celula==ponto or outro.origem_rota()==ponto)): continue
				candidatos.append(ponto)
		candidatos.sort_custom(func(a,b): return pessoa.local.distance_squared_to(Vector2(a))+Vector2(a).distance_squared_to(Vector2(centro))*2 < pessoa.local.distance_squared_to(Vector2(b))+Vector2(b).distance_squared_to(Vector2(centro))*2)
		for ponto in candidatos:
			var rota:=clientes.caminho(pessoa.origem_rota(),ponto)
			if rota.is_empty(): continue
			pessoa.assento=-1
			pessoa.trabalho="seguir_familia"
			pessoa.andar(rota)
			reservados.append(ponto)
			break
	return todos

static func lugar(clientes: ClientesPlex, pessoa: PersonagemPlex, grupo: Dictionary) -> Dictionary:
	var mesa: Dictionary=clientes.jogo.planta.objetos.get(int(grupo.mesa),{})
	if mesa.is_empty(): return {}
	var cadeiras:=LugaresPlex.cadeiras(clientes.jogo.planta,mesa)
	var atual:=int(pessoa.visita.get("cadeira",-1))
	if cadeiras.has(atual): return {"cadeira":atual,"slot":cadeiras.find(atual)}
	for slot in cadeiras.size():
		var id:=cadeiras[slot]
		if id<0: continue
		if clientes.jogo.personagens.any(func(p): return p!=pessoa and (p.assento==id or int(p.visita.get("cadeira",-1))==id)): continue
		var acessos: Array[Vector2i]=clientes.jogo.planta.interacoes(id)
		if not acessos.any(func(c): return not clientes.caminho(pessoa.origem_rota(),c).is_empty()): continue
		pessoa.visita.cadeira=id
		pessoa.visita.slot=slot
		return {"cadeira":id,"slot":slot}
	return {}
