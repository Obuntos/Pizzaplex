class_name InicioPlex
extends Control

const T = preload("res://scripts/interface/tema_hud.gd")
const MUNDO = "res://cenas/mundo/principal.tscn"
var botoes := VBoxContainer.new()
var informacao: Label
var painel_opcoes := PanelContainer.new()
var carregamento := CanvasLayer.new()
var barra := ProgressBar.new()
var etapa: Label
var carregando := false
var modo := "novo"
var criacao := CriacaoPartidaPlex.new()
var config_partida: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = T.criar()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo := FundoInicioPlex.new()
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for nome in ["margin_left","margin_right","margin_top","margin_bottom"]: margem.add_theme_constant_override(nome,48)
	add_child(margem)
	var coluna := VBoxContainer.new()
	margem.add_child(coluna)
	T.texto(coluna,"PIZZAPLEX",42,T.AMBAR)
	T.texto(coluna,"RESTAURE SUA PIZZARIA",16,T.SUAVE)
	var espaco := Control.new()
	espaco.custom_minimum_size.y = 36
	coluna.add_child(espaco)
	botoes.custom_minimum_size.x = 260
	botoes.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	coluna.add_child(botoes)
	T.botao(botoes,"Novo jogo",func(): iniciar("novo"),T.MARROM)
	T.botao(botoes,"Modo debug · Grátis",func(): iniciar("debug"),T.AZUL)
	var continuar := T.botao(botoes,"Carregar",func(): iniciar("carregar"))
	continuar.disabled = not FileAccess.file_exists(ArquivoPlex.CAMINHO)
	T.botao(botoes,"Opções",mostrar_opcoes)
	T.botao(botoes,"Créditos",func(): informacao.text="Pizzaplex / Projeto independente.\nMóveis e personagens do repertório do projeto.")
	T.botao(botoes,"Sair",func(): get_tree().quit())
	informacao = T.texto(coluna,"Uma pizzaria abandonada.\nMóveis gastos, um palco vazio\ne espaço para recomeçar.",18,T.SUAVE)
	informacao.size_flags_vertical = Control.SIZE_EXPAND_FILL
	informacao.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	criar_opcoes()
	criar_carregamento()
	add_child(criacao)
	criacao.confirmada.connect(func(dados,modo_debug): config_partida=dados; comecar_carga("debug" if modo_debug else "novo"))
	set_process(false)

func criar_opcoes() -> void:
	painel_opcoes.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	painel_opcoes.offset_left = -240
	painel_opcoes.offset_right = 240
	painel_opcoes.offset_top = -190
	painel_opcoes.offset_bottom = 190
	add_child(painel_opcoes)
	var lista := VBoxContainer.new()
	painel_opcoes.add_child(lista)
	T.texto(lista,"OPÇÕES",24,T.AMBAR)
	T.botao(lista,"Tela cheia / Janela",func():
		var janela := get_window()
		janela.mode = Window.MODE_WINDOWED if janela.mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN)
	T.botao(lista,"Modo debug · Grátis",func(): iniciar("debug"),T.AZUL).tooltip_text="Crie seu administrador e teste um restaurante equipado, com construção e compras gratuitas."
	T.texto(lista,"WASD / botão direito: câmera\nR: girar objeto\nShift: girar visão\nCtrl: altura das paredes\nHome: enquadrar / F11: tela cheia",16,T.SUAVE)
	T.botao(lista,"Voltar",func(): painel_opcoes.hide())
	painel_opcoes.hide()

func mostrar_opcoes() -> void:
	painel_opcoes.show()

func criar_carregamento() -> void:
	carregamento.layer = 200
	add_child(carregamento)
	var fundo := ColorRect.new()
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.color = T.FUNDO
	carregamento.add_child(fundo)
	var painel := PanelContainer.new()
	painel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	painel.offset_left = -270
	painel.offset_right = 270
	painel.offset_top = -90
	painel.offset_bottom = 90
	fundo.add_child(painel)
	var lista := VBoxContainer.new()
	painel.add_child(lista)
	T.texto(lista,"PIZZAPLEX",28,T.AMBAR)
	etapa = T.texto(lista,"Abrindo o restaurante…",18)
	barra.custom_minimum_size.y = 14
	barra.show_percentage = false
	barra.add_theme_stylebox_override("background",T.caixa(Color("2e4041"),T.LINHA,0))
	barra.add_theme_stylebox_override("fill",T.caixa(T.AMBAR,T.AMBAR,0))
	lista.add_child(barra)
	carregamento.hide()

func iniciar(destino: String) -> void:
	if carregando: return
	if destino in ["novo","debug","teste"]:
		painel_opcoes.hide()
		criacao.abrir(destino!="novo")
		return
	comecar_carga(destino)

func comecar_carga(destino: String) -> void:
	if carregando: return
	if destino=="carregar" and ArquivoPlex.ler().is_empty():
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
	if estado==ResourceLoader.THREAD_LOAD_FAILED:
		carregando=false
		carregamento.hide()
		informacao.text="Falha ao carregar os recursos."
		set_process(false)
	elif estado==ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		etapa.text = "Preparando o espaço…"
		barra.value = 65
		await get_tree().process_frame
		var cena := ResourceLoader.load_threaded_get(MUNDO) as PackedScene
		var jogo := cena.instantiate()
		get_tree().root.add_child(jogo)
		etapa.text = "Organizando a pizzaria…"
		barra.value = 85
		await get_tree().process_frame
		if modo in ["novo","debug"]:
			jogo.operacao.configurar(config_partida,modo=="debug")
			if modo=="debug": ExemploSalasPlex.montar(jogo)
			else: PizzariaAbandonadaPlex.montar(jogo)
			AdministradorPlex.criar(jogo)
		elif modo=="carregar": jogo.carregar()
		jogo.painel.hud.catalogo.painel.hide()
		jogo.painel.painel.hide()
		jogo.painel.hud.atualizar(1.0)
		get_tree().current_scene = jogo
		jogo.enquadrar()
		barra.value = 100
		await get_tree().process_frame
		queue_free()

func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and evento.keycode==KEY_ESCAPE and not carregando:
		if criacao.visible: criacao.hide()
		elif painel_opcoes.visible: painel_opcoes.hide()
		get_viewport().set_input_as_handled()
