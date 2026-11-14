class_name KitPlex
extends RefCounted
## Peças de interface em pixel art compartilhadas pelo HUD e pelas janelas.
## Tudo é gerado numa grade de U px de tela: contornos, cantos em degrau,
## frisos e lábios dos botões têm sempre a mesma espessura, em qualquer tamanho.

const U:=2
const TINTA=Color("1d0e08")
const NOITE=Color("30211d")
const MADEIRA=Color("4f281a")
const MADEIRA_CLARA=Color("6b3f26")
const LINHA=Color("896147")
const CREME=Color("f1dcaa")
const PAPEL=Color("f6e3b8")
const AREIA=Color("bda380")
const AMBAR=Color("dfb16a")
const OURO=Color("e8a237")
const VINHO=Color("7d1d22")
const VERDE=Color("4b5c3d")
const VERDE_LUZ=Color("b8da9c")
const VARIANTES={
	"madeira":{"face":Color("5a3320"),"texto":CREME},
	"ouro":{"face":OURO,"texto":Color("2a1408")},
	"verde":{"face":Color("4f6a3f"),"texto":CREME},
	"vinho":{"face":Color("8b2026"),"texto":CREME},
	"creme":{"face":CREME,"texto":Color("2a1408")},
	"noite":{"face":Color("3b2a25"),"texto":CREME}
}
static var cache:Dictionary={}

## Gera uma moldura 9-patch. `aneis` lista as cores de fora para dentro; o
## canto recua `canto` unidades em degraus. `labio` cria a base saliente dos
## botões e `afundado` desenha a face já encostada nela (estado pressionado).
static func quadro(aneis:Array, fundo:Color, canto:int=1, margem:int=10, labio:int=0, cor_labio:Color=TINTA, afundado:bool=false, projetada:int=0, luz:Color=Color.TRANSPARENT) -> StyleBoxTexture:
	var chave:=str([aneis,fundo,canto,margem,labio,cor_labio,afundado,projetada,luz])
	if cache.has(chave):return cache[chave]
	var borda:int=maxi(aneis.size(),canto+1)+1
	var lado:=borda*2+2
	var extra:=labio+projetada
	var im:=Image.create_empty(lado*U,(lado+extra)*U,false,Image.FORMAT_RGBA8)
	var pintar:=func(desloc:int, cores:Array, miolo:Color, brilho:Color):
		for y in lado:
			for x in lado:
				var cx:=mini(x,lado-1-x);var cy:=mini(y,lado-1-y)
				if cx+cy<canto:continue
				var anel:=mini(mini(cx,cy),cx+cy-canto)
				var cor:Color=cores[anel] if anel<cores.size() else miolo
				if brilho.a>0 and anel==cores.size() and y==cores.size():cor=brilho
				if cor.a<=0:continue
				im.fill_rect(Rect2i(x*U,(y+desloc)*U,U,U),cor)
	if projetada>0:pintar.call(labio+projetada,[Color(0.07,0.03,0.02,.45)],Color(0.07,0.03,0.02,.45),Color.TRANSPARENT)
	if labio>0:pintar.call(labio,[aneis[0]],cor_labio,Color.TRANSPARENT)
	pintar.call(labio if afundado else 0,aneis,fundo,luz)
	var s:=StyleBoxTexture.new()
	s.texture=ImageTexture.create_from_image(im)
	var afunda:=labio if afundado else 0
	for l in [SIDE_LEFT,SIDE_RIGHT]:s.set_texture_margin(l,borda*U)
	s.set_texture_margin(SIDE_TOP,(borda+afunda)*U)
	s.set_texture_margin(SIDE_BOTTOM,(borda+extra-afunda)*U)
	for l in [SIDE_LEFT,SIDE_RIGHT]:s.set_content_margin(l,margem)
	s.set_content_margin(SIDE_TOP,margem+(labio*U if afundado else 0))
	s.set_content_margin(SIDE_BOTTOM,margem+(0 if afundado else labio*U))
	if projetada>0:s.expand_margin_bottom=projetada*U
	cache[chave]=s
	return s

## Molduras nomeadas. Cada uma corresponde a um material das telas prontas.
static func moldura(tipo:String="hud", margem:int=-1) -> StyleBoxTexture:
	match tipo:
		"hud":return quadro([TINTA,LINHA],NOITE,1,10 if margem<0 else margem,0,TINTA,false,1,Color("3d2b25"))
		"hud_ativo":return quadro([TINTA,AMBAR],NOITE,1,10 if margem<0 else margem,0,TINTA,false,1,Color("3d2b25"))
		"hud_alerta":return quadro([TINTA,Color("a97565")],NOITE,1,10 if margem<0 else margem,0,TINTA,false,1,Color("3d2b25"))
		"janela":return quadro([Color("150803"),MADEIRA_CLARA,Color("2a140c")],MADEIRA,2,18 if margem<0 else margem,0,TINTA,false,2,Color("5d3120"))
		"papel":return quadro([Color("2a1408"),Color("b8955e")],CREME,1,14 if margem<0 else margem,0,TINTA,false,0,PAPEL)
		"papel_ativo":return quadro([Color("7a4a10"),Color("f0a92a")],PAPEL,1,14 if margem<0 else margem,0,TINTA,false,0,Color("fff4d6"))
		"janela_escura":return quadro([Color("150803"),MADEIRA_CLARA,Color("2a140c")],NOITE,2,18 if margem<0 else margem,0,TINTA,false,2,Color("3d2b25"))
		"placa":return quadro([Color("2a0a0c"),VINHO,Color("c98a4b")],VINHO,2,12 if margem<0 else margem,0,TINTA,false,0,Color.TRANSPARENT)
		"campo":return quadro([TINTA,Color("150a05")],Color("28160e"),1,8 if margem<0 else margem)
		"campo_foco":return quadro([TINTA,Color("c98a4b")],Color("382013"),1,8 if margem<0 else margem)
		"visor":return quadro([TINTA],Color("20150f"),1,8 if margem<0 else margem,0,TINTA,false,0,Color("5f432f"))
		"etiqueta":return quadro([Color("2a1408")],Color("e6cf9c"),1,6 if margem<0 else margem)
		"contorno_ouro":return quadro([Color("f0c060")],Color.TRANSPARENT,1,0)
		"terminal":return quadro([Color("0b1410"),Color("779889")],Color("192923"),1,10 if margem<0 else margem,0,TINTA,false,1)
	return moldura("hud",margem)

## Estados de um botão com face `cor`: normal com lábio, hover com friso
## dourado, pressionado afundado e desabilitado apagado.
static func estado_botao(cor:Color, estado:String, margem:int=10, labio:int=2) -> StyleBoxTexture:
	var face:=cor
	var friso:=cor.lightened(.2)
	var base:=cor.darkened(.45)
	match estado:
		"hover":face=cor.lightened(.1);friso=Color("f0c060")
		"pressed","hover_pressed":face=cor.darkened(.16);friso=cor.darkened(.02)
		"disabled":
			var cinza:=cor.get_luminance()
			face=cor.lerp(Color(cinza,cinza,cinza),.55).darkened(.18);friso=face.lightened(.08);base=face.darkened(.4)
	return quadro([TINTA,friso],face,1,margem,labio,base,estado in ["pressed","hover_pressed"])

static func preparar_botao(b:Button, cor:Color=Color("5a3320"), claro:bool=false, margem:int=10, labio:int=2) -> void:
	for estado in ["normal","hover","pressed","hover_pressed","disabled"]:
		b.add_theme_stylebox_override(estado,estado_botao(cor,estado,margem,labio))
	var foco:=moldura("contorno_ouro")
	b.add_theme_stylebox_override("focus",foco)
	var tinta:=Color("2a1408") if claro else CREME
	for nome in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:b.add_theme_color_override(nome,tinta)
	b.add_theme_color_override("font_disabled_color",tinta.lerp(cor,.55) if claro else Color("a08a72"))

## Botão com variante nomeada: ouro para a ação principal, verde para ligar,
## vinho para destruir, madeira para o restante.
static func botao(pai:Node, rotulo:String, acao:Callable, variante:String="madeira", tamanho:int=16) -> Button:
	var v:Dictionary=VARIANTES.get(variante,VARIANTES.madeira)
	var b:=Button.new()
	b.text=rotulo
	b.custom_minimum_size=Vector2(44,40)
	b.add_theme_font_override("font",VintagePlex.fonte("botao"))
	b.add_theme_font_size_override("font_size",tamanho)
	preparar_botao(b,v.face,v.texto.get_luminance()<.4)
	b.pressed.connect(acao)
	pai.add_child(b)
	return b

## Botão sem face: só o texto, para ações terciárias como Fechar.
static func botao_discreto(pai:Node, rotulo:String, acao:Callable, tamanho:int=15) -> Button:
	var b:=Button.new()
	b.text=rotulo
	b.custom_minimum_size=Vector2(44,40)
	b.add_theme_font_override("font",VintagePlex.fonte("botao"))
	b.add_theme_font_size_override("font_size",tamanho)
	var vazio:=quadro([Color.TRANSPARENT],Color.TRANSPARENT,1,10,2,Color.TRANSPARENT)
	b.add_theme_stylebox_override("normal",vazio)
	b.add_theme_stylebox_override("disabled",vazio)
	b.add_theme_stylebox_override("hover",quadro([LINHA],Color(1,1,1,.06),1,10,2,Color.TRANSPARENT))
	for estado in ["pressed","hover_pressed"]:b.add_theme_stylebox_override(estado,quadro([LINHA],Color(0,0,0,.2),1,10,2,Color.TRANSPARENT,true))
	b.add_theme_stylebox_override("focus",moldura("contorno_ouro"))
	b.add_theme_color_override("font_color",AREIA)
	for nome in ["font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:b.add_theme_color_override(nome,CREME)
	b.pressed.connect(acao)
	pai.add_child(b)
	return b

## Botão quadrado de fechar, igual ao das telas de partida.
static func fechar(pai:Node, acao:Callable) -> Button:
	var b:=botao(pai,"",acao,"vinho")
	b.icon=VintagePlex.icone("x")
	b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size=Vector2(40,40)
	b.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	b.tooltip_text=""
	return b

## Seta de seletor. A direção fica no desenho, não em um caractere de fonte.
static func seta(pai:Node, direcao:int, acao:Callable) -> Button:
	var b:=botao(pai,"",acao,"madeira")
	b.icon=VintagePlex.icone("seta_direita" if direcao>0 else "seta_esquerda")
	b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size=Vector2(40,40)
	b.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	return b

## Seletor de valor: os dois botões abraçam o campo, formando uma peça só,
## para ficar claro o que cada seta altera. Numérico usa − e +.
static func seletor(pai:Node, anterior:Callable, seguinte:Callable, numerico:bool=false) -> Dictionary:
	var linha:=HBoxContainer.new()
	linha.add_theme_constant_override("separation",0)
	linha.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	pai.add_child(linha)
	var menos:=seta(linha,-1,anterior)
	var campo:=painel(linha,"campo",6)
	campo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	campo.custom_minimum_size.y=40
	campo.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var valor:=texto(campo,"",16,CREME,"forte")
	valor.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	valor.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	valor.clip_text=true
	var mais:=seta(linha,1,seguinte)
	if numerico:
		menos.icon=VintagePlex.icone("menos");mais.icon=VintagePlex.icone("mais")
	return {"linha":linha,"menos":menos,"mais":mais,"valor":valor}

static func texto(pai:Node, valor:String, tamanho:int=15, cor:Color=CREME, fonte:String="corpo") -> Label:
	var l:=Label.new()
	l.text=valor
	l.add_theme_font_override("font",VintagePlex.fonte(fonte))
	l.add_theme_font_size_override("font_size",tamanho)
	l.add_theme_color_override("font_color",cor)
	pai.add_child(l)
	return l

## Rótulo de seção: caixa alta miúda, com um fio que ocupa o resto da linha.
static func secao(pai:Node, valor:String, cor:Color=AREIA, fio:Color=Color("6b4a36")) -> HBoxContainer:
	var linha:=HBoxContainer.new()
	linha.add_theme_constant_override("separation",8)
	pai.add_child(linha)
	var l:=texto(linha,valor,12,cor,"forte")
	l.uppercase=true
	var traco:=ColorRect.new()
	traco.color=fio
	traco.custom_minimum_size=Vector2(8,U)
	traco.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	traco.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	traco.mouse_filter=Control.MOUSE_FILTER_IGNORE
	linha.add_child(traco)
	return linha

## Placa vinho de título, com losangos nas pontas como em Carregar partida.
static func placa(pai:Node, valor:String, tamanho:int=20) -> PanelContainer:
	var p:=PanelContainer.new()
	p.add_theme_stylebox_override("panel",moldura("placa"))
	p.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	pai.add_child(p)
	var l:=texto(p,valor,tamanho,Color("f3c46f"),"titulo")
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	l.uppercase=true
	l.name="Titulo"
	return p

## Cabeçalho de janela: placa de título que serve de alça de arrasto e o
## botão de fechar ao lado.
static func cabecalho(pai:Node, valor:String, ao_fechar:Callable=Callable()) -> HBoxContainer:
	var linha:=HBoxContainer.new()
	linha.add_theme_constant_override("separation",8)
	pai.add_child(linha)
	placa(linha,valor)
	if ao_fechar.is_valid():fechar(linha,ao_fechar)
	return linha

static func painel(pai:Node, tipo:String="hud", margem:int=-1) -> PanelContainer:
	var p:=PanelContainer.new()
	p.add_theme_stylebox_override("panel",moldura(tipo,margem))
	p.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	pai.add_child(p)
	return p

## Ícone ilustrado de 48 px, sempre em escala inteira.
static func icone(pai:Node, caminho:String, lado:int=48) -> TextureRect:
	var r:=TextureRect.new()
	r.texture=load(caminho)
	r.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode=TextureRect.STRETCH_KEEP_CENTERED
	r.custom_minimum_size=Vector2(lado,lado)
	r.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pai.add_child(r)
	return r

## Pulso curto para confirmar uma troca de valor sem mover o texto.
static func piscar(alvo:CanvasItem, cor:Color=Color(1.35,1.25,1.0)) -> void:
	if not is_instance_valid(alvo) or not alvo.is_inside_tree():return
	alvo.modulate=cor
	alvo.create_tween().tween_property(alvo,"modulate",Color.WHITE,.18)
