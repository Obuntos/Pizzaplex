class_name CabinesPlex
extends RefCounted

static func celulas(planta: PlantaPlex, cabine: Dictionary) -> Array[Vector2i]:
	return planta.celulas("divisoria_porta", cabine.celula, cabine.rotacao)

static func em(planta: PlantaPlex, celula: Vector2i) -> Dictionary:
	return planta.objetos.get(planta.cabines_por_celula.get(celula, -1), {})

static func fundo(planta: PlantaPlex, cabine: Dictionary) -> Vector2i:
	var ocupadas := celulas(planta, cabine)
	var frente := Vector2(GradePlex.frente(cabine.rotacao))
	ocupadas.sort_custom(func(a, b): return Vector2(a).dot(frente) < Vector2(b).dot(frente))
	return ocupadas[0]

static func entrada(planta: PlantaPlex, cabine: Dictionary) -> Vector2i:
	return fundo(planta, cabine) + GradePlex.frente(cabine.rotacao)

static func permite(planta: PlantaPlex, a: Vector2i, b: Vector2i) -> bool:
	for local in [a, b]:
		var cabine := em(planta, local)
		if cabine.is_empty(): continue
		var normal := GradePlex.frente(cabine.rotacao)
		if a - b != normal and b - a != normal: return false
	return true

static func atualizar(planta: PlantaPlex, personagens: Array) -> void:
	var alterou := false
	for cabine in planta.objetos.values():
		if cabine.tipo != "divisoria_porta": continue
		var passagem := entrada(planta, cabine)
		var fora := passagem + GradePlex.frente(cabine.rotacao)
		var abrir := false
		for ator in personagens:
			if ator.trabalho == "usar_vaso" and cabine.reserva == ator.identificador: continue
			if ator.celula == passagem:
				abrir = true
			elif ator.celula == fora:
				var proxima: Vector2i = ator.movimento.destino if ator.movimento.atravessando else (ator.movimento.rota[0] if not ator.movimento.rota.is_empty() else ator.celula)
				abrir = abrir or proxima == passagem
		var estado := "aberta" if abrir else "fechada"
		if cabine.estado != estado:
			cabine.estado = estado
			alterou = true
	if alterou: planta.alterada.emit()
