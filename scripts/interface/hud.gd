class_name HudPlex
extends Control

const T = preload("res://scripts/interface/tema_hud.gd")
var jogo: Node
var catalogo := CatalogoConstrucaoPlex.new()
var agenda := UICalendarioPlex.new()
var data := Label.new()
var saldo: Label
var icone := IconeHudPlex.new()
var corte: Button
var resumo: Label
var conforto_ui := UIConfortoPlex.new()
var nome_restaurante: Label
var controle := PanelContainer.new()
var expandir: Button
var abrir_botao: Button
var linha_controle := HBoxContainer.new()
var velocidades: Dictionary = {}
var painel_conforto: PanelContainer
var menu := PanelContainer.new()
var pausa_anterior := 1.0
var espera := 1.0

func configurar(cena: Node) -> void:
	jogo = cena
	theme = T.criar()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var topo := PanelContainer.new()
	topo.position = Vector2(16,14)
	topo.custom_minimum_size = Vector2(450,52)
	add_child(topo)
	var linha := HBoxContainer.new()
	topo.add_child(linha)
	T.botao(linha,"P",alternar_menu,T.MARROM).tooltip_text = "Menu da partida"
	nome_restaurante=T.texto(linha,"PIZZAPLEX",20,T.AMBAR)
	nome_restaurante.custom_minimum_size.x=250
	nome_restaurante.clip_text=true
	saldo = T.texto(linha,"$ 0",20)
	var relogio := PanelContainer.new()
	relogio.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	relogio.offset_left = -304
	relogio.offset_right = -16
	relogio.offset_top = 14
	relogio.offset_bottom = 94
	add_child(relogio)
	var tempo := HBoxContainer.new()
	relogio.add_child(tempo)
	tempo.add_child(icone)
	tempo.add_child(data)
	data.add_theme_font_size_override("font_size",16)
	var acoes := HBoxContainer.new()
	acoes.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	acoes.offset_left = -408
	acoes.offset_right = -16
	acoes.offset_top = -94
	acoes.offset_bottom = -44
	add_child(acoes)
	for spec in [["Construir","construir",T.MARROM],["Agenda","calendario",T.AZUL],["Corte","paredes",T.VERDE]]:
		var acao: String = spec[0]
		var b := T.botao(acoes,"ITENS" if acao=="Construir" else "AGENDA" if acao=="Agenda" else "CORTE",func():
			if acao=="Construir": catalogo.alternar()
			elif acao=="Agenda": agenda.abrir()
			else:
				jogo.painel.recorte.button_pressed = not jogo.cortar_frente
				atualizar(1.0),spec[2])
		b.custom_minimum_size = Vector2(125,48)
		var imagem := IconeHudPlex.new(spec[1])
		imagem.scale = Vector2(.6,.6)
		imagem.position = Vector2(6,9)
		b.add_child(imagem)
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_theme_font_size_override("font_size",14)
		if acao=="Corte":
			corte = b
			b.tooltip_text = "Corta as paredes da frente e as divisórias. Ctrl alterna a altura de 1 a 4."
	var ferramentas := HBoxContainer.new()
	ferramentas.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ferramentas.offset_left = 16
	ferramentas.offset_top = -92
	ferramentas.offset_bottom = -44
	add_child(ferramentas)
	conforto_ui.configurar(jogo,self,ferramentas)
	painel_conforto=conforto_ui.painel
	resumo=conforto_ui.titulo
	configurar_abertura()
	catalogo.configurar(jogo,self)
	catalogo.painel.hide()
	add_child(agenda)
	agenda.configurar(jogo)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -180
	menu.offset_right = 180
	menu.offset_top = -220
	menu.offset_bottom = 220
	add_child(menu)
	var opcoes := VBoxContainer.new()
	menu.add_child(opcoes)
	T.texto(opcoes,"PIZZAPLEX / PAUSA",22,T.AMBAR)
	T.botao(opcoes,"Continuar",alternar_menu)
	T.botao(opcoes,"Salvar partida",func(): jogo.salvar())
	T.botao(opcoes,"Carregar partida",func(): jogo.carregar(); alternar_menu())
	T.botao(opcoes,"Tela cheia / Janela",func(): jogo.alternar_tela_cheia())
	T.botao(opcoes,"Menu inicial",func(): jogo.get_tree().change_scene_to_file("res://cenas/interface/inicio.tscn"))
	T.botao(opcoes,"Sair",func(): jogo.get_tree().quit())
	menu.hide()
	atualizar(1.0)

func menu_aberto() -> bool:
	return menu.visible or agenda.visible or jogo.vestiario_ui.aberto()

func alternar_menu() -> void:
	menu.visible = not menu.visible
	if menu.visible:
		pausa_anterior = jogo.velocidade_tempo
		jogo.velocidade_tempo = 0.0
	else: jogo.velocidade_tempo = pausa_anterior

func atualizar(delta: float) -> void:
	espera += delta
	if espera < .5: return
	espera = 0.0
	nome_restaurante.text=jogo.operacao.nome.to_upper()
	nome_restaurante.tooltip_text=jogo.operacao.nome
	abrir_botao.text="Fechar restaurante" if jogo.operacao.aberto else "Abrir restaurante"
	linha_controle.visible=jogo.operacao.mostrar_controle
	expandir.text=("▼ " if jogo.operacao.mostrar_controle else "▶ ")+("ABERTO" if jogo.operacao.aberto else "FECHADO")
	for valor in velocidades: velocidades[valor].set_pressed_no_signal(is_equal_approx(jogo.velocidade_tempo,float(valor)))
	var c: CalendarioPlex = jogo.calendario
	var d := c.data()
	data.text = "%02d / %s\n%s · %s" % [d.dia,CalendarioPlex.MESES[int(d.mes)-1],c.hora(),c.previsao()]
	icone.tipo = c.periodo()
	icone.queue_redraw()
	saldo.text = "$ "+str(jogo.servicos.saldo)
	if corte != null: corte.text = "CORTE ON" if jogo.cortar_frente else "CORTE OFF"

func configurar_abertura() -> void:
	var paineis:=HBoxContainer.new()
	paineis.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	paineis.offset_left=-558
	paineis.offset_right=-16
	paineis.offset_top=100
	paineis.offset_bottom=192
	paineis.alignment=BoxContainer.ALIGNMENT_END
	paineis.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	add_child(paineis)
	var ritmo:=PanelContainer.new()
	ritmo.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	paineis.add_child(ritmo)
	var tempos:=VBoxContainer.new()
	ritmo.add_child(tempos)
	T.texto(tempos,"TEMPO",13,T.SUAVE).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var linha_tempo:=HBoxContainer.new()
	tempos.add_child(linha_tempo)
	for valor in [0,1,2,3]:
		var b:=T.botao(linha_tempo,"Ⅱ" if valor==0 else str(valor)+"×",func(): jogo.velocidade_tempo=float(valor); atualizar(1.0),T.AZUL)
		b.toggle_mode=true
		b.custom_minimum_size=Vector2(42,36)
		b.tooltip_text="Pausar simulação" if valor==0 else "Velocidade "+str(valor)+"×"
		velocidades[valor]=b
	controle.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	controle.custom_minimum_size.x=220
	paineis.add_child(controle)
	var coluna:=VBoxContainer.new()
	controle.add_child(coluna)
	expandir=T.botao(coluna,"▶ FECHADO",func(): jogo.operacao.mostrar_controle=not jogo.operacao.mostrar_controle; atualizar(1.0))
	expandir.custom_minimum_size.y=28
	coluna.add_child(linha_controle)
	abrir_botao=T.botao(linha_controle,"Abrir restaurante",func(): jogo.operacao.mudar_abertura(not jogo.operacao.aberto),T.VERDE)
	abrir_botao.size_flags_horizontal=Control.SIZE_EXPAND_FILL

func _process(delta: float) -> void:
	if conforto_ui.jogo!=null: conforto_ui.atualizar(delta)
