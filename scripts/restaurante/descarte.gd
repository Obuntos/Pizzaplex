class_name DescartePlex
extends RefCounted

static func eh(item: Dictionary) -> bool:
	return not item.is_empty() and CatalogoPlex.base(str(item.get("tipo","")))=="lixeira"

static func interna(planta: PlantaPlex, item: Dictionary) -> bool:
	return eh(item) and TerrenoPlex.contem(planta,item.celula) and int(item.get("sobre",-1))<0

static func acessos(planta: PlantaPlex, item: Dictionary) -> Array[Vector2i]:
	var resultado: Array[Vector2i]=[]
	for ocupado in planta.celulas(item.tipo,item.celula,item.rotacao):
		for d in GradePlex.VIZINHOS:
			var c: Vector2i=ocupado+d
			if interna(planta,item) and not TerrenoPlex.contem(planta,c): continue
			if not planta.transitavel(c) or not is_zero_approx(planta.altura(c)) or resultado.has(c): continue
			if str(planta.pisos.get(c,"")).begins_with("cidade_faixa_de_pedestre"): continue
			if planta.em(c).get("tipo","") in CatalogoPlex.PORTAS: continue
			resultado.append(c)
	return resultado

static func ordenar(servico: ServicosPlex, origem: Vector2i, ator: PersonagemPlex, itens: Array) -> Array:
	var alcancaveis: Array[Dictionary]=[]
	for item in itens:
		if not interna(servico.planta,item): continue
		var passo:=servico.etapa(item.id,"lixo",.7)
		var rota:=servico.rota_passo(origem,passo,ator)
		if not rota.is_empty(): alcancaveis.append({"item":item,"passos":rota.size(),"distancia":origem.distance_squared_to(item.celula)})
	alcancaveis.sort_custom(func(a,b): return a.passos<b.passos if a.passos!=b.passos else a.distancia<b.distancia)
	return alcancaveis.map(func(r): return r.item)

