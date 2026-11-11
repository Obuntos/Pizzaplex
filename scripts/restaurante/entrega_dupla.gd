class_name EntregaDuplaPlex
extends RefCounted

static func iniciar(servicos: ServicosPlex, ator: PersonagemPlex) -> bool:
	var pedidos: Array=[]
	var reservas: Array=[]
	for pedido in servicos.pedidos:
		if pedido.get("estoque_cozinha",false):continue
		if pedido.estado not in ["assando","pronta"] or not servicos.livre(pedido.mesa) or not servicos.livre(PartilhaPizzaPlex.fonte(servicos,pedido)): continue
		if pedido.has("lote_preparo") and servicos.pedidos.any(func(outro): return outro.id!=pedido.id and outro.get("lote_preparo",-1)==pedido.lote_preparo and outro.estado=="preparando"): continue
		if not servicos.planta.objetos.has(PartilhaPizzaPlex.fonte(servicos,pedido)): continue
		var pizza: Dictionary=servicos.planta.objetos[PartilhaPizzaPlex.fonte(servicos,pedido)]
		var forno: int=pizza.get("sobre",-1)
		if not (FornoPlex.eh(servicos.planta.objetos.get(forno,{})) or servicos.planta.objetos.get(forno,{}).get("mesa_cozinha",false)) or servicos.destino_mesa(pedido.mesa,pedido).is_empty(): continue
		if not pedidos.is_empty() and int(pedido.mesa)!=int(pedidos[0].mesa): continue
		pedidos.append(pedido)
		if pedidos.size()==2: break
	if pedidos.is_empty(): return false
	var limpos: Array=[]
	for estante in servicos.estantes():
		for item in ApoiosPlex.filhos(servicos.planta,estante):
			if not servicos.livre(item.id): continue
			if item.tipo=="prato" and not item.get("sujo",false) and ApoiosPlex.filhos(servicos.planta,item.id).is_empty(): limpos.append(item)
			elif PacotesPratosPlex.eh(item) and int(item.get("quantidade",0))>0: limpos.append(item)
	for item in servicos.planta.objetos.values():
		if PacotesPratosPlex.eh(item) and int(item.get("quantidade",0))>0 and servicos.livre(int(item.id)) and CozinhaProntaPlex.na_cozinha(servicos,int(item.id)) and not limpos.has(item):limpos.append(item)
	var fontes: Array=[]
	for item in PratosPlex.preferidos(servicos,limpos):
		var quantidade:=mini(pedidos.size()-fontes.size(),int(item.quantidade)) if PacotesPratosPlex.eh(item) else 1
		for _i in quantidade: fontes.append(item)
		if fontes.size()==pedidos.size(): break
	if fontes.is_empty(): return false
	pedidos.resize(fontes.size())
	var passos: Array=[]
	for i in fontes.size():
		var item: Dictionary=fontes[i]
		passos.append(servicos.etapa(item.id,"retirar_prato_pilha" if PacotesPratosPlex.eh(item) else "pegar",.6,{"indice_prato":i,"pedido":pedidos[i].id}))
		reservas.append(item.id)
	for i in pedidos.size():
		var pedido: Dictionary=pedidos[i]
		var forno: int=servicos.planta.objetos[PartilhaPizzaPlex.fonte(servicos,pedido)].sobre
		var prato: int=-1 if PacotesPratosPlex.eh(fontes[i]) else int(fontes[i].id)
		passos.append(servicos.etapa(forno,"aguardar_forno",0,{"pedido":pedido.id}))
		passos.append(servicos.etapa(forno,"emplatar",1.1,{"pedido":pedido.id,"prato":prato,"indice_prato":i}))
		reservas.append_array([pedido.mesa,PartilhaPizzaPlex.fonte(servicos,pedido)])
	for i in pedidos.size():
		var pedido: Dictionary=pedidos[i]
		var destino:=servicos.destino_mesa(pedido.mesa,pedido)
		destino.pedido=pedido.id
		destino.prato=-1 if PacotesPratosPlex.eh(fontes[i]) else int(fontes[i].id)
		destino.indice_prato=i
		passos.append(servicos.etapa(pedido.mesa,"servir",.8,destino))
	if not servicos.iniciar(ator,"Servir duas refeições" if pedidos.size()==2 else "Servir refeição no prato",passos,reservas,pedidos[0].id): return false
	servicos.trabalhos[ator.identificador].pedidos=pedidos.map(func(p): return p.id)
	for i in pedidos.size():
		pedidos[i].estado="entregando"
		pedidos[i].prato=-1 if PacotesPratosPlex.eh(fontes[i]) else int(fontes[i].id)
	return true
