class_name UISavesPlex
extends Control

signal escolhido(caminho: String)
const T = preload("res://scripts/interface/tema_hud.gd")
var janela := PanelContainer.new()
var lista := VBoxContainer.new()
var resumo: Label
var carregar: Button
var selecionado := ""
var botoes: Dictionary = {}
var registros: Array[Dictionary] = []

func _ready() -> void:
	theme=T.criar()
	z_index=300
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.color=Color(0.025,0.04,0.05,.86)
	add_child(fundo)
	add_child(janela)
	janela.add_theme_stylebox_override("panel",T.caixa(T.FUNDO,T.AMBAR,20))
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation",14)
	janela.add_child(coluna)
	var cabecalho := HBoxContainer.new()
	coluna.add_child(cabecalho)
	T.texto(cabecalho,"CARREGAR PARTIDA",24,T.AMBAR).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	T.botao(cabecalho,"×",fechar).tooltip_text="Fechar"
	T.texto(coluna,"Escolha uma partida para continuar de onde parou.",16,T.SUAVE)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	coluna.add_child(scroll)
	lista.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)
	resumo=T.texto(coluna,"",16,T.SUAVE)
	resumo.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	resumo.custom_minimum_size.y=42
	var acoes := HBoxContainer.new()
	coluna.add_child(acoes)
	T.botao(acoes,"Voltar",fechar)
	carregar=T.botao(acoes,"Carregar selecionado",confirmar,T.VERDE)
	carregar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	get_viewport().size_changed.connect(redimensionar)
	hide()

func redimensionar() -> void:
	var tela:=get_viewport_rect().size
	janela.size=Vector2(minf(700,tela.x-32),minf(540,tela.y-32))
	janela.position=((tela-janela.size)*.5).floor()

func abrir() -> void:
	selecionado=""
	carregar.disabled=true
	botoes.clear()
	for filho in lista.get_children():
		lista.remove_child(filho)
		filho.queue_free()
	registros=ArquivoPlex.listar()
	for registro in registros:
		var caminho: String=registro.caminho
		var texto: String=registro.nome+"\n"+registro.data+"  ·  "+("Debug" if registro.debug else "Normal")
		if not registro.carregavel: texto+="\nArquivo incompatível ou incompleto"
		var botao := T.botao(lista,texto,func(): selecionar(caminho))
		botao.custom_minimum_size.y=76
		botao.alignment=HORIZONTAL_ALIGNMENT_LEFT
		botao.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		botao.toggle_mode=true
		botao.disabled=not registro.carregavel
		botao.tooltip_text=caminho.get_file()
		botoes[caminho]=botao
	resumo.text="Nenhuma partida salva. Use Salvar partida no menu de pausa durante o jogo." if registros.is_empty() else "Selecione um save. Arquivos incompatíveis ficam desabilitados."
	show()
	redimensionar()
	for registro in registros:
		if registro.carregavel:
			selecionar(registro.caminho)
			break

func selecionar(caminho: String) -> void:
	for registro in registros:
		if registro.caminho!=caminho or not registro.carregavel: continue
		selecionado=caminho
		for id in botoes: botoes[id].set_pressed_no_signal(id==caminho)
		resumo.text="Dia %d · %s · $ %d\n%s" % [registro.dia,registro.hora,registro.saldo,registro.nome]
		carregar.disabled=false
		return

func confirmar() -> void:
	if selecionado.is_empty(): return
	if ArquivoPlex.ler(selecionado).is_empty():
		carregar.disabled=true
		resumo.text="Esta partida não pôde ser carregada. Escolha outro save."
		return
	var caminho := selecionado
	fechar()
	escolhido.emit(caminho)

func fechar() -> void:
	hide()

func _process(_delta: float) -> void:
	if visible: redimensionar()
