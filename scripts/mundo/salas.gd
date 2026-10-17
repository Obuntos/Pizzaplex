class_name SalasPlex
extends RefCounted

const ESTRUTURA = ["parede", "porta", "porta_dupla"]

static func ambiente_com_portas(planta: PlantaPlex, salas: Dictionary) -> Dictionary:
	var resultado := salas.duplicate()
	for porta in planta.objetos.values():
		if porta.tipo not in ["porta", "porta_dupla"]: continue
		var ocupadas := planta.celulas(porta.tipo, porta.celula, porta.rotacao)
		var frente := GradePlex.frente(porta.rotacao)
		var interna := false
		for celula in ocupadas:
			interna = interna or salas.has(celula + frente) or salas.has(celula - frente)
		if interna:
			for celula in ocupadas:
				resultado[celula] = true
	return resultado

static func mapa_ambiente(salas: Dictionary) -> Image:
	var imagem := Image.create_empty(GradePlex.TAMANHO.x, GradePlex.TAMANHO.y, false, Image.FORMAT_RGBA8)
	for y in GradePlex.TAMANHO.y:
		for x in GradePlex.TAMANHO.x:
			var interna := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					interna = interna or salas.has(Vector2i(x + dx, y + dy))
			imagem.set_pixel(x, y, Color(0, 1.0 if salas.has(Vector2i(x, y)) else 0.0, 1.0 if interna else 0.0, 0))
	return imagem

static func fechadas(planta: PlantaPlex) -> Dictionary:
	var exteriores: Dictionary = {}
	var fila: Array[Vector2i] = []
	for y in GradePlex.TAMANHO.y:
		for x in GradePlex.TAMANHO.x:
			var c := Vector2i(x, y)
			if (x == 0 or y == 0 or x == GradePlex.TAMANHO.x - 1 or y == GradePlex.TAMANHO.y - 1) and planta.em(c).get("tipo", "") not in ESTRUTURA:
				exteriores[c] = true
				fila.append(c)
	var indice := 0
	while indice < fila.size():
		var c := fila[indice]
		indice += 1
		for direcao in GradePlex.VIZINHOS:
			var vizinha: Vector2i = c + direcao
			if GradePlex.dentro(vizinha) and not exteriores.has(vizinha) and planta.em(vizinha).get("tipo", "") not in ESTRUTURA:
				exteriores[vizinha] = true
				fila.append(vizinha)
	var resultado: Dictionary = {}
	for y in GradePlex.TAMANHO.y:
		for x in GradePlex.TAMANHO.x:
			var c := Vector2i(x, y)
			if not exteriores.has(c) and planta.em(c).get("tipo", "") not in ESTRUTURA:
				resultado[c] = true
	return resultado
