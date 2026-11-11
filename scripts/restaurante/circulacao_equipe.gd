class_name CirculacaoEquipePlex
extends RefCounted

static func bloqueios(servico: ServicosPlex, ator: PersonagemPlex, origem: Vector2i) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	if not is_instance_valid(ator) or not TerrenoPlex.contem(servico.planta,origem): return resultado
	for porta in servico.planta.objetos.values():
		if porta.tipo not in CatalogoPlex.PORTAS: continue
		var normal := GradePlex.frente(porta.rotacao)
		for celula in servico.planta.celulas(porta.tipo,porta.celula,porta.rotacao):
			var lado_a: bool=servico.salas.em(celula+normal).get("fechada",false)
			var lado_b: bool=servico.salas.em(celula-normal).get("fechada",false)
			if lado_a!=lado_b and not resultado.has(celula): resultado.append(celula)
	return resultado

static func retornar(servico: ServicosPlex, ator: PersonagemPlex) -> bool:
	if ator.funcao!="cozinha" or ator.ocupado() or ator.carga_item>=0 or ator.carregando: return false
	var atual := servico.salas.em(ator.celula)
	var limites := bloqueios(servico,ator,ator.origem_rota())
	var equipamentos: Array=servico.planta.objetos.values().filter(func(item): return item.tipo in ["forno","bancada_preparo","geladeira"] or MobiliaPlex.dados(item).get("uso","")=="aquecer")
	var melhor: Array[Vector2i] = []
	for item in equipamentos:
		var sala := servico.salas.do_objeto(item.id)
		if not sala.get("fechada",false): continue
		if atual.get("id",-1)==sala.id: return false
		for destino in servico.planta.interacoes(item.id):
			if not sala.celulas.has(destino) or servico.personagens.any(func(outro): return outro!=ator and outro.celula==destino): continue
			var rota := servico.rotas.caminho(ator.origem_rota(),destino,limites)
			if not rota.is_empty() and (melhor.is_empty() or rota.size()<melhor.size()): melhor=rota
	if melhor.is_empty(): return false
	ator.trabalho="voltar_cozinha"
	ator.set_meta("limites_rota",limites)
	ator.andar(melhor)
	return true
