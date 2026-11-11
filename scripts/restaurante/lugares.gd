class_name LugaresPlex
extends RefCounted

static func mesa(tipo: String) -> bool:
	return CatalogoPlex.base(tipo) == "mesa"

static func cadeira_refeicao(item:Dictionary) -> bool:
	return item.get("tipo","")=="cadeira" and not MobiliaPlex.visual(item).begins_with("oficina_cadeira_escritorio_")

static func posicoes(objeto: Dictionary) -> Array:
	var resultado: Array = []
	var assentos: Array = CatalogoPlex.objetos.get(objeto.tipo, {}).get("assentos", [])
	if assentos.is_empty():
		for lado in GradePlex.VIZINHOS: resultado.append({"celula":objeto.celula + lado, "frente":-lado})
		return resultado
	var dimensao := CatalogoPlex.dimensoes(objeto.tipo, objeto.rotacao)
	var centro := Vector2(objeto.celula) + Vector2(dimensao - Vector2i.ONE) * .5
	for p in assentos:
		var local := centro + GradePlex.girar(Vector2(p.u, p.v), objeto.rotacao)
		var frente := GradePlex.girar(Vector2(p.frente[0], p.frente[1]), objeto.rotacao)
		resultado.append({"celula":Vector2i(local.round()), "frente":Vector2i(frente)})
	return resultado

static func cadeiras(planta: PlantaPlex, objeto: Dictionary) -> Array[int]:
	var resultado: Array[int] = []
	for p in posicoes(objeto):
		var cadeira: Dictionary = planta.em(p.celula) if planta != null else {}
		resultado.append(int(cadeira.id) if cadeira_refeicao(cadeira) and GradePlex.frente(cadeira.rotacao) == p.frente else -1)
	return resultado

static func ativo(planta: PlantaPlex, id: int, slot: int) -> bool:
	if not planta.objetos.has(id): return false
	var assentos := cadeiras(planta, planta.objetos[id])
	return slot >= 0 and slot < assentos.size() and assentos[slot] >= 0

static func total(planta: PlantaPlex, id: int) -> int:
	return cadeiras(planta, planta.objetos[id]).filter(func(valor): return valor >= 0).size() if planta.objetos.has(id) else 0

static func acessos(planta: PlantaPlex, objeto: Dictionary) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	for ocupada in planta.celulas(objeto.tipo, objeto.celula, objeto.rotacao):
		for x in range(-1, 2):
			for y in range(-1, 2):
				var c: Vector2i = ocupada + Vector2i(x, y)
				if planta.transitavel(c) and is_zero_approx(planta.altura(c)) and not resultado.has(c): resultado.append(c)
	return resultado

static func retirar(planta: PlantaPlex, id: int) -> void:
	for filho in ApoiosPlex.filhos(planta, id): retirar(planta, filho.id)
	planta.objetos.erase(id)

static func sincronizar(planta: PlantaPlex) -> void:
	for objeto in planta.objetos.values():
		if not mesa(objeto.tipo) or objeto.get("mesa_cozinha",false): continue
		var assentos := cadeiras(planta, objeto)
		var usados: Array[int] = []
		var pendentes: Array = []
		for prato in ApoiosPlex.filhos(planta, objeto.id):
			if prato.tipo != "prato": continue
			var cadeira: int = prato.get("cadeira", -1)
			var slot := assentos.find(cadeira) if cadeira >= 0 else -1
			if slot >= 0 and not usados.has(slot):
				prato.slot = slot
				usados.append(slot)
			elif cadeira >= 0: retirar(planta, prato.id)
			else: pendentes.append(prato)
		for prato in pendentes:
			var slot: int = prato.get("slot", -1)
			if slot < 0 or slot >= assentos.size() or assentos[slot] < 0 or usados.has(slot):
				slot = -1
				for i in assentos.size():
					if assentos[i] >= 0 and not usados.has(i):
						slot = i
						break
			if slot < 0: retirar(planta, prato.id)
			else:
				prato.slot = slot
				prato.cadeira = assentos[slot]
				usados.append(slot)
