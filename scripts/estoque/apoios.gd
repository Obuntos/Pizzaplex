class_name ApoiosPlex
extends RefCounted

static var definicoes: Dictionary = {}

static func carregar() -> void:
	if definicoes.is_empty():
		definicoes = JSON.parse_string(FileAccess.get_file_as_string("res://dados/funcoes_objetos.json"))
		definicoes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/funcoes_fachada.json")), true)

static func superficie(tipo: String) -> bool:
	return bool(CatalogoPlex.objetos.get(tipo, {}).get("apoio", false))

static func categoria(tipo: String) -> String:
	if tipo.begins_with("caixa_pecas_"): return "pecas-manutencao"
	if tipo.begins_with("caixa"): return "caixa"
	return tipo.replace("_", "-")

static func pontos(objeto: Dictionary, planta: PlantaPlex = null) -> Array:
	carregar()
	if objeto.tipo == "ponto_recebimento": return PilhasPlex.pontos(objeto,planta)
	if LugaresPlex.mesa(objeto.tipo):
		var resultado: Array = []
		var assentos := LugaresPlex.cadeiras(planta, objeto)
		var posicoes := LugaresPlex.posicoes(objeto)
		var dimensao := CatalogoPlex.dimensoes(objeto.tipo, objeto.rotacao)
		var centro := Vector2(objeto.celula) + Vector2(dimensao - Vector2i.ONE) * .5
		var altura := 30.0 if objeto.tipo == "mesa" else 29.0
		for i in assentos.size():
			var p: Dictionary = posicoes[i]
			var local: Vector2 = Vector2(p.celula) - centro + Vector2(p.frente) * .8
			if objeto.tipo == "mesa": local = (Vector2(p.celula) - centro) * .22
			resultado.append({"u":local.x,"v":local.y,"z":altura,"cadeira":assentos[i],"accepts":["prato","pizza","fatia-pizza","restos-mesa","bandeja"],"capacity":1})
		resultado.append({"u":0.0,"v":0.0,"z":altura+.8,"accepts":["dinheiro"],"capacity":1})
		resultado.append({"u":0.0,"v":0.0,"z":altura,"accepts":["terminal-ibm"],"capacity":1})
		for i in assentos.size():
			var p: Dictionary = resultado[i].duplicate(true)
			var frente: Vector2i = posicoes[i].frente
			p.u += frente.y * .15
			p.v -= frente.x * .15
			p.accepts = ["copo-bebida","guarana-copo","guarana-tampa"]
			resultado.append(p)
		return resultado
	if objeto.tipo == "forno":
		return FornoPlex.pontos(objeto)
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
		return FornoPlex.pontos(objeto)
	return []

static func filhos(planta: PlantaPlex, pai: int, slot: int = -1) -> Array:
	return planta.filhos_de(pai,slot)

static func aceita(planta: PlantaPlex, pai: int, tipo: String, slot: int) -> bool:
	if not planta.objetos.has(pai): return false
	var filhos_atuais := filhos(planta,pai)
	if LugaresPlex.mesa(planta.objetos[pai].tipo):
		if tipo == "terminal_ibm" and not filhos_atuais.is_empty(): return false
		if tipo != "terminal_ibm" and filhos_atuais.any(func(f): return f.tipo == "terminal_ibm"): return false
	var apoios := pontos(planta.objetos[pai],planta)
	if slot < 0 or slot >= apoios.size(): return false
	if planta.objetos[pai].tipo == "ponto_recebimento" and not PilhasPlex.aceita(planta,pai,slot): return false
	if LugaresPlex.mesa(planta.objetos[pai].tipo) and tipo not in ["dinheiro","terminal_ibm"]:
		var n := LugaresPlex.cadeiras(planta,planta.objetos[pai]).size()
		var lugar := slot if slot < n else slot - n - 2
		if not LugaresPlex.ativo(planta,pai,lugar): return false
	var permitidos: Array = apoios[slot].accepts
	if tipo == "terminal_ibm" and filhos_atuais.any(func(f): return str(f.tipo).begins_with("presente_")): return false
	if tipo.begins_with("presente_"): return planta.objetos[pai].tipo in ["balcao","bancada","estante"] and not filhos_atuais.any(func(f): return f.tipo in ["terminal_ibm","registradora"]) and filhos(planta,pai,slot).is_empty()
	if tipo.begins_with("caixa_pecas_") or tipo == "pecas_manutencao":
		return planta.objetos[pai].tipo in ["armario_ferramentas", "ponto_recebimento"] and filhos(planta, pai, slot).size() < int(apoios[slot].get("capacity", 1))
	return (permitidos.has(categoria(tipo)) or (tipo == "copo_bebida" and permitidos.has("copo")) or (tipo == "restos_mesa" and planta.objetos[pai].tipo == "prato")) and filhos(planta, pai, slot).size() < int(apoios[slot].get("capacity", 1))

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
	if LugaresPlex.mesa(planta.objetos[pai].tipo) and slot < LugaresPlex.cadeiras(planta,planta.objetos[pai]).size(): objeto.cadeira=LugaresPlex.cadeiras(planta,planta.objetos[pai])[slot]
	planta.reindexar()
	planta.alterada.emit()
	return true

