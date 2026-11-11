class_name TemaIBMPlex
extends RefCounted

const VERDE=Color("a0bf9b")
const SUAVE=Color("708e70")
const FUNDO=Color("08110b")
const FONTE=preload("res://assets/interface/ibm/vt323.ttf")
static func fonte(espaco:int=0) -> Font:
	if espaco==0:return FONTE
	var f:=FontVariation.new();f.base_font=FONTE;f.spacing_glyph=espaco;return f
static func marcado(sim:bool) -> Texture2D:
	var im:=Image.create_empty(20,20,false,Image.FORMAT_RGBA8)
	for r in [Rect2i(0,0,20,2),Rect2i(0,18,20,2),Rect2i(0,0,2,20),Rect2i(18,0,2,20)]:im.fill_rect(r,VERDE)
	if sim:im.fill_rect(Rect2i(5,5,10,10),VERDE)
	return ImageTexture.create_from_image(im)
static func caixa(cor:Color=Color.TRANSPARENT,borda:Color=SUAVE,margem:int=12) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=cor;s.border_color=borda;s.set_border_width_all(2)
	for lado in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:s.set_content_margin(lado,margem)
	return s
static func criar() -> Theme:
	var t:=Theme.new();t.default_font=FONTE;t.default_font_size=24
	t.set_color("font_color","Label",VERDE)
	for tipo in ["Button","OptionButton","CheckBox"]:
		for estado in ["normal","hover","pressed","disabled"]:
			t.set_stylebox(estado,tipo,caixa(Color(VERDE,.07) if estado=="hover" else Color.TRANSPARENT,VERDE if estado in ["hover","pressed"] else SUAVE,10))
		for nome in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:t.set_color(nome,tipo,VERDE)
		t.set_color("font_disabled_color",tipo,SUAVE)
		t.set_stylebox("focus",tipo,caixa(Color.TRANSPARENT,VERDE,0))
	for tipo in ["VScrollBar","HScrollBar"]:
		t.set_stylebox("scroll",tipo,caixa(FUNDO,FUNDO,2))
		for estado in ["grabber","grabber_highlight","grabber_pressed"]:t.set_stylebox(estado,tipo,caixa(SUAVE,SUAVE,3))
	t.set_stylebox("panel","PopupMenu",caixa(FUNDO,SUAVE,8));t.set_stylebox("hover","PopupMenu",caixa(Color(VERDE,.12),VERDE,8));t.set_color("font_color","PopupMenu",VERDE)
	t.set_icon("arrow","OptionButton",VintagePlex.icone("baixo",VERDE))
	for nome in ["checked","checked_disabled"]:t.set_icon(nome,"CheckBox",marcado(true))
	for nome in ["unchecked","unchecked_disabled"]:t.set_icon(nome,"CheckBox",marcado(false))
	return t
static func texto(pai:Node,valor:String,tamanho:int=24,cor:Color=VERDE) -> Label:
	var l:=Label.new();l.text=valor;l.add_theme_color_override("font_color",cor);l.add_theme_font_size_override("font_size",tamanho);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;pai.add_child(l);return l
static func botao(pai:Node,valor:String,acao:Callable,cheio:bool=false) -> Button:
	var b:=Button.new();b.text=valor;b.add_theme_font_override("font",fonte(1));b.custom_minimum_size.y=44;b.pressed.connect(acao);pai.add_child(b)
	if cheio:
		for e in ["normal","hover","pressed"]:b.add_theme_stylebox_override(e,caixa(VERDE.lightened(.06) if e=="hover" else VERDE,VERDE,10))
		for n in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(n,FUNDO)
	return b
