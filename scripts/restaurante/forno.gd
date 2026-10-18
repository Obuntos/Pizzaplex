class_name FornoPlex
extends RefCounted

const DURACAO = 6.0

static func pontos(objeto: Dictionary) -> Array:
	var frente := Vector2(GradePlex.frente(objeto.rotacao))
	var lado := Vector2(frente.y,-frente.x)
	var resultado: Array = []
	for posicao in [-.23,.23]:
		resultado.append({"u":lado.x*posicao,"v":lado.y*posicao,"z":15.0,"accepts":["pizza"],"capacity":1})
	return resultado

static func vaga(planta: PlantaPlex, id: int) -> int:
	var forno: Dictionary = planta.objetos.get(id,{})
	for slot in 2:
		if not forno.get("reservas_forno",{}).has(str(slot)) and ApoiosPlex.aceita(planta,id,"pizza",slot): return slot
	return -1

static func reservar(forno: Dictionary, slot: int, pedido: int) -> void:
	if not forno.has("reservas_forno"): forno.reservas_forno = {}
	forno.reservas_forno[str(slot)] = pedido

static func liberar(planta: PlantaPlex, pedido: int) -> void:
	for forno in planta.objetos.values():
		if forno.tipo!="forno": continue
		var reservas: Dictionary = forno.get("reservas_forno",{})
		for slot in reservas.keys():
			if int(reservas[slot])==pedido: reservas.erase(slot)

static func tempo(planta: PlantaPlex, pedido: Dictionary) -> float:
	var pizza: Dictionary = planta.objetos.get(pedido.get("pizza",-1),{})
	if pizza.is_empty(): return 0.0
	return float(pizza.get("tempo_assar",planta.objetos.get(pizza.get("sobre",-1),{}).get("tempo_assar",0.0)))

static func fechar(planta: PlantaPlex, forno: Dictionary) -> void:
	var restante := 0.0
	for pizza in ApoiosPlex.filhos(planta,forno.id):
		if pizza.tipo=="pizza": restante = maxf(restante,float(pizza.get("tempo_assar",0.0)))
	forno.tempo_assar = restante
	forno.estado = "funcionando" if restante>0 else "fechado"

static func atualizar(servicos: ServicosPlex, delta: float) -> void:
	for forno in servicos.planta.objetos.values():
		if forno.tipo!="forno": continue
		var mudou := false
		var restante := 0.0
		for pizza in ApoiosPlex.filhos(servicos.planta,forno.id):
			if pizza.tipo!="pizza": continue
			if not pizza.has("tempo_assar"): pizza.tempo_assar = float(forno.get("tempo_assar",0.0))
			var antes := float(pizza.tempo_assar)
			pizza.tempo_assar = maxf(0,antes-delta)
			restante = maxf(restante,pizza.tempo_assar)
			if antes>0 and pizza.tempo_assar<=0:
				for pedido in servicos.pedidos:
					if pedido.pizza==pizza.id and pedido.estado=="assando": pedido.estado = "pronta"
				mudou = true
		forno.tempo_assar = restante
		if mudou:
			if forno.estado!="aberto": fechar(servicos.planta,forno)
			servicos.planta.alterada.emit()
