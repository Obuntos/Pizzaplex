class_name ServicosPlex
extends RefCounted

signal aviso(texto: String)
var planta: PlantaPlex
var rotas: RotasPlex
var salas: AmbientesPlex
var inventario: InventarioPlex
var montagem: TarefasPlex
var personagens: Array
var trabalhos: Dictionary = {}
var pedidos: Array[Dictionary] = []
var proximo_pedido := 1
var entregas := 0
var limpezas := 0
var saldo := 0
var receita_arcade := 0
var espera := 0.0
var motivo := "Crie salas e coloque funcionários automáticos."

func _init(p: PlantaPlex, r: RotasPlex, a: AmbientesPlex, m: TarefasPlex, atores: Array) -> void:
	planta = p
	rotas = r
	salas = a
	montagem = m
	personagens = atores
	inventario = InventarioPlex.new(p)
	montagem.externos = trabalhos

func livre(id: int) -> bool:
	return planta.objetos.has(id) and planta.objetos[id].get("reserva", 0) == 0 and planta.objetos[id].get("carregada_por", 0) == 0

func encontrar(tipo: String, ambientes: Array = []) -> Array:
	return salas.equipamentos(tipo, ambientes).filter(func(id): return livre(id))

func alvos_passo(passo: Dictionary) -> Array[Vector2i]:
	if passo.acao=="reparar":
		var robo:=ReparosPlex.alvo(self,passo)
		return ReparosPlex.pontos(self,robo) if is_instance_valid(robo) else []
	var objeto: Dictionary = planta.objetos.get(passo.alvo,{})
	if passo.acao=="jogar" and passo.dados.has("posto"):
		var c: Array=passo.dados.posto
		return [Vector2i(c[0],c[1])]
	if passo.acao == "devolver" and planta.objetos.has(int(objeto.get("origem_sobre", -1))): return planta.interacoes(int(objeto.origem_sobre))
	if objeto.get("tipo","") in ["pia","bancada_preparo"]:
		var ponto := ponto_trabalho(passo)
		var alvos := planta.interacoes(passo.alvo)
		alvos.sort_custom(func(a,b): return Vector2(a).distance_squared_to(ponto)<Vector2(b).distance_squared_to(ponto))
		alvos.resize(mini(1,alvos.size()))
		return alvos
	if objeto.get("tipo","") == "forno" and passo.acao in ["assar","pegar_pizza","emplatar","aguardar_forno"]: return planta.interacoes_estado(passo.alvo,"aberto")
	if objeto.get("tipo","") == "geladeira" and passo.acao in ["ingrediente","abastecer","retirar_bebida"]: return planta.interacoes_estado(passo.alvo,"aberta")
	return planta.interacoes(passo.alvo)

func ponto_trabalho(passo: Dictionary) -> Vector2:
	if passo.acao=="reparar":
		var robo:=ReparosPlex.alvo(self,passo)
		return robo.local if is_instance_valid(robo) else Vector2.ZERO
	var raiz := ApoiosPlex.raiz(planta,passo.alvo)
	if passo.acao == "devolver":
		var origem: int = planta.objetos.get(passo.alvo, {}).get("origem_sobre", -1)
		if planta.objetos.has(origem): raiz = origem
	if raiz<0: return Vector2.ZERO
	var objeto: Dictionary = planta.objetos[raiz]
	var centro := ApoiosPlex.posicao(planta,objeto)
	if objeto.tipo in ["pia","bancada_preparo"]:
		var slot: int = passo.dados.get("slot",planta.objetos.get(passo.dados.get("prato",-1),{}).get("slot",0))
		var apoios := ApoiosPlex.pontos(objeto,planta)
		if slot>=0 and slot<apoios.size():
			centro += Vector3(apoios[slot].u,apoios[slot].v,apoios[slot].z)
	return Vector2(centro.x,centro.y)

func rota_passo(origem: Vector2i, passo: Dictionary, ator: PersonagemPlex = null) -> Array[Vector2i]:
	var bloqueios := CirculacaoEquipePlex.bloqueios(self,ator,origem)
	if is_instance_valid(ator): ator.set_meta("limites_rota",bloqueios)
	if passo.alvo < 0: return rotas.caminho(origem,Vector2i(passo.dados.celula[0],passo.dados.celula[1]),bloqueios)
	var melhor: Array[Vector2i] = []
	for alvo in alvos_passo(passo):
		var rota := rotas.caminho(origem,alvo,bloqueios)
		if not rota.is_empty() and (melhor.is_empty() or rota.size()<melhor.size()): melhor = rota
	return melhor

func etapa(alvo: int, acao: String, duracao: float = .6, dados: Dictionary = {}) -> Dictionary:
	return {"alvo":alvo,"acao":acao,"duracao":duracao,"dados":dados}

func iniciar(ator: PersonagemPlex, tipo: String, passos: Array, reservas: Array, pedido: int = -1) -> bool:
	if passos.is_empty(): return false
	if not EquipePlex.permite(ator, "manutencao"):
		if passos.any(func(p): return InventarioPlex.peca_oficina(planta.objetos.get(p.alvo, {}))): return false
		if InventarioPlex.peca_oficina(planta.objetos.get(ator.carga_item, {})): return false
	passos = passos.duplicate(true)
	reservas = reservas.duplicate()
	DevolucaoPlex.preparar(self, passos, reservas)
	reservas = RotinasPlex.reservas(self, reservas)
	var origem := ator.origem_rota()
	for passo in passos:
		var rota := rota_passo(origem,passo,ator)
		if rota.is_empty(): return false
		origem = rota[-1]
	for id in reservas:
		if not livre(id): return false
	if ator.trabalho=="circular_salao":
		ator.movimento.cancelar()
		ator.trabalho=""
	ator.visita.passeio_espera=2.0
	for id in reservas: planta.objetos[id].reserva = ator.identificador
	trabalhos[ator.identificador] = {"tipo":tipo,"passos":passos,"indice":0,"tempo":0.0,"reservas":reservas,"pedido":pedido,"iniciado":false}
	aviso.emit(tipo)
	return true

func pedido_por_id(id: int) -> Dictionary:
	for pedido in pedidos:
		if pedido.id == id: return pedido
	return {}

func criar_pedido(mesa: int = -1, cliente: int = -1, familia: int = -1, slot: int = -1) -> bool:
	salas.atualizar()
	if salas.equipamentos("registradora", ["salao", "recepcao"]).is_empty():
		motivo = "Coloque uma registradora no balcão de um salão ou recepção operacional."
		aviso.emit(motivo)
		return false
	var mesas := salas.equipamentos("mesa", ["salao"])
	if mesa >= 0: mesas = [mesa] if mesas.has(mesa) else []
	for id in mesas:
		if pedidos.any(func(p): return p.mesa == id and p.estado not in ["consumido", "cancelado"] and (slot<0 or int(p.get("slot",-1))==slot)): continue
		pedidos.append({"id":proximo_pedido,"mesa":id,"estado":"aguardando","pizza":-1,"tempo":0.0,"cliente":cliente,"familia":familia,"slot":slot})
		proximo_pedido += 1
		motivo = "Pedido do visitante registrado." if cliente >= 0 else "Pedido de teste registrado. O consumo é simulado após a entrega."
		aviso.emit(motivo)
		return true
	motivo = "É preciso ter uma mesa livre em um salão operacional."
	aviso.emit(motivo)
	return false

func organizar(ator: PersonagemPlex) -> bool:
	for caixa in inventario.caixas():
		if caixa.has("parte_endo") or InventarioPlex.peca_oficina(caixa): continue
		if caixa.get("sobre", -1) >= 0 and planta.objetos.get(caixa.sobre,{}).get("tipo","") != "ponto_recebimento": continue
		for estante in encontrar("estante", ["deposito"]):
			var slot := ApoiosPlex.livre(planta, estante, caixa.tipo)
			if slot >= 0 and iniciar(ator, "Guardar caixa", [etapa(caixa.id,"pegar"),etapa(estante,"apoiar",.8,{"slot":slot})], [caixa.id,estante]): return true
	return false

func guardar_pecas(ator: PersonagemPlex) -> bool:
	if not EquipePlex.permite(ator, "manutencao"): return false
	for item in inventario.pecas_oficina():
		var raiz := ApoiosPlex.raiz(planta, item.id)
		if planta.objetos.get(raiz, {}).get("tipo", "") == "armario_ferramentas": continue
		for pai in encontrar("armario_ferramentas"):
			var slot := ApoiosPlex.livre(planta, pai, item.tipo)
			if slot < 0: continue
			var passos := [etapa(item.id, "pegar"), etapa(pai, "apoiar", .9, {"slot":slot})]
			if iniciar(ator, "Guardar peças na oficina", passos, RotinasPlex.reservas(self, [item.id, pai])): return true
	return false

func abastecer(ator: PersonagemPlex) -> bool:
	for geladeira in encontrar("geladeira", ["cozinha"]):
		SuprimentosPlex.preparar(planta.objetos[geladeira])
		for caixa in inventario.caixas("ingredientes"):
			if not SuprimentosPlex.cabe(planta.objetos[geladeira],caixa): continue
			if iniciar(ator,"Abastecer geladeira",[etapa(caixa.id,"pegar"),etapa(geladeira,"abastecer",1.6),etapa(caixa.id,"devolver",.5)], [caixa.id,geladeira]): return true
	return false

func estantes() -> Array:
	return encontrar("armario_utensilios", ["cozinha", "deposito"]) + encontrar("estante", ["deposito", "cozinha"])

func destino_estante() -> Dictionary:
	for estante in estantes():
		var slot := ApoiosPlex.livre(planta, estante, "prato")
		if slot >= 0: return {"pai":estante, "slot":slot}
	return {}

func utensilios(ator: PersonagemPlex) -> bool:
	var destino := destino_estante()
	if destino.is_empty(): return false
	for caixa in inventario.caixas("utensilios"):
		if iniciar(ator,"Guardar pratos limpos",[etapa(caixa.id,"separar_prato",.8),etapa(destino.pai,"apoiar",.6,{"slot":destino.slot})],[caixa.id,destino.pai]): return true
	return false

func cozinhar(ator: PersonagemPlex) -> bool:
	if PreparoDuploPlex.iniciar(self,ator): return true
	for pedido in pedidos:
		if pedido.estado != "aguardando": continue
		for ambiente in salas.ambientes:
			if not ambiente.operacional or ambiente.tipo != "cozinha": continue
			for geladeira in salas.objetos(ambiente,"geladeira"):
				SuprimentosPlex.preparar(planta.objetos[geladeira])
				if not livre(geladeira) or planta.objetos[geladeira].get("ingredientes", 0) <= 0: continue
				for bancada in salas.objetos(ambiente,"bancada_preparo"):
					if not livre(bancada) or ApoiosPlex.livre(planta,bancada,"pizza") < 0: continue
					for forno in salas.objetos(ambiente,"forno"):
						var slot_forno := FornoPlex.vaga(planta,forno)
						if slot_forno<0: continue
						var passos := [etapa(geladeira,"ingrediente",.8),etapa(bancada,"preparar",3.0,{"slot":ApoiosPlex.livre(planta,bancada,"pizza")}),etapa(bancada,"pegar_pizza"),etapa(forno,"assar",1.0,{"slot":slot_forno})]
						if iniciar(ator,"Preparar pedido",passos,[geladeira,bancada],pedido.id):
							FornoPlex.reservar(planta.objetos[forno],slot_forno,pedido.id)
							pedido.estado = "preparando"
							return true
	return false

func destino_mesa(id: int, pedido: Dictionary = {}) -> Dictionary:
	var slot := int(pedido.get("slot", -1))
	if slot >= 0:
		return {"pai":id,"slot":slot} if ApoiosPlex.aceita(planta,id,"prato",slot) else {}
	slot = ApoiosPlex.livre(planta, id, "prato")
	return {"pai":id,"slot":slot} if slot >= 0 else {}

func guardar_pratos(ator: PersonagemPlex) -> bool:
	var destino := destino_estante()
	if destino.is_empty(): return false
	for prato in planta.objetos.values():
		var pai: int = prato.get("sobre", -1)
		if prato.tipo != "prato" or prato.get("sujo", false) or not livre(prato.id): continue
		if planta.objetos.get(pai, {}).get("tipo", "") in ["estante", "armario_utensilios"] or not ApoiosPlex.filhos(planta, prato.id).is_empty(): continue
		var reservas: Array = [prato.id, destino.pai]
		if pai >= 0:
			if not livre(pai): continue
			reservas.append(pai)
		if iniciar(ator,"Guardar prato limpo",[etapa(prato.id,"pegar"),etapa(destino.pai,"apoiar",.6,{"slot":destino.slot})],reservas): return true
	return false

func servir(ator: PersonagemPlex) -> bool:
	if EntregaDuplaPlex.iniciar(self,ator): return true
	for pedido in pedidos:
		if pedido.estado not in ["assando","pronta"] or not livre(pedido.mesa) or not planta.objetos.has(pedido.pizza): continue
		var forno: int = planta.objetos[pedido.pizza].get("sobre", -1)
		if planta.objetos.get(forno, {}).get("tipo", "") == "prato":
			var prato: Dictionary = planta.objetos[forno]
			if prato.get("sobre", -1) == pedido.mesa:
				pedido.estado = "entregue"
				pedido.tempo = 10.0
				continue
			var destino := destino_mesa(pedido.mesa, pedido)
			if destino.is_empty() or not livre(prato.id): continue
			var reservas: Array = [prato.id, pedido.mesa, pedido.pizza]
			var base: int = prato.get("sobre", -1)
			if base >= 0:
				if not livre(base): continue
				reservas.append(base)
			if iniciar(ator,"Retomar entrega",[etapa(prato.id,"pegar"),etapa(pedido.mesa,"servir",.8,destino)],reservas,pedido.id):
				pedido.estado = "entregando"
				return true
			continue

	return false

func limpar(ator: PersonagemPlex) -> bool:
	for item in planta.objetos.values():
		if (item.tipo not in ["mancha_chao","bebida_derramada"] and not MobiliaPlex.dados(item).get("entulho",false)) or item.get("sobre",-1)>=0 or not livre(item.id): continue
		var ferramentas := planta.objetos.values().filter(func(o): return o.tipo == ("balde" if item.tipo=="bebida_derramada" else "vassoura") and livre(o.id)).map(func(o): return o.id)
		var ambiente := salas.do_objeto(item.id)
		if ambiente.is_empty() or not ambiente.fechada: continue
		var lixeiras: Array = planta.objetos.values().filter(func(o): return o.tipo=="lixeira" and livre(o.id)).map(func(o): return o.id)
		for lixeira in lixeiras:
			if planta.objetos[lixeira].get("lixo",0) >= 6: continue
			for ferramenta in ferramentas:
				var passos := [etapa(ferramenta,"pegar"),etapa(item.id,"limpar",2.5),etapa(lixeira,"lixo",.7),etapa(ferramenta,"devolver",.5)]
				if iniciar(ator,"Limpar ambiente",passos,[item.id,lixeira,ferramenta]): return true
	return false

func lavar(ator: PersonagemPlex) -> bool:
	for prato in planta.objetos.values():
		if prato.tipo != "prato" or not livre(prato.id): continue
		var filhos := ApoiosPlex.filhos(planta, prato.id)
		if not prato.get("sujo", false) and not filhos.any(func(f): return f.tipo == "restos_mesa"): continue
		if filhos.any(func(f): return f.tipo != "restos_mesa" or not livre(f.id)): continue
		var pai: int = prato.get("sobre", -1)
		if pai >= 0 and not livre(pai): continue
		for pia in encontrar("pia", ["cozinha"]):
			var slot_pia := int(prato.slot) if pia == pai else ApoiosPlex.livre(planta, pia, "prato")
			if slot_pia < 0: continue
			var passos: Array = []
			if pia != pai: passos.append_array([etapa(prato.id,"pegar"),etapa(pia,"apoiar",.7,{"slot":slot_pia})])
			passos.append(etapa(pia,"lavar",3.5,{"prato":prato.id,"slot":slot_pia}))
			var reservas: Array = [prato.id,pia]
			if pai >= 0 and not reservas.has(pai): reservas.append(pai)
			for filho in filhos: reservas.append(filho.id)
			var destino := destino_estante()
			if not destino.is_empty():
				passos.append_array([etapa(pia,"recolher_prato",.6,{"prato":prato.id}),etapa(destino.pai,"apoiar",.6,{"slot":destino.slot})])
				reservas.append(destino.pai)
			if iniciar(ator,"Recolher e lavar prato",passos,reservas): return true
	return false

func esvaziar(ator: PersonagemPlex) -> bool:
	for lixeira in encontrar("lixeira"):
		if planta.objetos[lixeira].get("lixo",0) < 6: continue
		for y in GradePlex.TAMANHO.y:
			for x in GradePlex.TAMANHO.x:
				var c := Vector2i(x,y)
				if x not in [0,GradePlex.TAMANHO.x-1] and y not in [0,GradePlex.TAMANHO.y-1]: continue
				if not planta.transitavel(c): continue
				var passos := [etapa(lixeira,"coletar_lixo",1),etapa(-1,"descartar",1,{"celula":[x,y],"lixeira":lixeira})]
				if iniciar(ator,"Esvaziar lixeira",passos,[lixeira]): return true
	return false

func descansar(ator: PersonagemPlex) -> bool:
	if ator.energia >= 25: return false
	for cadeira in encontrar("cadeira",["descanso"]):
		if iniciar(ator,"Descansar",[etapa(cadeira,"descansar",7.0)],[cadeira]): return true
	return false

func cancelar(ator: PersonagemPlex) -> void:
	var trabalho: Dictionary = trabalhos.get(ator.identificador,{})
	for passo in trabalho.get("passos",[]):
		if passo.acao=="aquecer" and planta.objetos.has(passo.alvo):
			planta.objetos[passo.alvo].estado="apagado"
			planta.alterada.emit()
	BebidasPlex.cancelar(self,ator,trabalho)
	ReparosPlex.liberar(self,ator,trabalho)
	ArmariosPlex.fechar_reservas(planta, trabalho)
	ator.assento = -1
	for pedido_id in trabalho.get("pedidos",[trabalho.get("pedido",-1)]):
		if trabalho.get("tipo", "") == "Servir guaraná": break
		var pedido := pedido_por_id(int(pedido_id))
		FornoPlex.liberar(planta,int(pedido_id))
		if pedido.is_empty(): continue
		if pedido.estado == "preparando":
			if pedido.get("ingrediente_retirado", false) and planta.objetos.has(pedido.get("geladeira", -1)):
				SuprimentosPlex.devolver(planta.objetos[pedido.geladeira])
			pedido.ingrediente_retirado = false
			if planta.objetos.has(pedido.pizza): planta.remover(pedido.pizza)
			pedido.pizza = -1
			pedido.estado = "aguardando"
		elif pedido.estado == "entregando":
			pedido.estado = "assando" if FornoPlex.tempo(planta,pedido)>0 else "pronta"
	for id in trabalho.get("reservas",[]):
		if planta.objetos.has(id) and planta.objetos[id].reserva == ator.identificador: planta.objetos[id].reserva = 0
	for item in planta.objetos.values():
		if item.reserva == ator.identificador: item.reserva = 0
	inventario.devolver(ator)
	trabalhos.erase(ator.identificador)
	ator.trabalho = ""
	ator.progresso_acao = 0

func concluir(ator: PersonagemPlex) -> void:
	var trabalho: Dictionary = trabalhos[ator.identificador]
	BebidasPlex.cancelar(self,ator,trabalho)
	ReparosPlex.liberar(self,ator,trabalho)
	ArmariosPlex.fechar_reservas(planta, trabalho)
	ator.assento = -1
	for id in trabalho.reservas:
		if planta.objetos.has(id) and planta.objetos[id].reserva == ator.identificador: planta.objetos[id].reserva = 0
	trabalhos.erase(ator.identificador)
	ator.trabalho = ""
	ator.progresso_acao = 0

func executar(ator: PersonagemPlex, passo: Dictionary, trabalho: Dictionary) -> bool:
	var alvo: int = passo.alvo
	var objeto: Dictionary = planta.objetos.get(alvo,{})
	var pedido := pedido_por_id(int(passo.dados.get("pedido",trabalho.pedido)))
	if passo.acao in ["retirar_bebida", "servir_bebida", "descartar_copo"]: return BebidasPlex.executar(self,ator,passo,trabalho)
	match passo.acao:
		"reparar": return ReparosPlex.concluir(self,ator,passo)
		"pegar": return inventario.pegar(ator,alvo)
		"devolver": return inventario.devolver(ator)
		"apoiar": return inventario.apoiar(ator,alvo,int(passo.dados.slot))
		"depositar":
			var dinheiro: Dictionary = planta.objetos.get(ator.carga_item, {})
			if dinheiro.get("tipo", "") != "dinheiro" or objeto.get("tipo", "") != "registradora": return false
			var valor := maxi(0, int(dinheiro.get("valor", 0)))
			saldo += valor
			objeto.saldo = int(objeto.get("saldo", 0)) + valor
			var id := ator.carga_item
			ator.carga_item = -1
			planta.remover(id)
		"abastecer":
			if not planta.objetos.has(ator.carga_item): return false
			var caixa: Dictionary = planta.objetos[ator.carga_item]
			var qtd := SuprimentosPlex.abastecer(objeto,caixa)
			if qtd <= 0: return false
			objeto.estado = "fechada"
			if caixa.quantidade <= 0:
				var id: int = ator.carga_item
				ator.carga_item = -1
				planta.remover(id)

		"separar_prato":
			if not inventario.consumir_caixa(alvo): return false
			var id := inventario.criar("prato",ator.celula)
			return inventario.pegar(ator,id)
		"ingrediente":
			if not SuprimentosPlex.retirar(objeto): return false
			pedido.ingrediente_retirado = true
			pedido.geladeira = alvo
			objeto.estado = "fechada"
		"preparar":
			var slot: int = passo.dados.get("slot",ApoiosPlex.livre(planta,alvo,"pizza"))
			if slot < 0: return false
			var id := inventario.criar("pizza",ator.celula)
			if not ApoiosPlex.fixar(planta,id,alvo,slot): return false
			pedido.pizza = id
		"pegar_pizza":
			if pedido.is_empty() or not inventario.pegar(ator,pedido.pizza): return false
			if objeto.tipo == "forno": objeto.estado = "fechado"
		"emplatar":
			if not InventarioPlex.tem(ator,int(passo.dados.prato)) or not planta.objetos.has(pedido.pizza): return false
			var prato := int(passo.dados.prato)
			var slot := ApoiosPlex.livre(planta, prato, "pizza")
			if slot < 0 or not ApoiosPlex.fixar(planta, pedido.pizza, prato, slot): return false
			FornoPlex.fechar(planta,objeto)
		"assar":
			var slot := int(passo.dados.get("slot",FornoPlex.vaga(planta,alvo)))
			if not inventario.apoiar_item(ator,pedido.pizza,alvo,slot): return false
			planta.objetos[pedido.pizza].tempo_assar = FornoPlex.DURACAO
			FornoPlex.liberar(planta,pedido.id)
			objeto.tempo_assar = maxf(FornoPlex.DURACAO,float(objeto.get("tempo_assar",0.0)))
			objeto.pedido_forno = pedido.id
			objeto.estado = "funcionando"
			pedido.estado = "assando"
		"servir":
			if not inventario.apoiar_item(ator,int(passo.dados.get("prato",ator.carga_item)),int(passo.dados.pai),int(passo.dados.slot)): return false
			pedido.estado = "entregue"
			pedido.tempo = 10.0
			entregas += 1
		"aquecer":
			objeto.estado = "apagado"
			planta.alterada.emit()
		"limpar":
			planta.remover(alvo)
			limpezas += 1
		"lixo":
			objeto.lixo = mini(6,int(objeto.lixo)+1)
			objeto.estado = "cheia" if objeto.lixo >= 6 else "vazia"
			LimpezaContinuaPlex.proxima(self,ator,trabalho)
		"lavar":
			var prato_id: int = passo.dados.get("prato",ator.carga_item)
			if not planta.objetos.has(prato_id): return false
			for filho in ApoiosPlex.filhos(planta,prato_id):
				if filho.tipo=="restos_mesa": planta.remover(filho.id)
			planta.objetos[prato_id].sujo = false
			limpezas += 1
			planta.alterada.emit()
		"recolher_prato": return inventario.pegar(ator,int(passo.dados.prato))
		"descartar":
			var lixeira: int = passo.dados.lixeira
			if planta.objetos.has(lixeira):
				planta.objetos[lixeira].lixo = 0
				planta.objetos[lixeira].estado = "vazia"
		"descansar": ator.energia = minf(100,ator.energia+75)
		"usar_vaso", "higienizar", "jogar", "afastar_fliperama", "guardar_pertences", "consultar_armario":
			if not RotinasPlex.executar(self, ator, passo): return false
	planta.alterada.emit()
	return true

func atualizar_trabalho(ator: PersonagemPlex, trabalho: Dictionary, delta: float) -> void:
	if not EquipePlex.permite(ator, "manutencao") and InventarioPlex.peca_oficina(planta.objetos.get(ator.carga_item, {})):
		cancelar(ator)
		return
	if trabalho.indice<trabalho.passos.size() and not ReparosPlex.valido(self,ator,trabalho):
		cancelar(ator)
		return
	if trabalho.indice >= trabalho.passos.size():
		concluir(ator)
		return
	var passo: Dictionary = trabalho.passos[trabalho.indice]
	if (passo.acao == "devolver" or passo.dados.get("devolucao", false)) and ator.carga_item < 0:
		trabalho.indice += 1
		return
	if passo.alvo >= 0 and not planta.objetos.has(passo.alvo):
		cancelar(ator)
		return
	if ator.ocupado(): return
	if not DevolucaoPlex.atualizar_retorno(self,ator,trabalho,passo):
		ator.trabalho = "aguardar_armario"
		return
	var rota: Array[Vector2i]
	var chegou := false
	if passo.alvo >= 0:
		chegou = alvos_passo(passo).has(ator.celula)
		if not chegou: rota = rota_passo(ator.origem_rota(),passo,ator)
	else:
		var local := Vector2i(passo.dados.celula[0],passo.dados.celula[1])
		chegou = ator.celula == local
		if not chegou: rota = rota_passo(ator.origem_rota(),passo,ator)
	if not chegou:
		if rota.is_empty():
			motivo = "Tarefa interrompida: o acesso ao equipamento foi bloqueado."
			cancelar(ator)
		else: ator.andar(rota)
		return
	if passo.acao in ["aguardar_forno", "emplatar"] and FornoPlex.tempo(planta,pedido_por_id(int(passo.dados.get("pedido",trabalho.pedido))))>0.0:
		montagem.orientar(ator, ponto_trabalho(passo))
		ator.trabalho = "aguardar_forno"
		ator.progresso_acao = 0.0
		return
	if passo.acao == "aguardar_forno":
		trabalho.indice += 1
		trabalho.tempo = 0.0
		ator.trabalho = ""
		return
	if passo.acao in ["limpar","lavar","preparar","reparar","aquecer"] and trabalho.get("acomodado",-1)!=trabalho.indice:
		trabalho.acomodado = trabalho.indice
		var destino := ponto_trabalho(passo)
		var ponto := PosicaoTrabalhoPlex.aproximacao(ator, planta, destino, .25 if passo.acao=="reparar" else .6 if passo.acao=="preparar" else .42 if passo.acao=="lavar" else .28)
		ator.movimento.aproximar(ator,ponto)
		return
	if passo.alvo >= 0:
		montagem.orientar(ator,ponto_trabalho(passo))
	ator.trabalho = "preparar" if passo.acao in ["preparar","aquecer"] else "lavar" if passo.acao == "lavar" else "descansar" if passo.acao == "descansar" else "servico"
	if passo.acao == "limpar": ator.trabalho = "varrer" if planta.objetos.get(ator.carga_item,{}).get("tipo","")=="vassoura" else "esfregar"
	if passo.alvo >= 0 and planta.objetos[passo.alvo].tipo in ["geladeira","forno"]:
		var item: Dictionary = planta.objetos[passo.alvo]
		var aberto := "aberta" if item.tipo == "geladeira" else "aberto"
		if item.estado != aberto:
			item.estado = aberto
			planta.alterada.emit()
	if passo.acao == "depositar": ator.trabalho = "usar_caixa"
	RotinasPlex.preparar(self, ator, passo)
	if passo.acao=="reparar": ReparosPlex.preparar(self,ator,passo)
	trabalho.tempo += delta
	ator.progresso_acao = fposmod(trabalho.tempo/2.5,1.0)
	if trabalho.tempo >= passo.duracao:
		var armario := int(passo.dados.get("armario", ArmariosPlex.raiz(planta, passo.alvo)))
		if not executar(ator,passo,trabalho):
			motivo = "Tarefa aguarda material ou uma posição de apoio livre."
			cancelar(ator)
			return
		ArmariosPlex.estado(planta, armario, false)
		trabalho.indice += 1
		trabalho.tempo = 0.0
		ator.trabalho = ""

func atualizar_pedidos(delta: float) -> void:
	FornoPlex.atualizar(self,delta)
	BebidasPlex.atualizar(self,delta)
	for pedido in pedidos:
		if not planta.objetos.has(pedido.mesa):
			pedido.estado = "cancelado"
			continue
		if (LugaresPlex.total(planta,pedido.mesa)==0 or (pedido.pizza>=0 and not planta.objetos.has(pedido.pizza))) and pedido.estado not in ["consumido","cancelado"]:
			pedido.estado="cancelado"
			if planta.objetos.has(pedido.pizza): planta.remover(pedido.pizza)
			continue
		if pedido.estado == "entregue":
			if int(pedido.get("cliente", -1)) >= 0:
				var presentes := personagens.filter(func(a): return a.identificador == int(pedido.cliente) and a.trabalho == "sentar_mesa" and a.assento == LugaresPlex.cadeiras(planta,planta.objetos[pedido.mesa])[int(pedido.slot)])
				if presentes.is_empty(): continue
			pedido.tempo -= delta
			if pedido.tempo <= 0:
				var pai: int = planta.objetos.get(pedido.pizza,{}).get("sobre",pedido.mesa)
				planta.remover(pedido.pizza)
				if planta.objetos.get(pai,{}).get("tipo","")=="prato": planta.objetos[pai].sujo = true
				var id := inventario.criar("restos_mesa",planta.objetos[pedido.mesa].celula)
				var slot := ApoiosPlex.livre(planta,pai,"restos_mesa")
				if slot >= 0: ApoiosPlex.fixar(planta,id,pai,slot)
				else: planta.remover(id)
				pedido.estado = "consumido"

func atualizar(delta: float) -> void:
	salas.atualizar()
	atualizar_pedidos(delta)
	espera += delta
	for ator in personagens:
		if FantasiasRestaurantePlex.ocupando(ator) or ator.robo or (ator.cargo=="funcionario" and ator.funcao in ["caixa","seguranca"]) or (AdministradorPlex.eh(ator) and ator.trabalho in ["caixa","ir_caixa","usar_caixa"]): continue
		RotinasPlex.atualizar(ator, delta)
		if trabalhos.has(ator.identificador):
			ator.energia = maxf(0,ator.energia-delta*.15)
			atualizar_trabalho(ator,trabalhos[ator.identificador],delta)
		elif not EquipePlex.em_comando(ator) and str(ator.visita.get("fantasia_etapa",""))!="esperando" and espera >= .5 and ator.cargo == "funcionario" and ator.automatico and (not ator.ocupado() or ator.trabalho=="circular_salao") and ator.trabalho != "liberar_saida" and not montagem.trabalhos.has(ator.identificador):
			if ReparosPlex.voltar_oficina(self,ator): continue
			if ator.carregando: continue
			if EquipePlex.permite(ator,"manutencao") and ator.funcao in ["geral","manutencao","administrador"] and not montagem.alvos(ator).is_empty() and not montagem.caixas(ator).is_empty():
				ReparosPlex.iniciar(self,ator)
				continue
			if ator.carga_item >= 0:
				if DevolucaoPlex.guardar_carga(self, ator): continue
				inventario.devolver(ator)
			if RotinasPlex.prioritaria(self, ator) or descansar(ator) or atribuir_funcao(ator) or RotinasPlex.entre_tarefas(self, ator): continue
			if CirculacaoEquipePlex.retornar(self,ator): continue
			PasseioAtendimentoPlex.iniciar(self,ator,espera)
	if espera >= .5: espera = 0

func atribuir_funcao(ator: PersonagemPlex) -> bool:
	for funcao in EquipePlex.prioridades(ator):
		match str(funcao):
			"manutencao":
				if ReparosPlex.iniciar(self,ator) or guardar_pecas(ator) or RotinasPlex.organizar(self,ator): return true
			"cozinha":
				if cozinhar(ator): return true
			"atendimento":
				if servir(ator) or BebidasPlex.servir(self,ator) or BebidasPlex.recolher(self,ator) or recolher_pagamento(ator): return true
			"limpeza":
				if RotinasPlex.organizar(self,ator) or BebidasPlex.recolher(self,ator) or lavar(ator) or guardar_pratos(ator) or limpar(ator) or esvaziar(ator): return true
			"estoque":
				if abastecer(ator) or organizar(ator) or utensilios(ator) or guardar_pratos(ator): return true
	return false

func recolher_pagamento(ator: PersonagemPlex) -> bool:
	for item in planta.objetos.values():
		if item.tipo != "dinheiro" or not livre(item.id): continue
		for caixa in encontrar("registradora", ["salao", "recepcao"]):
			if iniciar(ator, "Levar pagamento ao caixa", [etapa(item.id,"pegar",.7),etapa(caixa,"depositar",1.2)], [item.id,caixa]): return true
	return false

func gravar() -> Dictionary:
	var ativos: Array = []
	for id in trabalhos: ativos.append({"ator":id,"trabalho":trabalhos[id]})
	return {"versao":5,"saldo":saldo,"receita_arcade":receita_arcade,"pedidos":pedidos,"proximo_pedido":proximo_pedido,"entregas":entregas,"limpezas":limpezas,"trabalhos":ativos}

func restaurar(dados: Dictionary) -> void:
	trabalhos.clear()
	pedidos.assign(dados.get("pedidos",[]).duplicate(true))
	for pedido in pedidos:
		for campo in ["id", "mesa", "pizza", "prato", "geladeira", "cliente", "familia", "slot"]:
			if pedido.has(campo): pedido[campo] = int(pedido[campo])
	proximo_pedido = int(dados.get("proximo_pedido",1))
	entregas = int(dados.get("entregas",0))
	limpezas = int(dados.get("limpezas",0))
	saldo = int(dados.get("saldo",0))
	receita_arcade = int(dados.get("receita_arcade",0))
	for salvo in dados.get("trabalhos",[]):
		var ator_id: int = salvo.ator
		if not personagens.any(func(a): return a.identificador == ator_id): continue
		var trabalho: Dictionary = salvo.trabalho.duplicate(true)
		trabalho.indice = int(trabalho.indice)
		trabalho.pedido = int(trabalho.get("pedido", -1))
		if trabalho.has("pedidos"): trabalho.pedidos = trabalho.pedidos.map(func(id): return int(id))
		trabalho.reservas = trabalho.reservas.map(func(id): return int(id))
		for passo in trabalho.passos:
			passo.alvo = int(passo.alvo)
			for campo in ["prato", "pai", "slot", "lixeira", "pedido", "robo", "caixa"]:
				if passo.dados.has(campo): passo.dados[campo] = int(passo.dados[campo])
		if int(dados.get("versao",0)) < 3 and (trabalho.tipo in ["Lavar prato","Recolher e lavar prato","Arrumar lugar na mesa","Entregar pedido","Separar pratos"] or trabalho.passos.any(func(p): return p.acao=="limpar" and planta.objetos.get(p.alvo,{}).get("tipo","")=="restos_mesa")):
			for ator in personagens:
				if ator.identificador==ator_id:
					inventario.devolver(ator)
					ator.trabalho = ""
			var pedido := pedido_por_id(trabalho.get("pedido",-1))
			if not pedido.is_empty() and pedido.estado == "entregando": pedido.estado = "pronta"
			continue
		trabalho.erase("acomodado")
		trabalhos[ator_id] = trabalho
		for id in trabalho.reservas:
			if planta.objetos.has(int(id)): planta.objetos[int(id)].reserva = ator_id

	for a in personagens:
		if a.robo: a.robotica.reparo_por=0
	for id in trabalhos:
		var trabalho: Dictionary=trabalhos[id]
		if trabalho.tipo!="Reparar animatrônico": continue
		var robo:=ReparosPlex.alvo(self,trabalho.passos[-1])
		if is_instance_valid(robo): robo.robotica.reparo_por=int(id)

