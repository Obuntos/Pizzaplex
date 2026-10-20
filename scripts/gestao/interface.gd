class_name TerminalUIPlex
extends CanvasLayer

const T = preload("res://scripts/gestao/tema.gd")
var jogo: Node
var raiz := Control.new()
var janela := PanelContainer.new()
var corpo := VBoxContainer.new()
var conteudo := HBoxContainer.new()
var catalogo_area := VBoxContainer.new()
var detalhe_area := VBoxContainer.new()
var rolagem_detalhe := ScrollContainer.new()
var lateral := VBoxContainer.new()
var conclusao := VBoxContainer.new()
var grade: GridContainer
var titulo: Label
var subtitulo: Label
var saldo_label: Label
var aviso_label: Label
var entregas_label: Label
var total_label: Label
var depois_label: Label
var quantidade_label: Label
var comprar_botao: Button
var abas: Dictionary = {}
var estoques: Dictionary = {}
var terminal := -1
var aba := "oficina"
var produto := "pecas_boa"
var quantidade := 1
var funcionario := -1
var espera := 0.0
var notificacao := ""
var tempo_notificacao := 0.0
var ultimo_tamanho := Vector2.ZERO
var rolagem := ScrollContainer.new()
var pagina_endo: UIEndoPlex
var reparos_label: Label

func configurar(cena: Node) -> void:
	jogo = cena
	pagina_endo = UIEndoPlex.new(self)
	layer = 40
	raiz.theme = T.criar()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(raiz)
	var sombra := ColorRect.new()
	sombra.color = Color(.035,.065,.05,.76)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(sombra)
	var estilo := T.caixa(T.FUNDO,Color("a4ae96"),9,0)
	estilo.shadow_color = Color(0,0,0,.36)
	estilo.shadow_size = 24
	estilo.shadow_offset = Vector2(0,10)
	janela.add_theme_stylebox_override("panel",estilo)
	raiz.add_child(janela)
	corpo.add_theme_constant_override("separation",0)
	janela.add_child(corpo)
	construir_cabecalho()
	construir_abas()
	var margem := MarginContainer.new()
	for lado in ["left","right","top","bottom"]: margem.add_theme_constant_override("margin_"+lado,24)
	margem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_child(margem)
	var principal := VBoxContainer.new()
	principal.add_theme_constant_override("separation",18)
	margem.add_child(principal)
	titulo = T.texto(principal,"Peças para continuar o show",27)
	subtitulo = T.texto(principal,"Escolha um kit. As compras chegam em caixas no recebimento.",13,T.SUAVE)
	subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	conteudo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	conteudo.add_theme_constant_override("separation",20)
	principal.add_child(conteudo)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.mouse_force_pass_scroll_events = false
	conteudo.add_child(rolagem)
	catalogo_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(catalogo_area)
	rolagem_detalhe.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem_detalhe.mouse_force_pass_scroll_events = false
	lateral.custom_minimum_size.x = 275
	conteudo.add_child(lateral)
	rolagem_detalhe.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lateral.add_child(rolagem_detalhe)
	lateral.add_child(conclusao)
	detalhe_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalhe_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem_detalhe.add_child(detalhe_area)
	construir_rodape()
	jogo.compras.alterada.connect(atualizar_valores)
	jogo.compras.aviso.connect(mensagem)
	raiz.hide()

func construir_cabecalho() -> void:
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel",T.caixa(Color("20362c"),Color.TRANSPARENT,0,20))
	corpo.add_child(painel)
	var linha := HBoxContainer.new()
	painel.add_child(linha)
	var marca := T.texto(linha,"P /",31,T.AMBAR,true)
	marca.custom_minimum_size.x = 70
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation",4)
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(coluna)
	T.texto(coluna,"PIZZAPLEX  /  CENTRAL DE GESTÃO",16,T.PAPEL)
	T.texto(coluna,"TERMINAL LOCAL   ·   CONEXÃO ATIVA",10,T.FOSFORO,true)
	var conta := VBoxContainer.new()
	conta.add_theme_constant_override("separation",3)
	linha.add_child(conta)
	T.texto(conta,"DISPONÍVEL NO CAIXA",10,Color("a6b79f"),true)
	saldo_label = T.texto(conta,"$ 0",24,T.FOSFORO,true)
	var fechar_botao := T.botao(linha,"×",fechar)
	fechar_botao.custom_minimum_size = Vector2(40,40)
	fechar_botao.tooltip_text = "Fechar · Esc"

func construir_abas() -> void:
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel",T.caixa(Color("dcded0"),Color.TRANSPARENT,0,12))
	corpo.add_child(painel)
	var linha := HBoxContainer.new()
	painel.add_child(linha)
	for item in [["funcionarios","01  Funcionários"],["mercado","02  Mercado"],["oficina","03  Oficina"],["endo","04  Animatrônicos"]]:
		var id: String = item[0]
		var b := T.botao(linha,item[1],func(): mudar_aba(id))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		abas[id] = b

func construir_rodape() -> void:
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel",T.caixa(Color("d9dccd"),Color.TRANSPARENT,0,14))
	corpo.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation",7)
	painel.add_child(coluna)
	aviso_label = T.texto(coluna,"Compras debitadas do saldo. Entregas físicas no restaurante.",12,T.VERDE)
	aviso_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entregas_label = T.texto(coluna,"Nenhuma encomenda em trânsito.",11,T.SUAVE,true)
	entregas_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func aberto() -> bool:
	return raiz.visible

func abrir(id: int) -> void:
	if not jogo.compras.terminal_valido(id):
		jogo.painel.mensagem("Ligue o terminal e coloque-o sobre um balcão.")
		return
	terminal = id
	jogo.planta.objetos[id].estado = "uso"
	jogo.planta.alterada.emit()
	jogo.arrastando = false
	jogo.traco_parede.encerrar()
	raiz.show()
	montar_pagina()
	redimensionar()
	atualizar_valores()

func fechar() -> void:
	if jogo != null and jogo.planta.objetos.has(terminal):
		jogo.planta.objetos[terminal].estado = "ligado"
		jogo.planta.alterada.emit()
	terminal = -1
	raiz.hide()

func limpar(pai: Node) -> void:
	for filho in pai.get_children():
		pai.remove_child(filho)
		filho.queue_free()

func mudar_aba(valor: String) -> void:
	aba = valor
	if aba not in ["funcionarios","endo"]:
		produto = "pecas_boa" if aba == "oficina" else "pizza"
		quantidade = 1
	montar_pagina()
	atualizar_valores()

func montar_pagina() -> void:
	limpar(catalogo_area)
	limpar(detalhe_area)
	limpar(conclusao)
	estoques.clear()
	reparos_label=null
	for id in abas:
		var b: Button = abas[id]
		var ativa: bool = aba == id
		for n in ["normal","hover","pressed"]: b.add_theme_stylebox_override(n,T.caixa(T.VERDE if ativa else Color.TRANSPARENT,T.VERDE if ativa else Color.TRANSPARENT,4,10))
		for n in ["font_color","font_hover_color","font_pressed_color"]: b.add_theme_color_override(n,T.PAPEL if ativa else T.SUAVE)
	if aba == "endo":
		pagina_endo.construir()
		redimensionar()
		return
	if aba == "funcionarios":
		montar_equipe()
		return
	titulo.text = "Peças para continuar o show" if aba == "oficina" else "A cozinha começa no estoque"
	subtitulo.text = "Compre um kit de reposição. O mecânico fará o reparo assim que o animatrônico estiver desligado." if aba == "oficina" else "Pizza e guaraná. Caixas que o estoquista leva até a cozinha."
	grade = GridContainer.new()
	grade.columns = 3 if janela.size.x >= 1080 else 1
	grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grade.add_theme_constant_override("h_separation",12)
	grade.add_theme_constant_override("v_separation",12)
	catalogo_area.add_child(grade)
	for id in jogo.compras.catalogo:
		var p: Dictionary = jogo.compras.catalogo[id]
		if p.grupo == aba: montar_produto(id,p)
	var nota := T.texto(catalogo_area,"RECEBIMENTO  /  Uma pilha de até 4 caixas. Novas entregas aguardam espaço; a retirada começa pelo topo.",11,T.SUAVE,true)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	montar_detalhe()
	redimensionar()

func montar_produto(id: String, p: Dictionary) -> void:
	var selecionado := id == produto
	var cartao := PanelContainer.new()
	cartao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cartao.add_theme_stylebox_override("panel",T.caixa(T.PAPEL,T.VERDE if selecionado else T.LINHA,5,16))
	grade.add_child(cartao)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation",13)
	cartao.add_child(c)
	var linha := HBoxContainer.new()
	c.add_child(linha)
	T.texto(linha,"KIT MECÂNICO" if aba == "oficina" else "INGREDIENTES",10,T.SUAVE,true)
	var espaco := Control.new()
	espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(espaco)
	T.texto(linha,"0"+str(int(p.get("nivel",1))) if aba == "oficina" else str(int(p.unidades)).pad_zeros(2),12,T.SUAVE,true)
	var quadro := PanelContainer.new()
	quadro.add_theme_stylebox_override("panel",T.caixa(Color("e2e5d7"),Color.TRANSPARENT,4,12))
	c.add_child(quadro)
	T.imagem(quadro,p.tipo,105)
	T.texto(c,p.nome,19)
	var barras := HBoxContainer.new()
	barras.add_theme_constant_override("separation",5)
	c.add_child(barras)
	if aba == "oficina":
		for i in 3:
			var barra := ColorRect.new()
			barra.custom_minimum_size = Vector2(26,4)
			barra.color = Color(p.cor) if i<int(p.nivel) else Color("d9ddcf")
			barras.add_child(barra)
	var unidade := T.texto(c,"1 kit completo" if aba=="oficina" else str(int(p.unidades))+" unidades por caixa",12,T.SUAVE)
	unidade.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if aba == "oficina": T.texto(c,"Durabilidade  "+str(int(p.durabilidade)),12,T.SUAVE)
	estoques[id] = T.texto(c,str(jogo.compras.estoque(id))+" em estoque",11,T.SUAVE,true)
	var rodape := HBoxContainer.new()
	c.add_child(rodape)
	var preco := T.texto(rodape,"$ "+str(int(p.preco)),23,T.TINTA,true)
	preco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	T.botao(c,"Selecionado" if selecionado else "Escolher kit" if aba=="oficina" else "Selecionar",func(): produto=id; montar_pagina(); atualizar_valores(),selecionado)

func montar_detalhe() -> void:
	var p: Dictionary = jogo.compras.catalogo[produto]
	var painel := PanelContainer.new()
	painel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	painel.add_theme_stylebox_override("panel",T.caixa(Color("d7dfc8"),Color("a5b296"),5,20))
	detalhe_area.add_child(painel)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation",15)
	painel.add_child(c)
	T.texto(c,"SEU PEDIDO",10,T.VERDE,true).set_meta("ocultar_compacto",true)
	T.texto(c,p.nome,23).set_meta("ocultar_compacto",true)
	var desc := T.texto(c,p.descricao,12,T.SUAVE)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.set_meta("ocultar_compacto",true)
	if aba=="oficina":
		T.texto(c,"MANUTENÇÃO AUTOMÁTICA",10,T.VERDE,true)
		reparos_label=T.texto(c,ReparosPlex.resumo(jogo.servicos),12,T.SUAVE)
		reparos_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	T.texto(c,"Quantidade de caixas",12,T.TINTA)
	var linha := HBoxContainer.new()
	c.add_child(linha)
	T.botao(linha,"−",func(): ajustar_quantidade(-1)).custom_minimum_size.x = 40
	quantidade_label = T.texto(linha,str(quantidade),22,T.TINTA,true)
	quantidade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantidade_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	T.botao(linha,"+",func(): ajustar_quantidade(1)).custom_minimum_size.x = 40
	var checkout := PanelContainer.new()
	checkout.add_theme_stylebox_override("panel",T.caixa(Color("c8d5b8"),Color("a5b296"),5,16))
	conclusao.add_child(checkout)
	var fim := VBoxContainer.new()
	fim.add_theme_constant_override("separation",8)
	checkout.add_child(fim)
	var resumo := HBoxContainer.new()
	fim.add_child(resumo)
	var legenda := T.texto(resumo,"Total",12,T.VERDE)
	legenda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_label = T.texto(resumo,"$ 0",27,T.TINTA,true)
	depois_label = T.texto(fim,"Saldo após a compra: $ 0",11,T.SUAVE)
	comprar_botao = T.botao(fim,"Confirmar compra  →",confirmar,true)

func ajustar_quantidade(delta: int) -> void:
	quantidade = clampi(quantidade+delta,1,8)
	atualizar_valores()

func confirmar() -> void:
	if jogo.compras.comprar(terminal,produto,quantidade):
		mensagem("Pedido #"+str(jogo.compras.proximo_id-1).pad_zeros(3)+" confirmado. A entrega está a caminho.")
	atualizar_valores()

func montar_equipe() -> void:
	titulo.text = "Cada pessoa, uma função"
	subtitulo.text = "A função principal tem prioridade. Autorize apoio em outras áreas quando necessário."
	var contratacao := HBoxContainer.new()
	catalogo_area.add_child(contratacao)
	var oficio := OptionButton.new()
	for funcao in EquipePlex.NOMES:
		if funcao in ["administrador","geral"]: continue
		oficio.add_item(EquipePlex.NOMES[funcao])
		oficio.set_item_metadata(oficio.item_count-1,funcao)
	contratacao.add_child(oficio)
	T.botao(contratacao,"Contratar",func(): AdministradorPlex.contratar(jogo,str(oficio.get_selected_metadata())); montar_pagina())
	var lista: Array = jogo.personagens.filter(func(a): return a.cargo=="funcionario" and not a.robo)
	if not lista.any(func(a): return a.identificador==funcionario): funcionario = lista[0].identificador if not lista.is_empty() else -1
	for ator in lista:
		var id: int = ator.identificador
		var linha := PanelContainer.new()
		linha.add_theme_stylebox_override("panel",T.caixa(T.PAPEL,T.VERDE if funcionario==id else T.LINHA,4,16))
		catalogo_area.add_child(linha)
		var c_local := HBoxContainer.new()
		linha.add_child(c_local)
		var face := TextureRect.new()
		face.texture = RetratoEquipePlex.criar(ator)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.custom_minimum_size = Vector2(50,50)
		c_local.add_child(face)
		var dados := VBoxContainer.new()
		dados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_local.add_child(dados)
		T.texto(dados,IdentidadesPlex.completo(ator),17)
		T.texto(dados,EquipePlex.NOMES.get(ator.funcao,"Geral")+" · "+("Automático" if ator.automatico else "Pausado"),12,T.SUAVE)
		T.botao(c_local,"Gerenciar",func(): funcionario=id; montar_pagina(); atualizar_valores(),funcionario==id)
	if lista.is_empty():
		T.texto(catalogo_area,"Coloque um funcionário no restaurante para atribuir funções.",15,T.SUAVE).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var atual: PersonagemPlex = lista.filter(func(a): return a.identificador==funcionario)[0]
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel",T.caixa(Color("d7dfc8"),Color("a5b296"),5,18))
	detalhe_area.add_child(painel)
	var c := VBoxContainer.new()
	painel.add_child(c)
	T.texto(c,"ATRIBUIÇÃO",10,T.VERDE,true)
	T.texto(c,IdentidadesPlex.completo(atual),20)
	T.botao(c,"Localizar no restaurante",func(): jogo.selecionar(atual); jogo.camera.position=atual.position; fechar())
	if AdministradorPlex.eh(atual):
		T.texto(c,"Cobre automaticamente as funções sem funcionário contratado. O uniforme e o cabelo são exclusivos do administrador.",15,T.SUAVE).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		T.texto(c,"Apoio atual: "+", ".join(EquipePlex.prioridades(atual).map(func(f): return EquipePlex.NOMES[f])),14,T.VERDE).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		return
	T.texto(c,"Função principal",12,T.SUAVE)
	var seletor := OptionButton.new()
	seletor.custom_minimum_size.y = 40
	for funcao in EquipePlex.NOMES:
		if funcao=="administrador": continue
		seletor.add_item(EquipePlex.NOMES[funcao])
		seletor.set_item_metadata(seletor.item_count-1,funcao)
		if atual.funcao==funcao: seletor.select(seletor.item_count-1)
	seletor.item_selected.connect(func(i): EquipePlex.definir(atual,str(seletor.get_item_metadata(i)),atual.funcoes_secundarias); jogo.selecionar(atual); montar_pagina(); mensagem("Função atualizada. A tarefa em andamento será concluída."))
	c.add_child(seletor)
	T.texto(c,"Apoio autorizado",12,T.SUAVE)
	for funcao in EquipePlex.FUNCOES:
		var f: String = funcao
		var check := CheckButton.new()
		check.text = EquipePlex.NOMES[f]
		check.button_pressed = atual.funcao == "geral" or atual.funcao==f or atual.funcoes_secundarias.has(f)
		check.disabled = atual.funcao == "geral" or atual.funcao==f
		check.toggled.connect(func(v):
			if v and not atual.funcoes_secundarias.has(f): atual.funcoes_secundarias.append(f)
			elif not v: atual.funcoes_secundarias.erase(f))
		c.add_child(check)

func mensagem(valor: String) -> void:
	notificacao = valor
	tempo_notificacao = 6.0
	aviso_label.text = valor
	aviso_label.add_theme_color_override("font_color",T.VERDE)

func atualizar_valores() -> void:
	if jogo == null or not aberto(): return
	saldo_label.text = "$ "+str(jogo.compras.saldo())
	if is_instance_valid(reparos_label): reparos_label.text=ReparosPlex.resumo(jogo.servicos)
	for id in estoques:
		if is_instance_valid(estoques[id]): estoques[id].text = str(jogo.compras.estoque(id))+" em estoque"
	if aba not in ["funcionarios","endo"] and is_instance_valid(total_label):
		var preco: int = int(jogo.compras.catalogo[produto].preco)*quantidade
		total_label.text = "$ "+str(preco)
		quantidade_label.text = str(quantidade)
		depois_label.text = "Saldo após a compra: $ "+str(jogo.compras.saldo()-preco)
		depois_label.add_theme_color_override("font_color",Color("aa654e") if preco>jogo.compras.saldo() else T.SUAVE)
		var erro: String = jogo.compras.motivo(terminal,produto,quantidade)
		comprar_botao.disabled = not erro.is_empty()
		comprar_botao.tooltip_text = erro
		aviso_label.text = notificacao if tempo_notificacao>0 else erro if not erro.is_empty() else "Compras debitadas do saldo. Entregas físicas no restaurante."
	if aba == "endo":
		pagina_endo.atualizar()
		aviso_label.text = notificacao if tempo_notificacao>0 else "Animatrônicos por R$ 0 nesta versão. Reposição de peças e reparos na aba Oficina."
	elif aba == "funcionarios": aviso_label.text = "O número e a função também aparecem sobre cada funcionário no restaurante."
	var lista: Array[String] = []
	for p in jogo.compras.encomendas.slice(maxi(0,jogo.compras.encomendas.size()-2)):
		lista.append("#"+str(p.id).pad_zeros(3)+"  "+jogo.compras.catalogo[p.produto].nome+" × "+str(p.total)+"  /  "+p.estado)
	if aba=="endo":
		lista.clear()
		for p in jogo.projetos_endo.pedidos.slice(maxi(0,jogo.projetos_endo.pedidos.size()-2)):
			lista.append("#E"+str(p.id).pad_zeros(3)+" · "+str(p.estado))
	entregas_label.text = "  ·  ".join(lista) if not lista.is_empty() else "Nenhuma encomenda em trânsito."

func ajustar_compacto(no: Node, compacto: bool) -> void:
	if no.has_meta("ocultar_compacto"): no.visible = not compacto
	for filho in no.get_children(): ajustar_compacto(filho,compacto)

func redimensionar() -> void:
	var tamanho := get_viewport().get_visible_rect().size
	ultimo_tamanho = tamanho
	ajustar_compacto(detalhe_area,tamanho.y<740)
	subtitulo.visible = tamanho.y >= 740
	titulo.add_theme_font_size_override("font_size",27 if tamanho.y>=740 else 22)
	janela.size = Vector2(minf(1190,tamanho.x-48),minf(750,tamanho.y-48))
	janela.position = ((tamanho-janela.size)*.5).round()
	lateral.custom_minimum_size.x = 275 if janela.size.x>=1080 else 250
	if aba=="endo" and pagina_endo!=null: pagina_endo.redimensionar()
	if is_instance_valid(grade): grade.columns = 3 if janela.size.x>=1080 else 1

func _process(delta: float) -> void:
	if not aberto(): return
	if not jogo.compras.terminal_valido(terminal):
		fechar()
		return
	var alvo := Vector2(minf(1190,get_viewport().get_visible_rect().size.x-48),minf(750,get_viewport().get_visible_rect().size.y-48))
	if get_viewport().get_visible_rect().size != ultimo_tamanho or janela.size.distance_to(alvo) > 1: redimensionar()
	tempo_notificacao = maxf(0,tempo_notificacao-delta)
	espera += delta
	if espera >= .5:
		espera = 0
		atualizar_valores()

func _input(evento: InputEvent) -> void:
	if aberto() and evento is InputEventKey and evento.pressed and evento.keycode==KEY_ESCAPE:
		fechar()
		get_viewport().set_input_as_handled()

