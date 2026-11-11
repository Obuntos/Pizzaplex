class_name ServicosPlex
extends RefCounted

signal aviso(texto: String)
signal dinheiro_recebido(valor: float)
var planta: PlantaPlex
var jogo:Node
var rotas: RotasPlex
var salas: AmbientesPlex
var inventario: InventarioPlex
var montagem: TarefasPlex
var personagens: Array
var recepcao: RecepcaoVisitantesPlex
var caminhos_descarte: CaminhosCidadePlex
var trabalhos: Dictionary = {}
var pedidos: Array[Dictionary] = []
var proximo_pedido := 1
var preferencia_prato:="ceramica"
var presentes: Array=[]
var recompensas: Array=[]
var prioridades: Array=[]
var reputacao: Dictionary={}
var aniversarios: Array=[]
var entregas := 0
var limpezas := 0
var saldo := 0.0
var receita_arcade := 0
var tempo_servico:=0.0
var espera := 0.0
var motivo := "Crie salas e coloque funcionários automáticos."

func _init(p: PlantaPlex, r: RotasPlex, a: AmbientesPlex, m: TarefasPlex, atores: Array) -> void:
	planta = p
	rotas = r
	caminhos_descarte=CaminhosCidadePlex.new(p,r)
	salas = a
	montagem = m
	personagens = atores
	inventario = InventarioPlex.new(p)

func receber(valor: float) -> void:
	if valor<=0: return
	saldo=snappedf(saldo+valor,.01)
	dinheiro_recebido.emit(float(valor))

func livre(id: int) -> bool:
	if planta.objetos.has(id) and not LoucaSecagemPlex.pode_recolher(self,planta.objetos[id]):return false
	return planta.objetos.has(id) and planta.objetos[id].get("reserva", 0) == 0 and planta.objetos[id].get("carregada_por", 0) == 0

func encontrar(tipo: String, ambientes: Array = []) -> Array:
	return salas.equipamentos(tipo, ambientes).filter(func(id): return livre(id))

func alvos_passo(passo: Dictionary) -> Array[Vector2i]:
	if passo.acao in ["descartar_saco","descartar_prato","lixo","descartar_copo","descartar_item"]: return DescartePlex.acessos(planta,planta.objetos.get(passo.alvo,{}))
	if passo.acao=="reparar":
		var robo:=ReparosPlex.alvo(self,passo)
		return ReparosPlex.pontos(self,robo) if is_instance_valid(robo) else []
	var objeto: Dictionary = planta.objetos.get(passo.alvo,{})
	var raiz:=ApoiosPlex.raiz(planta,passo.alvo)
	if raiz>=0 and not TerrenoPlex.contem(planta,planta.objetos[raiz].celula): return []
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
	if FornoPlex.eh(objeto) and passo.acao in ["assar","pegar_pizza","emplatar","aguardar_forno"]: return FornoPlex.acessos(planta,passo.alvo)
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
	if passo.dados.get("descarte_externo",false):
		if passo.alvo<0: return caminhos_descarte.caminho(origem,Vector2i(passo.dados.celula[0],passo.dados.celula[1]))
		var melhor_externa: Array[Vector2i]=[]
		for destino in alvos_passo(passo):
			var externa:=caminhos_descarte.caminho(origem,destino)
			if not externa.is_empty() and (melhor_externa.is_empty() or externa.size()<melhor_externa.size()): melhor_externa=externa
		return melhor_externa
	var bloqueios := CirculacaoEquipePlex.bloqueios(self,ator,origem)
	if is_instance_valid(ator): ator.set_meta("limites_rota",bloqueios)
	if passo.alvo < 0: return rotas.caminho(origem,Vector2i(passo.dados.celula[0],passo.dados.celula[1]),bloqueios)
	var melhor: Array[Vector2i] = []
	for alvo in alvos_passo(passo):
		if not TerrenoPlex.contem(planta,alvo): continue
		var rota := rotas.caminho(origem,alvo,bloqueios)
		if TerrenoPlex.contem(planta,origem) and rota.any(func(c): return not TerrenoPlex.contem(planta,c)): continue
		if not rota.is_empty() and (melhor.is_empty() or rota.size()<melhor.size()): melhor = rota
	return melhor

func etapa(alvo: int, acao: String, duracao: float = .6, dados: Dictionary = {}) -> Dictionary:
	return {"alvo":alvo,"acao":acao,"duracao":duracao,"dados":dados}

func iniciar(ator: PersonagemPlex, tipo: String, passos: Array, reservas: Array, pedido: int = -1) -> bool:
	if trabalhos.has(ator.identificador) or montagem.trabalhos.has(ator.identificador) or (ControleAdministradorPlex.ocupado(ator) and not tutorial_autorizado(ator,tipo,passos)) or passos.is_empty(): return false
	if reservas.any(func(id): return planta.objetos.has(id) and DescartePlex.eh(planta.objetos[id]) and not DescartePlex.interna(planta,planta.objetos[id]) and not (tipo=="Retirar saco de lixo" and passos.any(func(passo): return passo.alvo==id and passo.acao=="descartar_saco"))): return false
	if not EquipePlex.permite(ator, "manutencao"):
		if passos.any(func(p): return InventarioPlex.peca_oficina(planta.objetos.get(p.alvo, {}))): return false
		if InventarioPlex.peca_oficina(planta.objetos.get(ator.carga_item, {})): return false
	passos = passos.duplicate(true)
	reservas = reservas.duplicate()
	DevolucaoPlex.preparar(self, passos, reservas)
	reservas = RotinasPlex.reservas(self, reservas)
	for id in reservas:
		if not livre(id): return false
	var origem := ator.origem_rota()
	for passo in passos:
		var rota := rota_passo(origem,passo,ator)
		if rota.is_empty(): return false
		origem = rota[-1]
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
		pedidos.append({"id":proximo_pedido,"mesa":id,"estado":"aguardando","pizza":-1,"tempo":0.0,"cliente":cliente,"familia":familia,"slot":slot,"fatias_restantes":4,"fatias_comidas":0})
		PartilhaPizzaPlex.registrar(self,pedidos[-1])
		proximo_pedido += 1
		motivo = "Pedido do visitante registrado." if cliente >= 0 else "Pedido de teste registrado. O consumo é simulado após a entrega."
		aviso.emit(motivo)
		return true
	motivo = "É preciso ter uma mesa livre em um salão operacional."
	aviso.emit(motivo)
	return false

func organizar(ator: PersonagemPlex) -> bool:
	for caixa in inventario.caixas():
		if caixa.get("reservada_atracao",false): continue
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

func abastecer(ator: PersonagemPlex,apenas_cozinha:bool=false) -> bool:
	for geladeira in encontrar("geladeira", ["cozinha"]):
		SuprimentosPlex.preparar(planta.objetos[geladeira])
		for caixa in inventario.caixas("ingredientes"):
			if apenas_cozinha and not CozinhaProntaPlex.na_cozinha(self,int(caixa.id)):continue
			if not SuprimentosPlex.cabe(planta.objetos[geladeira],caixa): continue
			if iniciar(ator,"Abastecer geladeira",[etapa(caixa.id,"pegar"),etapa(geladeira,"abastecer",1.6),etapa(caixa.id,"devolver",.5)], [caixa.id,geladeira]): return true
	return false

func estantes() -> Array:
	return encontrar("armario_utensilios", ["cozinha", "deposito"]) + encontrar("estante", ["deposito", "cozinha"]) + encontrar("amb_carrinho_louca",["cozinha"])

func destino_estante(prato: Dictionary={},apenas_cozinha:bool=false) -> Dictionary:
	if not prato.is_empty() and prato.get("tipo","")=="prato":
		var carrinho:=LoucaSecagemPlex.destino(self,prato)
		if not carrinho.is_empty():return carrinho
	var parcial:=PacotesPratosPlex.parcial(planta,str(prato.get("material_prato","ceramica")))
	if not parcial.is_empty() and PacotesPratosPlex.eh(prato) and (not apenas_cozinha or CozinhaProntaPlex.na_cozinha(self,int(parcial.id))):return {"pai":int(parcial.sobre),"slot":int(parcial.slot)}
	var retorno:=PacotesPratosPlex.destino(planta,prato)
	if not retorno.is_empty() and (not apenas_cozinha or CozinhaProntaPlex.na_cozinha(self,int(retorno.pai))): return retorno
	for estante in estantes():
		if apenas_cozinha and not CozinhaProntaPlex.na_cozinha(self,int(estante)):continue
		var slot := ApoiosPlex.livre(planta, estante, "prato")
		if slot >= 0: return {"pai":estante, "slot":slot}
	return {}

func utensilios(ator: PersonagemPlex,apenas_cozinha:bool=false) -> bool:
	for caixa in PratosPlex.preferidos(self,inventario.caixas("utensilios")):
		if apenas_cozinha and not CozinhaProntaPlex.na_cozinha(self,int(caixa.id)):continue
		var destino:=destino_estante(caixa,apenas_cozinha)
		if destino.is_empty():continue
		if PacotesPratosPlex.guardado(caixa): continue
		var pai: Dictionary=planta.objetos.get(int(caixa.get("sobre",-1)),{})
		if CatalogoPlex.base(str(pai.get("tipo",""))) in ["estante","armario_utensilios"]:
			caixa.pratos_guardados=true
			PacotesPratosPlex.preparar(caixa)
			continue
		if iniciar(ator,"Guardar pacote de pratos",[etapa(caixa.id,"pegar",.8),etapa(destino.pai,"apoiar",.6,{"slot":destino.slot})],[caixa.id,destino.pai]): return true
	return false

func cozinhar(ator: PersonagemPlex) -> bool:
	if jogo!=null and not jogo.operacao.aberto and AdministradorPlex.eh(ator):return false
	if CozinhaProntaPlex.retirar(self,ator):return true
	CozinhaProntaPlex.encomendar(self)
	if PreparoDuploPlex.iniciar(self,ator): return true
	for pedido in pedidos:
		if pedido.estado != "aguardando": continue
		for ambiente in salas.ambientes:
			if not salas.habilitada(ambiente,["cozinha"]): continue
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
	for prato in planta.objetos.values():
		var pai: int = prato.get("sobre", -1)
		if prato.tipo != "prato" or prato.get("sujo", false) or not livre(prato.id) or not LoucaSecagemPlex.pode_recolher(self,prato): continue
		if planta.objetos.get(pai,{}).get("tipo","")=="amb_carrinho_louca":continue
		if CatalogoPlex.base(planta.objetos.get(pai, {}).get("tipo", "")) in ["estante", "armario_utensilios"] or not ApoiosPlex.filhos(planta, prato.id).is_empty(): continue
		var destino:=destino_estante(prato)
		if destino.is_empty(): continue
		var reservas: Array = [prato.id, destino.pai]
		if pai >= 0:
			if not livre(pai): continue
			reservas.append(pai)
		if iniciar(ator,"Guardar prato limpo",[etapa(prato.id,"pegar"),etapa(destino.pai,"apoiar",.6,{"slot":destino.slot})],reservas): return true
	return false

func servir(ator: PersonagemPlex) -> bool:
	if EntregaDuplaPlex.iniciar(self,ator): return true
	for pedido in pedidos:
		if pedido.get("estoque_cozinha",false):continue
		if pedido.estado not in ["assando","pronta"] or not livre(pedido.mesa) or not planta.objetos.has(pedido.pizza): continue
		var forno: int = planta.objetos[pedido.pizza].get("sobre", -1)
		if planta.objetos.get(forno, {}).get("tipo", "") == "prato":
			var prato: Dictionary = planta.objetos[forno]
			if prato.get("sobre", -1) == pedido.mesa:
				PartilhaPizzaPlex.receber(self,pedido)
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
	var candidatos:=planta.objetos.values().filter(func(item): return LimpezaAmbientesPlex.eh(item))
	candidatos.sort_custom(func(a,b): return Vector2(a.celula).distance_squared_to(ator.local)<Vector2(b.celula).distance_squared_to(ator.local))
	for item in candidatos:
		if limpar_alvo(ator,item.id): return true
	return LimpezaAmbientesPlex.descartar(self,ator)

func lavar(ator: PersonagemPlex, mesa_alvo: int=-1, prato_alvo:int=-1) -> bool:
	if PratosPlex.descartar(self,ator,mesa_alvo,prato_alvo): return true
	for prato in planta.objetos.values():
		if prato_alvo>=0 and int(prato.id)!=prato_alvo:continue
		if prato.tipo != "prato" or PratosPlex.papel(prato) or FestasRestaurantePlex.reservar_prato(self,prato) or not livre(prato.id): continue
		if mesa_alvo>=0 and int(prato.get("sobre",-1))!=mesa_alvo: continue
		var filhos := ApoiosPlex.filhos(planta, prato.id)
		if not prato.get("sujo", false) and not filhos.any(func(f): return f.tipo == "restos_mesa"): continue
		if not EsperaLimpezaPlex.pode(self,prato,prato_alvo>=0 or mesa_alvo>=0):continue
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
			var destino:=LoucaSecagemPlex.destino(self,prato,true)
			if destino.is_empty():destino=destino_estante(prato)
			if not destino.is_empty():
				passos.append_array([etapa(pia,"recolher_prato",.6,{"prato":prato.id}),etapa(destino.pai,"apoiar",.6,{"slot":destino.slot})])
				reservas.append(destino.pai)
			if iniciar(ator,"Recolher e lavar prato",passos,reservas): return true
	return recolher_louca(ator,mesa_alvo) if prato_alvo<0 else false

func recolher_louca(ator: PersonagemPlex, mesa_alvo: int=-1) -> bool:
	for prato in planta.objetos.values():
		if prato.tipo!="prato" or not prato.get("sujo",false) or not livre(prato.id):continue
		if PratosPlex.papel(prato):
			if PratosPlex.descartar(self,ator,mesa_alvo,prato.id):return true
			continue
		if not EsperaLimpezaPlex.pode(self,prato,mesa_alvo>=0):continue
		var mesa:Dictionary=planta.objetos.get(int(prato.get("sobre",-1)),{})
		if not LugaresPlex.mesa(str(mesa.get("tipo",""))) or not livre(int(mesa.id)) or mesa_alvo>=0 and int(mesa.id)!=mesa_alvo:continue
		var filhos:=ApoiosPlex.filhos(planta,prato.id)
		if filhos.any(func(f):return f.tipo!="restos_mesa" or not livre(int(f.id))):continue
		for pia in encontrar("pia",["cozinha"]):
			var slot:=ApoiosPlex.livre(planta,int(pia),"prato")
			if slot<0:continue
			var reservas:Array=[prato.id,mesa.id,pia]
			for filho in filhos:reservas.append(filho.id)
			if iniciar(ator,"Levar louça usada à cozinha",[etapa(prato.id,"pegar"),etapa(pia,"apoiar",.6,{"slot":slot})],reservas):return true
	return false

func esvaziar(ator: PersonagemPlex) -> bool:
	return SacosLixoPlex.iniciar(self,ator)

func descansar(ator: PersonagemPlex) -> bool:
	if ator.energia >= 25 or ator.cargo=="funcionario": return false
	for cadeira in encontrar("cadeira",["descanso"]):
		if iniciar(ator,"Descansar",[etapa(cadeira,"descansar",7.0)],[cadeira]): return true
	return false

func fechar_equipamentos(trabalho: Dictionary) -> void:
	var mudou:=false
	for passo in trabalho.get("passos",[]):
		var item: Dictionary=planta.objetos.get(int(passo.alvo),{})
		if item.get("tipo","")=="geladeira" and item.estado!="fechada":
			item.estado="fechada"
			mudou=true
		elif FornoPlex.eh(item) and item.estado=="aberto":
			FornoPlex.fechar(planta,item)
			mudou=true
	if mudou: planta.alterada.emit()

func cancelar(ator: PersonagemPlex) -> void:
	var trabalho: Dictionary = trabalhos.get(ator.identificador,{})
	for passo in trabalho.get("passos",[]):
		if passo.acao=="aquecer" and planta.objetos.has(passo.alvo):
			planta.objetos[passo.alvo].estado="apagado"
			planta.alterada.emit()
	BebidasPlex.cancelar(self,ator,trabalho)
	ReparosPlex.liberar(self,ator,trabalho)
	ArmariosPlex.fechar_reservas(planta, trabalho)
	fechar_equipamentos(trabalho)
	ator.assento = -1
	for pedido_id in trabalho.get("pedidos",[trabalho.get("pedido",-1)]):
		if trabalho.get("tipo", "") in ["Servir guaraná","Servir dois guaranás"]: break
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
			PartilhaPizzaPlex.marcar_fonte(self,pedido)
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
	fechar_equipamentos(trabalho)
	ator.assento = -1
	for id in trabalho.reservas:
		if planta.objetos.has(id) and planta.objetos[id].reserva == ator.identificador: planta.objetos[id].reserva = 0
	trabalhos.erase(ator.identificador)
	ator.trabalho = ""
	ator.progresso_acao = 0

func executar(ator: PersonagemPlex, passo: Dictionary, trabalho: Dictionary) -> bool:
	if passo.acao=="descartar_item":return LimpezaItensPlex.executar(self,ator,passo)
	if passo.acao=="desembalar": return EmbalagensMoveisPlex.abrir(planta,passo.alvo)
	var alvo: int = passo.alvo
	var objeto: Dictionary = planta.objetos.get(alvo,{})
	var pedido := pedido_por_id(int(passo.dados.get("pedido",trabalho.pedido)))
	if passo.acao in ["coletar_lixo","descartar_saco","retornar_restaurante"]: return SacosLixoPlex.executar(self,ator,passo)
	if passo.acao in ["retirar_bebida", "servir_bebida", "descartar_copo"]: return BebidasPlex.executar(self,ator,passo,trabalho)
	if passo.acao in ["preparar_bolo","servir_bolo"]: return FestasRestaurantePlex.executar(self,ator,passo)
	match passo.acao:
		"reparar": return ReparosPlex.concluir(self,ator,passo)
		"pegar": return inventario.pegar(ator,alvo)
		"devolver": return inventario.devolver(ator)
		"apoiar": return inventario.apoiar(ator,alvo,int(passo.dados.slot))
		"depositar":
			var dinheiro: Dictionary = planta.objetos.get(ator.carga_item, {})
			if dinheiro.get("tipo", "") != "dinheiro" or objeto.get("tipo", "") != "registradora": return false
			var valor := maxf(0.0, float(dinheiro.get("valor", 0.0)))
			receber(valor)
			objeto.saldo = snappedf(float(objeto.get("saldo", 0.0)) + valor,.01)
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

		"descartar_prato": return PratosPlex.executar(self,ator,objeto)
		"retirar_prato_pilha": return PacotesPratosPlex.receber_passo(self,ator,passo,trabalho)
		"separar_prato":
			if PacotesPratosPlex.eh(objeto):
				var separado:=PacotesPratosPlex.retirar(inventario,alvo,ator.celula,true)
				return separado>=0 and inventario.pegar(ator,separado)
			var origem_prato:=objeto.duplicate(true)
			if not inventario.consumir_caixa(alvo): return false
			var id:=PratosPlex.criar(inventario,origem_prato,ator.celula)
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
			RefeicoesPlex.preparar(pedido)
			RefeicoesPlex.visualizar(self,pedido)
		"pegar_pizza":
			if pedido.is_empty() or not inventario.pegar(ator,pedido.pizza): return false
			if FornoPlex.eh(objeto): FornoPlex.fechar(planta,objeto)
		"emplatar":
			if not InventarioPlex.tem(ator,int(passo.dados.prato)) or not planta.objetos.has(pedido.pizza): return false
			var prato := int(passo.dados.prato)
			if not PartilhaPizzaPlex.emplatar(self,pedido,prato): return false
			FornoPlex.fechar(planta,objeto)
		"assar":
			var slot := int(passo.dados.get("slot",FornoPlex.vaga(planta,alvo)))
			if not inventario.apoiar_item(ator,pedido.pizza,alvo,slot): return false
			planta.objetos[pedido.pizza].tempo_assar = FornoPlex.DURACAO
			FornoPlex.liberar(planta,pedido.id)
			objeto.tempo_assar = maxf(FornoPlex.DURACAO,float(objeto.get("tempo_assar",0.0)))
			objeto.pedido_forno = pedido.id
			FornoPlex.estado(objeto,true)
			PartilhaPizzaPlex.marcar_fonte(self,pedido)
			pedido.estado = "assando"
		"servir":
			if not inventario.apoiar_item(ator,int(passo.dados.get("prato",ator.carga_item)),int(passo.dados.pai),int(passo.dados.slot)): return false
			PartilhaPizzaPlex.receber(self,pedido)
			entregas += 1
		"aquecer":
			objeto.estado = "apagado"
			planta.alterada.emit()
		"limpar":
			if objeto.tipo!="bebida_derramada": ator.visita.lixo_limpeza=int(ator.visita.get("lixo_limpeza",0))+1
			planta.remover(alvo)
			limpezas += 1
			if trabalho.indice+1<trabalho.passos.size() and trabalho.passos[trabalho.indice+1].acao!="lixo": LimpezaContinuaPlex.proxima(self,ator,trabalho)
		"lixo":
			var quantidade:=maxi(1,int(ator.visita.get("lixo_limpeza",0)))
			var descartado:=mini(6-int(objeto.lixo),quantidade)
			objeto.lixo+=descartado
			ator.visita.lixo_limpeza=maxi(0,quantidade-descartado)
			objeto.estado = "cheia" if objeto.lixo >= 6 else str(MobiliaPlex.dados(objeto).get("estado_padrao","vazia"))
			LimpezaContinuaPlex.proxima(self,ator,trabalho)
		"lavar":
			var prato_id: int = passo.dados.get("prato",ator.carga_item)
			if not planta.objetos.has(prato_id): return false
			for filho in ApoiosPlex.filhos(planta,prato_id):
				if filho.tipo=="restos_mesa": planta.remover(filho.id)
			planta.objetos[prato_id].sujo = false
			planta.objetos[prato_id].erase("limpeza_liberar")
			limpezas += 1
			planta.alterada.emit()
		"recolher_prato": return inventario.pegar(ator,int(passo.dados.prato))
		"descartar":
			var lixeira: int = passo.dados.lixeira
			if planta.objetos.has(lixeira):
				planta.objetos[lixeira].lixo = 0
				planta.objetos[lixeira].estado = str(MobiliaPlex.dados(planta.objetos[lixeira]).get("estado_padrao","vazia"))
		"descansar": ator.energia = minf(100,ator.energia+75)
		"usar_vaso", "higienizar", "jogar", "afastar_fliperama", "guardar_pertences", "consultar_armario":
			if not RotinasPlex.executar(self, ator, passo): return false
	planta.alterada.emit()
	return true

func atualizar_trabalho(ator: PersonagemPlex, trabalho: Dictionary, delta: float) -> void:
	var etapa_atual:=int(trabalho.indice)
	if int(trabalho.get("etapa_acompanhada",-1))!=etapa_atual:
		trabalho.etapa_acompanhada=etapa_atual;trabalho.sem_progresso=0.0;trabalho.ultima_posicao=[ator.local.x,ator.local.y];trabalho.ultimo_tempo=float(trabalho.tempo)
	else:
		var ultima:Array=trabalho.get("ultima_posicao",[ator.local.x,ator.local.y]);var moveu:=ator.local.distance_to(Vector2(ultima[0],ultima[1]))>.02;var progrediu:=float(trabalho.tempo)>float(trabalho.get("ultimo_tempo",0))+.000001
		trabalho.sem_progresso=0.0 if moveu or progrediu else float(trabalho.get("sem_progresso",0))+delta;trabalho.ultimo_tempo=float(trabalho.tempo)
		if moveu:trabalho.ultima_posicao=[ator.local.x,ator.local.y]
		if float(trabalho.sem_progresso)>25.0:
			motivo="Acesso bloqueado. A tarefa será reorganizada.";cancelar(ator);ator.movimento.cancelar();ator.visita.servico_retomar_em=tempo_servico+3;return
	if trabalho.indice<trabalho.passos.size():
		var passo_atual:Dictionary=trabalho.passos[trabalho.indice]
		if passo_atual.acao in ["aguardar_forno","emplatar"]:
			var pedido_atual:=pedido_por_id(int(passo_atual.dados.get("pedido",trabalho.pedido)))
			if pedido_atual.is_empty() or pedido_atual.estado in ["cancelado","consumido"]:cancelar(ator);return
	delta*=HabilidadesEquipePlex.fator(ator)
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
	if passo.acao in ["limpar","lavar","preparar","preparar_bolo","reparar","aquecer"] and trabalho.get("acomodado",-1)!=trabalho.indice:
		trabalho.acomodado = trabalho.indice
		var destino := ponto_trabalho(passo)
		var ponto := PosicaoTrabalhoPlex.aproximacao(ator, planta, destino, .25 if passo.acao=="reparar" else .6 if passo.acao in ["preparar","preparar_bolo"] else .42 if passo.acao=="lavar" else .28)
		ator.movimento.aproximar(ator,ponto)
		return
	if passo.alvo >= 0:
		montagem.orientar(ator,ponto_trabalho(passo))
	ator.trabalho = "preparar" if passo.acao in ["preparar","preparar_bolo","aquecer"] else "lavar" if passo.acao == "lavar" else "descansar" if passo.acao == "descansar" else "servico"
	if passo.acao == "desembalar":
		ator.trabalho="montar"
		if not passo.dados.get("aproximou_cadeiras",false):
			passo.dados.aproximou_cadeiras=true
			PassagemCadeirasPlex.iniciar(ator,planta,planta.objetos[passo.alvo],false)
		if PassagemCadeirasPlex.movendo(ator):return
	if passo.acao == "limpar": ator.trabalho = "varrer" if planta.objetos.get(ator.carga_item,{}).get("tipo","")=="vassoura" else "esfregar"
	if passo.alvo >= 0 and planta.objetos[passo.alvo].tipo in ["geladeira","forno"]:
		var item: Dictionary = planta.objetos[passo.alvo]
		var aberto := "aberta" if item.tipo == "geladeira" else "aberto"
		if item.estado != aberto:
			item.estado = aberto
			planta.alterada.emit()
	if passo.acao in ["depositar","descartar_prato"]: ator.trabalho = "depositar_dinheiro" if passo.acao=="depositar" else "descartar_prato"
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
	PartilhaPizzaPlex.atualizar(self,delta)
	FornoPlex.atualizar(self,delta)
	BebidasPlex.atualizar(self,delta)
	for pedido in pedidos:
		if pedido.get("estoque_cozinha",false):
			if not planta.objetos.has(int(pedido.mesa)) and pedido.estado not in ["consumido","cancelado"]:pedido.estado="cancelado"
			continue
		if not planta.objetos.has(pedido.mesa):
			pedido.estado = "cancelado"
			continue
		if (LugaresPlex.total(planta,pedido.mesa)==0 or (pedido.pizza>=0 and not planta.objetos.has(pedido.pizza))) and pedido.estado not in ["consumido","cancelado"]:
			pedido.estado="cancelado"
			if planta.objetos.has(pedido.pizza): planta.remover(pedido.pizza)
			continue
		if pedido.estado == "entregue": RefeicoesPlex.consumir(self,pedido,delta)

func atualizar(delta: float) -> void:
	tempo_servico+=delta
	salas.atualizar()
	CozinhaProntaPlex.atualizar_mesas(self)
	atualizar_pedidos(delta)
	CozinhaProntaPlex.adotar(self)
	espera += delta
	for ator in personagens:
		if jogo!=null and not jogo.operacao.aberto and AdministradorPlex.eh(ator) and trabalhos.has(ator.identificador) and trabalhos[ator.identificador].tipo=="Preparar pedido":cancelar(ator)
		if ator.cargo in ["morador","cliente","crianca","adolescente"] and not trabalhos.has(ator.identificador): continue
		if tempo_servico<float(ator.visita.get("servico_retomar_em",0)) or ator.visita.get("obra_atracao",false) or (ControleAdministradorPlex.ocupado(ator) and not (ator.visita.get("tutorial_servico",false) and trabalhos.has(ator.identificador) and tutorial_autorizado(ator,trabalhos[ator.identificador].tipo,trabalhos[ator.identificador].passos))) or TurnosEquipePlex.ocupado(ator) or ator.visita.get("fora_turno",false) or ator.visita.get("saindo_fechamento",false): continue
		if FantasiasRestaurantePlex.ocupando(ator) or ator.robo or (ator.cargo=="funcionario" and ator.funcao in ["caixa","seguranca"] and not trabalhos.has(ator.identificador)) or (AdministradorPlex.eh(ator) and ator.trabalho in ["caixa","caixa_sentado","ir_caixa","usar_caixa"] and not trabalhos.has(ator.identificador)): continue
		RotinasPlex.atualizar(ator, delta)
		if trabalhos.has(ator.identificador):
			atualizar_trabalho(ator,trabalhos[ator.identificador],delta)
		elif not EquipePlex.em_comando(ator) and str(ator.visita.get("fantasia_etapa",""))!="esperando" and espera >= .5 and ator.cargo == "funcionario" and ator.automatico and (not ator.ocupado() or ator.trabalho=="circular_salao") and ator.trabalho != "liberar_saida" and not montagem.trabalhos.has(ator.identificador):
			if ReparosPlex.voltar_oficina(self,ator): continue
			if ator.carregando: continue
			if ator.carga_item >= 0:
				if planta.objetos.get(ator.carga_item,{}).get("tipo","")=="saco_lixo" and esvaziar(ator): continue
				if DevolucaoPlex.guardar_carga(self, ator): continue
				inventario.devolver(ator)
				if ator.carga_item>=0: continue
			if RotinasPlex.prioritaria(self, ator) or descansar(ator) or atribuir_funcao(ator) or RotinasPlex.entre_tarefas(self, ator): continue
			if CirculacaoEquipePlex.retornar(self,ator): continue
			PasseioAtendimentoPlex.iniciar(self,ator,espera)
	if espera >= .5: espera = 0

func atribuir_funcao(ator: PersonagemPlex) -> bool:
	if PrioridadesServicoPlex.atribuir(self,ator): return true
	if EmbalagensMoveisPlex.atribuir(self,ator): return true
	if recepcao!=null:
		if recepcao.precisa_atendimento() and (EquipePlex.permite(ator,"atendimento") or EquipePlex.permite(ator,"caixa")): return false
		if EquipePlex.permite(ator,"caixa") and recepcao.clientes.jogo.atendimento.aguardando_pagamento(): return false
	if EquipePlex.permite(ator,"atendimento") and (servir(ator) or BebidasPlex.servir(self,ator)): return true
	if FestasRestaurantePlex.atribuir(self,ator): return true
	if EquipePlex.permite(ator,"estoque") and abastecer(ator): return true
	if EquipePlex.permite(ator,"estoque") and estantes().all(func(id): return not ApoiosPlex.filhos(planta,id).any(func(p): return (p.tipo=="prato" or PacotesPratosPlex.guardado(p) and int(p.get("quantidade",0))>0) and p.get("material_prato","ceramica")==preferencia_prato and not p.get("sujo",false))) and utensilios(ator): return true
	for funcao in EquipePlex.prioridades(ator):
		match str(funcao):
			"manutencao":
				if ReparosPlex.iniciar(self,ator) or guardar_pecas(ator) or RotinasPlex.organizar(self,ator): return true
			"cozinha":
				if cozinhar(ator) or lavar(ator) or guardar_pratos(ator) or abastecer(ator,true) or utensilios(ator,true) or CozinhaProntaPlex.organizar(self,ator): return true
			"atendimento":
				if servir(ator) or BebidasPlex.servir(self,ator) or BebidasPlex.recolher(self,ator) or recolher_louca(ator) or recolher_pagamento(ator): return true
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
	return {"tempo_servico":tempo_servico,"prioridades":prioridades,"reputacao":reputacao,"aniversarios":aniversarios,"preferencia_prato":preferencia_prato,"presentes":presentes,"recompensas":recompensas,"versao":5,"saldo":saldo,"receita_arcade":receita_arcade,"pedidos":pedidos,"proximo_pedido":proximo_pedido,"entregas":entregas,"limpezas":limpezas,"trabalhos":ativos}

func restaurar(dados: Dictionary) -> void:
	tempo_servico=float(dados.get("tempo_servico",0.0))
	trabalhos.clear()
	prioridades=dados.get("prioridades",[]).duplicate(true)
	reputacao=dados.get("reputacao",{}).duplicate(true)
	aniversarios=dados.get("aniversarios",[]).duplicate(true)
	preferencia_prato=str(dados.get("preferencia_prato","ceramica"))
	presentes=dados.get("presentes",[]).duplicate()
	recompensas=dados.get("recompensas",[]).duplicate(true)
	pedidos.assign(dados.get("pedidos",[]).duplicate(true))
	for pedido in pedidos:
		for campo in ["id", "mesa", "pizza", "prato", "geladeira", "cliente", "familia", "slot"]:
			if pedido.has(campo): pedido[campo] = int(pedido[campo])
	proximo_pedido = int(dados.get("proximo_pedido",1))
	entregas = int(dados.get("entregas",0))
	limpezas = int(dados.get("limpezas",0))
	saldo = snappedf(float(dados.get("saldo",0.0)),.01)
	receita_arcade = int(dados.get("receita_arcade",0))
	for salvo in dados.get("trabalhos",[]):
		var ator_id: int = salvo.ator
		if not personagens.any(func(a): return a.identificador == ator_id): continue
		var trabalho: Dictionary = salvo.trabalho.duplicate(true)
		if trabalho.get("tipo","")=="Reparar animatrônico" or trabalho.get("passos",[]).any(func(p): return p.get("acao","") in ["reparar","montar_endo","instalar_endo"]): continue
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


func limpar_alvo(ator: PersonagemPlex, id: int) -> bool:
	return LimpezaAmbientesPlex.iniciar(self,ator,id)


static func tutorial_autorizado(ator:PersonagemPlex,tipo:String,passos:Array) -> bool:
	return ator.visita.get("tutorial_guia",false) and ator.visita.get("tutorial_ativo",false) and ator.visita.get("tutorial_servico",false) and tipo in ["Limpeza guiada","Retirar saco de lixo"] and passos.all(func(p):return p.acao in ["pegar","limpar","lixo","devolver","coletar_lixo","descartar_saco","retornar_restaurante"])
