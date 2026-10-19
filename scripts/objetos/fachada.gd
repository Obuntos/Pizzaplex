class_name FachadaPlex
extends RefCounted

static func estado(planta: PlantaPlex, item: Dictionary) -> String:
	if not str(item.tipo).begins_with("janela"): return str(item.get("estado", ""))
	var frente := GradePlex.frente(item.rotacao)
	var lado := Vector2i(frente.y, -frente.x)
	var antes := false
	var depois := false
	var ocupadas := planta.celulas(item.tipo, item.celula, item.rotacao)
	for celula in ocupadas:
		for sinal in [-1, 1]:
			var vizinha: Vector2i = celula + lado * sinal
			if ocupadas.has(vizinha): continue
			var outro := planta.em(vizinha)
			if str(outro.get("tipo", "")).begins_with("janela") and int(outro.rotacao) % 2 == int(item.rotacao) % 2:
				if sinal < 0: antes = true
				else: depois = true
	return "meio" if antes and depois else "inicio" if depois else "fim" if antes else "isolada"

static func corrigir_decoracao(planta: PlantaPlex) -> void:
	var estantes: Array = planta.objetos.values().filter(func(o): return CatalogoPlex.base(o.tipo)=="estante")
	for item in planta.objetos.values():
		if not str(item.tipo).begins_with("presente_"): continue
		var pai: int = item.get("sobre",-1)
		if pai<0 or not ApoiosPlex.filhos(planta,pai).any(func(f): return f.tipo in ["terminal_ibm","registradora"]): continue
		var transferido := false
		for estante in estantes:
			var slot := ApoiosPlex.livre(planta,estante.id,item.tipo)
			if slot>=0 and ApoiosPlex.fixar(planta,item.id,estante.id,slot):
				transferido=true
				break
		if transferido: continue
		for d in GradePlex.VIZINHOS:
			var c: Vector2i=item.celula+d
			if planta.transitavel(c) and is_zero_approx(planta.altura(c)):
				item.sobre=-1
				item.slot=-1
				item.celula=c
				break
