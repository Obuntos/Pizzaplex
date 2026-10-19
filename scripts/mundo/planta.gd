class_name PlantaPlex
extends RefCounted

signal alterada
var objetos: Dictionary = {}
var ocupacao: Dictionary = {}
var cores: Dictionary = {}
var pisos: Dictionary = {}
var proximo_id: int = 1
var funcoes_salas: Dictionary = {}
var reservas_abertura: Dictionary = {}
var cabines_por_celula: Dictionary = {}
var revisao := 0
var indice_filhos: Dictionary = {}
var indice_sujo := true

func _init() -> void:
	alterada.connect(invalidar_indices)
	alterada.connect(atualizar_reservas)

func invalidar_indices() -> void:
	revisao += 1
	indice_sujo = true

func filhos_de(pai: int, slot: int = -1) -> Array:
	if indice_sujo:
		indice_filhos.clear()
		for item in objetos.values():
			var base: int = item.get("sobre",-1)
			if base<0 or item.get("carregada_por",0)>0: continue
			if not indice_filhos.has(base): indice_filhos[base] = []
			indice_filhos[base].append(item)
		indice_sujo = false
	var lista: Array = indice_filhos.get(pai,[])
	return lista.duplicate() if slot<0 else lista.filter(func(item): return int(item.get("slot",-1))==slot)

func atualizar_reservas() -> void:
	cabines_por_celula.clear()
	for item in objetos.values():
		if item.tipo == "divisoria_porta":
			for local in celulas(item.tipo, item.celula, item.rotacao): cabines_por_celula[local] = item.id
	for porta in objetos.values():
		if porta.tipo not in CatalogoPlex.PORTAS: continue
		for c in celulas(porta.tipo,porta.celula,porta.rotacao):
			if pisos.has(c): continue
			for d in [GradePlex.frente(porta.rotacao),-GradePlex.frente(porta.rotacao)]:
				if pisos.has(c+d): pisos[c]=pisos[c+d]; break
	LugaresPlex.sincronizar(self)
	reservas_abertura.clear()
	ApoiosPlex.carregar()
	for objeto in objetos.values():
		if not ApoiosPlex.definicoes.has(objeto.tipo) or objeto.get("carregada_por",0)>0: continue
		var definicao: Dictionary = ApoiosPlex.definicoes[objeto.tipo]
		var estado: String = objeto.get("estado",CatalogoPlex.objetos[objeto.tipo].estado_padrao)
		var pontos: Array = definicao.estados.get(estado,definicao.estados.values()[0])[objeto.rotacao].reserva
		var centro := ApoiosPlex.posicao(self,objeto)
		for ponto in pontos:
			reservas_abertura[Vector2i(roundi(centro.x+ponto.u),roundi(centro.y+ponto.v))] = objeto.id

	for ponto in objetos.values():
		if ponto.tipo != "ponto_recebimento": continue
		var caixas := ApoiosPlex.filhos(self,ponto.id)
		if caixas.is_empty(): continue
		for c in celulas(ponto.tipo,ponto.celula,ponto.rotacao): reservas_abertura[c] = caixas[-1].id

func celulas(tipo: String, celula: Vector2i, rotacao: int) -> Array[Vector2i]:
	var dimensao := CatalogoPlex.dimensoes(tipo, rotacao)
	var resultado: Array[Vector2i] = []
	for x in dimensao.x:
		for y in dimensao.y:
			resultado.append(celula + Vector2i(x, y))
	return resultado

func sobreposto(tipo: String) -> bool:
	return tipo in ["luz_teto", "luz_parede", "luz_chao", "pose", "pose_quebrado"] or bool(CatalogoPlex.objetos.get(tipo, {}).get("sobreposto", false))

func sobre(celula: Vector2i, tipo: String = "") -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for objeto in objetos.values():
		if objeto.celula == celula and (sobreposto(objeto.tipo) or objeto.get("sobre", -1) >= 0) and (tipo.is_empty() or objeto.tipo == tipo):
			resultado.append(objeto)
	return resultado

func pode_colocar(tipo: String, celula: Vector2i, rotacao: int) -> bool:
	if tipo in CatalogoPlex.PORTAS:
		rotacao = PortasPlex.rotacao_para(self, tipo, celula, rotacao)
	if not GradePlex.dentro(celula):
		return false
	if tipo == "ponto_recebimento":
		for c in celulas(tipo,celula,rotacao):
			if not GradePlex.dentro(c) or not em(c).is_empty(): return false
			for p in objetos.values():
				if p.tipo == tipo and celulas(tipo,p.celula,p.rotacao).has(c): return false
		return true
	if tipo == "divisoria_porta":
		var modulo := {"tipo":tipo,"celula":celula,"rotacao":rotacao}
		for local in celulas(tipo, celula, rotacao):
			if not GradePlex.dentro(local) or not CabinesPlex.em(self, local).is_empty(): return false
			var base := em(local)
			if not base.is_empty() and (base.tipo != "vaso_sanitario" or base.rotacao != rotacao or local != CabinesPlex.fundo(self, modulo)): return false
		return true
	if ApoiosPlex.superficie(tipo):
		var apoio := ApoiosPlex.encontrar(self, celula, tipo)
		if tipo == "prato" and LugaresPlex.mesa(objetos.get(apoio.get("pai", -1), {}).get("tipo", "")): return false
		return not apoio.is_empty()
	if sobreposto(tipo):
		if tipo.begins_with("luz_") and objetos.values().filter(func(item): return item.tipo.begins_with("luz_")).size() >= 32:
			return false
		if tipo != "pose" and not sobre(celula, tipo).is_empty():
			return false
		var base := em(celula).get("tipo", "") as String
		if tipo == "pose_quebrado": return base==""
		if tipo == "pose":
			return base == "palco"
		if CatalogoPlex.objetos[tipo].get("parede_requerida",false):
			return CatalogoPlex.base(base) == "parede"
		if tipo == "luz_parede":
			return CatalogoPlex.base(base) == "parede"
		if tipo == "luz_chao":
			return base in ["", "palco"]
		return base not in SalasPlex.ESTRUTURA
	for local in celulas(tipo, celula, rotacao):
		var cabine := CabinesPlex.em(self, local)
		if not cabine.is_empty() and (tipo != "vaso_sanitario" or rotacao != cabine.rotacao or local != CabinesPlex.fundo(self, cabine)): return false
		if not GradePlex.dentro(local) or ocupacao.has(local) or reservas_abertura.has(local):
			return false
		if not sobre(local,"pose_quebrado").is_empty(): return false
		if tipo != "palco" and not sobre(local, "luz_chao").is_empty():
			return false
	return true

func colocar(tipo: String, celula: Vector2i, rotacao: int = 0) -> int:
	if tipo in CatalogoPlex.PORTAS:
		rotacao = PortasPlex.rotacao_para(self, tipo, celula, rotacao)
	if not pode_colocar(tipo, celula, rotacao):
		return -1
	if tipo == "pose" and not sobre(celula, "pose").is_empty():
		var existente: Dictionary = sobre(celula, "pose")[0]
		existente.rotacao = posmod(rotacao, 4)
		alterada.emit()
		return existente.id
	var encaixe := ApoiosPlex.encontrar(self, celula, tipo) if ApoiosPlex.superficie(tipo) else {}
	var id := proximo_id
	proximo_id += 1
	objetos[id] = {"id": id, "tipo": tipo, "celula": celula, "rotacao": posmod(rotacao, 4), "aberta": false, "endo": false, "pecas": 0, "montado": false, "robo_saiu": false, "caixa": false, "reserva": 0, "entregue": false, "ligada": true, "cor_luz": "#fff0d5", "energia": 1.2}
	var registro: Dictionary = objetos[id]
	registro.estado = CatalogoPlex.objetos[tipo].get("estado_padrao", "")
	registro.sobre = encaixe.get("pai", -1)
	registro.slot = encaixe.get("slot", -1)
	registro.carregada_por = 0
	registro.ingredientes = 0
	registro.lixo = 0
	MobiliaPlex.preparar(registro, tipo)
	if tipo.begins_with("caixa"):
		registro.recurso = CatalogoPlex.objetos[tipo].get("recurso", "pecas")
		registro.quantidade = CatalogoPlex.objetos[tipo].get("quantidade", 1)
	if tipo == "divisoria_porta":
		for local in celulas(tipo, celula, rotacao): cabines_por_celula[local] = id
	if ocupa(registro):
		for local in celulas(tipo, celula, rotacao):
			ocupacao[local] = id
	alterada.emit()
	return id

func em(celula: Vector2i) -> Dictionary:
	return objetos.get(ocupacao.get(celula, -1), {})

func remover(id: int) -> void:
	if not objetos.has(id):
		return
	var objeto: Dictionary = objetos[id]
	for filho in ApoiosPlex.filhos(self, id): remover(filho.id)
	if ocupa(objeto):
		for local in celulas(objeto.tipo, objeto.celula, objeto.rotacao):
			if ocupacao.get(local, -1) == id: ocupacao.erase(local)
			for adicional in sobre(local):
				if adicional.tipo in ["pose", "pose_quebrado", "luz_parede"] or CatalogoPlex.objetos[adicional.tipo].get("parede_requerida",false):
					objetos.erase(adicional.id)
	objetos.erase(id)
	PilhasPlex.compactar(self,int(objeto.get("sobre",-1)))
	alterada.emit()

func ocupa(objeto: Dictionary) -> bool:
	return objeto.tipo != "divisoria_porta" and not sobreposto(objeto.tipo) and not objeto.get("solto", false) and objeto.get("sobre", -1) < 0 and objeto.get("carregada_por", 0) == 0

func reindexar() -> void:
	indice_sujo = true
	for objeto in objetos.values():
		if objeto.tipo == "terminal_ibm" and int(objeto.get("slot",-1)) == 3: objeto.slot = 0
		if objeto.tipo == "ponto_recebimento": PilhasPlex.compactar(self,objeto.id)
	ocupacao.clear()
	for objeto in objetos.values():
		if ocupa(objeto):
			for local in celulas(objeto.tipo, objeto.celula, objeto.rotacao):
				ocupacao[local] = objeto.id

func altura(celula: Vector2i) -> float:
	var objeto := em(celula)
	if objeto.get("tipo", "") == "palco":
		return GradePlex.ALTURA_PALCO
	if objeto.get("tipo", "") == "escada":
		return GradePlex.ALTURA_PALCO * 0.5
	return 0.0

func transitavel(celula: Vector2i) -> bool:
	if not GradePlex.dentro(celula) or reservas_abertura.has(celula):
		return false
	var objeto := em(celula)
	return objeto.is_empty() or objeto.tipo in (CatalogoPlex.PORTAS + ["palco", "escada"])

func interacoes(id: int) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	if not objetos.has(id):
		return resultado
	var objeto: Dictionary = objetos[id]
	if objeto.get("sobre", -1) >= 0:
		return interacoes(ApoiosPlex.raiz(self, id))
	if LugaresPlex.mesa(objeto.tipo): return LugaresPlex.acessos(self,objeto)
	ApoiosPlex.carregar()
	if ApoiosPlex.definicoes.has(objeto.tipo) and not sobreposto(objeto.tipo):
		return interacoes_estado(id,objeto.get("estado",CatalogoPlex.objetos[objeto.tipo].estado_padrao))
	if objeto.tipo == "mesa":
		for deslocamento in [Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
			var local: Vector2i = objeto.celula + deslocamento
			if transitavel(local) and is_zero_approx(altura(local)): resultado.append(local)
		return resultado
	if PontosUsoPlex.tem(objeto.tipo):
		for local in PontosUsoPlex.alvos(objeto):
			if transitavel(local) and is_zero_approx(altura(local)): resultado.append(local)
		return resultado
	for ocupado in celulas(objeto.tipo, objeto.celula, objeto.rotacao):
		for deslocamento in GradePlex.VIZINHOS:
			var local: Vector2i = ocupado + deslocamento
			if transitavel(local) and is_zero_approx(altura(local)) and not resultado.has(local):
				resultado.append(local)
	return resultado

func interacoes_estado(id: int, estado: String) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	if not objetos.has(id): return resultado
	var objeto: Dictionary = objetos[id]
	ApoiosPlex.carregar()
	if not ApoiosPlex.definicoes.has(objeto.tipo): return interacoes(id)
	var definicao: Dictionary = ApoiosPlex.definicoes[objeto.tipo]
	var vista: Dictionary = definicao.estados.get(estado,definicao.estados.values()[0])[objeto.rotacao]
	var ponto: Dictionary = vista.interacao
	var dimensao := CatalogoPlex.dimensoes(objeto.tipo,objeto.rotacao)
	var centro := Vector2(objeto.celula)+Vector2(dimensao-Vector2i.ONE)*.5
	var preferida := Vector2i((centro+Vector2(ponto.u,ponto.v)).round())
	if transitavel(preferida) and is_zero_approx(altura(preferida)): resultado.append(preferida)
	if not vista.reserva.is_empty(): return resultado
	var frente := GradePlex.frente(objeto.rotacao)
	for ocupado in celulas(objeto.tipo,objeto.celula,objeto.rotacao):
		var local: Vector2i = ocupado+frente
		if transitavel(local) and is_zero_approx(altura(local)) and not resultado.has(local): resultado.append(local)
	return resultado

func bancada_proxima(suporte: int) -> bool:
	if not objetos.has(suporte):
		return false
	for objeto in objetos.values():
		if objeto.tipo == "bancada" and Vector2(objeto.celula).distance_to(Vector2(objetos[suporte].celula)) <= 2.1:
			return true
	return false

func bancada_para(suporte: int) -> int:
	if not objetos.has(suporte):
		return -1
	var dono: int = objetos[suporte].reserva
	var melhor: int = -1
	var distancia: float = 2.11
	for objeto in objetos.values():
		if objeto.tipo != "bancada" or objeto.reserva not in [0, dono]:
			continue
		if objeto.caixa and objeto.get("caixa_para", suporte) != suporte:
			continue
		var atual := Vector2(objeto.celula).distance_to(Vector2(objetos[suporte].celula))
		if atual < distancia:
			distancia = atual
			melhor = objeto.id
	return melhor

func ponto_caixa(bancada: int) -> Vector3:
	return PontosUsoPlex.caixa(objetos[bancada])

