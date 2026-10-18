class_name ProjetosEndoPlex
extends RefCounted

signal alterada
signal aviso(texto: String)
var jogo: Node
var pedidos: Array[Dictionary] = []
var proximo_id := 1

func _init(cena: Node) -> void:
	jogo = cena

func suporte_livre(id: int) -> bool:
	var item: Dictionary = jogo.planta.objetos.get(id,{})
	if item.get("tipo","")!="suporte": return false
	if item.get("robo_saiu",false):
		return not jogo.personagens.any(func(a): return a.suporte==id or a.celula==item.celula or (a.movimento.atravessando and a.movimento.destino==item.celula))
	return not item.get("endo",false) and not item.has("pedido_endo")

func motivo(terminal: int, suporte: int, modelo: String) -> String:
	if not jogo.compras.terminal_valido(terminal): return "Ligue o terminal e coloque-o em uma mesa ou balcão."
	if CatalogoMontagemPlex.modelo(modelo).is_empty(): return "Escolha um animatrônico."
	if not suporte_livre(suporte): return "Escolha um suporte vazio."
	if not jogo.planta.bancada_proxima(suporte): return "Coloque uma bancada de manutenção perto do suporte."
	if jogo.compras.recebimentos().is_empty(): return "Coloque um ponto de recebimento."
	if jogo.compras.recebimentos().all(func(p): return jogo.planta.interacoes(p.id).is_empty()): return "Libere o acesso ao recebimento."
	if CatalogoMontagemPlex.quebrado(modelo) and not GradePlex.dentro(jogo.quebrados.escolher(suporte)): return "Libere um canto acessível no chão da sala para o quebrado."
	return ""

func encomendar(terminal: int, suporte: int, modelo: String, _qualidade: String = "boa") -> bool:
	var erro := motivo(terminal,suporte,modelo)
	if not erro.is_empty():
		aviso.emit(erro)
		return false
	var definicao := CatalogoMontagemPlex.modelo(modelo)
	var config := CatalogoMontagemPlex.config(modelo)
	var marca := -1
	if definicao.quebrado:
		marca = jogo.quebrados.reservar(suporte,modelo,proximo_id)
		if marca<0: return false
	var estacao: Dictionary = jogo.planta.objetos[suporte]
	estacao.endo = false
	estacao.qualidade_pecas = "boa"
	estacao.modelo_alvo = modelo
	estacao.familia_endo = definicao.familia
	estacao.fur_modelo = modelo
	estacao.destino_quebrado = marca
	estacao.pedido_endo = proximo_id
	estacao.componentes_endo = config.duplicate(true)
	estacao.instaladas_endo = []
	estacao.fase_montagem = "endo"
	estacao.montado = false
	estacao.robo_saiu = false
	estacao.pecas = 0
	var partes: Array = ["pernas","bracos","cabeca","corpo"]
	if CatalogoMontagemPlex.carcaca(modelo): partes.append("fur")
	pedidos.append({"id":proximo_id,"suporte":suporte,"modelo":modelo,"config":config.duplicate(true),"pendentes":partes,"tempo":2.0,"estado":"Em transporte","etapa":"completo","custo":0})
	proximo_id+=1
	jogo.planta.alterada.emit()
	alterada.emit()
	aviso.emit(CatalogoMontagemPlex.nome(modelo)+" encomendado por R$ 0. A manutenção recebe e monta o modelo escolhido.")
	return true

func entregar(pedido: Dictionary) -> bool:
	var estacao: Dictionary = jogo.planta.objetos.get(pedido.suporte,{})
	if estacao.is_empty() or pedido.pendentes.is_empty(): return false
	var parte: String = pedido.pendentes[0]
	if parte=="fur" and estacao.get("instaladas_endo",[]).size()<4: return false
	for ponto in jogo.compras.recebimentos():
		if jogo.planta.interacoes(ponto.id).is_empty(): continue
		var slot := ApoiosPlex.livre(jogo.planta,ponto.id,"caixa")
		if slot<0: continue
		var celulas: Array[Vector2i] = jogo.planta.celulas(ponto.tipo,ponto.celula,ponto.rotacao)
		if jogo.personagens.any(func(a): return celulas.has(a.celula) or (a.movimento.atravessando and celulas.has(a.movimento.destino))): continue
		var id: int = jogo.servicos.inventario.criar("caixa",ponto.celula)
		var caixa: Dictionary = jogo.planta.objetos[id]
		caixa.recurso = "fur" if parte=="fur" else "endo"
		caixa.quantidade = 1
		caixa.qualidade = str(estacao.get("qualidade_pecas","boa"))
		caixa.pedido_endo = pedido.id
		caixa.suporte_endo = pedido.suporte
		caixa.parte_endo = parte
		caixa.variante_endo = estacao.modelo_alvo if parte=="fur" else pedido.config[parte]
		var nome_parte: String = "Base de sustentação" if parte=="pernas" and estacao.get("familia_endo","")=="barril" else EndoPecasPlex.PARTES.get(parte,"Carcaça")
		caixa.rotulo = nome_parte+" · "+CatalogoMontagemPlex.nome(estacao.modelo_alvo)
		if not ApoiosPlex.fixar(jogo.planta,id,ponto.id,slot):
			jogo.planta.remover(id)
			continue
		pedido.pendentes.pop_front()
		pedido.estado = "Peças entregues" if pedido.pendentes.is_empty() else "Entregando peças"
		alterada.emit()
		return true
	return false

func atualizar(delta: float) -> void:
	for pedido in pedidos:
		var suporte: Dictionary = jogo.planta.objetos.get(pedido.suporte,{})
		if suporte.is_empty():
			pedido.estado = "Suporte removido"
			continue
		if int(suporte.get("pedido_endo",-1))!=int(pedido.get("projeto",pedido.id)): continue
		if suporte.get("montado",false):
			pedido.estado = "Reservado para reutilização" if CatalogoMontagemPlex.quebrado(suporte.get("modelo_alvo","")) else "Concluído"
			continue
		if pedido.pendentes.is_empty():
			pedido.estado = "Instalando carcaça" if suporte.fase_montagem=="fur" else "Montagem · "+str(suporte.get("instaladas_endo",[]).size())+" / 4"
			continue
		pedido.tempo = maxf(0,float(pedido.tempo)-delta)
		if pedido.tempo>0: continue
		if entregar(pedido): pedido.tempo=.8
		else: pedido.estado = "Aguardando montagem do endo" if pedido.pendentes[0]=="fur" else "Aguardando espaço no recebimento"

func gravar() -> Dictionary:
	return {"pedidos":pedidos,"proximo_id":proximo_id}

func restaurar(dados: Dictionary) -> void:
	pedidos.assign(dados.get("pedidos",[]).duplicate(true))
	proximo_id = int(dados.get("proximo_id",1))
	for p in pedidos:
		p.id=int(p.id)
		p.suporte=int(p.suporte)
	for item in jogo.planta.objetos.values():
		if item.tipo!="suporte" or not item.has("componentes_endo") or item.has("modelo_alvo"): continue
		var familia: String = item.componentes_endo.get("corpo","base")
		CatalogoMontagemPlex.carregar()
		var modelos: Array = CatalogoMontagemPlex.dados.familias.get(familia,CatalogoMontagemPlex.dados.familias.base).modelos
		item.modelo_alvo = item.get("fur_modelo",modelos[0])
		if not modelos.has(item.modelo_alvo): item.modelo_alvo=modelos[0]
		item.fur_modelo=item.modelo_alvo
		if not item.get("montado",false) and not pedidos.any(func(p): return p.suporte==item.id and p.pendentes.has("fur")):
			pedidos.append({"id":proximo_id,"projeto":item.pedido_endo,"suporte":item.id,"config":item.componentes_endo.duplicate(true),"modelo":item.modelo_alvo,"pendentes":["fur"],"tempo":2.0,"estado":"Aguardando montagem do endo","etapa":"fur","custo":0})
			proximo_id+=1
		if item.get("fase_montagem","")=="endo_pronto": item.fase_montagem="fur"
	for ator in jogo.personagens:
		var carga: Dictionary = jogo.planta.objetos.get(ator.carga_item,{})
		if carga.has("parte_endo"):
			jogo.servicos.inventario.devolver(ator)
			ator.carregando=false
	for item in jogo.planta.objetos.values():
		if item.tipo=="bancada" and item.get("caixa_montagem",-1)>=0:
			var caixa: Dictionary = jogo.planta.objetos.get(item.caixa_montagem,{})
			if not caixa.is_empty(): caixa.celula=Vector2i(PontosUsoPlex.parada(item).round())
			item.caixa=false
			item.erase("caixa_montagem")
	for caixa in jogo.planta.objetos.values():
		if not caixa.has("parte_endo"): continue
		caixa.reserva=0
		if caixa.get("carregada_por",0)!=0:
			caixa.carregada_por=0
			caixa.sobre=-1
			caixa.solto=true
	jogo.planta.reindexar()
