class_name LuminariasPlex
extends RefCounted

static func rotacao_parede(objeto: Dictionary, planta: PlantaPlex, salas: Dictionary = {}) -> int:
	var opcoes: Array[int] = []
	var interiores: Array[int] = []
	for rotacao in 4:
		var vizinha: Vector2i = objeto.celula + GradePlex.frente(rotacao)
		if GradePlex.dentro(vizinha) and planta.em(vizinha).get("tipo", "") not in SalasPlex.ESTRUTURA:
			opcoes.append(rotacao)
			if salas.has(vizinha):
				interiores.append(rotacao)
	var direcoes: Array[int] = interiores if not interiores.is_empty() else opcoes
	if direcoes.is_empty() or direcoes.has(int(objeto.rotacao)):
		return objeto.rotacao
	for preferida in [0, 3, 2, 1]:
		if direcoes.has(preferida):
			return preferida
	return objeto.rotacao

static func montagem_parede(objeto: Dictionary, planta: PlantaPlex, salas: Dictionary = {}) -> Dictionary:
	var rotacao := rotacao_parede(objeto, planta, salas)
	var frente := Vector2(GradePlex.frente(rotacao))
	var deslocamento := frente * .56
	var vizinha: Vector2i = objeto.celula + GradePlex.frente(rotacao)
	if not GradePlex.dentro(vizinha) or planta.em(vizinha).get("tipo", "") in SalasPlex.ESTRUTURA:
		var nota_melhor := -1e20
		for diagonal in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var local: Vector2i = objeto.celula + diagonal
			if not GradePlex.dentro(local) or planta.em(local).get("tipo", "") in SalasPlex.ESTRUTURA:
				continue
			var nota: float = (10.0 if salas.has(local) else 0.0) + Vector2(diagonal).normalized().dot(Vector2(GradePlex.frente(objeto.rotacao)))
			if nota > nota_melhor:
				nota_melhor = nota
				frente = Vector2(diagonal).normalized()
				deslocamento = Vector2(diagonal) * .56
	return {"rotacao": rotacao, "frente": frente, "deslocamento": deslocamento}

static func especificacao(objeto: Dictionary, planta: PlantaPlex, salas: Dictionary = {}, em_mundo: bool = false) -> Dictionary:
	var celula := Vector2(objeto.celula)
	var altura := planta.altura(objeto.celula)
	var ponto := GradePlex.projetar_local(celula) if em_mundo else GradePlex.projetar(celula)
	var posicao := Vector3(ponto.x, ponto.y * 2.0, altura + 2.0)
	var direcao := Vector3(0, 0, 1)
	var alcance := 180.0
	var cone := -1.0
	if objeto.tipo == "luz_teto":
		posicao.z = altura + 140.0
		direcao = Vector3(0, 0, -1)
		alcance = 270.0
		cone = -0.15
	elif objeto.tipo == "luz_parede":
		var montagem := montagem_parede(objeto, planta, salas)
		var frente := GradePlex.projetar_local(montagem.deslocamento) if em_mundo else GradePlex.projetar_vetor(montagem.deslocamento)
		posicao += Vector3(frente.x, frente.y * 2.0, 72.0 - altura - 2.0)
		direcao = Vector3(frente.x, frente.y * 2.0, -22.0).normalized()
		alcance = 220.0
		cone = -0.35
	var potencia := float(objeto.get("energia", 1.2)) * (1.6 if objeto.tipo == "luz_chao" else 1.0)
	return {"posicao": posicao, "direcao": direcao, "alcance": alcance, "cone": cone, "cor": Color(objeto.get("cor_luz", "#fff0d5")), "energia": potencia}
