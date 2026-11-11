class_name HudPlex
extends Control

const T = preload("res://scripts/interface/tema_hud.gd")
var jogo: Node
var catalogo := CatalogoConstrucaoPlex.new()
var agenda := UICalendarioPlex.new()
var calendario_visual:=RelogioCalendarioPlex.new()
var catalogo_botao:Button
var terminal_atalho: Button
var terminal_icone:=IconeHudPlex.new("ibm")
var controles_horario:=HBoxContainer.new()
var icone_relogio:IconeHudPlex
var livro_ui:=UILivroPlex.new()
var saldo: Label
var icone := IconeHudPlex.new()
var corte: Button
var resumo: Label
var conforto_ui := UIConfortoPlex.new()
var ar_ui:=UIArPlex.new()
var debug_ui:=DebugPlex.new()
var quadro_investigacao:=QuadroInvestigacaoPlex.new()
var nome_restaurante: Label
var expandir: Button
var abrir_botao: Button
var placa_abertura:=PlacaAberturaPlex.new()
var linha_controle := HBoxContainer.new()
var velocidades: Dictionary = {}
var mostrar_tempo := true
var linha_tempo := HBoxContainer.new()
var expandir_tempo: Button
var painel_conforto: PanelContainer
var menu := PanelContainer.new()
var sombra_pausa:=ColorRect.new()
var arquivos := UISavesPlex.new()
var pausa_anterior := 1.0
var espera := 1.0
var pendencias:=PendenciasRestaurantePlex.new()
var carregar_botao: Button
var ganho:=Label.new()
var acumulado:=0.0
var animacao_ganho: Tween

func configurar(cena: Node) -> void:
	jogo = cena
	theme = T.criar()
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var topo:=PanelContainer.new();topo.position=Vector2(16,14);topo.custom_minimum_size=Vector2(216,58)
	topo.add_theme_stylebox_override("panel",T.caixa(T.FUNDO,T.LINHA,10));add_child(topo)
	var linha:=HBoxContainer.new();topo.add_child(linha)
	var notas:=IconeHudPlex.new("dinheiro");notas.escala_pixel=1.5;notas.custom_minimum_size=Vector2(36,36);linha.add_child(notas)
	var carteira:=VBoxContainer.new();carteira.add_theme_constant_override("separation",0);linha.add_child(carteira)
	saldo=T.texto(carteira,"$ 0.00",23,T.PAPEL);saldo.custom_minimum_size.x=142;saldo.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	carteira.add_child(ganho);ganho.add_theme_font_size_override("font_size",13);ganho.add_theme_color_override("font_color",Color("b8da9c"));ganho.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	jogo.servicos.dinheiro_recebido.connect(receber_dinheiro)
	var relogio := PanelContainer.new()
	relogio.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	relogio.offset_left = -304
	relogio.offset_right = -16
	relogio.offset_top = 14
	relogio.offset_bottom = 146
	relogio.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	add_child(relogio)
	var tempo := HBoxContainer.new()
	tempo.alignment=BoxContainer.ALIGNMENT_END
	icone.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	relogio.add_child(tempo)
	tempo.add_child(icone)
	tempo.add_child(calendario_visual)
	var acoes := HBoxContainer.new()
	acoes.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	acoes.offset_left = -500
	acoes.offset_right = -16
	acoes.offset_top = -68
	acoes.offset_bottom = -12
	add_child(acoes)
	for spec in [["Construir","construir",T.MARROM],["Agenda","calendario",T.AZUL],["Corte","paredes",T.VERDE]]:
		var acao: String = spec[0]
		var b := T.botao(acoes,"CATÁLOGO" if acao=="Construir" else "AGENDA" if acao=="Agenda" else "CORTE",func():
			if acao=="Construir": catalogo.alternar()
			elif acao=="Agenda": agenda.abrir()
			else:
				jogo.definir_corte(not jogo.cortar_frente)
				atualizar(1.0),spec[2])
		b.custom_minimum_size = Vector2(138,52)
		var imagem := IconeHudPlex.new(spec[1])
		imagem.escala_pixel=1.5
		imagem.custom_minimum_size=Vector2(36,36)
		imagem.position = Vector2(6,8)
		b.add_child(imagem)
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_theme_font_size_override("font_size",14)
		if acao=="Construir":catalogo_botao=b
		if acao=="Corte":
			corte = b
			b.tooltip_text=""
	var ferramentas := HBoxContainer.new()
	ferramentas.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ferramentas.offset_left = 16
	ferramentas.offset_top = -60
	ferramentas.offset_bottom = -12
	add_child(ferramentas)
	conforto_ui.configurar(jogo,self,ferramentas)
	ar_ui.configurar(jogo,self,ferramentas)
	jogo.add_child(debug_ui);debug_ui.configurar(jogo)
	jogo.add_child(quadro_investigacao);quadro_investigacao.configurar(jogo)
	var debug_botao:=T.botao(ferramentas,"",debug_ui.alternar,T.AZUL);debug_botao.custom_minimum_size=Vector2(48,48)
	var cubo:=IconeHudPlex.new("debug");cubo.escala_pixel=1.5;cubo.custom_minimum_size=Vector2(36,36);cubo.position=Vector2(6,6);debug_botao.add_child(cubo)
	terminal_atalho=T.botao(acoes,"",abrir_terminal,T.AZUL)
	acoes.move_child(terminal_atalho,0)
	terminal_atalho.custom_minimum_size=Vector2(48,48)
	terminal_icone.escala_pixel=1.5
	terminal_icone.custom_minimum_size=Vector2(36,36)
	terminal_icone.position=Vector2(6,6)
	terminal_atalho.add_child(terminal_icone)
	terminal_atalho.tooltip_text=""
	add_child(livro_ui);livro_ui.configurar(jogo)
	painel_conforto=conforto_ui.painel
	resumo=conforto_ui.titulo
	configurar_abertura()
	add_child(pendencias)
	pendencias.configurar(jogo)
	catalogo.configurar(jogo,self)
	catalogo.painel.hide()
	add_child(agenda)
	agenda.configurar(jogo)
	add_child(sombra_pausa)
	sombra_pausa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra_pausa.color=Color(.05,.025,.015,.65)
	sombra_pausa.z_index=105
	sombra_pausa.hide()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left=-200
	menu.offset_right=200
	menu.offset_top=-285
	menu.offset_bottom=285
	menu.z_index=106
	menu.add_theme_stylebox_override("panel",T.caixa(T.FUNDO,T.AMBAR,18))
	add_child(menu)
	var opcoes:=VBoxContainer.new()
	opcoes.add_theme_constant_override("separation",10)
	menu.add_child(opcoes)
	var placa:=PanelContainer.new()
	placa.add_theme_stylebox_override("panel",T.caixa(Color("69392f"),T.LINHA,12))
	opcoes.add_child(placa)
	T.texto(placa,"◆  PIZZAPLEX / PAUSA",20,T.PAPEL)
	T.texto(opcoes,"Idioma",16,T.PAPEL)
	IdiomaPlex.criar_seletor(opcoes)
	TemaTerminalPlex.botao(opcoes,"CONTINUAR  ›",alternar_menu,true)
	T.botao(opcoes,"Salvar partida",func(): jogo.salvar())
	carregar_botao=T.botao(opcoes,"Carregar partida",abrir_saves)
	carregar_botao.disabled=not ArquivoPlex.tem_saves()
	T.botao(opcoes,"Tela cheia / Janela",func(): jogo.alternar_tela_cheia())
	T.botao(opcoes,"Menu inicial",func(): jogo.get_tree().change_scene_to_file("res://cenas/interface/inicio.tscn"))
	T.botao(opcoes,"Sair do jogo",func(): jogo.get_tree().quit())
	menu.hide()
	add_child(arquivos)
	arquivos.excluido.connect(func(_caminho): carregar_botao.disabled=not ArquivoPlex.tem_saves())
	arquivos.salvar_escolhido.connect(func(slot):jogo.salvar(slot))
	arquivos.escolhido.connect(func(caminho): jogo.carregar(caminho); alternar_menu())
	atualizar(1.0)

func menu_aberto() -> bool:
	return arquivos.visible or menu.visible or agenda.visible or livro_ui.aberto() or jogo.vestiario_ui.aberto()

func alternar_menu() -> void:
	menu.visible = not menu.visible
	sombra_pausa.visible=menu.visible
	if menu.visible:
		carregar_botao.disabled=not ArquivoPlex.tem_saves()
		jogo.pausar("menu")
	else: jogo.retomar("menu")

func atualizar(delta: float) -> void:
	pendencias.atualizar(delta)
	espera += delta
	if espera < .5: return
	espera = 0.0

	atualizar_abertura()
	linha_controle.visible=false
	expandir.tooltip_text=""
	linha_tempo.show()
	for valor in velocidades: velocidades[valor].set_pressed_no_signal(is_equal_approx(jogo.velocidade_base,float(valor)))
	var c: CalendarioPlex = jogo.calendario
	calendario_visual.atualizar(c)
	terminal_atalho.disabled=terminal_disponivel()<0
	terminal_icone.bloqueado=terminal_atalho.disabled
	terminal_icone.queue_redraw()
	organizar_controles()
	icone.tipo = c.periodo()
	icone.queue_redraw()
	saldo.text = "$ %.2f"%float(jogo.servicos.saldo)
	if corte != null: corte.text = "CORTE ON" if jogo.cortar_frente else "CORTE OFF"

func compacto(pai: Node, texto: String, acao: Callable, cor: Color = T.FUNDO) -> Button:
	var botao := T.botao(pai,texto,acao,cor)
	botao.custom_minimum_size=Vector2(32,28)
	botao.add_theme_font_size_override("font_size",12)
	for estado in ["normal","hover","pressed"]:
		botao.add_theme_stylebox_override(estado,T.caixa(cor.lightened(.14) if estado=="hover" else cor,T.AMBAR if estado=="pressed" else T.LINHA,4))
	return botao

func configurar_abertura() -> void:
	var paineis:=controles_horario;paineis.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	paineis.offset_left=-336;paineis.offset_right=-6;paineis.offset_top=150;paineis.offset_bottom=204
	paineis.add_theme_constant_override("separation",8);paineis.alignment=BoxContainer.ALIGNMENT_END;add_child(paineis)
	paineis.add_child(linha_tempo);linha_tempo.alignment=BoxContainer.ALIGNMENT_CENTER;linha_tempo.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	linha_tempo.add_theme_constant_override("separation",3)
	for valor in [0,1,2,3]:
		var b:=compacto(linha_tempo,"Ⅱ" if valor==0 else str(valor)+"×",func():jogo.velocidade_tempo=float(valor);atualizar(1),T.AZUL)
		b.custom_minimum_size=Vector2(36,32);b.toggle_mode=true;velocidades[valor]=b
		for estado in ["pressed","hover_pressed"]:b.add_theme_stylebox_override(estado,T.caixa(Color("806139"),T.AMBAR,4))
	expandir=compacto(paineis,"",func():jogo.operacao.mudar_abertura(not jogo.operacao.aberto);atualizar(1),T.MARROM)
	expandir.custom_minimum_size=Vector2(144,52);abrir_botao=expandir
	expandir.add_child(placa_abertura);placa_abertura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	expandir.button_down.connect(func():placa_abertura.self_modulate=Color(.86,.86,.86))
	expandir.button_up.connect(func():placa_abertura.self_modulate=Color.WHITE)
	mostrar_tempo=true;add_child(linha_controle);linha_controle.hide()

func _process(delta: float) -> void:
	if is_instance_valid(icone_relogio):icone_relogio.minutos=jogo.calendario.minutos;icone_relogio.queue_redraw()
	if conforto_ui.jogo!=null: conforto_ui.atualizar(delta)
	if ar_ui.jogo!=null:ar_ui.atualizar(delta)
	catalogo.atualizar_ar()

func abrir_saves() -> void:
	carregar_botao.disabled=not ArquivoPlex.tem_saves()
	if carregar_botao.disabled: return
	if not menu.visible: alternar_menu()
	arquivos.abrir()


func receber_dinheiro(valor: float) -> void:
	if valor<=0.0: return
	acumulado+=valor
	ganho.text="(+%.2f)"%acumulado
	ganho.modulate.a=1.0
	if animacao_ganho!=null and animacao_ganho.is_valid(): animacao_ganho.kill()
	animacao_ganho=create_tween()
	animacao_ganho.tween_interval(1.8)
	animacao_ganho.tween_property(ganho,"modulate:a",0.0,.5)
	animacao_ganho.tween_callback(limpar_ganho)

func limpar_ganho() -> void:
	acumulado=0.0
	ganho.text=""

func terminal_disponivel() -> int:
	if jogo.compras.terminal_valido(jogo.terminal_ui.terminal): return jogo.terminal_ui.terminal
	for id in jogo.planta.objetos:
		if jogo.planta.objetos[id].tipo=="terminal_ibm" and jogo.compras.terminal_valido(id): return id
	return -1

func abrir_terminal() -> void:
	var id:=terminal_disponivel()
	if id>=0:
		if is_instance_valid(jogo.sistemas.tutorial) and jogo.sistemas.tutorial.etapa=="ibm_abrir":jogo.terminal_ui.aba="mercado";jogo.terminal_ui.produto="pizza";jogo.terminal_ui.quantidade=1
		jogo.terminal_ui.abrir(id)

func organizar_controles() -> void:
	if not is_instance_valid(pendencias) or not pendencias.is_inside_tree(): return
	pendencias.position=Vector2(size.x-248,212)

func alternar_pausa() -> void:
	if jogo.velocidade_base>0:
		pausa_anterior=jogo.velocidade_base;jogo.velocidade_base=0.0
	else: jogo.velocidade_base=maxf(1.0,pausa_anterior)
	espera=1.0;atualizar(0)

func atualizar_abertura() -> void:
	var trancado:bool=jogo.operacao.bloqueado_por_seguranca()
	abrir_botao.disabled=trancado
	abrir_botao.text="";placa_abertura.aberto=jogo.operacao.aberto;placa_abertura.trancado=trancado;placa_abertura.queue_redraw()
	for estado in ["normal","hover","pressed","disabled","focus"]:abrir_botao.add_theme_stylebox_override(estado,StyleBoxEmpty.new())
	abrir_botao.modulate=Color("bbb5a7") if trancado else Color.WHITE
	abrir_botao.tooltip_text="Abertura indisponível." if trancado else "Fechar restaurante" if jogo.operacao.aberto else "Abrir restaurante"
