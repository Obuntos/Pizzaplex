class_name TemaHudPlex
extends RefCounted

const FUNDO = Color("30211d")
const PAPEL = Color("f1dfb9")
const SUAVE = Color("bda380")
const LINHA = Color("896147")
const AMBAR = Color("dfb16a")
const MARROM = Color("68462f")
const AZUL = Color("47403d")
const VERDE = Color("4b5c3d")

static func caixa(cor: Color, borda: Color = LINHA, margem: int = 10) -> StyleBoxFlat:
	var tinta:=Color("68442d") if borda==AMBAR else borda.darkened(.2)
	return VintagePlex.caixa(cor,tinta,margem)

static func cabecalho(pai: Node, titulo: String, simbolo: String, cor: Color=AMBAR) -> HBoxContainer:
	# Janelas com título usam a placa vinho; quem chama acrescenta o × ao lado.
	if not titulo.is_empty(): return KitPlex.cabecalho(pai,titulo)
	var linha:=HBoxContainer.new()
	linha.add_theme_constant_override("separation",12)
	pai.add_child(linha)
	var i:=IconeHudPlex.new(simbolo)
	i.custom_minimum_size=Vector2(32,32)
	i.escala_pixel=1.25
	linha.add_child(i)
	if not titulo.is_empty():
		var l:=texto(linha,titulo,18,cor)
		l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	return linha

static func criar() -> Theme:
	var t:=Theme.new()
	t.default_font=VintagePlex.fonte()
	t.default_font_size=16
	t.set_color("font_color","Label",PAPEL)
	for tipo in ["Button","OptionButton","CheckButton","CheckBox","MenuButton"]:
		for propriedade in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]: t.set_color(propriedade,tipo,PAPEL)
		var caixa_de_marcar:bool=tipo in ["CheckButton","CheckBox"]
		for estado in ["normal","hover","pressed","hover_pressed","disabled"]:
			# Caixas de marcar ficam planas: quem muda é o ícone, não a face.
			if caixa_de_marcar: t.set_stylebox(estado,tipo,KitPlex.moldura("campo_foco" if estado.begins_with("hover") else "campo",8))
			else: t.set_stylebox(estado,tipo,KitPlex.estado_botao(Color("3b2a25") if tipo=="OptionButton" else Color("5a3320"),estado,10))
		t.set_stylebox("focus",tipo,KitPlex.moldura("contorno_ouro"))
		t.set_color("font_disabled_color",tipo,Color("a08a72"))
		for ic in ["checked","radio_checked","checked_disabled","radio_checked_disabled"]: t.set_icon(ic,tipo,VintagePlex.icone("marcado"))
		for ic in ["unchecked","radio_unchecked","unchecked_disabled","radio_unchecked_disabled"]: t.set_icon(ic,tipo,VintagePlex.icone("desmarcado"))
	t.set_icon("arrow","OptionButton",VintagePlex.icone("baixo"))
	for estado in ["normal","read_only"]: t.set_stylebox(estado,"LineEdit",KitPlex.moldura("campo",10))
	t.set_stylebox("focus","LineEdit",KitPlex.moldura("campo_foco",10))
	for estado in ["normal","read_only"]: t.set_stylebox(estado,"TextEdit",KitPlex.moldura("campo",10))
	t.set_stylebox("focus","TextEdit",KitPlex.moldura("campo_foco",10))
	for tipo in ["LineEdit","TextEdit"]:
		t.set_color("font_color",tipo,PAPEL)
		t.set_color("caret_color",tipo,PAPEL)
		t.set_color("selection_color",tipo,Color("7d4930"))
		t.set_color("font_placeholder_color",tipo,SUAVE)
	t.set_stylebox("background","ProgressBar",KitPlex.moldura("visor",4))
	t.set_stylebox("fill","ProgressBar",KitPlex.quadro([KitPlex.TINTA,Color("8fb072")],Color("65834e"),1,0))
	t.set_color("font_color","ProgressBar",PAPEL)
	t.set_stylebox("panel","PanelContainer",KitPlex.moldura("hud"))
	t.set_stylebox("panel","Panel",KitPlex.moldura("hud"))
	t.set_stylebox("panel","PopupMenu",KitPlex.moldura("hud",6))
	t.set_stylebox("panel","PopupPanel",KitPlex.moldura("hud",8))
	t.set_stylebox("hover","PopupMenu",KitPlex.quadro([Color("a46d3d")],Color("78402a"),1,5))
	t.set_constant("v_separation","PopupMenu",8)
	for nome in ["font_color","font_hover_color"]: t.set_color(nome,"PopupMenu",PAPEL)
	for nome in ["checked","radio_checked"]: t.set_icon(nome,"PopupMenu",VintagePlex.icone("marcado"))
	for nome in ["unchecked","radio_unchecked"]: t.set_icon(nome,"PopupMenu",VintagePlex.icone("desmarcado"))
	for tipo in ["HScrollBar","VScrollBar"]:
		var trilho:=KitPlex.quadro([Color("1d0e08")],Color("28160e"),0,0)
		for l in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:trilho.set_content_margin(l,6)
		t.set_stylebox("scroll",tipo,trilho)
		for nome in ["grabber","grabber_highlight","grabber_pressed"]:
			t.set_stylebox(nome,tipo,KitPlex.quadro([KitPlex.TINTA,Color("c98a4b") if nome=="grabber_highlight" else Color("a5784c")],Color("a5784c") if nome=="grabber_highlight" else Color("5a3320") if nome=="grabber_pressed" else Color("795138"),1,6))
	for tipo in ["HSeparator","VSeparator"]:
		var fio:=StyleBoxLine.new();fio.color=Color("6b4a36");fio.thickness=2;fio.vertical=tipo=="VSeparator"
		t.set_stylebox("separator",tipo,fio)
	t.set_constant("separation","HSeparator",10)
	# Abas: a ativa se une ao painel; as outras ficam recuadas e mais escuras.
	t.set_stylebox("panel","TabContainer",KitPlex.moldura("hud",12))
	t.set_stylebox("tab_selected","TabContainer",KitPlex.quadro([KitPlex.TINTA,AMBAR],FUNDO,1,10))
	t.set_stylebox("tab_unselected","TabContainer",KitPlex.quadro([KitPlex.TINTA,Color("4a352c")],Color("24160f"),1,10))
	t.set_stylebox("tab_hovered","TabContainer",KitPlex.quadro([KitPlex.TINTA,LINHA],Color("3b2a25"),1,10))
	t.set_stylebox("tab_disabled","TabContainer",KitPlex.quadro([KitPlex.TINTA,Color("4a352c")],Color("24160f"),1,10))
	t.set_stylebox("tab_focus","TabContainer",KitPlex.moldura("contorno_ouro"))
	t.set_color("font_selected_color","TabContainer",AMBAR)
	t.set_color("font_unselected_color","TabContainer",SUAVE)
	t.set_color("font_hovered_color","TabContainer",PAPEL)
	# Diálogos do sistema (AcceptDialog) com a moldura de madeira das janelas.
	t.set_stylebox("embedded_border","Window",KitPlex.quadro([Color("150803"),KitPlex.MADEIRA_CLARA,Color("2a140c")],KitPlex.MADEIRA,2,14,0,KitPlex.TINTA,false,0,Color("5d3120")))
	t.set_stylebox("embedded_unfocused_border","Window",KitPlex.quadro([Color("150803"),KitPlex.MADEIRA_CLARA,Color("2a140c")],KitPlex.MADEIRA,2,14,0,KitPlex.TINTA,false,0,Color("5d3120")))
	t.set_stylebox("panel","AcceptDialog",KitPlex.quadro([KitPlex.MADEIRA],KitPlex.MADEIRA,0,10))
	t.set_color("title_color","Window",Color("f3c46f"))
	t.set_font("title_font","Window",VintagePlex.fonte("titulo"))
	t.set_font_size("title_font_size","Window",18)
	t.set_constant("title_height","Window",40)
	t.set_icon("close","Window",VintagePlex.icone("x"))
	t.set_icon("close_pressed","Window",VintagePlex.icone("x",AMBAR))
	t.set_constant("close_h_offset","Window",34)
	t.set_constant("close_v_offset","Window",32)
	t.set_stylebox("panel","TooltipPanel",KitPlex.moldura("etiqueta",8))
	t.set_color("font_color","TooltipLabel",Color("2a1408"))
	t.set_font_size("font_size","TooltipLabel",14)
	t.set_constant("separation","HBoxContainer",8)
	t.set_constant("separation","VBoxContainer",8)
	return t

static func texto(pai: Node, valor: String, tamanho: int = 18, cor: Color = PAPEL) -> Label:
	var l := Label.new()
	l.text = valor
	if tamanho>=22: l.add_theme_font_override("font",VintagePlex.fonte("titulo"))
	l.add_theme_font_size_override("font_size",tamanho)
	l.add_theme_color_override("font_color",cor)
	pai.add_child(l)
	return l

static func botao(pai: Node, valor: String, acao: Callable, cor: Color = Color("5a3320")) -> Button:
	if valor in ["×","X"] and cor.is_equal_approx(Color("5a3320")): return KitPlex.fechar(pai,acao)
	var b:=VintagePlex.botao(pai,valor,acao,cor)
	b.add_theme_font_size_override("font_size",16)
	# A cor de fundo dos painéis não destaca um botão: vira madeira de botão.
	KitPlex.preparar_botao(b,Color("5a3320") if cor.is_equal_approx(FUNDO) else cor,cor.get_luminance()>.45)
	return b
