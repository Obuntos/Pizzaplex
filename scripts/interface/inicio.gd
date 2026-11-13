class_name InicioPlex
extends Control

const T = preload("res://scripts/interface/tema_hud.gd")
const MUNDO = "res://cenas/mundo/principal.tscn"
var fundo_menu: FundoInicioPlex
var creditos:=PanelContainer.new()
var sombra_dialogo:=ColorRect.new()
var informacao: Label
var painel_opcoes := PanelContainer.new()
var carregamento := CanvasLayer.new()
var barra:MedidorDocumentoPlex
var etapa: Label
var carregando := false
var modo := "novo"
var criacao := CriacaoPartidaPlex.new()
var config_partida: Dictionary = {}
var arquivos := UISavesPlex.new()
var save_escolhido := ""
var botao_carregar: Button

func _ready() -> void:
	AudioServer.set_bus_mute(0,false)
	get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = T.criar()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo:=FundoInicioPlex.new()
	fundo_menu=fundo
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	fundo.acao_escolhida.connect(escolher_acao)
	botao_carregar=fundo.botoes.carregar
	botao_carregar.disabled=not ArquivoPlex.tem_saves()
	informacao=Label.new()
	informacao.position=Vector2(40,40)
	informacao.add_theme_color_override("font_color",Color("efcfaa"))
	add_child(informacao)
	add_child(sombra_dialogo)
	sombra_dialogo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra_dialogo.color=Color(0.06,0.04,0.04,.66)
	sombra_dialogo.hide()
	sombra_dialogo.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed: painel_opcoes.hide();creditos.hide();sombra_dialogo.hide())
	criar_opcoes()
	criar_creditos()
	criar_carregamento()
	add_child(arquivos)
	arquivos.excluido.connect(func(_caminho): botao_carregar.disabled=not ArquivoPlex.tem_saves())
	arquivos.escolhido.connect(func(caminho): save_escolhido=caminho; comecar_carga("carregar"))
	add_child(criacao)
	criacao.confirmada.connect(func(dados): config_partida=dados; comecar_carga("novo"))
	set_process(false)

func criar_opcoes() -> void:
	painel_opcoes.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	painel_opcoes.grow_horizontal=Control.GROW_DIRECTION_BOTH;painel_opcoes.grow_vertical=Control.GROW_DIRECTION_BOTH
	painel_opcoes.custom_minimum_size.x=440
	add_child(painel_opcoes)
	painel_opcoes.add_theme_stylebox_override("panel",KitPlex.moldura("janela",20))
	var lista:=VBoxContainer.new();lista.add_theme_constant_override("separation",12)
	painel_opcoes.add_child(lista)
	KitPlex.cabecalho(lista,"Opções",func(): painel_opcoes.hide();sombra_dialogo.hide())
	KitPlex.secao(lista,"Idioma")
	IdiomaPlex.criar_seletor(lista).custom_minimum_size.y=44
	KitPlex.secao(lista,"Tela")
	KitPlex.botao(lista,"Tela cheia / Janela",func():
		var janela:=get_window()
		janela.mode=Window.MODE_WINDOWED if janela.mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN,"noite")
	var movimento:=CheckBox.new();movimento.text="Reduzir animações da interface"
	movimento.custom_minimum_size.y=44
	movimento.toggled.connect(func(valor): fundo_menu.reduzido=valor)
	lista.add_child(movimento)
	var rodape:=HBoxContainer.new();rodape.alignment=BoxContainer.ALIGNMENT_END;lista.add_child(rodape)
	KitPlex.botao(rodape,"VOLTAR",func(): painel_opcoes.hide();sombra_dialogo.hide(),"ouro").custom_minimum_size.x=160
	painel_opcoes.hide()

func mostrar_opcoes() -> void:
	creditos.hide();sombra_dialogo.show()
	painel_opcoes.show()

func criar_carregamento() -> void:
	carregamento.layer=200;add_child(carregamento)
	var documento:=CarregamentoDocumentoPlex.new();carregamento.add_child(documento)
	barra=documento.barra;etapa=documento.etapa;carregamento.hide()

func iniciar(destino: String) -> void:
	if carregando: return
	if destino == "novo":
		painel_opcoes.hide()
		criacao.abrir()
		return
	comecar_carga(destino)

func comecar_carga(destino: String) -> void:
	if destino not in ["novo","carregar"]: return
	if carregando: return
	if destino=="carregar" and ArquivoPlex.ler(save_escolhido).is_empty():
		informacao.text="Não foi possível ler a partida salva."
		return
	modo = destino
	carregando = true
	painel_opcoes.hide()
	carregamento.show()
	barra.value = 0
	etapa.text = "Carregando recursos…"
	var resultado := ResourceLoader.load_threaded_request(MUNDO)
	if resultado != OK:
		informacao.text = "Não foi possível abrir o mundo."
		carregando = false
		carregamento.hide()
		return
	set_process(true)

func _process(_delta: float) -> void:
	var progresso: Array = []
	var estado := ResourceLoader.load_threaded_get_status(MUNDO,progresso)
	if not progresso.is_empty(): barra.value = float(progresso[0])*60.0
	if estado in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
		falhar_abertura("Falha ao carregar os recursos do mundo.")
	elif estado==ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		etapa.text = "Preparando o espaço…"
		barra.value = 65
		await get_tree().process_frame
		var cena := ResourceLoader.load_threaded_get(MUNDO) as PackedScene
		if cena==null:
			falhar_abertura("A cena do mundo não pôde ser carregada.")
			return
		var jogo := cena.instantiate()
		get_tree().root.add_child(jogo)
		jogo.set_process(false)
		jogo.set_physics_process(false)
		jogo.set_process_input(false)
		jogo.set_process_unhandled_input(false)
		etapa.text = "Organizando a pizzaria…"
		barra.value = 85
		await get_tree().process_frame
		if modo == "novo":
			jogo.operacao.configurar(config_partida)
			PizzariaAbandonadaPlex.montar(jogo)
			AdministradorPlex.criar(jogo)
		elif modo=="carregar":
			if not jogo.carregar(save_escolhido):
				jogo.queue_free();carregando=false;carregamento.hide();informacao.text="Esta partida não está disponível."
				botao_carregar.disabled=not ArquivoPlex.tem_saves()
				return
		etapa.text="Preparando personagens e iluminação…"
		for ator in jogo.personagens: jogo.preparacao.personagem(ator)
		jogo.preparacao.cenario(jogo.planta)
		while not jogo.preparacao.concluida():
			jogo.preparacao.atualizar()
			barra.value=85.0+jogo.preparacao.progresso()*12.0
			await get_tree().process_frame
		if not jogo.preparacao.falhas.is_empty():
			falhar_abertura("Alguns arquivos do jogo não puderam ser carregados.",jogo)
			return
		var inicio_visuais:=Time.get_ticks_msec()
		while not jogo.atualizacoes.ordem.is_empty():
			jogo.processar_atualizacoes()
			await get_tree().process_frame
			if Time.get_ticks_msec()-inicio_visuais>90000:
				falhar_abertura("Não foi possível preparar os gráficos do jogo.",jogo)
				return
		jogo.painel.hud.catalogo.painel.hide()
		jogo.painel.painel.hide()
		jogo.painel.hud.atualizar(1.0)
		get_tree().current_scene = jogo
		jogo.show()
		jogo.camera.enabled=true
		jogo.camera.make_current()
		jogo.enquadrar()
		jogo.set_process(true)
		await get_tree().process_frame
		jogo.set_physics_process(true)
		jogo.set_process_input(true)
		jogo.set_process_unhandled_input(true)
		barra.value = 100
		await get_tree().process_frame
		queue_free()

func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and evento.keycode==KEY_ESCAPE and not carregando:
		if arquivos.visible: arquivos.fechar()
		elif criacao.visible: criacao.hide()
		elif painel_opcoes.visible: painel_opcoes.hide();sombra_dialogo.hide()
		elif creditos.visible: creditos.hide();sombra_dialogo.hide()
		get_viewport().set_input_as_handled()

func falhar_abertura(texto: String, jogo: Node=null) -> void:
	if is_instance_valid(jogo):
		jogo.set_process(false)
		jogo.set_physics_process(false)
		jogo.atualizacoes.limpar()
		get_tree().current_scene=self
		jogo.queue_free()
	carregando=false
	carregamento.hide()
	set_process(false)
	show()
	informacao.text=texto

func criar_creditos() -> void:
	add_child(creditos)
	creditos.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	creditos.grow_horizontal=Control.GROW_DIRECTION_BOTH;creditos.grow_vertical=Control.GROW_DIRECTION_BOTH
	creditos.custom_minimum_size.x=440
	creditos.add_theme_stylebox_override("panel",KitPlex.moldura("janela",20))
	var lista:=VBoxContainer.new();lista.add_theme_constant_override("separation",12);creditos.add_child(lista)
	KitPlex.cabecalho(lista,"Créditos",func(): creditos.hide();sombra_dialogo.hide())
	# Folha de papel com a equipe, como um cartão preso à parede do restaurante.
	var folha:=KitPlex.painel(lista,"papel",18)
	var nomes:=VBoxContainer.new();nomes.add_theme_constant_override("separation",4);folha.add_child(nomes)
	for par in [["Arte","Sho E Ocenaette"],["Código","Oceanette e Shadow"]]:
		var papel_secao:=KitPlex.secao(nomes,par[0],Color("8a5a38"),Color("b8955e"))
		papel_secao.name="Secao"
		KitPlex.texto(nomes,par[1],20,Color("2a1408"),"titulo")
	var rodape:=HBoxContainer.new();rodape.alignment=BoxContainer.ALIGNMENT_END;lista.add_child(rodape)
	KitPlex.botao(rodape,"VOLTAR",func(): creditos.hide();sombra_dialogo.hide(),"ouro").custom_minimum_size.x=160
	creditos.hide()

func mostrar_creditos() -> void:
	painel_opcoes.hide();sombra_dialogo.show();creditos.show()

func escolher_acao(acao: String) -> void:
	match acao:
		"novo": iniciar("novo")
		"carregar": arquivos.abrir()
		"opcoes": mostrar_opcoes()
		"creditos": mostrar_creditos()
		"sair": get_tree().quit()

func _enter_tree() -> void:
	RenderingServer.set_default_clear_color(Color("120a06"))
