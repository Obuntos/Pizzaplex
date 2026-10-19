class_name BebidasPlex
extends RefCounted

static func preparar(pedido: Dictionary) -> void:
	if not pedido.has("bebida_estado"): pedido.bebida_estado = "aguardando" if int(pedido.get("cliente", -1)) >= 0 else "consumida"
	if not pedido.has("bebida"): pedido.bebida = -1

static func servir(servico: ServicosPlex, ator: PersonagemPlex) -> bool:
	for pedido in servico.pedidos:
		preparar(pedido)
		if pedido.estado == "cancelado" or pedido.bebida_estado != "aguardando" or not servico.livre(pedido.mesa): continue
		var mesa: Dictionary = servico.planta.objetos.get(pedido.mesa, {})
		if mesa.is_empty(): continue
		var n := LugaresPlex.cadeiras(servico.planta, mesa).size()
		var slot := n + 2 + int(pedido.slot)
		if not ApoiosPlex.aceita(servico.planta, pedido.mesa, "guarana_tampa", slot): continue
		for id in servico.encontrar("geladeira", ["cozinha"]):
			var geladeira: Dictionary = servico.planta.objetos[id]
			SuprimentosPlex.preparar(geladeira)
			if int(geladeira.estoque.guarana) < 1: continue
			var passos := [servico.etapa(id, "retirar_bebida", .8), servico.etapa(pedido.mesa, "servir_bebida", .7, {"slot":slot})]
			if servico.iniciar(ator, "Servir guaraná", passos, [id, pedido.mesa], pedido.id):
				pedido.bebida_estado = "entregando"
				pedido.geladeira_bebida = id
				return true
	return false

static func executar(servico: ServicosPlex, ator: PersonagemPlex, passo: Dictionary, trabalho: Dictionary) -> bool:
	var pedido := servico.pedido_por_id(trabalho.pedido)
	match str(passo.acao):
		"retirar_bebida":
			if pedido.is_empty() or not SuprimentosPlex.retirar(servico.planta.objetos[passo.alvo], "guarana"): return false
			var id := servico.inventario.criar("guarana_tampa", ator.celula)
			pedido.bebida = id
			pedido.bebida_retirada = true
			if not servico.inventario.pegar(ator, id): return false
			servico.planta.objetos[passo.alvo].estado = "fechada"
		"servir_bebida":
			if pedido.is_empty() or not servico.inventario.apoiar(ator, passo.alvo, int(passo.dados.slot)): return false
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
		pedido.tempo_bebida = maxf(0.0, float(pedido.get("tempo_bebida", 8.0)) - delta)
		cliente.visita.bebendo = pedido.tempo_bebida > 0
		var estado := "vazio" if pedido.tempo_bebida <= 0 else "meio" if pedido.tempo_bebida <= 4 else "cheio"
		if estado != copo.estado:
			copo.estado = estado
			servico.planta.alterada.emit()
		if pedido.tempo_bebida <= 0: pedido.bebida_estado = "consumida"

static func recolher(servico: ServicosPlex, ator: PersonagemPlex) -> bool:
	for copo in servico.planta.objetos.values():
		if copo.tipo not in ["guarana_copo", "guarana_tampa"] or copo.estado != "vazio" or int(copo.get("sobre", -1)) < 0 or not servico.livre(copo.id): continue
		for lixeira in servico.encontrar("lixeira"):
			var passos := [servico.etapa(copo.id, "pegar"), servico.etapa(lixeira, "descartar_copo", .7)]
			if servico.iniciar(ator, "Recolher copo", passos, RotinasPlex.reservas(servico, [copo.id, lixeira])): return true
	return false

static func cancelar(servico: ServicosPlex, ator: PersonagemPlex, trabalho: Dictionary) -> void:
	if trabalho.get("tipo", "") != "Servir guaraná": return
	var pedido := servico.pedido_por_id(int(trabalho.get("pedido", -1)))
	if pedido.is_empty() or pedido.get("bebida_estado", "") == "servida": return
	var id := int(pedido.get("bebida", -1))
	if servico.planta.objetos.has(id):
		if ator.carga_item == id: ator.carga_item = -1
		servico.planta.remover(id)
	if pedido.get("bebida_retirada", false) and servico.planta.objetos.has(int(pedido.get("geladeira_bebida", -1))):
		SuprimentosPlex.devolver(servico.planta.objetos[int(pedido.geladeira_bebida)], "guarana")
	pedido.bebida_retirada = false
	pedido.bebida = -1
	pedido.bebida_estado = "aguardando"
