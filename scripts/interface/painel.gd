class_name PainelPlex
extends CanvasLayer

signal catalogo_solicitado
signal cabelo_escolhido(valor: String)
signal uniforme_escolhido(valor: String)
signal luz_ajustada(valor: Dictionary)
signal ferramenta_escolhida(valor: String)
signal cor_escolhida(valor: int)
signal expressao_escolhida(valor: String)
signal autonomia_escolhida(valor: bool)
signal salvar_solicitado
signal carregar_solicitado
signal paredes_solicitadas
signal recorte_escolhido(valor: bool)
var status := Label.new()
var ferramenta := Label.new()
var selecao := Label.new()
var paredes := Button.new()
var recorte := CheckButton.new()
var autonomia := CheckButton.new()
var cabelo := OptionButton.new()
var uniforme := OptionButton.new()
var expressao := OptionButton.new()
var retrato := TextureRect.new()
var cor_luz := ColorPickerButton.new()
var energia_luz := HSlider.new()
var ligar_luz := CheckButton.new()
var painel: PanelContainer
var rodape: PanelContainer
var abas := TabContainer.new()
var navegacao := OptionButton.new()

func _ready() -> void:
	var tema := Theme.new()
	tema.default_font_size = 14
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("243138")
	fundo.content_margin_left = 18
	fundo.content_margin_right = 18
	fundo.content_margin_top = 16
	fundo.content_margin_bottom = 16
	tema.set_stylebox("panel", "PanelContainer", fundo)
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = tema
	add_child(raiz)
	painel = PanelContainer.new()
	painel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	painel.offset_right = 248
	painel.mouse_force_pass_scroll_events = false
	raiz.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	painel.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "PIZZAPLEX"
	titulo.add_theme_font_size_override("font_size", 25)
	coluna.add_child(titulo)
	var subtitulo := Label.new()
	subtitulo.text = "Construção · %d × %d tiles" % [GradePlex.TAMANHO.x, GradePlex.TAMANHO.y]
	subtitulo.modulate = Color("a5b5b3")
	coluna.add_child(subtitulo)
	ferramenta.text = "Selecionar e mover"
	coluna.add_child(ferramenta)
	coluna.add_child(navegacao)
	navegacao.item_selected.connect(func(indice): abas.current_tab = indice)
	abas.tabs_visible = false
	abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(abas)
	var construir := VBoxContainer.new()
	construir.name = "Objetos"
	abas.add_child(construir)
	var rolagem := ScrollContainer.new()
	rolagem.mouse_force_pass_scroll_events = false
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	construir.add_child(rolagem)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(lista)
	botao(lista, "Selecionar / mover", "selecionar")
	for tipo in ["parede", "porta", "porta_dupla", "mesa", "cadeira", "balcao", "bancada", "suporte", "caixa", "palco", "escada", "pose", "chao", "remover"]:
		var nome: String = CatalogoPlex.objetos[tipo].nome if CatalogoPlex.objetos.has(tipo) else "Remover objeto"
		botao(lista, nome, tipo)
	var cores := OptionButton.new()
	for nome in ["Chão original", "Chão creme", "Chão grafite", "Chão vinho"]:
		cores.add_item(nome)
	cores.item_selected.connect(func(indice): cor_escolhida.emit(indice))
	construir.add_child(cores)
	var luzes := VBoxContainer.new()
	luzes.name = "Luzes"
	abas.add_child(luzes)
	for tipo in ["luz_teto", "luz_parede", "luz_chao"]:
		botao(luzes, CatalogoPlex.objetos[tipo].nome, tipo)
	botao(luzes, "Editar luz no tile", "editar_luz")
	cor_luz.color = Color("fff0d5")
	cor_luz.custom_minimum_size.y = 30
	cor_luz.color_changed.connect(func(_valor): emitir_luz())
	luzes.add_child(cor_luz)
	var intensidade := Label.new()
	intensidade.text = "Intensidade da luz"
	luzes.add_child(intensidade)
	energia_luz.min_value = 0
	energia_luz.max_value = 3
	energia_luz.step = .05
	energia_luz.value = 1.2
	energia_luz.value_changed.connect(func(_valor): emitir_luz())
	luzes.add_child(energia_luz)
	ligar_luz.text = "Luz ligada"
	ligar_luz.button_pressed = true
	ligar_luz.toggled.connect(func(_valor): emitir_luz())
	luzes.add_child(ligar_luz)
	var regra := Label.new()
	regra.text = "Teto: área ampla.\nParede: exige uma parede.\nChão: embutida e transitável.\nPose: posição e direção no palco."
	regra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regra.add_theme_font_size_override("font_size", 12)
	luzes.add_child(regra)
	var aba_atores := ScrollContainer.new()
	aba_atores.name = "Bonecos"
	aba_atores.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	aba_atores.mouse_force_pass_scroll_events=false
	abas.add_child(aba_atores)
	var atores := VBoxContainer.new()
	atores.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	aba_atores.add_child(atores)
	var rolagem_atores := VBoxContainer.new()
	rolagem_atores.mouse_force_pass_scroll_events = false
	rolagem_atores.size_flags_vertical = Control.SIZE_EXPAND_FILL
	atores.add_child(rolagem_atores)
	var lista_atores := VBoxContainer.new()
	lista_atores.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem_atores.add_child(lista_atores)
	for item in [["humano", "Dummy homem"], ["humana", "Dummy mulher"], ["faxineiro", "Faxineiro"], ["entregador", "Entregador"], ["caixista", "Caixista"], ["seguranca", "Segurança"], ["fantasia_coelho", "Fantasia de coelho"], ["fantasia_ovelha", "Fantasia de ovelha"], ["fantasia_raposa", "Fantasia de raposa"], ["coelho", "Animatrônico coelho"], ["ovelha", "Animatrônico ovelha"], ["raposa", "Animatrônico raposa"]]:
		botao(lista_atores, item[1], "spawn:" + item[0])
	retrato.custom_minimum_size=Vector2(64,64)
	retrato.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	retrato.hide()
	atores.add_child(retrato)
	selecao.text = "Nenhum personagem selecionado"
	selecao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	atores.add_child(selecao)
	for nome in ["Neutro", "Feliz", "Triste", "Cansado", "Assustado"]:
		expressao.add_item(nome)
	expressao.item_selected.connect(func(indice): expressao_escolhida.emit(["neutro", "feliz", "triste", "cansado", "assustado"][indice]))
	atores.add_child(expressao)
	autonomia.text = "Tarefas automáticas"
	autonomia.button_pressed = true
	autonomia.toggled.connect(func(valor): autonomia_escolhida.emit(valor))
	atores.add_child(autonomia)
	AparenciaPlex.carregar()
	cabelo.add_item("Cabelo automático")
	cabelo.set_item_metadata(0,"automatico")
	cabelo.add_item("Sem cabelo")
	cabelo.set_item_metadata(1,"nenhum")
	for item in AparenciaPlex.dados.cabelos:
		cabelo.add_item(item.nome)
		cabelo.set_item_metadata(cabelo.item_count-1,item.id)
	uniforme.add_item("Uniforme da função")
	uniforme.set_item_metadata(0,"automatico")
	uniforme.add_item("Sem uniforme")
	uniforme.set_item_metadata(1,"nenhum")
	for id in AparenciaPlex.dados.uniformes:
		uniforme.add_item(AparenciaPlex.dados.uniformes[id].nome)
		uniforme.set_item_metadata(uniforme.item_count-1,id)
	cabelo.item_selected.connect(func(i): cabelo_escolhido.emit(cabelo.get_item_metadata(i)))
	uniforme.item_selected.connect(func(i): uniforme_escolhido.emit(uniforme.get_item_metadata(i)))
	cabelo.disabled = true
	uniforme.disabled = true
	cabelo.clip_text = true
	uniforme.clip_text = true
	atores.add_child(cabelo)
	atores.add_child(uniforme)
	var repertorio := Button.new()
	repertorio.text = "Catálogo de novos modelos"
	repertorio.pressed.connect(func(): catalogo_solicitado.emit())
	atores.add_child(repertorio)
	paredes.text = "Paredes: 4 / 4 · Ctrl"
	paredes.pressed.connect(func(): paredes_solicitadas.emit())
	coluna.add_child(paredes)
	recorte.text = "Cortar frente e divisórias"
	recorte.button_pressed = true
	recorte.tooltip_text = "Mantém as paredes dos fundos na altura escolhida com Ctrl. Corta as da frente e do meio. Desative para aplicar a altura em todas."
	recorte.toggled.connect(func(valor): recorte_escolhido.emit(valor))
	coluna.add_child(recorte)
	var arquivo := HBoxContainer.new()
	coluna.add_child(arquivo)
	var salvar := Button.new()
	salvar.text = "Salvar"
	salvar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	salvar.pressed.connect(func(): salvar_solicitado.emit())
	arquivo.add_child(salvar)
	var carregar := Button.new()
	carregar.text = "Carregar"
	carregar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carregar.pressed.connect(func(): carregar_solicitado.emit())
	arquivo.add_child(carregar)
	var dicas := Label.new()
	dicas.text = "Parede: clique ou arraste\nR gira objeto · Esc seleciona\nWASD / botão direito: câmera\nRoda: zoom · Ctrl: paredes\nShift: gira a visão\nHome: enquadrar · F11: tela cheia"
	dicas.add_theme_font_size_override("font_size", 12)
	dicas.modulate = Color("a5b5b3")
	coluna.add_child(dicas)
	rodape = PanelContainer.new()
	rodape.mouse_force_pass_scroll_events = false
	rodape.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	rodape.offset_left = 260
	rodape.offset_right = -12
	rodape.offset_top = -64
	rodape.offset_bottom = -12
	raiz.add_child(rodape)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Construa terminal, recebimento, suporte e bancada. Abra Endo no computador para encomendar os componentes."
	rodape.add_child(status)
	atualizar_abas()

func botao(lista: VBoxContainer, nome: String, valor: String) -> void:
	var item := Button.new()
	item.text = nome
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size.y = 32
	if valor.begins_with("spawn:"): item.icon=RetratoEquipePlex.icone(valor.trim_prefix("spawn:"))
	item.pressed.connect(func(): ferramenta_escolhida.emit(valor))
	lista.add_child(item)

func mensagem(texto: String) -> void:
	status.text = texto

func bloqueia_mouse(ponto: Vector2) -> bool:
	if not is_instance_valid(painel) or not painel.is_visible_in_tree():
		return false
	if painel.get_global_rect().has_point(ponto) or (is_instance_valid(rodape) and rodape.get_global_rect().has_point(ponto)):
		return true
	return get_viewport().gui_get_hovered_control() != null

func emitir_luz() -> void:
	luz_ajustada.emit({"cor_luz": "#" + cor_luz.color.to_html(false), "energia": energia_luz.value, "ligada": ligar_luz.button_pressed})

func mostrar_luz(objeto: Dictionary) -> void:
	cor_luz.color = Color(objeto.get("cor_luz", "#fff0d5"))
	energia_luz.set_value_no_signal(objeto.get("energia", 1.2))
	ligar_luz.set_pressed_no_signal(objeto.get("ligada", true))
	mensagem("Editando " + CatalogoPlex.objetos[objeto.tipo].nome.to_lower() + ".")

func atualizar_abas() -> void:
	navegacao.clear()
	for i in abas.get_tab_count(): navegacao.add_item(abas.get_tab_title(i))
	navegacao.select(abas.current_tab)

func mostrar_aparencia(ator: PersonagemPlex) -> void:
	retrato.texture=RetratoEquipePlex.criar(ator)
	retrato.visible=retrato.texture!=null
	var permitido := AparenciaPlex.permitida(ator)
	cabelo.disabled = not permitido
	uniforme.disabled = not permitido
	for controle in [cabelo,uniforme]:
		var valor: String = ator.cabelo if controle == cabelo else ator.uniforme
		for i in controle.item_count:
			if controle.get_item_metadata(i) == valor: controle.select(i)
