class_name LugaresPlex
extends RefCounted

static func cadeiras(planta: PlantaPlex, mesa: Dictionary) -> Array[int]:
	var resultado: Array[int] = [-1,-1,-1,-1]
	if planta==null: return resultado
	for i in 4:
		var lado: Vector2i = GradePlex.VIZINHOS[i]
		var cadeira := planta.em(mesa.celula+lado)
		if cadeira.get("tipo","")=="cadeira" and GradePlex.frente(cadeira.rotacao)==-lado: resultado[i]=cadeira.id
	return resultado

static func ativo(planta: PlantaPlex, mesa: int, slot: int) -> bool:
	return planta.objetos.has(mesa) and slot>=0 and slot<4 and cadeiras(planta,planta.objetos[mesa])[slot]>=0

static func total(planta: PlantaPlex, mesa: int) -> int:
	return cadeiras(planta,planta.objetos[mesa]).filter(func(id): return id>=0).size() if planta.objetos.has(mesa) else 0

static func retirar(planta: PlantaPlex, id: int) -> void:
	for filho in ApoiosPlex.filhos(planta,id): retirar(planta,filho.id)
	planta.objetos.erase(id)

static func sincronizar(planta: PlantaPlex) -> void:
	for mesa in planta.objetos.values():
		if mesa.tipo!="mesa": continue
		var assentos := cadeiras(planta,mesa)
		var usados: Array[int] = []
		var pendentes: Array = []
		for prato in ApoiosPlex.filhos(planta,mesa.id):
			if prato.tipo!="prato": continue
			var cadeira: int = prato.get("cadeira",-1)
			var slot := assentos.find(cadeira) if cadeira>=0 else -1
			if slot>=0 and not usados.has(slot):
				prato.slot=slot
				usados.append(slot)
			elif cadeira>=0: retirar(planta,prato.id)
			else: pendentes.append(prato)
		for prato in pendentes:
			var slot: int = prato.get("slot",-1)
			if slot<0 or slot>=4 or assentos[slot]<0 or usados.has(slot):
				slot=-1
				for i in 4:
					if assentos[i]>=0 and not usados.has(i):
						slot=i
						break
			if slot<0: retirar(planta,prato.id)
			else:
				prato.slot=slot
				prato.cadeira=assentos[slot]
				usados.append(slot)
