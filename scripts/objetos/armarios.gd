class_name ArmariosPlex
extends RefCounted

static func armario(tipo: String) -> bool:
	return bool(CatalogoPlex.objetos.get(tipo, {}).get("armazenamento", false))

static func raiz(planta: PlantaPlex, id: int) -> int:
	var pai := ApoiosPlex.raiz(planta, id)
	return pai if armario(planta.objetos.get(pai, {}).get("tipo", "")) else -1

static func estado(planta: PlantaPlex, id: int, aberto: bool) -> void:
	if not planta.objetos.has(id) or not armario(planta.objetos[id].tipo): return
	var valor := "aberto" if aberto else "fechado"
	if planta.objetos[id].estado != valor:
		planta.objetos[id].estado = valor
		planta.alterada.emit()

static func fechar_reservas(planta: PlantaPlex, trabalho: Dictionary) -> void:
	for id in trabalho.get("reservas", []): estado(planta, id, false)
