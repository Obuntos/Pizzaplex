class_name PortasPlex
extends RefCounted

var atrasos: Dictionary = {}

static func rotacao_para(planta: PlantaPlex, tipo: String, origem: Vector2i, pedida: int, id: int = -1) -> int:
	var melhor := pedida
	var nota_melhor := -1
	for rotacao in [pedida, (pedida + 1) % 4]:
		var ocupadas := planta.celulas(tipo, origem, rotacao)
		var cabe := true
		var nota := 0
		var frente := GradePlex.frente(rotacao)
		var lado := Vector2i(frente.y, -frente.x)
		for c in ocupadas:
			if not GradePlex.dentro(c) or (not planta.em(c).is_empty() and planta.em(c).id != id) or not planta.sobre(c, "luz_chao").is_empty():
				cabe = false
			for d in [lado, -lado]:
				var vizinha: Vector2i = c + d
				if not ocupadas.has(vizinha) and planta.em(vizinha).get("tipo", "") in SalasPlex.ESTRUTURA:
					nota += 1
		if cabe and nota > nota_melhor:
			nota_melhor = nota
			melhor = rotacao
	return melhor

static func normalizar(planta: PlantaPlex) -> bool:
	var mudou := false
	for objeto in planta.objetos.values():
		if objeto.tipo not in CatalogoPlex.PORTAS:
			continue
		var correta := rotacao_para(planta, objeto.tipo, objeto.celula, objeto.rotacao, objeto.id)
		if correta != objeto.rotacao:
			for c in planta.celulas(objeto.tipo, objeto.celula, objeto.rotacao):
				planta.ocupacao.erase(c)
			objeto.rotacao = correta
			for c in planta.celulas(objeto.tipo, objeto.celula, objeto.rotacao):
				planta.ocupacao[c] = objeto.id
			mudou = true
	return mudou

func atravessando(pessoa: Node2D, objeto: Dictionary, planta: PlantaPlex) -> bool:
	var ocupadas := planta.celulas(objeto.tipo, objeto.celula, objeto.rotacao)
	var dimensao := CatalogoPlex.dimensoes(objeto.tipo, objeto.rotacao)
	var centro := Vector2(objeto.celula) + Vector2(dimensao - Vector2i.ONE) * .5
	var frente := Vector2(GradePlex.frente(objeto.rotacao))
	var lado := Vector2(frente.y, -frente.x)
	var local: Vector2 = pessoa.local - centro
	var meia_largura := 1.0 if CatalogoPlex.base(objeto.tipo) == "porta_dupla" else .5
	if absf(local.dot(frente)) < .45 and absf(local.dot(lado)) < meia_largura - .08:
		return true
	var movimento: MovimentoPlex = pessoa.movimento
	if movimento.escala.ativo or movimento.rota.is_empty(): return false
	var proxima: Vector2i = movimento.destino if movimento.atravessando else movimento.rota[0]
	if proxima == pessoa.celula and movimento.rota.size() > 1: proxima = movimento.rota[1]
	if not ocupadas.has(proxima): return false
	var vetor: Vector2 = Vector2(proxima) - pessoa.local
	return absf(vetor.dot(frente)) > .05 and vetor.length() < 1.2

func atualizar(delta: float, planta: PlantaPlex, personagens: Array) -> void:
	for id in atrasos.keys():
		if not planta.objetos.has(id): atrasos.erase(id)
	for objeto in planta.objetos.values():
		if objeto.tipo not in CatalogoPlex.PORTAS: continue
		var id: int = int(objeto.id)
		var em_uso := personagens.any(func(pessoa): return is_instance_valid(pessoa) and atravessando(pessoa, objeto, planta))
		if em_uso: atrasos[id] = .7
		else: atrasos[id] = maxf(0.0, atrasos.get(id, 0.0) - delta)
		objeto.aberta = atrasos.get(id, 0.0) > 0.0

