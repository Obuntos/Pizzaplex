class_name BebidasPlex
extends RefCounted

static func preparar(pedido: Dictionary) -> void:
	if not pedido.has("bebida_estado"): pedido.bebida_estado = "aguardando" if int(pedido.get("cliente", -1)) >= 0 else "consumida"
	if not pedido.has("bebida"): pedido.bebida = -1

static func servir(servico: ServicosPlex, ator: PersonagemPlex) -> bool:
	if ator.carga_item>=0 or not ator.carga_extra.is_empty() or ator.carregando: return false
	for primeiro in servico.pedidos:
		preparar(primeiro)
		if primeiro.estado=="cancelado" or primeiro.bebida_estado!="aguardando" or not servico.livre(primeiro.mesa): continue
		var mesa: Dictionary=servico.planta.objetos.get(primeiro.mesa,{})
		if mesa.is_empty(): continue
		var pedidos: Array=[]
		var n:=LugaresPlex.cadeiras(servico.planta,mesa).size()
		for pedido in servico.pedidos:
			preparar(pedido)
			if pedido.mesa!=primeiro.mesa or pedido.estado=="cancelado" or pedido.bebida_estado!="aguardando": continue
			var slot:=n+2+int(pedido.slot)
			if ApoiosPlex.aceita(servico.planta,pedido.mesa,"guarana_tampa",slot): pedidos.append(pedido)
			if pedidos.size()==2: break
		if pedidos.is_empty(): continue
		if pedidos.size()==1:
			if not primeiro.has("bebida_desde"):primeiro.bebida_desde=servico.tempo_servico
			var sentados:=servico.personagens.filter(func(p): return p.trabalho=="sentar_mesa" and LugaresPlex.cadeiras(servico.planta,mesa).has(p.assento)).size()
			if sentados>=2 and servico.tempo_servico-float(primeiro.bebida_desde)<6.0: continue
		for id in servico.encontrar("geladeira",["cozinha"]):
			var geladeira: Dictionary=servico.planta.objetos[id]
			SuprimentosPlex.preparar(geladeira)
			var quantidade:=mini(pedidos.size(),int(geladeira.estoque.guarana))
			if quantidade<=0: continue
			var lote: Array=pedidos.slice(0,quantidade)
			var passos: Array=[]
			for pedido in lote: passos.append(servico.etapa(id,"retirar_bebida",.8,{"pedido":pedido.id}))
			for pedido in lote: passos.append(servico.etapa(pedido.mesa,"servir_bebida",.7,{"pedido":pedido.id,"slot":n+2+int(pedido.slot)}))
			if servico.iniciar(ator,"Servir dois guaranás" if lote.size()==2 else "Servir guaraná",passos,[id,primeiro.mesa],primeiro.id):
				servico.trabalhos[ator.identificador].pedidos=lote.map(func(p): return p.id)
				for pedido in lote:
					pedido.bebida_estado="entregando";pedido.geladeira_bebida=id
				return true
	return false

static func executar(servico: ServicosPlex, ator: PersonagemPlex, passo: Dictionary, trabalho: Dictionary) -> bool:
	var pedido := servico.pedido_por_id(int(passo.dados.get("pedido",trabalho.pedido)))
	match str(passo.acao):
		"retirar_bebida":
			if pedido.is_empty() or not SuprimentosPlex.retirar(servico.planta.objetos[passo.alvo], "guarana"): return false
			var id := servico.inventario.criar("guarana_tampa", ator.celula)
			pedido.bebida = id
			pedido.bebida_retirada = true
			if not servico.inventario.pegar(ator,id):
				servico.planta.remover(id)
				return false
			servico.planta.objetos[passo.alvo].estado = "fechada"
			servico.planta.alterada.emit()
		"servir_bebida":
			if pedido.is_empty() or not servico.inventario.apoiar_item(ator,int(pedido.get("bebida",-1)),passo.alvo,int(passo.dados.slot)): return false
			pedido.bebida_estado = "servida"
			pedido.tempo_bebida = 8.0
		"descartar_copo":
			var id := ator.carga_item
			if id < 0: return false
			ator.carga_item = -1
			servico.planta.remover(id)
			servico.planta.objetos[passo.alvo].lixo = int(servico.planta.objetos[passo.alvo].get("lixo", 0)) + 1
	return true

static func atualizar(servico: ServicosPlex, delta: float) -> void:
	for pedido in servico.pedidos:
		preparar(pedido)
		if pedido.bebida_estado != "servida": continue
		var copo: Dictionary = servico.planta.objetos.get(int(pedido.bebida), {})
		if copo.is_empty():
			pedido.bebida_estado = "aguardando"
			continue
		var cliente: PersonagemPlex = null
		for a in servico.personagens:
			if a.identificador == int(pedido.get("cliente", -1)): cliente = a
		if not is_instance_valid(cliente) or cliente.trabalho != "sentar_mesa" or cliente.ocupado(): continue
		OcorrenciasClientesPlex.derramar(servico,pedido,cliente,true)
		pedido.tempo_bebida = maxf(0.0, float(pedido.get("tempo_bebida", 8.0)) - delta)
		cliente.visita.bebendo = pedido.tempo_bebida > 0
		var estado := "vazio" if pedido.tempo_bebida <= 0 else "meio" if pedido.tempo_bebida <= 4 else "cheio"
		if estado != copo.estado:
			copo.estado = estado
			if estado=="vazio":copo.limpeza_liberar=servico.tempo_servico+EsperaLimpezaPlex.INTERVALO
			servico.planta.alterada.emit()
		if pedido.tempo_bebida <= 0: pedido.bebida_estado = "consumida"

static func recolher(servico: ServicosPlex, ator: PersonagemPlex, mesa_alvo: int=-1) -> bool:
	for copo in servico.planta.objetos.values():
		if mesa_alvo>=0 and int(copo.get("sobre",-1))!=mesa_alvo: continue
		if copo.tipo not in ["guarana_copo", "guarana_tampa"] or copo.estado != "vazio" or int(copo.get("sobre", -1)) < 0 or not servico.livre(copo.id): continue
		if not EsperaLimpezaPlex.pode(servico,copo,mesa_alvo>=0):continue
		for lixeira in servico.encontrar("lixeira"):
			var passos := [servico.etapa(copo.id, "pegar"), servico.etapa(lixeira, "descartar_copo", .7)]
			if servico.iniciar(ator, "Recolher copo", passos, RotinasPlex.reservas(servico, [copo.id, lixeira])): return true
	return false

static func cancelar(servico: ServicosPlex, ator: PersonagemPlex, trabalho: Dictionary) -> void:
	if trabalho.get("tipo","") not in ["Servir guaraná","Servir dois guaranás"]: return
	for pedido_id in trabalho.get("pedidos",[trabalho.get("pedido",-1)]):
		var pedido:=servico.pedido_por_id(int(pedido_id))
		if pedido.is_empty() or pedido.get("bebida_estado","") in ["servida","consumida"]: continue
		var id:=int(pedido.get("bebida",-1))
		if ator.carga_item==id: ator.carga_item=ator.carga_extra.pop_front() if not ator.carga_extra.is_empty() else -1
		else: ator.carga_extra.erase(id)
		if servico.planta.objetos.has(id): servico.planta.remover(id)
		if pedido.get("bebida_retirada",false) and servico.planta.objetos.has(int(pedido.get("geladeira_bebida",-1))):
			SuprimentosPlex.devolver(servico.planta.objetos[int(pedido.geladeira_bebida)],"guarana")
		pedido.bebida_retirada=false;pedido.bebida=-1;pedido.bebida_estado="aguardando"
