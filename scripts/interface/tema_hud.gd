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
	for tipo in ["Button","OptionButton","CheckButton","CheckBox"]:
		for propriedade in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: t.set_color(propriedade,tipo,PAPEL)
		for estado in ["normal","hover","pressed","hover_pressed","disabled"]:
			var cor:=Color("65402c") if estado=="hover" else Color("24140d") if estado in ["pressed","hover_pressed"] else FUNDO
			t.set_stylebox(estado,tipo,caixa(cor,Color("a46d3d") if estado=="hover" else LINHA,8))
		t.set_stylebox("focus",tipo,caixa(Color.TRANSPARENT,Color("a46d3d"),0))
		t.set_color("font_disabled_color",tipo,Color("8c7058"))
		for ic in ["checked","radio_checked","checked_disabled","radio_checked_disabled"]: t.set_icon(ic,tipo,VintagePlex.icone("marcado"))
		for ic in ["unchecked","radio_unchecked","unchecked_disabled","radio_unchecked_disabled"]: t.set_icon(ic,tipo,VintagePlex.icone("desmarcado"))
	t.set_icon("arrow","OptionButton",VintagePlex.icone("baixo"))
	for estado in ["normal","read_only"]: t.set_stylebox(estado,"LineEdit",caixa(Color("28160e"),LINHA,10))
	t.set_stylebox("focus","LineEdit",caixa(Color("382013"),Color("a46d3d"),10))
	t.set_color("font_color","LineEdit",PAPEL)
	t.set_color("caret_color","LineEdit",PAPEL)
	t.set_color("selection_color","LineEdit",Color("7d4930"))
	t.set_color("font_placeholder_color","LineEdit",SUAVE)
	t.set_stylebox("background","ProgressBar",caixa(Color("20150f"),LINHA,3))
	t.set_stylebox("fill","ProgressBar",caixa(VERDE,Color("65834e"),0))
	t.set_color("font_color","ProgressBar",PAPEL)
	t.set_stylebox("panel","PanelContainer",caixa(FUNDO))
	t.set_stylebox("panel","PopupMenu",caixa(Color("382013")))
	t.set_stylebox("hover","PopupMenu",caixa(Color("78402a"),Color("a46d3d"),5))
	for nome in ["font_color","font_hover_color"]: t.set_color(nome,"PopupMenu",PAPEL)
	for nome in ["checked","radio_checked"]: t.set_icon(nome,"PopupMenu",VintagePlex.icone("marcado"))
	for nome in ["unchecked","radio_unchecked"]: t.set_icon(nome,"PopupMenu",VintagePlex.icone("desmarcado"))
	for tipo in ["HScrollBar","VScrollBar"]:
		t.set_stylebox("scroll",tipo,caixa(Color("28160e"),Color("28160e"),3))
		for nome in ["grabber","grabber_highlight","grabber_pressed"]:
			var barra:=caixa(Color("a5784c") if nome=="grabber_highlight" else Color("795138"),Color("3a2115"),3)
			barra.content_margin_left=5;barra.content_margin_right=5;barra.content_margin_top=5;barra.content_margin_bottom=5
			t.set_stylebox(nome,tipo,barra)
	t.set_stylebox("panel","TooltipPanel",caixa(Color("ead2a3"),Color("6b3f26"),8))
	t.set_color("font_color","TooltipLabel",Color("2a1408"))
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

static func botao(pai: Node, valor: String, acao: Callable, cor: Color = FUNDO) -> Button:
	return VintagePlex.botao(pai,valor,acao,cor)
