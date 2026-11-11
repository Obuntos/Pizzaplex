class_name CirculacaoPlex
extends RefCounted

static func tarefa(ator: Node2D) -> bool:
	return bool(ator.get_meta("tarefa_ativa", false)) or ator.carregando or ator.carga_item >= 0 or ator.trabalho not in ["", "descansar"]

static func bloqueios(ator: Node2D, personagens: Array) -> Array[Vector2i]:
	var locais: Array[Vector2i] = []
	for outro in personagens:
		if outro == ator or not is_instance_valid(outro) or PosturaPlex.sentada(outro) or outro.visita.get("morto",false) or outro.visita.get("fora_turno",false): continue
		if not locais.has(outro.celula): locais.append(outro.celula)
		if outro.movimento.atravessando and not locais.has(outro.movimento.destino): locais.append(outro.movimento.destino)
	return locais

static func ocupantes(ator: Node2D, primeiro: Vector2i, destino: Vector2i, personagens: Array) -> Array:
	return personagens.filter(func(outro): return is_instance_valid(outro) and not PosturaPlex.sentada(outro) and not outro.visita.get("morto",false) and not outro.visita.get("fora_turno",false) and outro != ator and (outro.celula in [primeiro, destino] or (outro.movimento.atravessando and outro.movimento.destino in [primeiro, destino])))

static func ceder(ator: Node2D, passante: Node2D, planta: PlantaPlex, rotas: RotasPlex, personagens: Array) -> bool:
	if ator.ocupado() or tarefa(ator) or ator.suporte >= 0 or ator.pose >= 0: return false
	var vetados := bloqueios(ator, personagens)
	var corredor: Array[Vector2i] = passante.movimento.rota
	var melhor: Array[Vector2i] = []
	for y in range(maxi(0,ator.celula.y-2),mini(GradePlex.TAMANHO.y,ator.celula.y+3)):
		for x in range(maxi(0,ator.celula.x-2),mini(GradePlex.TAMANHO.x,ator.celula.x+3)):
			var local := Vector2i(x, y)
			if local == ator.celula or Vector2(local - ator.celula).length_squared() > 4.0: continue
			if vetados.has(local) or corredor.has(local) or not planta.transitavel(local): continue
			if not is_equal_approx(planta.altura(local), ator.altura): continue
			if planta.em(local).get("tipo", "") in (CatalogoPlex.PORTAS + ["escada"]): continue
			var caminho := rotas.caminho(ator.celula, local, vetados)
			if not caminho.is_empty() and (melhor.is_empty() or caminho.size() < melhor.size()): melhor = caminho
	if melhor.is_empty(): return false
	ator.andar(melhor)
	ator.movimento.cedendo = true
	ator.movimento.passante = passante.identificador
	return true

static func liberou(ator: Node2D, personagens: Array) -> bool:
	for outro in personagens:
		if outro.identificador == ator.movimento.passante:
			return not outro.ocupado() or ator.local.distance_to(outro.local) > 1.2
	return true

static func permitir(ator: Node2D, primeiro: Vector2i, destino: Vector2i, planta: PlantaPlex, rotas: RotasPlex, personagens: Array, delta: float) -> bool:
	var outros := ocupantes(ator, primeiro, destino, personagens)
	var movimento: MovimentoPlex = ator.movimento
	if outros.is_empty():
		movimento.bloqueado = 0.0
		movimento.proxima_rota = 0.0
		return true
	movimento.bloqueado += delta
	if movimento.bloqueado < .12: return false
	if str(ator.visita.get("rotina_casa_etapa","")) in ["indo","voltando"]:
		return not outros.any(func(outro): return outro.robo and not outro.ocupado())
	if planta.em(ator.celula).get("tipo", "") == "suporte": return true
	var impedidos := bloqueios(ator,personagens)
	for limite in ator.get_meta("limites_rota",[]):
		if not impedidos.has(limite): impedidos.append(limite)
	if movimento.bloqueado>=movimento.proxima_rota:
		movimento.proxima_rota=movimento.bloqueado+.35+float(ator.identificador%4)*.025
		var alternativa := rotas.caminho(ator.celula,movimento.rota[-1],impedidos)
		if alternativa.size() > 1 and alternativa[1] != primeiro and alternativa.size() <= movimento.rota.size() + 4:
			ator.andar(alternativa)
			return false
	if outros.any(func(outro): return outro.robo and not outro.ocupado()): return false
	if tarefa(ator):
		movimento.bloqueado = 0.0
		return true
	for outro in outros:
		if ceder(outro, ator, planta, rotas, personagens): return false
	if movimento.bloqueado >= .65:
		var tem_prioridade := true
		for outro in outros:
			if tarefa(outro) or (outro.ocupado() and outro.identificador < ator.identificador): tem_prioridade = false
		if tem_prioridade:
			movimento.bloqueado = 0.0
			return true
	return false

