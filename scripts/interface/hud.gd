class_name HudPlex
extends Control

const T = preload("res://scripts/interface/tema_hud.gd")
var jogo: Node
var catalogo := CatalogoConstrucaoPlex.new()
var agenda := UICalendarioPlex.new()
var calendario_visual:=RelogioCalendarioPlex.new()
var catalogo_botao:Button
var terminal_atalho: Button
var controles_horario:=HBoxContainer.new()
var icone_relogio:IconeHudPlex
var livro_ui:=UILivroPlex.new()
var saldo: NumeroPixelPlex
var painel_saldo: PanelContainer
var agenda_botao: BotaoHudPlex
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
var ganho:=NumeroPixelPlex.new("",2,Color("b8da9c"))
var etiqueta_ganho: PanelContainer
var acumulado:=0.0
var animacao_ganho: Tween

func configurar(cena: Node) -> void:
	jogo = cena
	theme = T.criar()
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Saldo: cédula + visor de dígitos, da mesma família do relógio. O painel
	# cresce para a direita conforme o valor aumenta.
	painel_saldo=KitPlex.painel(self,"hud",8);painel_saldo.position=Vector2(16,14);painel_saldo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	painel_saldo.tooltip_text=""
	var linha:=HBoxContainer.new();linha.add_theme_constant_override("separation",8);linha.mouse_filter=Control.MOUSE_FILTER_IGNORE;painel_saldo.add_child(linha)
	KitPlex.icone(linha,"res://assets/interface/hud/dinheiro.png",32)
	var visor:=KitPlex.painel(linha,"visor",8);visor.mouse_filter=Control.MOUSE_FILTER_IGNORE;visor.custom_minimum_size=Vector2(168,37)
	saldo=NumeroPixelPlex.new("$ 0.00",3,T.AMBAR);saldo.apagado=Color("2c1d15");visor.add_child(saldo)
	etiqueta_ganho=KitPlex.painel(self,"hud",6);etiqueta_ganho.mouse_filter=Control.MOUSE_FILTER_IGNORE;etiqueta_ganho.add_child(ganho);etiqueta_ganho.hide()
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
	# Barra inferior. À esquerda, os atalhos de consulta (só ícone); à direita,
	# as ferramentas de trabalho (ícone + nome). Todos com 56 px de altura.
	var acoes := HBoxContainer.new()
	acoes.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	acoes.grow_horizontal=Control.GROW_DIRECTION_BEGIN
	acoes.offset_right = -16
	acoes.offset_top = -68
	acoes.offset_bottom = -12
	acoes.alignment=BoxContainer.ALIGNMENT_END
	acoes.add_theme_constant_override("separation",6)
	add_child(acoes)
	catalogo_botao=BotaoHudPlex.new("res://assets/interface/ajustes/martelo.png","Catálogo","Catálogo de construção",Color("5a3320"))
	acoes.add_child(catalogo_botao);catalogo_botao.pressed.connect(func():catalogo.alternar())
	agenda_botao=BotaoHudPlex.new("res://assets/interface/hud/agenda.png","Agenda","Agenda de apresentações")
	acoes.add_child(agenda_botao);agenda_botao.pressed.connect(func():agenda.abrir())
	corte=BotaoHudPlex.new("res://assets/interface/ajustes/paredes.png","Corte","Alternar paredes completas e recortadas")
	acoes.add_child(corte);corte.pressed.connect(func():
		jogo.definir_corte(not jogo.cortar_frente)
		atualizar(1.0))
	var ferramentas := HBoxContainer.new()
	ferramentas.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ferramentas.offset_left = 16
	ferramentas.offset_top = -68
	ferramentas.offset_bottom = -12
	ferramentas.add_theme_constant_override("separation",6)
	add_child(ferramentas)
	conforto_ui.configurar(jogo,self,ferramentas)
	ar_ui.configurar(jogo,self,ferramentas)
	jogo.add_child(debug_ui);debug_ui.configurar(jogo)
	jogo.add_child(quadro_investigacao);quadro_investigacao.configurar(jogo)
	terminal_atalho=BotaoHudPlex.new("res://assets/interface/ajustes/ibm.png","","Terminal de administração")
	ferramentas.add_child(terminal_atalho);terminal_atalho.pressed.connect(abrir_terminal)
	var debug_botao:=BotaoHudPlex.new("res://assets/interface/hud/debug.png","","Ferramentas de teste")
	ferramentas.add_child(debug_botao);debug_botao.pressed.connect(debug_ui.alternar)
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
	menu.grow_horizontal=Control.GROW_DIRECTION_BOTH;menu.grow_vertical=Control.GROW_DIRECTION_BOTH
	menu.custom_minimum_size.x=380
	menu.z_index=106
	menu.add_theme_stylebox_override("panel",KitPlex.moldura("janela",20))
	add_child(menu)
	var opcoes:=VBoxContainer.new()
	opcoes.add_theme_constant_override("separation",10)
	menu.add_child(opcoes)
	KitPlex.placa(opcoes,"Pausa",22)
	nome_restaurante=KitPlex.texto(opcoes,"",14,KitPlex.AREIA);nome_restaurante.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var continuar:=KitPlex.botao(opcoes,"CONTINUAR",alternar_menu,"ouro",18);continuar.custom_minimum_size.y=50
	KitPlex.secao(opcoes,"Partida")
	var partida:=HBoxContainer.new();partida.add_theme_constant_override("separation",8);opcoes.add_child(partida)
	KitPlex.botao(partida,"Salvar",func(): jogo.salvar()).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	carregar_botao=KitPlex.botao(partida,"Carregar",abrir_saves);carregar_botao.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	carregar_botao.disabled=not ArquivoPlex.tem_saves()
	KitPlex.secao(opcoes,"Opções")
	var linha_idioma:=HBoxContainer.new();linha_idioma.add_theme_constant_override("separation",10);opcoes.add_child(linha_idioma)
	KitPlex.texto(linha_idioma,"Idioma",15).custom_minimum_size.x=84
	IdiomaPlex.criar_seletor(linha_idioma).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	KitPlex.botao(opcoes,"Tela cheia / Janela",func(): jogo.alternar_tela_cheia(),"noite")
	KitPlex.secao(opcoes,"Sair")
	var saida:=HBoxContainer.new();saida.add_theme_constant_override("separation",8);opcoes.add_child(saida)
	KitPlex.botao(saida,"Menu inicial",func(): jogo.get_tree().change_scene_to_file("res://cenas/interface/inicio.tscn"),"noite").size_flags_horizontal=Control.SIZE_EXPAND_FILL
	KitPlex.botao(saida,"Sair do jogo",func(): jogo.get_tree().quit(),"vinho").size_flags_horizontal=Control.SIZE_EXPAND_FILL
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
		nome_restaurante.text=str(jogo.operacao.nome)
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
	organizar_controles()
	icone.tipo = c.periodo()
	icone.queue_redraw()
	saldo.texto=NumeroPixelPlex.dinheiro(float(jogo.servicos.saldo))
	if corte != null and (corte.lampada==null or corte.ligado!=jogo.cortar_frente): corte.definir_estado(jogo.cortar_frente,"LIGADO","DESLIGADO","res://assets/interface/hud/paredes_corte.png")

func compacto(pai: Node, texto: String, acao: Callable, cor: Color = T.FUNDO) -> Button:
	var botao := T.botao(pai,texto,acao,cor)
	botao.custom_minimum_size=Vector2(32,28)
	botao.add_theme_font_size_override("font_size",12)
	for estado in ["normal","hover","pressed"]:
		botao.add_theme_stylebox_override(estado,T.caixa(cor.lightened(.14) if estado=="hover" else cor,T.AMBAR if estado=="pressed" else T.LINHA,4))
	return botao

func configurar_abertura() -> void:
	var paineis:=controles_horario;paineis.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	paineis.offset_left=-304;paineis.offset_right=-16;paineis.offset_top=150;paineis.offset_bottom=204
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
	ganho.texto="+"+NumeroPixelPlex.dinheiro(acumulado).trim_prefix("$ ")
	etiqueta_ganho.reset_size();etiqueta_ganho.position=painel_saldo.position+Vector2(painel_saldo.size.x-etiqueta_ganho.size.x,painel_saldo.size.y+2)
	etiqueta_ganho.modulate.a=1.0;etiqueta_ganho.show()
	if animacao_ganho!=null and animacao_ganho.is_valid(): animacao_ganho.kill()
	animacao_ganho=create_tween()
	animacao_ganho.tween_interval(1.8)
	animacao_ganho.tween_property(etiqueta_ganho,"modulate:a",0.0,.5)
	animacao_ganho.tween_callback(limpar_ganho)

func limpar_ganho() -> void:
	acumulado=0.0
	etiqueta_ganho.hide()

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
	abrir_botao.tooltip_text=""
