class_name InventarioPlex
extends RefCounted

var planta: PlantaPlex

func _init(p: PlantaPlex) -> void:
	planta = p

func criar(tipo: String, celula: Vector2i) -> int:
	var id := planta.proximo_id
	planta.proximo_id += 1
	planta.objetos[id] = {"id":id,"tipo":tipo,"celula":celula,"rotacao":0,"estado":CatalogoPlex.objetos[tipo].get("estado_padrao", ""),"sobre":-1,"slot":-1,"carregada_por":0,"reserva":0,"caixa":false,"endo":false,"pecas":0,"montado":false,"robo_saiu":false,"entregue":false,"ligada":true,"cor_luz":"#fff0d5","energia":1.2,"ingredientes":0,"lixo":0}
	return id

func pegar(ator: PersonagemPlex, id: int) -> bool:
	if not planta.objetos.has(id): return false
	if ator.carga_item == id: return true
	if ator.carga_item >= 0 or not PilhasPlex.retiravel(planta,id): return false
	var item: Dictionary = planta.objetos[id]
	item.origem_sobre = item.get("sobre", -1)
	item.origem_slot = item.get("slot", -1)
	item.origem_celula = [item.celula.x, item.celula.y]
	item.sobre = -1
	item.carregada_por = ator.identificador
	ator.carga_item = id
	planta.reindexar()
	planta.alterada.emit()
	return true

func apoiar(ator: PersonagemPlex, pai: int, slot: int) -> bool:
	if ator.carga_item < 0 or not ApoiosPlex.fixar(planta, ator.carga_item, pai, slot): return false
	ator.carga_item = -1
	return true

func devolver(ator: PersonagemPlex) -> bool:
	if not planta.objetos.has(ator.carga_item):
		ator.carga_item = -1
		return true
	var item: Dictionary = planta.objetos[ator.carga_item]
	var pai: int = item.get("origem_sobre", -1)
	var slot: int = item.get("origem_slot", -1)
	if pai >= 0 and apoiar(ator, pai, slot): return true
	if ApoiosPlex.superficie(item.tipo):
		for base in planta.objetos.values():
			var livre := ApoiosPlex.livre(planta, base.id, item.tipo)
			if livre >= 0 and apoiar(ator, base.id, livre): return true
	var origem: Array = item.get("origem_celula", [ator.celula.x, ator.celula.y])
	var celula := Vector2i(origem[0], origem[1])
	if not planta.em(celula).is_empty():
		for vizinha in GradePlex.VIZINHOS:
			if planta.em(ator.celula + vizinha).is_empty() and GradePlex.dentro(ator.celula + vizinha):
				celula = ator.celula + vizinha
				break
	item.celula = celula
	item.sobre = -1
	item.slot = -1
	item.carregada_por = 0
	if not planta.em(celula).is_empty(): item.solto = true
	ator.carga_item = -1
	planta.reindexar()
	planta.alterada.emit()
	return true

func caixas(recurso: String = "") -> Array:
	return planta.objetos.values().filter(func(item): return item.tipo.begins_with("caixa") and item.get("carregada_por", 0) == 0 and item.get("quantidade", 1) > 0 and item.get("reserva", 0) == 0 and PilhasPlex.retiravel(planta,item.id) and (recurso.is_empty() or item.get("recurso", "pecas") == recurso))

func consumir_caixa(id: int, quantidade: int = 1) -> bool:
	if not planta.objetos.has(id) or planta.objetos[id].get("quantidade", 0) < quantidade: return false
	planta.objetos[id].quantidade -= quantidade
	if planta.objetos[id].quantidade == 0: planta.remover(id)
	else: planta.alterada.emit()
	return true
