class_name PasseioAtendimentoPlex
extends RefCounted

static func iniciar(servico: ServicosPlex, ator: PersonagemPlex, delta: float) -> void:
	if ator.funcao != "atendimento" or ator.carga_item >= 0 or ator.carregando: return
	if ator.ocupado(): return
	ator.visita.passeio_espera = maxf(0.0,float(ator.visita.get("passeio_espera",2.0))-delta)
	if ator.visita.passeio_espera > 0.0: return
	var candidatos: Array[Vector2i] = []
	for ambiente in servico.salas.ambientes:
		if not ambiente.operacional or not FuncoesSalaPlex.aceita(ambiente,["salao","recepcao"]): continue
		for c in ambiente.celulas:
			var distancia: float = ator.local.distance_to(Vector2(c))
			if distancia < 2.0 or not servico.planta.transitavel(c) or not servico.planta.em(c).is_empty(): continue
			if GradePlex.VIZINHOS.any(func(d): return servico.planta.em(c+d).get("tipo","") in CatalogoPlex.PORTAS): continue
			if servico.personagens.any(func(a): return a != ator and (a.celula == c or (not a.movimento.rota.is_empty() and a.movimento.rota[-1] == c))): continue
			candidatos.append(c)
	var ciclo := int(ator.visita.get("passeio_ciclo",0))
	var inicio := posmod(ator.identificador*13+ciclo*17,maxi(1,candidatos.size()))
	ator.visita.passeio_ciclo = ciclo+1
	ator.visita.passeio_espera = 3.0+float(posmod(ator.identificador+ciclo,4))
	for i in mini(8,candidatos.size()):
		var alvo := candidatos[(inicio+i)%candidatos.size()]
		var rota := servico.rotas.caminho(ator.origem_rota(),alvo)
		if rota.is_empty() or rota.any(func(c): return servico.planta.altura(c) > 0): continue
		ator.trabalho = "circular_salao"
		ator.andar(rota)
		return

