class_name EntregaDuplaPlex
extends RefCounted

static func iniciar(servicos: ServicosPlex, ator: PersonagemPlex) -> bool:
	var pedidos: Array = []
	var pratos: Array = []
	var reservas: Array = []
	for pedido in servicos.pedidos:
		if pedido.estado not in ["assando","pronta"] or not servicos.livre(pedido.mesa) or not servicos.livre(pedido.pizza): continue
		if pedido.has("lote_preparo") and servicos.pedidos.any(func(outro): return outro.id!=pedido.id and outro.get("lote_preparo",-1)==pedido.lote_preparo and outro.estado=="preparando"): continue
		var pizza: Dictionary = servicos.planta.objetos[pedido.pizza]
		var forno: int = pizza.get("sobre",-1)
		if servicos.planta.objetos.get(forno,{}).get("tipo","")!="forno" or servicos.destino_mesa(pedido.mesa,pedido).is_empty(): continue
		pedidos.append(pedido)
		if pedidos.size()==2: break
	if pedidos.is_empty(): return false
	for estante in servicos.estantes():
		for prato in ApoiosPlex.filhos(servicos.planta,estante):
			if prato.tipo!="prato" or prato.get("sujo",false) or not servicos.livre(prato.id) or not ApoiosPlex.filhos(servicos.planta,prato.id).is_empty(): continue
			pratos.append(prato.id)
			if not reservas.has(estante): reservas.append(estante)
			if pratos.size()==pedidos.size(): break
		if pratos.size()==pedidos.size(): break
	if pratos.is_empty(): return false
	pedidos.resize(pratos.size())
	var passos: Array = []
	for prato in pratos:
		passos.append(servicos.etapa(prato,"pegar"))
		reservas.append(prato)
	for i in pedidos.size():
		var pedido: Dictionary = pedidos[i]
		var forno: int = servicos.planta.objetos[pedido.pizza].sobre
		passos.append(servicos.etapa(forno,"aguardar_forno",0,{"pedido":pedido.id}))
		passos.append(servicos.etapa(forno,"emplatar",1.1,{"pedido":pedido.id,"prato":pratos[i]}))
		reservas.append_array([pedido.mesa,pedido.pizza])
	for i in pedidos.size():
		var pedido: Dictionary = pedidos[i]
		var destino := servicos.destino_mesa(pedido.mesa,pedido)
		destino.pedido = pedido.id
		destino.prato = pratos[i]
		passos.append(servicos.etapa(pedido.mesa,"servir",.8,destino))
	if not servicos.iniciar(ator,"Servir duas refeições" if pedidos.size()==2 else "Servir refeição no prato",passos,reservas,pedidos[0].id): return false
	servicos.trabalhos[ator.identificador].pedidos = pedidos.map(func(p): return p.id)
	for i in pedidos.size():
		pedidos[i].estado = "entregando"
		pedidos[i].prato = pratos[i]
	return true
