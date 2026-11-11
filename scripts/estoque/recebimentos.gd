class_name RecebimentosPlex
extends RefCounted

static func interno(planta: PlantaPlex, ponto: Dictionary) -> bool:
	if ponto.get("tipo","")!="ponto_recebimento": return false
	for c in planta.celulas(ponto.tipo,ponto.celula,ponto.rotacao):
		if not TerrenoPlex.contem(planta,c) or TerrenoPlex.borda(planta,c): return false
	return true

static func acessos(planta: PlantaPlex, ponto: Dictionary) -> Array[Vector2i]:
	var resultado: Array[Vector2i]=[]
	if interno(planta,ponto):
		for c in planta.interacoes(ponto.id):
			if TerrenoPlex.contem(planta,c) and not TerrenoPlex.borda(planta,c): resultado.append(c)
	return resultado

static func corrigir(planta: PlantaPlex) -> void:
	var mudou:=false
	for ponto in planta.objetos.values():
		if ponto.tipo!="ponto_recebimento" or interno(planta,ponto): continue
		var candidatos: Array[Vector2i]=[]
		var area:=TerrenoPlex.area(planta).grow(-1)
		for y in range(area.position.y,area.end.y):
			for x in range(area.position.x,area.end.x):
				var c:=Vector2i(x,y)
				if planta.pode_colocar(ponto.tipo,c,ponto.rotacao): candidatos.append(c)
		candidatos.sort_custom(func(a,b): return a.distance_squared_to(ponto.celula)<b.distance_squared_to(ponto.celula))
		var original: Vector2i=ponto.celula
		var realocado:=false
		for c in candidatos:
			ponto.celula=c
			if acessos(planta,ponto).is_empty(): continue
			for filho in ApoiosPlex.filhos(planta,ponto.id): filho.celula=c
			mudou=true
			realocado=true
			break
		if not realocado: ponto.celula=original
	if mudou: planta.reindexar()
