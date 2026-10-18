class_name DevolucaoPlex
extends RefCounted

static func tipos(tipo: String) -> Array:
	if tipo.begins_with("caixa_pecas_"): return ["armario_ferramentas"]
	if tipo in ["vassoura", "balde"]: return ["armario_limpeza"]
	if tipo in ["caixa_ferramentas", "pecas_manutencao"]: return ["armario_ferramentas"]
	if tipo in ["prato", "copo_bebida", "bandeja"]: return ["armario_utensilios", "estante"]
	if tipo.begins_with("caixa"): return ["estante"]
	return []

static func destino(servico: ServicosPlex, item: Dictionary) -> Dictionary:
	for tipo in tipos(item.tipo):
		var candidatos := servico.encontrar(tipo)
		candidatos.sort_custom(func(a,b): return Vector2(servico.planta.objetos[a].celula).distance_squared_to(Vector2(item.celula)) < Vector2(servico.planta.objetos[b].celula).distance_squared_to(Vector2(item.celula)))
		for pai in candidatos:
			var slot := ApoiosPlex.livre(servico.planta, pai, item.tipo)
			if int(item.get("sobre", -1)) == int(pai): slot = int(item.slot)
			if slot >= 0: return {"pai":pai,"slot":slot}
	return {}

static func preparar(servico: ServicosPlex, passos: Array, reservas: Array) -> void:
	for i in passos.size():
		var passo: Dictionary = passos[i]
		if passo.acao != "devolver": continue
		var item: Dictionary = servico.planta.objetos.get(passo.alvo, {})
		if item.is_empty(): continue
		var d := destino(servico, item)
		if d.is_empty(): continue
		passos[i] = servico.etapa(d.pai, "apoiar", .9, {"slot":d.slot,"devolucao":true})
		if not reservas.has(d.pai): reservas.append(d.pai)

static func guardar_carga(servico: ServicosPlex, ator: PersonagemPlex) -> bool:
	var item: Dictionary = servico.planta.objetos.get(ator.carga_item, {})
	if item.is_empty():
		ator.carga_item = -1
		return false
	var d := destino(servico, item)
	if d.is_empty(): return false
	return servico.iniciar(ator, "Guardar item utilizado", [servico.etapa(d.pai, "apoiar", .9, {"slot":d.slot})], [d.pai])

static func atualizar_retorno(servico: ServicosPlex, ator: PersonagemPlex, trabalho: Dictionary, passo: Dictionary) -> bool:
	if passo.acao != "devolver" or ator.carga_item < 0: return true
	var item: Dictionary = servico.planta.objetos.get(ator.carga_item,{})
	if item.is_empty() or tipos(item.tipo).is_empty(): return true
	var d := destino(servico,item)
	if d.is_empty():
		var origem: int = item.get("origem_sobre",-1)
		if servico.planta.objetos.has(origem): return true
		return not servico.planta.objetos.values().any(func(o): return o.tipo in tipos(item.tipo))
	var retorno := servico.etapa(d.pai,"apoiar",.9,{"slot":d.slot,"devolucao":true})
	if servico.rota_passo(ator.origem_rota(),retorno).is_empty(): return true
	servico.planta.objetos[d.pai].reserva = ator.identificador
	if not trabalho.reservas.has(d.pai): trabalho.reservas.append(d.pai)
	passo.alvo = retorno.alvo
	passo.acao = retorno.acao
	passo.dados = retorno.dados
	passo.duracao = retorno.duracao
	return true
