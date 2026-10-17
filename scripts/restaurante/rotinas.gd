class_name RotinasPlex
extends RefCounted

static func reservas(servico: ServicosPlex, alvos: Array) -> Array:
	var resultado: Array = []
	for id in alvos:
		if id < 0 or not servico.planta.objetos.has(id): continue
		if not resultado.has(id): resultado.append(id)
		var raiz := ApoiosPlex.raiz(servico.planta, id)
		if raiz >= 0 and not resultado.has(raiz): resultado.append(raiz)
	return resultado

static func iniciar(servico: ServicosPlex, ator: PersonagemPlex, alvo: int) -> bool:
	var item: Dictionary = servico.planta.objetos.get(alvo, {})
	if item.is_empty() or not servico.livre(alvo): return false
	var passos: Array = []
	var alvos: Array = [alvo]
	var titulo := ""
	match str(item.tipo):
		"vaso_sanitario":
			if not servico.salas.permite(alvo, ["banheiro"]): return false
			var pias := servico.salas.objetos(servico.salas.do_objeto(alvo), "pia_banheiro")
			pias = pias.filter(func(id): return servico.livre(id))
			if pias.is_empty(): return false
			var cabine := CabinesPlex.em(servico.planta, item.celula)
			if cabine.is_empty() or not servico.livre(cabine.id): return false
			alvos.append_array([cabine.id, pias[0]])
			passos = [servico.etapa(alvo, "usar_vaso", 4.0), servico.etapa(pias[0], "higienizar", 3.0)]
			titulo = "Usar banheiro e lavar as mãos"
		"pia_banheiro":
			if not servico.salas.permite(alvo, ["banheiro"]): return false
			passos = [servico.etapa(alvo, "higienizar", 3.0)]
			titulo = "Lavar as mãos"
		"maquina_fliperama":
			if item.estado != "ligada" or not servico.salas.permite(alvo, ["jogos"]): return false
			passos = [servico.etapa(alvo, "jogar", 7.0)]
			titulo = "Jogar no fliperama"
		"armario_funcionarios":
			if not servico.salas.permite(alvo, ["vestiario"]): return false
			passos = [servico.etapa(alvo, "guardar_pertences", 2.0)]
			titulo = "Guardar pertences"
		_:
			if not ArmariosPlex.armario(item.tipo): return false
			passos = [servico.etapa(alvo, "consultar_armario", 2.0)]
			titulo = "Consultar armário"
	return servico.iniciar(ator, titulo, passos, reservas(servico, alvos))

static func solicitar(servico: ServicosPlex, alvo: int) -> bool:
	var atores := servico.personagens.duplicate()
	var item: Dictionary = servico.planta.objetos.get(alvo, {})
	if item.is_empty(): return false
	atores.sort_custom(func(a, b): return a.local.distance_squared_to(Vector2(item.celula)) < b.local.distance_squared_to(Vector2(item.celula)))
	for ator in atores:
		if ator.robo or ator.cargo != "funcionario" or not ator.automatico or ator.ocupado() or ator.carga_item >= 0: continue
		if servico.trabalhos.has(ator.identificador) or servico.montagem.trabalhos.has(ator.identificador): continue
		if iniciar(servico, ator, alvo): return true
	servico.aviso.emit("É preciso ter um funcionário livre e acesso ao equipamento em uma sala operacional.")
	return false

static func prioritaria(servico: ServicosPlex, ator: PersonagemPlex) -> bool:
	if float(ator.necessidades.banheiro) < 25.0:
		for alvo in servico.encontrar("vaso_sanitario", ["banheiro"]):
			if iniciar(servico, ator, alvo): return true
	if float(ator.necessidades.higiene) < 30.0:
		for alvo in servico.encontrar("pia_banheiro", ["banheiro"]):
			if iniciar(servico, ator, alvo): return true
	return false

static func entre_tarefas(servico: ServicosPlex, ator: PersonagemPlex) -> bool:
	if not bool(ator.necessidades.turno):
		for alvo in servico.encontrar("armario_funcionarios", ["vestiario"]):
			if iniciar(servico, ator, alvo): return true
	if float(ator.necessidades.lazer) < 40.0:
		for alvo in servico.encontrar("maquina_fliperama", ["jogos"]):
			if iniciar(servico, ator, alvo): return true
	return false

static func organizar(servico: ServicosPlex, ator: PersonagemPlex) -> bool:
	for item in servico.planta.objetos.values():
		if item.tipo not in ["vassoura", "balde", "caixa_ferramentas", "pecas_manutencao"]: continue
		if item.get("sobre", -1) >= 0 or not servico.livre(item.id): continue
		var tipo := "armario_limpeza" if item.tipo in ["vassoura", "balde"] else "armario_ferramentas"
		for pai in servico.encontrar(tipo):
			var slot := ApoiosPlex.livre(servico.planta, pai, item.tipo)
			if slot < 0: continue
			var passos := [servico.etapa(item.id, "pegar"), servico.etapa(pai, "apoiar", 0.9, {"slot":slot})]
			if servico.iniciar(ator, "Guardar equipamento", passos, reservas(servico, [item.id, pai])): return true
	return false

static func preparar(servico: ServicosPlex, ator: PersonagemPlex, passo: Dictionary) -> void:
	var raiz := ArmariosPlex.raiz(servico.planta, passo.alvo)
	if passo.acao == "devolver":
		var origem: int = servico.planta.objetos.get(passo.alvo, {}).get("origem_sobre", -1)
		if origem >= 0: raiz = ArmariosPlex.raiz(servico.planta, origem)
	passo.dados.armario = raiz
	if raiz >= 0: ArmariosPlex.estado(servico.planta, raiz, true)
	if passo.acao == "usar_vaso":
		ator.assento = passo.alvo
		var item: Dictionary = servico.planta.objetos[passo.alvo]
		ator.direcao = GradePlex.direcao_suporte(item.rotacao)
		if item.estado != "aberta":
			item.estado = "aberta"
			servico.planta.alterada.emit()
	if passo.acao == "higienizar": ator.trabalho = "higienizar"
	elif passo.acao == "jogar": ator.trabalho = "jogar"
	elif passo.acao == "usar_vaso": ator.trabalho = "usar_vaso"
	elif passo.acao in ["guardar_pertences", "consultar_armario"]: ator.trabalho = "usar_armario"

static func executar(servico: ServicosPlex, ator: PersonagemPlex, passo: Dictionary) -> bool:
	match str(passo.acao):
		"usar_vaso":
			ator.necessidades.banheiro = 100.0
			if ator.cargo == "cliente": ator.visita.banheiro = true
			ator.necessidades.higiene = maxf(0.0, float(ator.necessidades.higiene) - 25.0)
			ator.assento = -1
			servico.planta.objetos[passo.alvo].estado = "fechada"
		"higienizar":
			ator.necessidades.higiene = 100.0
			if ator.cargo == "cliente": ator.visita.higiene = true
		"jogar":
			ator.necessidades.lazer = 100.0
			if ator.cargo == "crianca": ator.visita.jogou = true
		"guardar_pertences": ator.necessidades.turno = true
		"consultar_armario": pass
		_: return false
	return true

static func atualizar(ator: PersonagemPlex, delta: float) -> void:
	for item in [["banheiro", 0.055], ["higiene", 0.04], ["lazer", 0.025]]:
		ator.necessidades[item[0]] = maxf(0.0, float(ator.necessidades[item[0]]) - delta * float(item[1]))
