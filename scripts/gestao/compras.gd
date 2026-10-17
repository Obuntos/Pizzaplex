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

func terminal_valido(id: int) -> bool:
	var objeto: Dictionary = jogo.planta.objetos.get(id,{})
	return objeto.get("tipo","") == "terminal_ibm" and objeto.get("estado","") != "desligado" and int(objeto.get("sobre",-1)) >= 0

func recebimentos() -> Array:
	return jogo.planta.objetos.values().filter(func(o): return o.tipo == "ponto_recebimento")

func saldo() -> int:
	return int(jogo.servicos.saldo)

func motivo(terminal: int, produto: String, quantidade: int) -> String:
	if not terminal_valido(terminal): return "O terminal precisa estar ligado e apoiado em uma mesa ou balcão."
	if not catalogo.has(produto) or quantidade < 1 or quantidade > 8: return "Escolha de 1 a 8 caixas por pedido."
	if recebimentos().is_empty(): return "Coloque um ponto de recebimento para receber as caixas."
	if recebimentos().all(func(p): return jogo.planta.interacoes(p.id).is_empty()): return "Libere o acesso ao ponto de recebimento."
	if saldo() < int(catalogo[produto].preco)*quantidade: return "Saldo insuficiente. Os pagamentos recolhidos entram no caixa."
	return ""

func comprar(terminal: int, produto: String, quantidade: int) -> bool:
	var erro := motivo(terminal,produto,quantidade)
	if not erro.is_empty():
		aviso.emit(erro)
		return false
	var custo := int(catalogo[produto].preco)*quantidade
	jogo.servicos.saldo -= custo
	encomendas.append({"id":proximo_id,"produto":produto,"total":quantidade,"restantes":quantidade,"tempo":4.0,"estado":"Em transporte","custo":custo})
	proximo_id += 1
	alterada.emit()
	aviso.emit("Compra confirmada. As caixas serão entregues no recebimento.")
	return true

func estoque(produto: String) -> int:
	if not catalogo.has(produto): return 0
	var total := 0
	for item in jogo.planta.objetos.values():
		if item.tipo == catalogo[produto].tipo: total += int(item.get("quantidade",1))
	if catalogo[produto].has("componente"):
		for geladeira in jogo.planta.objetos.values():
			if geladeira.tipo != "geladeira": continue
			SuprimentosPlex.preparar(geladeira)
			total += int(geladeira.estoque.get(catalogo[produto].componente,0))
	return total

func entregar(pedido: Dictionary) -> bool:
	var produto: Dictionary = catalogo.get(pedido.produto,{})
	if produto.is_empty(): return false
	for ponto in recebimentos():
		if jogo.planta.interacoes(ponto.id).is_empty(): continue
		var slot := ApoiosPlex.livre(jogo.planta,ponto.id,produto.tipo)
		if slot < 0: continue
		var ocupadas: Array[Vector2i] = jogo.planta.celulas(ponto.tipo,ponto.celula,ponto.rotacao)
		if jogo.personagens.any(func(a): return ocupadas.has(a.celula) or (a.movimento.atravessando and ocupadas.has(a.movimento.destino))): continue
		var id: int = jogo.servicos.inventario.criar(produto.tipo,ponto.celula)
		var caixa: Dictionary = jogo.planta.objetos[id]
		caixa.recurso = "pecas" if produto.grupo == "oficina" else "ingredientes"
		caixa.quantidade = int(produto.unidades)
		caixa.componente = str(produto.get("componente",""))
		caixa.qualidade = str(produto.get("qualidade","media"))
		caixa.durabilidade = int(produto.get("durabilidade",100))
		caixa.compra = pedido.id
		if not ApoiosPlex.fixar(jogo.planta,id,ponto.id,slot):
			jogo.planta.remover(id)
			continue
		pedido.restantes -= 1
		pedido.estado = "Entregue" if pedido.restantes == 0 else "Aguardando espaço"
		alterada.emit()
		return true
	return false

func atualizar(delta: float) -> void:
	for pedido in encomendas:
		if int(pedido.restantes) <= 0: continue
		pedido.tempo = maxf(0.0,float(pedido.tempo)-delta)
		if pedido.tempo > 0: continue
		if entregar(pedido): pedido.tempo = 1.5
		else: pedido.estado = "Aguardando recebimento"

func gravar() -> Dictionary:
	return {"encomendas":encomendas,"proximo_id":proximo_id,"endos":jogo.projetos_endo.gravar()}

func restaurar(dados: Dictionary) -> void:
	encomendas.assign(dados.get("encomendas",[]).duplicate(true))
	proximo_id = int(dados.get("proximo_id",1))
	for p in encomendas:
		for campo in ["id","total","restantes","custo"]: p[campo] = int(p.get(campo,0))
	jogo.projetos_endo.restaurar(dados.get("endos",{}))
	for objeto in jogo.planta.objetos.values():
		if objeto.tipo == "terminal_ibm" and objeto.estado == "uso": objeto.estado = "ligado"
