class_name KitLimpezaPlex
extends RefCounted

static func fornecer(planta: PlantaPlex, armario: Dictionary) -> void:
	if planta.entrega_embalada: return
	if armario.get("tipo","")!="armario_limpeza" or armario.get("kit_limpeza_fornecido",false): return
	armario.kit_limpeza_fornecido=true
	var inventario:=InventarioPlex.new(planta)
	var bloqueado:=planta.is_blocking_signals()
	planta.set_block_signals(true)
	for tipo in ["vassoura","balde"]:
		if ApoiosPlex.filhos(planta,armario.id).any(func(item): return item.tipo==tipo): continue
		var slot:=ApoiosPlex.livre(planta,armario.id,tipo)
		if slot<0: continue
		var id:=inventario.criar(tipo,armario.celula)
		if not ApoiosPlex.fixar(planta,id,armario.id,slot): planta.objetos.erase(id)
	planta.set_block_signals(bloqueado)
	planta.indice_sujo=true

static func restaurar(planta: PlantaPlex) -> void:
	for item in planta.objetos.values(): fornecer(planta,item)

static func em_uso(planta:PlantaPlex,tipo:String,celulas:Dictionary={}) -> bool:
	for item in planta.objetos.values():
		if item.tipo!=tipo or int(item.get("carregada_por",0))<=0:continue
		var origem:Dictionary=planta.objetos.get(int(item.get("origem_sobre",-1)),{})
		var c:Vector2i=origem.get("celula",item.celula)
		if TerrenoPlex.contem(planta,c) and (celulas.is_empty() or celulas.has(c)):return true
	return false

