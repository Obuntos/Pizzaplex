class_name AmbientesPlex
extends RefCounted

signal atualizados
var planta: PlantaPlex
var rotas: RotasPlex
var definicoes: Dictionary
var ambientes: Array[Dictionary] = []
var por_celula: Dictionary = {}
var sujo := true

func _init(p: PlantaPlex, r: RotasPlex) -> void:
	planta = p
	rotas = r
	definicoes = JSON.parse_string(FileAccess.get_file_as_string("res://dados/salas.json"))
	planta.alterada.connect(invalidar)

func invalidar() -> void:
	sujo = true

func atualizar() -> void:
	if not sujo: return
	sujo = false
	ambientes.clear()
	por_celula.clear()
	var vistas: Dictionary = {}
	for y in GradePlex.TAMANHO.y:
		for x in GradePlex.TAMANHO.x:
			var inicio := Vector2i(x, y)
			if vistas.has(inicio) or planta.em(inicio).get("tipo", "") in SalasPlex.ESTRUTURA: continue
			var fila: Array[Vector2i] = [inicio]
			var celulas: Dictionary = {inicio:true}
			var fechada := true
			vistas[inicio] = true
			var indice := 0
			while indice < fila.size():
				var c := fila[indice]
				indice += 1
				if c.x == 0 or c.y == 0 or c.x == GradePlex.TAMANHO.x - 1 or c.y == GradePlex.TAMANHO.y - 1: fechada = false
				for d in GradePlex.VIZINHOS:
					var v: Vector2i = c + d
					if GradePlex.dentro(v) and not vistas.has(v) and planta.em(v).get("tipo", "") not in SalasPlex.ESTRUTURA:
						vistas[v] = true
						celulas[v] = true
						fila.append(v)
			var tipos: Array[String] = []
			for marca in planta.funcoes_salas:
				if celulas.has(marca) and not tipos.has(planta.funcoes_salas[marca]): tipos.append(planta.funcoes_salas[marca])
			var ambiente := {"id":ambientes.size(),"celulas":celulas,"fechada":fechada,"tipo":tipos[0] if not tipos.is_empty() else "livre","marcas":tipos,"conflito":tipos.size() > 1,"objetos":[],"faltas":[],"operacional":false,"portas":[]}
			for c in celulas: por_celula[c] = ambiente.id
			ambientes.append(ambiente)
	for item in planta.objetos.values():
		if ApoiosPlex.portador(planta,item.id) > 0: continue
		var raiz := ApoiosPlex.raiz(planta, item.id)
		if raiz >= 0:
			var base: Dictionary = planta.objetos[raiz]
			if por_celula.has(base.celula): ambientes[por_celula[base.celula]].objetos.append(item.id)
	for ambiente in ambientes:
		FuncoesSalaPlex.classificar(planta, ambiente, definicoes)
		validar(ambiente)
	atualizados.emit()

func em(celula: Vector2i) -> Dictionary:
	atualizar()
	return ambientes[por_celula[celula]] if por_celula.has(celula) else {}

func do_objeto(id: int) -> Dictionary:
	var raiz := ApoiosPlex.raiz(planta, id)
	return em(planta.objetos[raiz].celula) if raiz >= 0 else {}

func definir(celula: Vector2i, tipo: String) -> bool:
	var ambiente := em(celula)
	if ambiente.is_empty(): return false
	for marca in planta.funcoes_salas.keys():
		if ambiente.celulas.has(marca): planta.funcoes_salas.erase(marca)
	if definicoes.has(tipo) or tipo == "livre": planta.funcoes_salas[celula] = tipo
	planta.alterada.emit()
	atualizar()
	return true

func objetos(ambiente: Dictionary, tipo: String) -> Array:
	return ambiente.get("objetos", []).filter(func(id): return planta.objetos.has(id) and planta.objetos[id].tipo == tipo)

func validar(ambiente: Dictionary) -> void:
	var faltas: Array[String] = []
	if ambiente.tipo == "livre":
		ambiente.faltas = ["Escolha uma função para esta área."]
		return
	if not ambiente.fechada: faltas.append("Feche a área com paredes e portas.")
	if ambiente.conflito: faltas.append("Áreas unidas têm funções diferentes. Escolha a função novamente.")
	var entradas: Array[Vector2i] = []
	for item in planta.objetos.values():
		if item.tipo not in ["porta", "porta_dupla"]: continue
		var frente := GradePlex.frente(item.rotacao)
		for c in planta.celulas(item.tipo, item.celula, item.rotacao):
			for d in [frente, -frente]:
				if ambiente.celulas.has(c + d) and (not GradePlex.dentro(c - d) or planta.transitavel(c - d)):
					entradas.append(c)
					if not ambiente.portas.has(item.id): ambiente.portas.append(item.id)
	if entradas.is_empty(): faltas.append("Adicione uma porta com passagem livre dos dois lados.")
	var requisitos: Dictionary = definicoes[ambiente.tipo].requisitos
	for tipo in requisitos:
		var encontrados := objetos(ambiente, tipo)
		if encontrados.size() < int(requisitos[tipo]):
			faltas.append("Falta: " + CatalogoPlex.objetos[tipo].nome + ".")
		elif tipo not in ["palco", "pose", "escada", "registradora", "divisoria_porta"]:
			for id in encontrados:
				if tipo in ["forno","geladeira"]:
					var item: Dictionary = planta.objetos[id]
					var estado_aberto := "aberto" if tipo == "forno" else "aberta"
					var dados: Dictionary = ApoiosPlex.definicoes[tipo].estados[estado_aberto][item.rotacao]
					var centro := ApoiosPlex.posicao(planta,item)
					for ponto in dados.reserva:
						var c := Vector2i(roundi(centro.x+ponto.u),roundi(centro.y+ponto.v))
						if not GradePlex.dentro(c) or not planta.em(c).is_empty(): faltas.append(CatalogoPlex.objetos[tipo].nome+": deixe espaço para abrir a porta.")
				var acessivel := false
				for entrada in entradas:
					if not rotas.aproximar(entrada, id).is_empty(): acessivel = true
				if not acessivel: faltas.append(CatalogoPlex.objetos[tipo].nome + ": acesso obstruído.")
	if "salao" in ambiente.funcoes:
		var ligadas := false
		for mesa in objetos(ambiente, "mesa"):
			if LugaresPlex.total(planta,mesa)>0: ligadas=true
		if not ligadas: faltas.append("Coloque uma cadeira voltada para a mesa.")
	if "apresentacoes" in ambiente.funcoes:
		for id in objetos(ambiente, "escada"):
			if not EscadasPlex.acessivel(planta.objetos[id].celula, planta): faltas.append("Alinhe a escada ao palco e deixe a entrada livre.")
	ambiente.faltas = faltas
	ambiente.operacional = faltas.is_empty()

func permite(id: int, tipos: Array) -> bool:
	var ambiente := do_objeto(id)
	return not ambiente.is_empty() and ambiente.operacional and FuncoesSalaPlex.aceita(ambiente, tipos)

func equipamentos(tipo: String, salas: Array = []) -> Array:
	atualizar()
	var resultado: Array = []
	for ambiente in ambientes:
		if ambiente.operacional and FuncoesSalaPlex.aceita(ambiente, salas):
			for id in objetos(ambiente, tipo): resultado.append(id)
	return resultado
