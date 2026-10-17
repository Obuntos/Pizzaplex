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
	jogo = cena
	var sala := coluna("Salas")
	texto(sala,"Salas fechadas são reconhecidas pelos objetos. Você também pode definir a função manualmente.")
	botao(sala,"Reconhecer pelos objetos",func(): jogo.escolher_ferramenta("sala:automatico"))
	for tipo in jogo.ambientes.definicoes:
		seletor.add_item(jogo.ambientes.definicoes[tipo].nome)
		seletor.set_item_metadata(seletor.item_count-1,tipo)
	sala.add_child(seletor)
	botao(sala,"Definir função",func(): jogo.escolher_ferramenta("sala:"+str(seletor.get_selected_metadata())))
	botao(sala,"Remover função",func(): jogo.escolher_ferramenta("sala:livre"))
	var mostrar := CheckButton.new()
	mostrar.text = "Mostrar limites das salas"
	mostrar.toggled.connect(func(valor): jogo.desenho_salas.mostrar = valor; jogo.desenho_salas.queue_redraw())
	sala.add_child(mostrar)
	sala.add_child(resumo)
	resumo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sala.add_child(detalhe)
	detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var objetos := coluna("Novos")
	for tipo in CatalogoPlex.objetos:
		if tipo != "dinheiro" and not CatalogoPlex.objetos[tipo].get("compravel",false) and (CatalogoPlex.objetos[tipo].has("estados") or CatalogoPlex.objetos[tipo].has("recurso")):
			jogo.painel.botao(objetos,CatalogoPlex.objetos[tipo].nome,tipo)
	var gestao := coluna("Gestão")
	botao(gestao,"Abrir central do terminal",func():
		var terminais: Array = jogo.planta.objetos.values().filter(func(o): return o.tipo == "terminal_ibm" and jogo.compras.terminal_valido(o.id))
		if not terminais.is_empty(): jogo.terminal_ui.abrir(terminais[0].id)
		else: jogo.painel.mensagem("Coloque um terminal ligado sobre um balcão."))
	botao(gestao,"Inspecionar tile",func(): jogo.escolher_ferramenta("inspecionar"))
	gestao.add_child(inspecao)
	inspecao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	estado.text = "Alterar estado"
	estado.pressed.connect(alterar_estado)
	gestao.add_child(estado)
	botao(gestao,"Testar interação",func(): RotinasPlex.solicitar(jogo.servicos, selecionado))
	botao(gestao,"Pedido de teste",func(): jogo.servicos.criar_pedido(selecionado if jogo.planta.objetos.get(selecionado,{}).get("tipo","") == "mesa" else -1))
	texto(gestao,"O pedido de teste simula consumo. Para clientes reais, adicione uma família na aba Clientes.")
	gestao.add_child(pedidos)
	pedidos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	botao(gestao,"Montar exemplo",func(): ExemploSalasPlex.montar(jogo))
	texto(gestao,"32 × 24 tiles: salão com palco, recepção, cozinha, depósito, oficina, jogos, banheiro, vestiário e limpeza.")
	botao(gestao,"Enquadrar restaurante",func(): jogo.enquadrar())
	botao(gestao,"Alternar tela cheia · F11",func(): jogo.alternar_tela_cheia())
	var clientes := coluna("Clientes")
	texto(clientes,"Escolha uma família e clique no chão, perto da entrada. Cada adulta acompanha uma ou duas crianças.")
	botao(clientes,"Adulta + 1 criança",func(): jogo.escolher_ferramenta("visita:familia1"))
	botao(clientes,"Adulta + 2 crianças",func(): jogo.escolher_ferramenta("visita:familia2"))
	botao(clientes,"Adicionar criança à adulta selecionada",func(): jogo.escolher_ferramenta("visita:crianca"))
	texto(clientes,"A adulta senta, pede e espera a refeição na mesa. Após comer, deixa o pagamento e sai com as crianças. Elas jogam e assistem ao palco. O banheiro é usado quando necessário.")
	clientes.add_child(visitas)
	visitas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	jogo.painel.atualizar_abas()
	atualizar(1)

func inspecionar(celula: Vector2i) -> bool:
	celula_sala = celula
	jogo.desenho_salas.selecionada = celula
	jogo.desenho_salas.queue_redraw()
	var objeto: Dictionary = jogo.planta.em(celula)
	if objeto.is_empty(): objeto = CabinesPlex.em(jogo.planta, celula)
	var adicionais: Array = jogo.planta.objetos.values().filter(func(item): return item.celula == celula and item.get("sobre",-1)>=0 and item.get("carregada_por",0)==0)
	if not adicionais.is_empty(): objeto = adicionais[-1]
	selecionado = int(objeto.get("id",-1))
	atualizar(1)
	return selecionado >= 0

func alterar_estado() -> void:
	if not jogo.planta.objetos.has(selecionado): return
	var objeto: Dictionary = jogo.planta.objetos[selecionado]
	var definicao: Dictionary = CatalogoPlex.objetos[objeto.tipo]
	if objeto.get("tempo_assar",0)>0 or objeto.reserva != 0:
		jogo.painel.mensagem("O equipamento está sendo usado por uma tarefa.")
		return
	if not definicao.has("estados"): return
	var indice: int = definicao.estados.find(objeto.estado)
	objeto.estado = definicao.estados[(indice+1)%definicao.estados.size()]
	jogo.planta.alterada.emit()
	atualizar(1)

func atualizar(delta: float) -> void:
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
	inspecao.text = "Clique no tile de um objeto para ver seu estado."
	estado.disabled = true
	if jogo.planta.objetos.has(selecionado):
		var item: Dictionary = jogo.planta.objetos[selecionado]
		var info: Dictionary = CatalogoPlex.objetos[item.tipo]
		inspecao.text = info.nome + "\nEstado: " + str(item.get("estado","padrão"))
		if item.tipo == "geladeira":
			SuprimentosPlex.preparar(item)
			inspecao.text += "\nMassa: "+str(item.estoque.massa)+" · Molho: "+str(item.estoque.molho)+" · Queijo: "+str(item.estoque.queijo)
		if item.tipo == "estante": inspecao.text += "\nPosições ocupadas: "+str(ApoiosPlex.filhos(jogo.planta,item.id).size())+" / 6"
		if item.tipo.begins_with("caixa"): inspecao.text += "\nConteúdo: "+str(item.get("rotulo",item.get("recurso","peças")))+" × "+str(item.get("quantidade",1))
		if item.tipo == "lixeira": inspecao.text += "\nResíduos: "+str(item.get("lixo",0))+" / 6"
		if item.tipo == "prato": inspecao.text += "\n"+("Precisa de lavagem" if item.get("sujo",false) else "Limpo")
		if ArmariosPlex.armario(item.tipo): inspecao.text += "\nItens guardados: " + str(ApoiosPlex.filhos(jogo.planta, item.id).size())
		if item.tipo == "maquina_fliperama": inspecao.text += "\n" + ("Disponível para jogar" if item.estado == "ligada" else "Máquina desligada")
		if item.tipo == "dinheiro": inspecao.text += "\nValor: $ " + str(item.get("valor",0))
		if item.tipo == "suporte" and item.has("componentes_endo"):
			inspecao.text += "\nMontagem: "+str(item.get("instaladas_endo",[]).size())+" / 4 · "+str(item.get("fase_montagem","")).replace("_"," ")
		if item.tipo == "suporte" and item.has("qualidade"): inspecao.text += "\nPeças: "+str(item.qualidade).capitalize()+" · Durabilidade: "+str(item.durabilidade)
		if item.tipo == "terminal_ibm": inspecao.text += "\nClique direito curto: abrir central. Arraste para mover a câmera."
		if item.tipo == "registradora": inspecao.text += "\nRecebido: $ " + str(item.get("saldo",0))
		if item.tipo == "mesa": inspecao.text += "\nLugares ativos: "+str(LugaresPlex.total(jogo.planta,item.id))+" / 4"
		estado.disabled = not info.has("estados") or info.get("estados",[]).size()<2
	var ativos: Array[String] = []
	for pedido in jogo.servicos.pedidos.slice(maxi(0,jogo.servicos.pedidos.size()-5)):
		ativos.append("Pedido "+str(pedido.id)+": "+pedido.estado)
	for id in jogo.servicos.trabalhos:
		ativos.append("Funcionário "+str(id)+": "+jogo.servicos.trabalhos[id].tipo)
	visitas.text = "Famílias presentes: " + str(jogo.clientes.grupos.size()) + "\nVisitas concluídas: " + str(jogo.clientes.visitas_concluidas) + "\nGuardado no caixa: $ " + str(jogo.servicos.saldo)
	pedidos.text = "Caixa: $ " + str(jogo.servicos.saldo) + "\nEntregas: "+str(jogo.servicos.entregas)+" · Limpezas: "+str(jogo.servicos.limpezas)+"\n"+"\n".join(ativos)+"\n"+jogo.servicos.motivo
