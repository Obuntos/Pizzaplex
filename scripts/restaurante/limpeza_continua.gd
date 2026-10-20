class_name LimpezaContinuaPlex
extends RefCounted

static func proxima(servico: ServicosPlex, ator: PersonagemPlex, trabalho: Dictionary) -> bool:
	var ferramenta: Dictionary=servico.planta.objetos.get(ator.carga_item,{})
	if trabalho.get("tipo", "")!="Limpar ambiente" or ferramenta.get("tipo","") not in ["vassoura","balde"]: return false
	var candidatos: Array=servico.planta.objetos.values().filter(func(item): return item.tipo==("bebida_derramada" if ferramenta.tipo=="balde" else "mancha_chao") or (ferramenta.tipo=="vassoura" and MobiliaPlex.dados(item).get("entulho",false)))
	candidatos.sort_custom(func(a,b): return Vector2(a.celula-ator.celula).length_squared()<Vector2(b.celula-ator.celula).length_squared())
	var lixeiras: Array=servico.planta.objetos.values().filter(func(item): return item.tipo=="lixeira" and int(item.get("lixo",0))<6 and int(item.get("reserva",0)) in [0,ator.identificador])
	for item in candidatos:
		if not servico.livre(item.id) or item.get("sobre",-1)>=0 or not servico.salas.do_objeto(item.id).get("fechada",false): continue
		var limpar := servico.etapa(item.id,"limpar",2.5)
		var rota := servico.rota_passo(ator.origem_rota(),limpar,ator)
		if rota.is_empty(): continue
		lixeiras.sort_custom(func(a,b): return Vector2(a.celula-item.celula).length_squared()<Vector2(b.celula-item.celula).length_squared())
		for lixeira in lixeiras:
			var descartar := servico.etapa(lixeira.id,"lixo",.7)
			if servico.rota_passo(rota[-1],descartar,ator).is_empty(): continue
			for id in [item.id,lixeira.id]:
				servico.planta.objetos[id].reserva=ator.identificador
				if not trabalho.reservas.has(id): trabalho.reservas.append(id)
			trabalho.passos.insert(trabalho.indice+1,limpar)
			trabalho.passos.insert(trabalho.indice+2,descartar)
			return true
	return false
