class_name PilhasPlex
extends RefCounted

const LIMITE = 4

static func pontos(objeto: Dictionary, planta: PlantaPlex) -> Array:
	var resultado: Array = []
	var altura := 0.2
	for nivel in LIMITE:
		resultado.append({"u":0.0,"v":0.0,"z":altura,"accepts":["caixa"],"capacity":1})
		var caixas: Array = ApoiosPlex.filhos(planta,objeto.id,nivel) if planta != null else []
		altura += ItensPlex.altura(caixas[0].tipo) if not caixas.is_empty() else 9.0
	return resultado

static func aceita(planta: PlantaPlex, pai: int, slot: int) -> bool:
	if slot < 0 or slot >= LIMITE: return false
	if slot == 0: return true
	var abaixo := ApoiosPlex.filhos(planta,pai,slot-1)
	return abaixo.size() == 1 and int(abaixo[0].get("reserva",0)) == 0

static func retiravel(planta: PlantaPlex, id: int) -> bool:
	if not planta.objetos.has(id): return false
	return int(planta.objetos[id].get("carregada_por",0))==0

static func compactar(planta: PlantaPlex, pai: int) -> void:
	if planta.objetos.get(pai,{}).get("tipo","") != "ponto_recebimento": return
	var caixas := ApoiosPlex.filhos(planta,pai)
	caixas.sort_custom(func(a,b): return int(a.get("slot",0)) < int(b.get("slot",0)))
	for i in caixas.size(): caixas[i].slot = i
