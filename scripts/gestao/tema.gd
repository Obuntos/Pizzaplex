class_name TemaTerminalPlex
extends RefCounted

const FUNDO = Color("e9e3d4")
const PAPEL = Color("f5f0e5")
const TINTA = Color("293a33")
const SUAVE = Color("718075")
const LINHA = Color("c9cabb")
const VERDE = Color("304d3d")
const FOSFORO = Color("bdd2a3")
const AMBAR = Color("d2b477")

static func caixa(cor: Color, borda: Color = Color.TRANSPARENT, raio: int = 5, margem: int = 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.border_color = borda
	s.set_border_width_all(1 if borda.a > 0 else 0)
	s.set_corner_radius_all(raio)
	s.content_margin_left = margem
	s.content_margin_right = margem
	s.content_margin_top = margem
	s.content_margin_bottom = margem
	return s

static func criar() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/interface/fontes/interface.ttf")
	t.default_font_size = 14
	t.set_color("font_color","Label",TINTA)
	t.set_color("font_color","Button",TINTA)
	t.set_color("font_hover_color","Button",TINTA)
	t.set_color("font_pressed_color","Button",TINTA)
	t.set_color("font_disabled_color","Button",Color("91998c"))
	for nome in ["normal","hover","pressed"]: t.set_stylebox(nome,"Button",caixa(PAPEL,LINHA,4,10))
	t.set_stylebox("disabled","Button",caixa(Color("deded1"),Color("d4d5c7"),4,10))
	var foco := caixa(Color.TRANSPARENT,AMBAR,4,0)
	foco.set_border_width_all(2)
	t.set_stylebox("focus","Button",foco)
	t.set_stylebox("panel","PanelContainer",caixa(PAPEL,LINHA))
	t.set_stylebox("normal","OptionButton",caixa(PAPEL,LINHA,4,10))
	t.set_stylebox("hover","OptionButton",caixa(PAPEL,LINHA,4,10))
	t.set_color("font_color","OptionButton",TINTA)
	t.set_color("font_hover_color","OptionButton",TINTA)
	t.set_color("font_color","CheckButton",TINTA)
	t.set_color("font_hover_color","CheckButton",TINTA)
	t.set_stylebox("panel","PopupMenu",caixa(PAPEL,LINHA,4,10))
	t.set_color("font_color","PopupMenu",TINTA)
	t.set_stylebox("hover","PopupMenu",caixa(Color("d6dfc7"),Color.TRANSPARENT,3,4))
	t.set_constant("separation","VBoxContainer",12)
	t.set_constant("separation","HBoxContainer",12)
	return t

static func texto(pai: Node, valor: String, tamanho: int = 14, cor: Color = TINTA, mono: bool = false) -> Label:
	var l := Label.new()
	l.text = valor
	l.add_theme_font_size_override("font_size",tamanho)
	l.add_theme_color_override("font_color",cor)
	if mono: l.add_theme_font_override("font",load("res://assets/interface/fontes/terminal.ttf"))
	pai.add_child(l)
	return l

static func botao(pai: Node, valor: String, acao: Callable, primario: bool = false) -> Button:
	var b := Button.new()
	b.text = valor
	b.custom_minimum_size.y = 40
	b.pressed.connect(acao)
	if primario:
		for n in ["normal","hover","pressed"]: b.add_theme_stylebox_override(n,caixa(VERDE,VERDE,4,11))
		for n in ["font_color","font_hover_color","font_pressed_color"]: b.add_theme_color_override(n,PAPEL)
	pai.add_child(b)
	return b

static func imagem(pai: Node, tipo: String, altura: int = 110) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load("res://assets/objetos/gestao/"+tipo+"/icone.png")
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(90,altura)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pai.add_child(r)
	return r
