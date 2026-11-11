class_name SubstituicaoParedesPlex
extends RefCounted

static func estrutural(item: Dictionary) -> bool:
	return item.get("tipo","") in SalasPlex.ESTRUTURA or CatalogoPlex.base(str(item.get("tipo","")))=="parede" or AcabamentoEsquadriasPlex.eh(item)

static func antigas(planta: PlantaPlex, novas: Array[Vector2i]) -> Array[Dictionary]:
	var resultado: Array[Dictionary]=[]
	for item in planta.objetos.values():
		if not estrutural(item) and not LuminariasPlex.eh(str(item.tipo)): continue
		for c in planta.celulas(item.tipo,item.celula,item.rotacao):
			if novas.has(c):
				resultado.append(item)
				break
	return resultado

static func permite(planta: PlantaPlex, tipo: String, celula: Vector2i, rotacao: int=0) -> bool:
	if not estrutural({"tipo":CatalogoPlex.objetos.get(tipo,{}).get("logico",tipo)}): return false
	var direcao:=PortasPlex.rotacao_para(planta,tipo,celula,rotacao) if PortasPlex.ajusta(str(tipo)) else rotacao
	if not TerrenoPlex.cabe(planta,tipo,celula,direcao) or not planta.construcao_limpa(tipo,celula,direcao): return false
	var novas:=planta.celulas(tipo,celula,direcao)
	var lista:=antigas(planta,novas)
	if lista.is_empty(): return false
	for c in novas:
		var item:=planta.em(c)
		if not item.is_empty() and not estrutural(item): return false
		if planta.reservas_abertura.has(c) and not estrutural(planta.objetos.get(int(planta.reservas_abertura[c]),{})): return false
	for item in lista:
		if int(item.get("reserva",0))>0: return false
		for c in planta.celulas(item.tipo,item.celula,item.rotacao):
			if not TerrenoPlex.contem(planta,c): return false
	return true

static func aplicar(planta: PlantaPlex, tipo: String, celula: Vector2i, rotacao: int, estado: String) -> int:
	if not permite(planta,tipo,celula,rotacao): return -1
	var direcao:=PortasPlex.rotacao_para(planta,tipo,celula,rotacao) if PortasPlex.ajusta(str(tipo)) else rotacao
	var novas:=planta.celulas(tipo,celula,direcao)
	var anteriores:=antigas(planta,novas)
	var sobras: Dictionary={}
	var entrada:=false
	for item in anteriores:
		entrada=entrada or bool(item.get("entrada_clientes",false))
		for outra in planta.celulas(item.tipo,item.celula,item.rotacao):
			if not novas.has(outra): sobras[outra]=item.rotacao
	var bloqueado:=planta.is_blocking_signals()
	planta.set_block_signals(true)
	for item in anteriores: planta.remover(item.id)
	for c in sobras: planta.inserir("parede",c,int(sobras[c]),{})
	var id:=planta.inserir(tipo,celula,direcao,{})
	var novo: Dictionary=planta.objetos[id]
	if tipo in CatalogoPlex.PORTAS: novo.entrada_clientes=entrada or TerrenoPlex.borda(planta,celula)
	if CatalogoPlex.objetos[tipo].get("estados",[]).has(estado):
		novo.estado_visual=estado
		if not novo.has("variante"): novo.estado=estado
	planta.reindexar()
	planta.set_block_signals(bloqueado)
	if not bloqueado: planta.alterada.emit()
	return id
