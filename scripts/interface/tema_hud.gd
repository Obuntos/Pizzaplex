class_name TemaHudPlex
extends RefCounted

const FUNDO = Color("19272c")
const PAPEL = Color("efe1bc")
const SUAVE = Color("b5b6a0")
const LINHA = Color("566361")
const AMBAR = Color("cfa760")
const MARROM = Color("6d4d33")
const AZUL = Color("344f65")
const VERDE = Color("3f624f")

static func caixa(cor: Color, borda: Color = LINHA, margem: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.border_color = borda
	s.set_border_width_all(2)
	s.content_margin_left = margem
	s.content_margin_right = margem
	s.content_margin_top = margem
	s.content_margin_bottom = margem
	s.shadow_color = Color(0.025,0.04,0.045,.5)
	s.shadow_size = 3
	s.shadow_offset = Vector2(3,3)
	return s

static func criar() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/interface/fontes/interface.ttf")
	t.default_font_size = 17
	t.set_color("font_color","Label",PAPEL)
	for tipo in ["Button","OptionButton","CheckButton","CheckBox"]:
		for propriedade in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: t.set_color(propriedade,tipo,PAPEL)
		for estado in ["normal","hover","pressed","disabled"]: t.set_stylebox(estado,tipo,caixa(Color("2c3d40") if estado=="hover" else FUNDO,AMBAR if estado=="pressed" else LINHA,8))
	t.set_stylebox("panel","PanelContainer",caixa(FUNDO))
	t.set_stylebox("panel","PopupMenu",caixa(FUNDO))
	t.set_stylebox("hover","PopupMenu",caixa(AZUL))
	t.set_color("font_color","PopupMenu",PAPEL)
	t.set_color("font_hover_color","PopupMenu",PAPEL)
	t.set_constant("separation","HBoxContainer",8)
	t.set_constant("separation","VBoxContainer",8)
	return t

static func texto(pai: Node, valor: String, tamanho: int = 18, cor: Color = PAPEL) -> Label:
	var l := Label.new()
	l.text = valor
	l.add_theme_font_size_override("font_size",tamanho)
	l.add_theme_color_override("font_color",cor)
	pai.add_child(l)
	return l

static func botao(pai: Node, valor: String, acao: Callable, cor: Color = FUNDO) -> Button:
	var b := Button.new()
	b.text = valor
	b.custom_minimum_size.y = 40
	for estado in ["normal","hover","pressed"]: b.add_theme_stylebox_override(estado,caixa(cor.lightened(.14) if estado=="hover" else cor,AMBAR if estado=="pressed" else LINHA,8))
	b.pressed.connect(acao)
	pai.add_child(b)
	return b
