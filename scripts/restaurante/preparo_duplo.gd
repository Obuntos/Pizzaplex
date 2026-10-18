class_name PreparoDuploPlex
extends RefCounted

static func iniciar(servicos: ServicosPlex, ator: PersonagemPlex) -> bool:
	var pedidos := servicos.pedidos.filter(func(p): return p.estado=="aguardando")
	if pedidos.size()<2: return false
	pedidos.resize(2)
	for ambiente in servicos.salas.ambientes:
		if not ambiente.operacional or ambiente.tipo!="cozinha": continue
		for geladeira in servicos.salas.objetos(ambiente,"geladeira"):
			var refrigerador: Dictionary = servicos.planta.objetos[geladeira]
			SuprimentosPlex.preparar(refrigerador)
			if not servicos.livre(geladeira) or refrigerador.get("ingredientes",0)<2: continue
			for bancada in servicos.salas.objetos(ambiente,"bancada_preparo"):
				if not servicos.livre(bancada): continue
				var apoios: Array[int] = []
				for slot in ApoiosPlex.pontos(servicos.planta.objetos[bancada],servicos.planta).size():
					if ApoiosPlex.aceita(servicos.planta,bancada,"pizza",slot): apoios.append(slot)
				if apoios.size()<2: continue
				for forno in servicos.salas.objetos(ambiente,"forno"):
					var disponiveis: Array[int] = []
					for slot in 2:
						if not servicos.planta.objetos[forno].get("reservas_forno",{}).has(str(slot)) and ApoiosPlex.aceita(servicos.planta,forno,"pizza",slot): disponiveis.append(slot)
					if disponiveis.size()<2: continue
					var passos: Array = []
					for i in 2: passos.append(servicos.etapa(geladeira,"ingrediente",.8,{"pedido":pedidos[i].id}))
					for i in 2: passos.append(servicos.etapa(bancada,"preparar",3.0,{"pedido":pedidos[i].id,"slot":apoios[i]}))
					for i in 2: passos.append(servicos.etapa(bancada,"pegar_pizza",.6,{"pedido":pedidos[i].id}))
					for i in 2: passos.append(servicos.etapa(forno,"assar",1.0,{"pedido":pedidos[i].id,"slot":disponiveis[i]}))
					if not servicos.iniciar(ator,"Preparar duas pizzas",passos,[geladeira,bancada],pedidos[0].id): continue
					servicos.trabalhos[ator.identificador].pedidos = pedidos.map(func(p): return p.id)
					for i in 2:
						FornoPlex.reservar(servicos.planta.objetos[forno],disponiveis[i],pedidos[i].id)
						pedidos[i].estado = "preparando"
						pedidos[i].lote_preparo = pedidos[0].id
					return true
	return false
