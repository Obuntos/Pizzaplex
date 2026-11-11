class_name ComprasPlex
extends RefCounted

signal alterada
signal aviso(texto: String)
var jogo: Node
var catalogo: Dictionary = {}
var encomendas: Array[Dictionary] = []
var proximo_id := 1

func _init(cena: Node) -> void:
	jogo = cena
	catalogo = JSON.parse_string(FileAccess.get_file_as_string("res://dados/compras.json"))
	for produto in catalogo.keys():
		if str(catalogo[produto].get("tipo","")).begins_with("caixa_pecas_") or str(catalogo[produto].get("tipo","")) in ["pecas_manutencao","caixa_ferramentas"]:catalogo.erase(produto)

func terminal_valido(id: int) -> bool:
	var objeto: Dictionary = jogo.planta.objetos.get(id,{})
	var raiz:=ApoiosPlex.raiz(jogo.planta,id)
	return objeto.get("tipo","") == "terminal_ibm" and objeto.get("estado","") != "desligado" and int(objeto.get("sobre",-1)) >= 0 and raiz>=0 and TerrenoPlex.contem(jogo.planta,jogo.planta.objetos[raiz].celula)

func recebimentos() -> Array:
	return jogo.planta.objetos.values().filter(func(o): return RecebimentosPlex.interno(jogo.planta,o))

func destino(terminal: int) -> int:
	var pontos:=recebimentos()
	var origem:=ApoiosPlex.posicao(jogo.planta,jogo.planta.objetos.get(terminal,{"tipo":"terminal_ibm","celula":Vector2i.ZERO,"rotacao":0}))
	pontos.sort_custom(func(a,b): return Vector2(a.celula).distance_squared_to(Vector2(origem.x,origem.y))<Vector2(b.celula).distance_squared_to(Vector2(origem.x,origem.y)))
	for ponto in pontos:
		if not RecebimentosPlex.acessos(jogo.planta,ponto).is_empty(): return ponto.id
	return -1

func saldo() -> float:
	return float(jogo.servicos.saldo)

func motivo(terminal: int, produto: String, quantidade: int) -> String:
	if not terminal_valido(terminal): return "O terminal precisa estar ligado e apoiado em uma mesa ou balcão."
	if not catalogo.has(produto) or quantidade < 1 or quantidade > 8: return "Escolha de 1 a 8 caixas por pedido."
	var guiada:=primeira_pizza(terminal,produto,quantidade)
	if recebimentos().is_empty() and not guiada: return "Coloque um ponto de recebimento dentro do restaurante."
	if destino(terminal)<0 and not guiada: return "Libere um acesso interno ao ponto de recebimento."
	if saldo() < int(catalogo[produto].preco)*quantidade: return "Saldo insuficiente. Os pagamentos recolhidos entram no caixa."
	return ""

func comprar(terminal: int, produto: String, quantidade: int) -> bool:
	var erro := motivo(terminal,produto,quantidade)
	if not erro.is_empty():
		aviso.emit(erro)
		return false
	var custo := int(catalogo[produto].preco)*quantidade
	jogo.servicos.saldo -= custo
	if catalogo[produto].has("material_prato"): jogo.servicos.preferencia_prato=str(catalogo[produto].material_prato)
	encomendas.append({"id":proximo_id,"produto":produto,"total":quantidade,"restantes":quantidade,"tempo":4.0,"estado":"Em transporte","custo":custo,"recebimento":destino(terminal),"tutorial_aguarda":primeira_pizza(terminal,produto,quantidade)})
	proximo_id += 1
	if primeira_pizza(terminal,produto,quantidade):jogo.sistemas.tutorial.pizza_comprada(proximo_id-1)
	alterada.emit()
	aviso.emit("Compra confirmada. As caixas serão entregues no recebimento.")
	return true

func estoque(produto: String) -> int:
	if not catalogo.has(produto): return 0
	var total := 0
	for item in jogo.planta.objetos.values():
		if item.tipo == catalogo[produto].tipo and (not catalogo[produto].has("material_prato") or item.get("material_prato","ceramica")==catalogo[produto].material_prato): total += int(item.get("quantidade",1))
	if catalogo[produto].has("material_prato"):
		for item in jogo.planta.objetos.values():
			if item.tipo=="prato" and item.get("material_prato","ceramica")==catalogo[produto].material_prato and not item.get("sujo",false) and ApoiosPlex.filhos(jogo.planta,item.id).is_empty(): total+=1
	if catalogo[produto].has("componente"):
		for geladeira in jogo.planta.objetos.values():
			if geladeira.tipo != "geladeira": continue
			SuprimentosPlex.preparar(geladeira)
			total += int(geladeira.estoque.get(catalogo[produto].componente,0))
	return total

func entregar(pedido: Dictionary) -> bool:
	if pedido.produto in ["massa","molho","queijo"]: pedido.produto = "pizza"
	if pedido.produto=="utensilios": pedido.produto="pratos_ceramica"
	var produto: Dictionary = catalogo.get(pedido.produto,{})
	if produto.is_empty(): return false
	if not jogo.planta.objetos.has(int(pedido.get("recebimento",-1))): pedido.recebimento=destino(-1)
	for ponto in recebimentos():
		if int(pedido.get("recebimento",ponto.id))!=int(ponto.id): continue
		if RecebimentosPlex.acessos(jogo.planta,ponto).is_empty(): continue
		var slot := ApoiosPlex.livre(jogo.planta,ponto.id,produto.tipo)
		var ocupadas: Array[Vector2i] = jogo.planta.celulas(ponto.tipo,ponto.celula,ponto.rotacao)
		if jogo.personagens.any(func(a): return not a.visita.get("entregador_mercado",false) and (ocupadas.has(a.celula) or (a.movimento.atravessando and ocupadas.has(a.movimento.destino)))): slot=-1
		var chao:=Vector2i(-1,-1)
		if slot < 0:
			chao=chao_livre(ponto)
			if chao.x<0: continue
		var id: int = jogo.servicos.inventario.criar(produto.tipo,ponto.celula if slot>=0 else chao)
		var caixa: Dictionary = jogo.planta.objetos[id]
		caixa.recurso = "pecas" if produto.grupo == "oficina" else str(CatalogoPlex.objetos[produto.tipo].get("recurso","ingredientes"))
		caixa.quantidade = int(produto.unidades)
		caixa.componente = str(produto.get("componente",""))
		caixa.qualidade = str(produto.get("qualidade","media"))
		caixa.durabilidade = int(produto.get("durabilidade",100))
		caixa.material_prato=str(produto.get("material_prato","ceramica"))
		caixa.cor_prato=str(produto.get("cor_prato","branco"))
		caixa.compra = pedido.id
		if produto.has("material_prato"): PacotesPratosPlex.preparar(caixa)
		if slot>=0 and not ApoiosPlex.fixar(jogo.planta,id,ponto.id,slot):
			jogo.planta.remover(id)
			continue
		pedido.restantes -= 1
		pedido.estado = "Entregue" if pedido.restantes == 0 else "Descarregando"
		jogo.planta.alterada.emit()
		alterada.emit()
		return true
	return false

func chao_livre(ponto: Dictionary) -> Vector2i:
	var candidatos: Array[Vector2i]=[]
	for c in RecebimentosPlex.acessos(jogo.planta,ponto):
		for d in [Vector2i.ZERO]+GradePlex.VIZINHOS:
			var celula: Vector2i=c+d
			if not candidatos.has(celula): candidatos.append(celula)
	for celula in candidatos:
		if not GradePlex.dentro(celula) or not TerrenoPlex.contem(jogo.planta,celula) or not jogo.planta.transitavel(celula) or not jogo.planta.em(celula).is_empty(): continue
		if jogo.planta.objetos.values().any(func(o): return o.celula==celula and str(o.tipo).begins_with("caixa") and int(o.get("carregada_por",0))==0): continue
		if jogo.personagens.any(func(a): return a.celula==celula): continue
		return celula
	return Vector2i(-1,-1)

func atualizar(delta: float) -> void:
	for pedido in encomendas:
		if int(pedido.restantes) <= 0: continue
		pedido.tempo = maxf(0.0,float(pedido.tempo)-delta)
		if pedido.tempo > 0: continue
		if not jogo.sistemas.entregas.liberado(pedido): continue
		if pedido.get("tutorial_aguarda",false) and int(pedido.get("recebimento",-1))<0:
			for ponto in recebimentos():
				if not RecebimentosPlex.acessos(jogo.planta,ponto).is_empty():pedido.recebimento=int(ponto.id);pedido.tutorial_aguarda=false;break
		if entregar(pedido): pedido.tempo = 1.5
		else: pedido.estado = "Aguardando recebimento"

func gravar() -> Dictionary:
	return {"preferencia_prato":jogo.servicos.preferencia_prato,"encomendas":encomendas,"proximo_id":proximo_id}

func restaurar(dados: Dictionary) -> void:
	for pedido in dados.get("encomendas",[]):
		if str(pedido.get("produto","")).begins_with("pecas_") and int(pedido.get("restantes",0))>0:jogo.servicos.receber(float(pedido.get("custo",0))*int(pedido.restantes)/maxi(1,int(pedido.get("total",1))))
	encomendas.assign(dados.get("encomendas",[]).filter(func(p): return catalogo.has(str(p.get("produto","")))).duplicate(true))
	proximo_id = int(dados.get("proximo_id",1))
	if dados.has("preferencia_prato"):
		jogo.servicos.preferencia_prato=str(dados.preferencia_prato)
	else:
		var antigas:=encomendas.duplicate()
		antigas.reverse()
		for pedido in antigas:
			var produto: Dictionary=catalogo.get(str(pedido.produto),{})
			if produto.has("material_prato"):
				jogo.servicos.preferencia_prato=str(produto.material_prato)
				break
	for p in encomendas:
		for campo in ["id","total","restantes","custo"]: p[campo] = int(p.get(campo,0))
		if not p.has("recebimento"):
			for ponto in recebimentos():
				if not RecebimentosPlex.acessos(jogo.planta,ponto).is_empty(): p.recebimento=ponto.id;break
	for objeto in jogo.planta.objetos.values():
		if PacotesPratosPlex.eh(objeto):
			objeto.pratos_guardados=jogo.planta.objetos.get(int(objeto.get("sobre",-1)),{}).get("tipo","") in ["estante","armario_utensilios"] or bool(objeto.get("pratos_guardados",false))
			PacotesPratosPlex.preparar(objeto)
		if objeto.tipo == "terminal_ibm" and objeto.estado == "uso": objeto.estado = "ligado"



func primeira_pizza(terminal:int,produto:String,quantidade:int) -> bool:
	return "sistemas" in jogo and jogo.sistemas!=null and "tutorial" in jogo.sistemas and is_instance_valid(jogo.sistemas.tutorial) and jogo.sistemas.tutorial.permite_pizza(terminal,produto,quantidade)
