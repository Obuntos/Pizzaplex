class_name TarefasPlex
extends RefCounted

signal aviso(texto: String)
signal montado(suporte: int)
var planta: PlantaPlex
var rotas: RotasPlex
var personagens: Array = []
var trabalhos: Dictionary = {}
var espera := 0.0
var externos: Dictionary = {}
var inventario: InventarioPlex

func _init(valor: PlantaPlex, caminhos: RotasPlex) -> void:
	planta = valor
	rotas = caminhos
	inventario = InventarioPlex.new(planta)

func disponivel(objeto: Dictionary, personagem: PersonagemPlex) -> bool:
	return objeto.get("reserva",0) in [0,personagem.identificador]

func liberar(personagem: PersonagemPlex) -> void:
	var trabalho: Dictionary = trabalhos.get(personagem.identificador,{})
	var caixa: int = trabalho.get("caixa",-1)
	if planta.objetos.has(caixa) and planta.objetos[caixa].get("carregada_por",0)==personagem.identificador:
		personagem.carga_item = caixa
		inventario.devolver(personagem)
	var bancada: Dictionary = planta.objetos.get(trabalho.get("bancada",-1),{})
	if bancada.get("caixa_montagem",-1)==caixa:
		bancada.caixa = false
		bancada.erase("caixa_montagem")
	for item in planta.objetos.values():
		if item.get("reserva",0)==personagem.identificador: item.reserva = 0
	trabalhos.erase(personagem.identificador)
	personagem.trabalho = ""
	personagem.carregando = false
	personagem.progresso_acao = 0.0

func alvos(personagem: PersonagemPlex) -> Array:
	var resultado: Array = planta.objetos.values().filter(func(item): return item.tipo=="suporte" and item.get("fase_montagem","") in ["endo","fur"] and disponivel(item,personagem) and planta.bancada_proxima(item.id))
	resultado.sort_custom(func(a,b): return Vector2(a.celula).distance_squared_to(personagem.local)<Vector2(b.celula).distance_squared_to(personagem.local))
	return resultado

func caixas(personagem: PersonagemPlex) -> Array:
	var resultado: Array = planta.objetos.values().filter(func(item): return item.has("parte_endo") and item.get("carregada_por",0)==0 and disponivel(item,personagem) and PilhasPlex.retiravel(planta,item.id) and planta.objetos.has(item.suporte_endo))
	resultado.sort_custom(func(a,b):
		var ativo_a: bool = not planta.objetos[a.suporte_endo].get("instaladas_endo",[]).is_empty()
		var ativo_b: bool = not planta.objetos[b.suporte_endo].get("instaladas_endo",[]).is_empty()
		if ativo_a!=ativo_b: return ativo_a
		return int(a.suporte_endo)<int(b.suporte_endo) if a.suporte_endo!=b.suporte_endo else int(a.id)<int(b.id))
	return resultado

func buscar(personagem: PersonagemPlex, caixa: int, estacao: int = -1) -> bool:
	if not EquipePlex.permite(personagem,"manutencao") or personagem.carga_item>=0 or not planta.objetos.has(caixa): return false
	var item: Dictionary = planta.objetos[caixa]
	if not item.has("parte_endo") or not disponivel(item,personagem) or not PilhasPlex.retiravel(planta,caixa): return false
	estacao = int(item.suporte_endo) if estacao<0 else estacao
	if int(item.suporte_endo)!=estacao: return false
	var suporte: Dictionary = planta.objetos.get(estacao,{})
	if suporte.get("fase_montagem","") not in ["endo","fur"] or not disponivel(suporte,personagem): return false
	if item.parte_endo=="fur" and (suporte.fase_montagem!="fur" or item.variante_endo!=suporte.get("fur_modelo","")): return false
	if item.parte_endo!="fur" and item.variante_endo!=suporte.get("componentes_endo",{}).get(item.parte_endo,""): return false
	if item.parte_endo!="fur" and suporte.get("instaladas_endo",[]).has(item.parte_endo): return false
	var bancada := planta.bancada_para(estacao)
	if bancada<0 or not disponivel(planta.objetos[bancada],personagem): return false
	var caminho := rotas.aproximar(personagem.origem_rota(),caixa)
	if caminho.is_empty() or rotas.aproximar(caminho[-1],bancada).is_empty() or rotas.aproximar_montagem(caminho[-1],estacao).is_empty(): return false
	liberar(personagem)
	for id in [caixa,estacao,bancada]: planta.objetos[id].reserva = personagem.identificador
	trabalhos[personagem.identificador] = {"estacao":estacao,"caixa":caixa,"bancada":bancada,"etapa":"buscar","relogio":0.0}
	personagem.andar(caminho)
	aviso.emit("Buscando "+str(item.get("rotulo","peça do endo"))+".")
	return true

func solicitar(personagem: PersonagemPlex, id: int) -> bool:
	if not planta.objetos.has(id): return false
	if trabalhos.get(personagem.identificador,{}).get("estacao",-1)==id: return true
	if planta.objetos[id].has("parte_endo"): return buscar(personagem,id)
	for caixa in caixas(personagem):
		if caixa.suporte_endo==id and buscar(personagem,caixa.id,id): return true
	return false

func atribuir(personagem: PersonagemPlex) -> bool:
	for caixa in caixas(personagem):
		if buscar(personagem,caixa.id): return true
	return false

func orientar(personagem: PersonagemPlex, destino: Vector2) -> void:
	var deslocamento := GradePlex.projetar_local(destino-personagem.local)
	personagem.direcao = posmod(int(round(atan2(deslocamento.x,deslocamento.y*2.0)/(PI/4.0))),8)

func chegou(personagem: PersonagemPlex, alvo: int, montagem: bool = false) -> bool:
	if personagem.ocupado(): return false
	if planta.interacoes(alvo).has(personagem.celula): return true
	var caminho := rotas.aproximar_montagem(personagem.origem_rota(),alvo) if montagem else rotas.aproximar(personagem.origem_rota(),alvo)
	if not caminho.is_empty(): personagem.andar(caminho)
	else: liberar(personagem)
	return false

func atualizar_trabalho(personagem: PersonagemPlex, trabalho: Dictionary, delta: float) -> void:
	for id in [trabalho.estacao,trabalho.caixa,trabalho.bancada]:
		if not planta.objetos.has(id):
			liberar(personagem)
			return
	var estacao: Dictionary = planta.objetos[trabalho.estacao]
	var caixa: Dictionary = planta.objetos[trabalho.caixa]
	var bancada: Dictionary = planta.objetos[trabalho.bancada]
	if not planta.bancada_proxima(estacao.id):
		liberar(personagem)
		return
	match trabalho.etapa:
		"buscar":
			if not chegou(personagem,caixa.id): return
			trabalho.relogio += delta
			if trabalho.relogio<.45: return
			if not inventario.pegar(personagem,caixa.id):
				liberar(personagem)
				return
			personagem.caixa_tipo = caixa.tipo
			trabalho.etapa = "entregar"
			personagem.andar(rotas.aproximar(personagem.origem_rota(),bancada.id))
		"entregar":
			if not chegou(personagem,bancada.id): return
			trabalho.etapa = "aproximar_bancada"
			personagem.movimento.aproximar(personagem,PontosUsoPlex.parada(bancada))
		"aproximar_bancada":
			if personagem.ocupado(): return
			trabalho.etapa = "colocar"
			trabalho.relogio = 0.0
			personagem.trabalho = "colocar"
			personagem.alvo_carga = planta.ponto_caixa(bancada.id)
			orientar(personagem,Vector2(bancada.celula))
		"colocar":
			trabalho.relogio += delta
			personagem.progresso_acao = clampf(trabalho.relogio/1.2,0,1)
			if trabalho.relogio<1.2: return
			personagem.carga_item = -1
			personagem.trabalho = ""
			bancada.caixa = true
			bancada.caixa_tipo = caixa.tipo
			bancada.caixa_montagem = caixa.id
			bancada.caixa_para = estacao.id
			caixa.celula = bancada.celula
			trabalho.etapa = "ir_suporte"
			planta.alterada.emit()
			personagem.andar(rotas.aproximar_montagem(personagem.origem_rota(),estacao.id))
		"ir_suporte":
			if not chegou(personagem,estacao.id,true): return
			trabalho.etapa = "aproximar_suporte"
			personagem.movimento.aproximar(personagem,PontosUsoPlex.parada(estacao))
		"aproximar_suporte":
			if personagem.ocupado(): return
			trabalho.etapa = "montar"
			trabalho.relogio = 0.0
			personagem.trabalho = "montar"
			orientar(personagem,Vector2(estacao.celula))
		"montar":
			personagem.trabalho = "montar"
			trabalho.relogio += delta
			personagem.progresso_acao = fposmod(trabalho.relogio,2.4)/2.4
			var duracao := 7.2 if caixa.parte_endo=="fur" else 4.8
			if trabalho.relogio<duracao: return
			var fur: bool = caixa.parte_endo=="fur"
			if fur:
				estacao.montado = true
				estacao.fase_montagem = "concluido"
			else:
				if not estacao.instaladas_endo.has(caixa.parte_endo): estacao.instaladas_endo.append(caixa.parte_endo)
				estacao.endo = true
				estacao.pecas = estacao.instaladas_endo.size()
				if estacao.pecas==4:
					estacao.montado = not CatalogoMontagemPlex.carcaca(estacao.get("modelo_alvo",""))
					estacao.fase_montagem = "concluido" if estacao.montado else "fur"
			bancada.caixa = false
			bancada.erase("caixa_montagem")
			planta.remover(caixa.id)
			liberar(personagem)
			planta.alterada.emit()
			if fur or estacao.montado: montado.emit(estacao.id)
			elif estacao.pecas==4: aviso.emit("Endo pronto. A carcaça do modelo escolhido será entregue automaticamente.")

func atualizar(delta: float) -> void:
	espera += delta
	for personagem in personagens:
		if FantasiasRestaurantePlex.ocupando(personagem) or personagem.robo or personagem.cargo!="funcionario" or externos.has(personagem.identificador) or personagem.trabalho in ["caixa","ir_caixa","usar_caixa","aguardar_caixa"]: continue
		if trabalhos.has(personagem.identificador): atualizar_trabalho(personagem,trabalhos[personagem.identificador],delta)
		elif not EquipePlex.em_comando(personagem) and str(personagem.visita.get("fantasia_etapa",""))!="esperando" and EquipePlex.permite(personagem,"manutencao") and espera>=.5 and personagem.automatico and not personagem.ocupado() and personagem.trabalho!="liberar_saida": atribuir(personagem)
	if espera>=.5: espera = 0.0

