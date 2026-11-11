class_name VintagePlex
extends RefCounted

const MADEIRA=Color("4f281a")
const ESCURO=Color("2a1408")
const PAPEL=Color("f1dcaa")
const CREME=Color("f6e3b8")
const VERMELHO=Color("7d1d22")
const SOMBRA=Color("3a0b10")
const OURO=Color("e8b56a")
const BORDA=Color("6b3f26")
static var fontes:Dictionary={}
static var icones:Dictionary={}

static func fonte(tipo:String="corpo") -> Font:
	var arquivo:String={"corpo":"courier_regular","forte":"courier_bold","titulo":"pixelify","botao":"oswald"}.get(tipo,"courier_regular")
	if not fontes.has(arquivo): fontes[arquivo]=load("res://assets/interface/vintage/"+arquivo+".ttf")
	return fontes[arquivo]

static func caixa(cor:Color, borda:Color=BORDA, margem:int=10) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=cor
	s.border_color=borda
	s.set_border_width_all(2)
	for lado in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: s.set_content_margin(lado,margem)
	return s

static func icone(tipo:String, cor:Color=CREME) -> Texture2D:
	var chave:=tipo+":"+cor.to_html()
	if icones.has(chave): return icones[chave]
	var im:=Image.create_empty(24,24,false,Image.FORMAT_RGBA8)
	var ret:=func(x:int,y:int,w:int,h:int): im.fill_rect(Rect2i(x,y,w,h),cor)
	match tipo:
		"masc","fem":
			for y in 24:
				for x in 24:
					var d:=Vector2(x-9,y-11).length_squared()
					if d>=20 and d<=40: im.set_pixel(x,y,cor)
			if tipo=="masc":
				for i in 8: ret.call(13+i,7-i,2,2)
				ret.call(15,0,8,2);ret.call(21,0,2,8)
			else:
				ret.call(8,16,3,8);ret.call(4,19,11,3)
		"salvar":
			ret.call(2,2,20,20)
			im.fill_rect(Rect2i(6,2,11,8),Color("f1d9a6"))
			im.fill_rect(Rect2i(13,3,3,5),cor)
			im.fill_rect(Rect2i(5,12,14,8),Color("f1d9a6"))
			im.fill_rect(Rect2i(7,15,9,1),cor);im.fill_rect(Rect2i(7,18,7,1),cor)
		"lixeira","lixeira_aberta":
			ret.call(9,0 if tipo=="lixeira_aberta" else 1,6,2);ret.call(3,2 if tipo=="lixeira_aberta" else 4,18,3)
			ret.call(6,9,2,13);ret.call(16,9,2,13);ret.call(6,20,12,2)
			ret.call(10,11,1,7);ret.call(13,11,1,7)
		"x":
			for i in 8: ret.call(4+i*2,4+i*2,2,2);ret.call(18-i*2,4+i*2,2,2)
		"seta_direita","seta_esquerda","baixo":
			for i in 7:
				if tipo=="baixo": ret.call(5+i,8+i,14-i*2,2)
				else: ret.call(7+i if tipo=="seta_direita" else 15-i,5+i,2,14-i*2)
		"marcado","desmarcado":
			ret.call(3,3,18,2);ret.call(3,19,18,2);ret.call(3,3,2,18);ret.call(19,3,2,18)
			if tipo=="marcado":
				for i in 5: ret.call(6+i,11+i,2,2)
				for i in 8: ret.call(10+i,15-i,2,2)
	icones[chave]=ImageTexture.create_from_image(im)
	return icones[chave]

static func preparar_botao(b:Button, cor:Color=MADEIRA, claro:bool=false) -> void:
	b.add_theme_font_override("font",fonte("botao"))
	b.add_theme_font_size_override("font_size",18)
	var tinta:=ESCURO if claro else CREME
	for estado in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(estado,tinta)
	for estado in ["normal","hover","pressed","hover_pressed","disabled"]:
		var fundo:=cor.lightened(.15) if estado=="hover" else cor.darkened(.18) if estado in ["pressed","hover_pressed","disabled"] else cor
		var s:=caixa(fundo,Color("3c1d10"),10)
		if estado=="hover":
			s.expand_margin_top=3
			s.border_color=Color("a66f3e")
		if estado in ["pressed","hover_pressed"]: s.content_margin_top=12;s.content_margin_bottom=8
		b.add_theme_stylebox_override(estado,s)
	var foco:=caixa(Color.TRANSPARENT,Color("c98a4b"),0)
	foco.set_border_width_all(1)
	b.add_theme_stylebox_override("focus",foco)
	b.tooltip_text=""

static func botao(pai:Node, texto:String, acao:Callable, cor:Color=MADEIRA, claro:bool=false) -> Button:
	var b:=Button.new()
	b.text=texto
	b.custom_minimum_size=Vector2(44,44)
	preparar_botao(b,cor,claro)
	b.pressed.connect(acao)
	pai.add_child(b)
	return b

static func recorte(cor:Color, borda_a:Color, borda_b:Color, estado:String) -> StyleBoxTexture:
	var im:=Image.create_empty(24,24,false,Image.FORMAT_RGBA8)
	im.fill_rect(Rect2i(0,8,24,8),borda_b);im.fill_rect(Rect2i(8,0,8,24),borda_b);im.fill_rect(Rect2i(4,4,16,16),borda_b)
	im.fill_rect(Rect2i(4,8,16,8),borda_a);im.fill_rect(Rect2i(8,4,8,16),borda_a)
	im.fill_rect(Rect2i(8,8,8,8),cor)
	var t:=StyleBoxTexture.new();t.texture=ImageTexture.create_from_image(im)
	for lado in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		t.set_texture_margin(lado,8);t.set_expand_margin(lado,8);t.set_content_margin(lado,10)
	if estado=="hover": t.expand_margin_top+=3;t.expand_margin_bottom-=3
	if estado in ["pressed","hover_pressed"]: t.content_margin_top=12;t.content_margin_bottom=8
	return t

static func preparar_pixel(b:Button, cor:Color, a:Color, fundo:Color, claro:bool=false) -> void:
	preparar_botao(b,cor,claro)
	for estado in ["normal","hover","pressed","hover_pressed","disabled"]:
		var tinta:=cor.lightened(.18) if estado=="hover" else cor.darkened(.22) if estado in ["pressed","hover_pressed","disabled"] else cor
		b.add_theme_stylebox_override(estado,recorte(tinta,a,fundo,estado))
