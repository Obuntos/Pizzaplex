class_name FornoPlex
extends RefCounted

const DURACAO = 6.0

static func eh(objeto: Dictionary) -> bool:
	if objeto.is_empty(): return false
	return objeto.get("tipo","")=="forno" or MobiliaPlex.dados(objeto).get("uso","") in ["aquecer","assar_pizza"]

static func capacidade(objeto: Dictionary) -> int:
	return 2 if objeto.get("tipo","")=="forno" else 1 if eh(objeto) else 0

static func estado(objeto: Dictionary, funcionando: bool) -> void:
	objeto.estado=("funcionando" if funcionando else "fechado") if objeto.tipo=="forno" else ("aceso" if funcionando else "apagado")

static func acessos(planta: PlantaPlex, id: int) -> Array[Vector2i]:
	var objeto: Dictionary=planta.objetos.get(id,{})
	if objeto.get("tipo","")=="forno": return planta.interacoes_estado(id,"aberto")
	var resultado: Array[Vector2i]=[]
	if not eh(objeto): return resultado
	var ponto:=PontosUsoPlex.frente(objeto)
	if planta.transitavel(ponto) and is_zero_approx(planta.altura(ponto)): resultado.append(ponto)
	return resultado

static func pontos(objeto: Dictionary) -> Array:
	if capacidade(objeto)==1: return [{"u":0.0,"v":0.0,"z":float(MobiliaPlex.dados(objeto).get("altura",35)),"accepts":["pizza"],"capacity":1}]
	var frente := Vector2(GradePlex.frente(objeto.rotacao))
	var lado := Vector2(frente.y,-frente.x)
	var resultado: Array = []
	for posicao in [-.23,.23]:
		resultado.append({"u":lado.x*posicao,"v":lado.y*posicao,"z":15.0,"accepts":["pizza"],"capacity":1})
	return resultado

static func vaga(planta: PlantaPlex, id: int) -> int:
	var forno: Dictionary = planta.objetos.get(id,{})
	for slot in capacidade(forno):
		if not forno.get("reservas_forno",{}).has(str(slot)) and ApoiosPlex.aceita(planta,id,"pizza",slot): return slot
	return -1

static func reservar(forno: Dictionary, slot: int, pedido: int) -> void:
	if not forno.has("reservas_forno"): forno.reservas_forno = {}
	forno.reservas_forno[str(slot)] = pedido

static func liberar(planta: PlantaPlex, pedido: int) -> void:
	for forno in planta.objetos.values():
		if not eh(forno): continue
		var reservas: Dictionary = forno.get("reservas_forno",{})
		for slot in reservas.keys():
			if int(reservas[slot])==pedido: reservas.erase(slot)

static func tempo(planta: PlantaPlex, pedido: Dictionary) -> float:
	var pizza: Dictionary = planta.objetos.get(pedido.get("pizza",-1),{})
	if pizza.is_empty(): return 0.0
	return float(pizza.get("tempo_assar",planta.objetos.get(pizza.get("sobre",-1),{}).get("tempo_assar",0.0)))

static func fechar(planta: PlantaPlex, forno: Dictionary) -> void:
	if not eh(forno):return
	var restante := 0.0
	for pizza in ApoiosPlex.filhos(planta,forno.id):
		if pizza.tipo=="pizza": restante = maxf(restante,float(pizza.get("tempo_assar",0.0)))
	forno.tempo_assar = restante
	estado(forno,restante>0)

static func atualizar(servicos: ServicosPlex, delta: float) -> void:
	for forno in servicos.planta.objetos.values():
		if not eh(forno): continue
		var mudou := false
		var restante := 0.0
		for pizza in ApoiosPlex.filhos(servicos.planta,forno.id):
			if pizza.tipo!="pizza": continue
			if not pizza.has("tempo_assar"): pizza.tempo_assar = float(forno.get("tempo_assar",0.0))
			var antes := float(pizza.tempo_assar)
			pizza.tempo_assar = maxf(0,antes-delta)
			restante = maxf(restante,pizza.tempo_assar)
			if pizza.tempo_assar<=0:
				if antes>0:forno.pizzas_feitas=int(forno.get("pizzas_feitas",0))+1
				for pedido in servicos.pedidos:
					if pedido.pizza==pizza.id and pedido.estado=="assando":pedido.estado="pronta";mudou=true
		forno.tempo_assar = restante
		if mudou:
			if forno.estado!="aberto": fechar(servicos.planta,forno)
			servicos.planta.alterada.emit()

