class_name AmbientesPlex
extends RefCounted

signal atualizados
var planta: PlantaPlex
var rotas: RotasPlex
var definicoes: Dictionary
var ambientes: Array[Dictionary] = []
var por_celula: Dictionary = {}
var sujo := true
var assinatura_estrutura := -1
var assinatura_requisitos := -1
var requisitos: Dictionary = {}
var qtd_bases := 0
const ORDEM_ZONAS := ["banheiro","vestiario","cozinha","escritorio","oficina","jogos","limpeza","deposito","salao"]

func _init(p: PlantaPlex, r: RotasPlex) -> void:
	planta = p
	rotas = r
	definicoes = JSON.parse_string(FileAccess.get_file_as_string("res://dados/salas.json"))
	for definicao in definicoes.values():
		for tipo in definicao.requisitos: requisitos[tipo] = true
	planta.alterada.connect(invalidar)

func invalidar() -> void:
	sujo = true

func atualizar() -> void:
	if not sujo: return
	sujo = false
	var estrutura: Array = [planta.funcoes_salas]
	var equipamentos_local: Array = [planta.ocupacao,planta.reservas_abertura.keys()]
	for item in planta.objetos.values():
		if item.tipo in SalasPlex.ESTRUTURA: estrutura.append([item.id,item.tipo,item.celula,item.rotacao])
		if int(item.get("sobre",-1))<0 or item.tipo=="terminal_ibm": equipamentos_local.append([item.id,item.tipo,MobiliaPlex.visual(item),item.celula,item.rotacao,item.get("sobre",-1),item.get("carregada_por",0)])
	var assinatura := hash(estrutura)
	var reconstruir := assinatura!=assinatura_estrutura
	var requisitos_atuais := hash(equipamentos_local)
	var revalidar := requisitos_atuais!=assinatura_requisitos
	assinatura_requisitos=requisitos_atuais
	if reconstruir:
		assinatura_estrutura = assinatura
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
				ambiente.total = celulas
				for c in celulas: por_celula[c] = ambiente.id
				ambientes.append(ambiente)
		qtd_bases = ambientes.size()
	elif revalidar:
		restaurar_bases()
	atribuir_objetos()
	if not reconstruir and not revalidar: return
	for ambiente in ambientes:
		FuncoesSalaPlex.classificar(planta, ambiente, definicoes)
	if dividir_zonas(): atribuir_objetos()
	for ambiente in ambientes:
		FuncoesSalaPlex.classificar(planta, ambiente, definicoes)
		validar(ambiente)
	atualizados.emit()

func atribuir_objetos() -> void:
	for ambiente in ambientes: ambiente.objetos.clear()
	for item in planta.objetos.values():
		if ApoiosPlex.portador(planta,item.id) > 0: continue
		var raiz := ApoiosPlex.raiz(planta, item.id)
		if raiz >= 0:
			var base: Dictionary = planta.objetos[raiz]
			if por_celula.has(base.celula): ambientes[por_celula[base.celula]].objetos.append(item.id)

func restaurar_bases() -> void:
	ambientes.resize(qtd_bases)
	for ambiente in ambientes:
		ambiente.celulas = ambiente.total
		ambiente.erase("zona")
		ambiente.erase("automatica")
		for c in ambiente.celulas: por_celula[c] = ambiente.id

func grupo_zona(item: Dictionary) -> String:
	for tipo in ["vaso_sanitario","pia_banheiro"]:
		if FuncoesSalaPlex.corresponde(item,tipo): return "banheiro"
	if FuncoesSalaPlex.corresponde(item,"armario_funcionarios"): return "vestiario"
	for tipo in ["forno","geladeira","bancada_preparo","pia","armario_utensilios"]:
		if FuncoesSalaPlex.corresponde(item,tipo): return "cozinha"
	if FuncoesSalaPlex.corresponde(item,"terminal_ibm"): return "escritorio"
	if FuncoesSalaPlex.corresponde(item,"estante"): return "deposito"
	if FuncoesSalaPlex.corresponde(item,"armario_limpeza"): return "limpeza"
	for tipo in ["bancada_montagem_coelho","area_montagem_atracao","mesa_desenho_inclinada"]:
		if FuncoesSalaPlex.corresponde(item,tipo): return "oficina"
	if FuncoesSalaPlex.corresponde(item,"maquina_fliperama"): return "jogos"
	if FuncoesSalaPlex.corresponde(item,"mesa") or LugaresPlex.cadeira_refeicao(item) or FuncoesSalaPlex.corresponde(item,"registradora") or FuncoesSalaPlex.corresponde(item,"palco"): return "salao"
	return ""

func dividir_zonas() -> bool:
	var dividiu := false
	for i in qtd_bases:
		var base: Dictionary = ambientes[i]
		if not base.fechada or not base.marcas.is_empty() or base.celulas.size() < 9: continue
		var com_ibm: Dictionary = {}
		for id in base.objetos:
			var item: Dictionary = planta.objetos.get(int(id),{})
			if not item.is_empty() and FuncoesSalaPlex.corresponde(item,"terminal_ibm"):
				var dono_ibm: int = ApoiosPlex.raiz(planta,int(id))
				if dono_ibm >= 0: com_ibm[dono_ibm] = true
		var fontes: Dictionary = {}
		for id in base.objetos:
			var item: Dictionary = planta.objetos.get(int(id),{})
			if item.is_empty(): continue
			var grupo: String = grupo_zona(item)
			if grupo.is_empty() or (grupo == "salao" and com_ibm.has(int(id))): continue
			var raiz: int = ApoiosPlex.raiz(planta,int(id))
			if raiz < 0: continue
			var origem: Dictionary = planta.objetos[raiz]
			if not fontes.has(grupo): fontes[grupo] = {}
			for c in planta.celulas(origem.tipo,origem.celula,origem.rotacao):
				if base.celulas.has(c): fontes[grupo][c] = true
		if fontes.size() < 2: continue
		var dono: Dictionary = {}
		var fila: Array[Vector2i] = []
		for grupo in ORDEM_ZONAS:
			if not fontes.has(grupo): continue
			for c in fontes[grupo]:
				if not dono.has(c):
					dono[c] = grupo
					fila.append(c)
		var indice := 0
		while indice < fila.size():
			var atual: Vector2i = fila[indice]
			indice += 1
			for d in GradePlex.VIZINHOS:
				var vizinha: Vector2i = atual + d
				if base.celulas.has(vizinha) and not dono.has(vizinha):
					dono[vizinha] = dono[atual]
					fila.append(vizinha)
		var grupos: Dictionary = {}
		for c in dono:
			var g: String = dono[c]
			if not grupos.has(g): grupos[g] = {}
			grupos[g][c] = true
		var maior := ""
		var tamanho := 0
		for g in grupos:
			if grupos[g].size() > tamanho:
				maior = g
				tamanho = grupos[g].size()
		for g in grupos:
			if g == maior:
				base.celulas = grupos[g]
				base.zona = g
				base.automatica = true
				continue
			var zona: Dictionary = {"id":ambientes.size(),"celulas":grupos[g],"fechada":true,"tipo":"livre","marcas":[],"conflito":false,"objetos":[],"faltas":[],"operacional":false,"portas":[],"zona":g,"automatica":true,"total":base.total}
			for c in grupos[g]: por_celula[c] = zona.id
			ambientes.append(zona)
		dividiu = true
	return dividiu

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
	return ambiente.get("objetos", []).filter(func(id): return planta.objetos.has(id) and FuncoesSalaPlex.corresponde(planta.objetos[id],tipo) and TerrenoPlex.contem(planta,planta.objetos[ApoiosPlex.raiz(planta,id)].celula))

func faltas_funcao(ambiente: Dictionary, tipo_sala: String) -> Array[String]:
	var faltas: Array[String] = []
	if tipo_sala == "livre": return ["Escolha uma função para esta área."]
	if not ambiente.fechada: faltas.append("Feche a área com paredes e portas.")
	if ambiente.conflito: faltas.append("Áreas unidas têm funções diferentes. Escolha a função novamente.")
	var entradas: Array[Vector2i] = []
	var celulas_porta: Dictionary = ambiente.get("total",ambiente.celulas)
	for item in planta.objetos.values():
		if item.tipo not in CatalogoPlex.PORTAS: continue
		var frente := GradePlex.frente(item.rotacao)
		for c in planta.celulas(item.tipo, item.celula, item.rotacao):
			for d in [frente, -frente]:
				if celulas_porta.has(c + d) and (not GradePlex.dentro(c - d) or planta.transitavel(c - d)):
					entradas.append(c)
					if not ambiente.portas.has(item.id): ambiente.portas.append(item.id)
	if entradas.is_empty(): faltas.append("Adicione uma porta com passagem livre dos dois lados.")
	var requisitos_local: Dictionary = definicoes[tipo_sala].requisitos
	for tipo in requisitos_local:
		var encontrados := objetos(ambiente, tipo)
		if tipo in ["vassoura","balde"] and KitLimpezaPlex.em_uso(planta,tipo,ambiente.celulas):continue
		if encontrados.size() < int(requisitos_local[tipo]):
			faltas.append("Falta: " + CatalogoPlex.objetos[tipo].nome + ".")
		elif tipo not in ["palco", "pose", "escada", "registradora", "divisoria_porta", "cadeira", "mesa"]:
			for id in encontrados:
				if planta.objetos[id].tipo in ["forno","geladeira"]:
					var item: Dictionary = planta.objetos[id]
					var estado_aberto := "aberto" if tipo == "forno" else "aberta"
					var dados: Dictionary = ApoiosPlex.definicoes[tipo].estados[estado_aberto][item.rotacao]
					var centro := ApoiosPlex.posicao(planta,item)
					for ponto in dados.reserva:
						var c := Vector2i(roundi(centro.x+ponto.u),roundi(centro.y+ponto.v))
						if not GradePlex.dentro(c) or not planta.em(c).is_empty(): faltas.append(CatalogoPlex.objetos[tipo].nome+": deixe espaço para abrir a porta.")
				var acessivel := false
				var alvos:=FornoPlex.acessos(planta,id) if tipo=="forno" else planta.interacoes_estado(id,"aberta") if tipo=="geladeira" else planta.interacoes(id)
				for entrada in entradas:
					if alvos.any(func(c): return not rotas.caminho(entrada,c).is_empty()):
						acessivel = true
						break
				if not acessivel: faltas.append(CatalogoPlex.objetos[tipo].nome + ": acesso obstruído.")
	if tipo_sala in ["salao","salao_festas"]:
		var ligadas := false
		for mesa in objetos(ambiente, "mesa"):
			for cadeira in LugaresPlex.cadeiras(planta,planta.objetos[mesa]):
				if cadeira>=0 and entradas.any(func(c): return not rotas.aproximar(c,cadeira).is_empty()): ligadas=true
		if not ligadas: faltas.append("Coloque uma cadeira voltada para a mesa.")
	if tipo_sala in ["apresentacoes","salao_festas"]:
		for id in objetos(ambiente, "escada"):
			if not EscadasPlex.acessivel(planta.objetos[id].celula, planta): faltas.append("Alinhe a escada ao palco e deixe a entrada livre.")
	return faltas

func validar(ambiente: Dictionary) -> void:
	ambiente.por_funcao={}
	ambiente.portas.clear()
	for tipo in ambiente.funcoes:
		ambiente.por_funcao[tipo]=faltas_funcao(ambiente,tipo)
	ambiente.faltas=ambiente.por_funcao.get(ambiente.tipo,[])
	ambiente.operacional=ambiente.faltas.is_empty()

func habilitada(ambiente: Dictionary, tipos: Array) -> bool:
	if ambiente.is_empty(): return false
	if ambiente.get("tipo","") in ["descanso","vestiario","banheiro","oficina","escritorio"] and tipos.any(func(t):return t in ["salao","salao_festas"]) and not tipos.any(func(t):return t==ambiente.tipo):return false
	var candidatas: Array=ambiente.get("funcoes",[]) if tipos.is_empty() else tipos
	for tipo in candidatas:
		if ambiente.get("por_funcao",{}).has(tipo) and ambiente.por_funcao[tipo].is_empty(): return true
	return false

func permite(id: int, tipos: Array) -> bool:
	var ambiente := do_objeto(id)
	return habilitada(ambiente,tipos)

func equipamentos(tipo: String, salas: Array = []) -> Array:
	atualizar()
	var resultado: Array = []
	for ambiente in ambientes:
		if habilitada(ambiente,salas):
			for id in objetos(ambiente, tipo): resultado.append(id)
	return resultado

