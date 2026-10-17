class_name ApoiosPlex
extends RefCounted

static var definicoes: Dictionary = {}

static func carregar() -> void:
	if definicoes.is_empty():
		definicoes = JSON.parse_string(FileAccess.get_file_as_string("res://dados/funcoes_objetos.json"))

static func superficie(tipo: String) -> bool:
	return bool(CatalogoPlex.objetos.get(tipo, {}).get("apoio", false))

static func categoria(tipo: String) -> String:
	if tipo.begins_with("caixa"): return "caixa"
	return tipo.replace("_", "-")

static func pontos(objeto: Dictionary, planta: PlantaPlex = null) -> Array:
	carregar()
	if objeto.tipo == "ponto_recebimento": return PilhasPlex.pontos(objeto,planta)
	if objeto.tipo=="mesa":
		var resultado: Array = []
		var assentos := LugaresPlex.cadeiras(planta,objeto)
		for i in 4:
			var lado: Vector2i = GradePlex.VIZINHOS[i]
			resultado.append({"u":lado.x*.22,"v":lado.y*.22,"z":30.0,"cadeira":assentos[i],"accepts":["prato","pizza","fatia-pizza","copo-bebida","restos-mesa","bandeja"],"capacity":1})
		resultado.append({"u":0.0,"v":0.0,"z":30.8,"accepts":["dinheiro"],"capacity":1})
		resultado.append({"u":0.0,"v":0.0,"z":30.0,"accepts":["terminal-ibm"],"capacity":1})
		return resultado
	if objeto.tipo == "forno":
		return [{"u":0.0,"v":0.0,"z":15.0,"accepts":["pizza"],"capacity":1}]
	if definicoes.has(objeto.tipo):
		var definicao: Dictionary = definicoes[objeto.tipo]
		var estado: String = objeto.get("estado", CatalogoPlex.objetos[objeto.tipo].get("estado_padrao", "padrao"))
		if ArmariosPlex.armario(objeto.tipo): estado = "aberto"
		var apoios: Array = definicao.estados.get(estado, definicao.estados.values()[0])[objeto.rotacao].apoios.duplicate(true)
		var fator := ItensPlex.escala(objeto.tipo)
		for p in apoios:
			p.u *= fator
			p.v *= fator
			p.z *= fator
		if objeto.tipo=="pia":
			for p in apoios: p.z=32.0
		return apoios
	var altura := 29.0 if objeto.tipo == "mesa" else 31.0
	if objeto.tipo in ["mesa", "balcao", "bancada"]:
		var frente := Vector2(GradePlex.frente(objeto.rotacao))
		var lado := Vector2(frente.y, -frente.x)
		var resultado: Array = []
		for u in ([-.23,.23] if objeto.tipo == "mesa" else [-.5, .5]):
			var local: Vector2 = lado * u
			resultado.append({"u":local.x,"v":local.y,"z":altura,"accepts":["terminal-ibm","registradora","pizza","fatia-pizza","copo-bebida","prato","bandeja","caixa-ferramentas","pecas-manutencao","restos-mesa"],"capacity":1})
		resultado.append({"u":0.0,"v":0.0,"z":30.8,"accepts":["dinheiro"],"capacity":1})
		return resultado
	if objeto.tipo == "forno":
		return [{"u":0.0,"v":0.0,"z":15.0,"accepts":["pizza"],"capacity":1}]
	return []

static func filhos(planta: PlantaPlex, pai: int, slot: int = -1) -> Array:
	return planta.objetos.values().filter(func(item): return item.get("sobre", -1) == pai and (slot < 0 or item.get("slot", -1) == slot) and item.get("carregada_por", 0) == 0)

static func aceita(planta: PlantaPlex, pai: int, tipo: String, slot: int) -> bool:
	if not planta.objetos.has(pai): return false
	var filhos_atuais := filhos(planta,pai)
	if planta.objetos[pai].tipo == "mesa":
		if tipo == "terminal_ibm" and not filhos_atuais.is_empty(): return false
		if tipo != "terminal_ibm" and filhos_atuais.any(func(f): return f.tipo == "terminal_ibm"): return false
	var apoios := pontos(planta.objetos[pai],planta)
	if slot < 0 or slot >= apoios.size(): return false
	if planta.objetos[pai].tipo == "ponto_recebimento" and not PilhasPlex.aceita(planta,pai,slot): return false
	if planta.objetos[pai].tipo=="mesa" and tipo not in ["dinheiro","terminal_ibm"] and not LugaresPlex.ativo(planta,pai,slot): return false
	var permitidos: Array = apoios[slot].accepts
	return (permitidos.has(categoria(tipo)) or (tipo == "copo_bebida" and permitidos.has("copo")) or (tipo == "restos_mesa" and planta.objetos[pai].tipo == "prato") or (tipo == "pecas_manutencao" and permitidos.has("ingrediente"))) and filhos(planta, pai, slot).size() < int(apoios[slot].get("capacity", 1))

static func livre(planta: PlantaPlex, pai: int, tipo: String) -> int:
	for i in pontos(planta.objetos.get(pai, {"tipo":"","rotacao":0}),planta).size():
		if aceita(planta, pai, tipo, i): return i
	return -1

static func encontrar(planta: PlantaPlex, celula: Vector2i, tipo: String) -> Dictionary:
	var candidatos: Array = []
	var base := planta.em(celula)
	if not base.is_empty(): candidatos.append(base)
	for item in planta.objetos.values():
		if item.get("carregada_por", 0) == 0 and item.celula == celula and item.get("sobre", -1) >= 0:
			candidatos.push_front(item)
	for item in candidatos:
		var melhor := -1
		var distancia := INF
		var centro := posicao(planta,item)
		var apoios := pontos(item,planta)
		for i in apoios.size():
			if not aceita(planta,item.id,tipo,i): continue
			var p: Dictionary = apoios[i]
			var d := Vector2(centro.x+p.u,centro.y+p.v).distance_squared_to(Vector2(celula))
			if d < distancia:
				distancia = d
				melhor = i
		if melhor >= 0: return {"pai":item.id,"slot":melhor}
	return {}

static func posicao(planta: PlantaPlex, objeto: Dictionary, profundidade: int = 0) -> Vector3:
	if profundidade > 6: return Vector3(objeto.celula.x, objeto.celula.y, 0)
	var pai: int = objeto.get("sobre", -1)
	if pai >= 0 and planta.objetos.has(pai):
		var apoios := pontos(planta.objetos[pai],planta)
		var slot: int = objeto.get("slot", 0)
		if slot >= 0 and slot < apoios.size():
			var p: Dictionary = apoios[slot]
			return posicao(planta, planta.objetos[pai], profundidade + 1) + Vector3(p.u, p.v, p.z)
	var dimensao := CatalogoPlex.dimensoes(objeto.tipo, objeto.rotacao)
	var centro := Vector2(objeto.celula) + Vector2(dimensao - Vector2i.ONE) * .5
	return Vector3(centro.x, centro.y, planta.altura(objeto.celula) if planta.sobreposto(objeto.tipo) and objeto.tipo not in ["pose", "luz_teto", "luz_parede", "luz_chao"] else 0.0)

static func raiz(planta: PlantaPlex, id: int) -> int:
	for i in 7:
		if not planta.objetos.has(id): return -1
		var pai: int = planta.objetos[id].get("sobre", -1)
		if pai < 0: return id
		id = pai
	return -1

static func portador(planta: PlantaPlex, id: int) -> int:
	for i in 7:
		if not planta.objetos.has(id): return 0
		var objeto: Dictionary = planta.objetos[id]
		if objeto.get("carregada_por",0)>0: return int(objeto.carregada_por)
		id = int(objeto.get("sobre",-1))
	return 0

static func fixar(planta: PlantaPlex, id: int, pai: int, slot: int) -> bool:
	if not planta.objetos.has(id) or id == pai or not aceita(planta, pai, planta.objetos[id].tipo, slot): return false
	var atual := pai
	for i in 7:
		if atual == id: return false
		atual = planta.objetos.get(atual, {}).get("sobre", -1)
		if atual < 0: break
	var objeto: Dictionary = planta.objetos[id]
	objeto.sobre = pai
	objeto.slot = slot
	objeto.celula = planta.objetos[pai].celula
	objeto.carregada_por = 0
	if planta.objetos[pai].tipo=="mesa" and slot < 4: objeto.cadeira=LugaresPlex.cadeiras(planta,planta.objetos[pai])[slot]
	planta.reindexar()
	planta.alterada.emit()
	return true
