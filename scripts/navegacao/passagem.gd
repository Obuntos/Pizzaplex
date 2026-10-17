class_name PassagemPlex
extends RefCounted

static func bloqueios(ator: PersonagemPlex, personagens: Array, trajetos: bool = false) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	for outro in personagens:
		if outro == ator: continue
		resultado.append(outro.celula)
		if outro.movimento.atravessando: resultado.append(outro.movimento.destino)
		if trajetos and outro.identificador == ator.movimento.passante:
			resultado.append_array(outro.movimento.rota)
	return resultado

static func ceder(ator: PersonagemPlex, passante: PersonagemPlex, planta: PlantaPlex, rotas: RotasPlex, personagens: Array) -> bool:
	if ator.movimento.cedendo or ator.movimento.atravessando or ator.suporte >= 0 or ator.pose >= 0: return false
	var vetadas := bloqueios(ator,personagens)
	var corredor: Array[Vector2i] = passante.movimento.rota.duplicate()
	corredor.append(passante.celula)
	var melhor: Array[Vector2i] = []
	for y in GradePlex.TAMANHO.y:
		for x in GradePlex.TAMANHO.x:
			var c := Vector2i(x,y)
			if c == ator.celula or corredor.has(c) or vetadas.has(c): continue
			if not planta.transitavel(c) or not is_zero_approx(planta.altura(c)): continue
			if planta.em(c).get("tipo","") in ["porta","porta_dupla","escada"]: continue
			var caminho := rotas.caminho(ator.celula,c,vetadas)
			if not caminho.is_empty() and (melhor.is_empty() or caminho.size()<melhor.size()): melhor = caminho
	if melhor.is_empty(): return false
	ator.movimento.retomar = ator.movimento.rota[-1] if not ator.movimento.rota.is_empty() else ator.celula
	ator.movimento.passante = passante.identificador
	ator.movimento.iniciar(ator,melhor)
	ator.movimento.cedendo = true
	return true
