class_name FicharioEstiloPlex
extends RefCounted

const AZUL=Color("1f58c4")
const PAPEL=Color("e8dcc0")
const TINTA=Color("1d1224")

static func caixa(cor: Color) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=cor;s.border_color=TINTA
	s.set_border_width_all(2)
	s.content_margin_left=8;s.content_margin_right=8;s.content_margin_top=4;s.content_margin_bottom=4
	return s

static func tema() -> Theme:
	var t:=Theme.new();t.default_font=load("res://assets/interface/fichario_pixel/letras.fnt");t.default_font_size=24
	t.set_color("font_color","Label",Color("e8f3ff"))
	for estado in ["normal","hover","pressed","disabled"]:
		t.set_stylebox(estado,"Button",caixa(PAPEL.darkened(.20) if estado=="pressed" else PAPEL))
		t.set_color("font_"+estado+"_color" if estado!="normal" else "font_color","Button",TINTA)
	t.set_color("font_focus_color","Button",TINTA);t.set_color("font_hover_color","Button",TINTA);t.set_color("font_disabled_color","Button",Color("617394"))
	return t

static func texto(pai: Node, valor: String, tamanho: int=24, cor: Color=Color("e8f3ff")) -> Label:
	var l:=Label.new();l.text=valor;l.add_theme_font_size_override("font_size",tamanho);l.add_theme_color_override("font_color",cor);pai.add_child(l);return l

static func botao(pai: Node, valor: String, acao: Callable, cor: Color=PAPEL) -> Button:
	var b:=Button.new();b.text=valor;b.custom_minimum_size.y=40;b.focus_mode=Control.FOCUS_NONE
	for estado in ["normal","hover","pressed","disabled"]:
		b.add_theme_stylebox_override(estado,caixa(cor.lightened(.10) if estado=="hover" else cor.darkened(.18) if estado=="pressed" else cor.darkened(.3) if estado=="disabled" else cor))
	b.pressed.connect(acao);pai.add_child(b);return b
