class_name InterfaceGestaoPlex
extends RefCounted

var jogo: Node
var seletor := OptionButton.new()
var resumo := Label.new()
var detalhe := Label.new()
var inspecao := Label.new()
var pedidos := Label.new()
var visitas := Label.new()
var estado := Button.new()
var selecionado := -1
var celula_sala := Vector2i(-1,-1)
var espera := 0.0

func texto(pai: Node, valor: String) -> Label:
	var item := Label.new()
	item.text = valor
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pai.add_child(item)
	return item

func botao(pai: Node, titulo: String, acao: Callable) -> Button:
	var item := Button.new()
	item.text = titulo
	item.custom_minimum_size.y = 32
	item.pressed.connect(acao)
	pai.add_child(item)
	return item

func coluna(nome: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = nome
	scroll.mouse_force_pass_scroll_events = false
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	jogo.painel.abas.add_child(scroll)
	var conteudo := VBoxContainer.new()
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conteudo.add_theme_constant_override("separation",9)
	scroll.add_child(conteudo)
	return conteudo

func configurar(cena: Node) -> void:
	jogo=cena
	for controle in [seletor,resumo,detalhe,inspecao,pedidos,visitas,estado]: jogo.painel.painel.add_child(controle)

func inspecionar(celula: Vector2i) -> bool:
	celula_sala = celula
	jogo.desenho_salas.selecionada = celula
	jogo.desenho_salas.queue_redraw()
	var objeto: Dictionary = jogo.planta.em(celula)
	if objeto.is_empty(): objeto = CabinesPlex.em(jogo.planta, celula)
	var adicionais: Array = jogo.planta.objetos.values().filter(func(item): return item.celula == celula and item.get("sobre",-1)>=0 and item.get("carregada_por",0)==0)
	if not adicionais.is_empty(): objeto = adicionais[-1]
	if jogo.populacao.dados.get("locais",{}).values().has(str(objeto.get("tipo",""))):
		return false
	selecionado = int(objeto.get("id",-1))
	atualizar(1)
	return selecionado >= 0

func atualizar(delta: float) -> void:
	if not jogo.painel.painel.visible: return
	espera += delta
	if espera < .3: return
	espera = 0
	jogo.ambientes.atualizar()
	var linhas: Array[String] = []
	for ambiente in jogo.ambientes.ambientes:
		if ambiente.tipo == "livre": continue
		linhas.append(jogo.ambientes.definicoes[ambiente.tipo].nome + " · " + ("operacional" if ambiente.operacional else "incompleta"))
	resumo.text = "\n".join(linhas) if not linhas.is_empty() else "Nenhuma função definida."
	var ambiente: Dictionary = jogo.ambientes.em(celula_sala)
	detalhe.text = ""
	if not ambiente.is_empty():
		detalhe.text = str(ambiente.celulas.size())+" tiles · "+("fechada" if ambiente.fechada else "aberta")+"\n"+"\n".join(ambiente.faltas)
		detalhe.text += "\nFunções: " + ", ".join(ambiente.funcoes.map(func(tipo): return jogo.ambientes.definicoes.get(tipo, {"nome":"Livre"}).nome))
	if not ambiente.is_empty() and ambiente.fechada:
		var conforto: Dictionary = jogo.conforto.em(celula_sala)
		detalhe.text += "\nConforto: %.1f / 10 · %s\nEntulho e sujeira: %d" % [conforto.nota,conforto.titulo,conforto.sujeira]
	inspecao.text = "Clique no tile de um objeto para ver seu estado."
	estado.disabled = true
	if jogo.planta.objetos.has(selecionado):
		var item: Dictionary = jogo.planta.objetos[selecionado]
		var info: Dictionary = MobiliaPlex.dados(item)
		inspecao.text = info.nome + "\nEstado: " + MobiliaPlex.estado(item)
		inspecao.text += "\nConforto do item: "+str(MobiliaPlex.nota(item))+" / 10 · "+ConfortoPlex.titulo(MobiliaPlex.nota(item))
		if item.tipo == "geladeira":
			SuprimentosPlex.preparar(item)
			inspecao.text += "\nMassa: "+str(item.estoque.massa)+" · Molho: "+str(item.estoque.molho)+" · Queijo: "+str(item.estoque.queijo)
		if item.tipo == "estante": inspecao.text += "\nPosições ocupadas: "+str(ApoiosPlex.filhos(jogo.planta,item.id).size())+" / 6"
		if item.tipo.begins_with("caixa"): inspecao.text += "\nConteúdo: "+str(item.get("rotulo",item.get("recurso","peças")))+" × "+str(item.get("quantidade",1))
		if CatalogoPlex.base(item.tipo) == "lixeira": inspecao.text += "\nResíduos: "+str(item.get("lixo",0))+" / 6"
		if item.tipo == "prato": inspecao.text += "\n"+("Precisa de lavagem" if item.get("sujo",false) else "Limpo")
		if ArmariosPlex.armario(item.tipo): inspecao.text += "\nItens guardados: " + str(ApoiosPlex.filhos(jogo.planta, item.id).size())
		if item.tipo == "maquina_fliperama": inspecao.text += "\n" + ("Disponível para jogar" if item.estado == "ligada" else "Máquina desligada")
		if item.tipo == "dinheiro": inspecao.text += "\nValor: $ " + str(item.get("valor",0))
		if item.tipo == "suporte" and item.has("componentes_endo"):
			inspecao.text += "\nMontagem: "+str(item.get("instaladas_endo",[]).size())+" / 4 · "+str(item.get("fase_montagem","")).replace("_"," ")
		if item.tipo == "suporte" and item.has("qualidade"): inspecao.text += "\nPeças: "+str(item.qualidade).capitalize()+" · Durabilidade: "+str(item.durabilidade)
		if item.tipo == "terminal_ibm": inspecao.text += "\nClique direito curto: abrir central. Arraste para mover a câmera."
		if item.tipo == "registradora": inspecao.text += "\nRecebido: $ " + str(item.get("saldo",0))
		if LugaresPlex.mesa(item.tipo): inspecao.text += "\nLugares ativos: "+str(LugaresPlex.total(jogo.planta,item.id))+" / "+str(LugaresPlex.cadeiras(jogo.planta,item).size())
		estado.disabled = not info.has("estados") or info.get("estados",[]).size()<2 or item.tipo in CatalogoPlex.PORTAS
	var ativos: Array[String] = []
	for pedido in jogo.servicos.pedidos.slice(maxi(0,jogo.servicos.pedidos.size()-5)):
		ativos.append("Pedido "+str(pedido.id)+": "+pedido.estado)
	for id in jogo.servicos.trabalhos:
		ativos.append("Funcionário "+str(id)+": "+jogo.servicos.trabalhos[id].tipo)
	visitas.text = "Famílias presentes: " + str(jogo.clientes.grupos.size()) + "\nVisitas concluídas: " + str(jogo.clientes.visitas_concluidas) + "\nReceita dos fliperamas: $ " + str(jogo.servicos.receita_arcade) + "\nTotal disponível: $ " + str(jogo.servicos.saldo)
	pedidos.text = "Caixa: $ " + str(jogo.servicos.saldo) + "\nEntregas: "+str(jogo.servicos.entregas)+" · Limpezas: "+str(jogo.servicos.limpezas)+"\n"+"\n".join(ativos)+"\n"+jogo.servicos.motivo


