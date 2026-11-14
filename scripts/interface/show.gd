class_name ShowPlex
extends RefCounted
## Kit de show: as peças de palco da interface. Madeira com veios, placas
## penduradas, cortina, tampas de metal, ornamentos e lâmpadas de letreiro,
## pintados pixel a pixel numa grade de 2 px. Como tudo é desenhado no
## tamanho exato do controle, nada estica nem borra.

const U:=2
const TINTA=Color("1d0e08")
const MADEIRA=Color("8a5a38")
const MADEIRA_ESCURA=Color("5a3320")
const MADEIRA_CLARA=Color("a5713f")
const CREME=Color("f6e3b8")
const PAPEL=Color("f1dcaa")
const SEPIA=Color("8a5a38")
const NANQUIM=Color("4a2318")
const OURO=Color("e8a237")
const AMBAR=Color("f3c46f")
const VINHO=Color("8b2026")
const VERDE=Color("4f6a3f")
const METAL=Color("8fa3a8")
const FESTA=[Color("c94a44"),Color("e8a237"),Color("f6e3b8"),Color("8fb072"),Color("7eb5bd"),Color("e88d9f")]
static var estilos:Dictionary={}

static func ret(ci:RID, x:float, y:float, w:float, h:float, cor:Color) -> void:
	if w>0 and h>0:RenderingServer.canvas_item_add_rect(ci,Rect2(x,y,w,h),cor)

## Valor estável entre 0 e 1 para um ponto: dá os veios sem sorteio.
static func ruido(x:int, y:int, semente:int=0) -> float:
	return float(hash(Vector3i(x,y,semente))&0xffff)/65535.0

## Retângulo com os cantos recuados em degraus.
static func bloco(ci:RID, r:Rect2, cor:Color, canto:int=U) -> void:
	var n:=int(float(canto)/U)
	for i in n:
		var d:=float((n-i)*U)
		ret(ci,r.position.x+d,r.position.y+i*U,r.size.x-d*2,U,cor)
		ret(ci,r.position.x+d,r.end.y-(i+1)*U,r.size.x-d*2,U,cor)
	ret(ci,r.position.x,r.position.y+canto,r.size.x,r.size.y-canto*2,cor)

## Madeira: luz no topo, sombra na base e veios curtos. Com `tabua`, divide
## em tábuas dessa altura.
static func madeira(ci:RID, r:Rect2, base:Color=MADEIRA, tabua:int=0, semente:int=0) -> void:
	ret(ci,r.position.x,r.position.y,r.size.x,r.size.y,base)
	var escura:=base.darkened(.16);var clara:=base.lightened(.12)
	var y:=int(r.position.y)+U*2
	while y<r.end.y-U*2:
		var x:=int(r.position.x)+U+int(ruido(0,y,semente)*12.0)*U
		while x<r.end.x-U*3:
			var n:=ruido(x,y,semente)
			var comp:=U*(3+int(n*7.0))
			if n>.3:ret(ci,x,y,minf(comp,r.end.x-U*2-x),U,escura if n<.82 else clara)
			x+=comp+U*(3+int(ruido(x+5,y,semente)*9.0))
		y+=U*3
	if tabua>0:
		var corte:=int(r.position.y)+tabua
		while corte<r.end.y-U*2:
			ret(ci,r.position.x,corte,r.size.x,U,base.darkened(.42))
			ret(ci,r.position.x,corte+U,r.size.x,U,clara)
			corte+=tabua
	ret(ci,r.position.x,r.position.y,r.size.x,U,base.lightened(.2))
	ret(ci,r.position.x,r.end.y-U,r.size.x,U,base.darkened(.3))

## Tampa de metal das pontas, com dois rebites.
static func tampa(ci:RID, r:Rect2) -> void:
	ret(ci,r.position.x,r.position.y,r.size.x,r.size.y,METAL)
	ret(ci,r.position.x,r.position.y,U,r.size.y,Color("c9d6d4"))
	ret(ci,r.end.x-U,r.position.y,U,r.size.y,Color("5f7278"))
	ret(ci,r.position.x,r.end.y-U,r.size.x,U,Color("5f7278"))
	for y in [r.position.y+U*2,r.end.y-U*4]:
		var x:=r.position.x+roundf((r.size.x-U*2)*.25)*2.0-U
		ret(ci,x,y,U*2,U*2,Color("4a5a60"));ret(ci,x,y,U,U,Color("dfe8e4"))

## Placa: moldura de madeira com a folha creme por dentro.
static func placa(ci:RID, r:Rect2, moldura:Color=MADEIRA, folha:Color=CREME, semente:int=0) -> void:
	bloco(ci,r,TINTA,U*2)
	bloco(ci,r.grow(-U),moldura,U*2)
	ret(ci,r.position.x+U*3,r.position.y+U,r.size.x-U*6,U,moldura.lightened(.22))
	ret(ci,r.position.x+U*3,r.end.y-U*2,r.size.x-U*6,U,moldura.darkened(.28))
	# veios curtos na moldura
	var x:=int(r.position.x)+U*6
	while x<r.end.x-U*10:
		if ruido(x,int(r.position.y),semente)>.45:ret(ci,x,r.position.y+U*2,U*4,U,moldura.darkened(.16))
		if ruido(x,int(r.end.y),semente)>.45:ret(ci,x,r.end.y-U*3,U*3,U,moldura.lightened(.1))
		x+=U*9
	bloco(ci,r.grow(-U*4),moldura.darkened(.5),U)
	bloco(ci,r.grow(-U*5),folha,U)
	# desgaste suave da folha nas bordas
	var d:=r.grow(-U*5)
	ret(ci,d.position.x+U,d.end.y-U,d.size.x-U*2,U,folha.darkened(.1))
	ret(ci,d.position.x+U,d.position.y,d.size.x-U*2,U,folha.lightened(.3))
	ret(ci,d.end.x-U,d.position.y+U,U,d.size.y-U*2,folha.darkened(.06))
	# pregos nos cantos da moldura
	for p in [Vector2(r.position.x+U*2,r.position.y+U*2),Vector2(r.end.x-U*3,r.position.y+U*2),Vector2(r.position.x+U*2,r.end.y-U*3),Vector2(r.end.x-U*3,r.end.y-U*3)]:
		ret(ci,p.x,p.y,U,U,moldura.lightened(.4))

## Painel de madeira. Com `tampas`, ganha as pontas de metal.
static func painel(ci:RID, r:Rect2, base:Color=MADEIRA, tampas:bool=false, tabua:int=0, semente:int=0) -> void:
	bloco(ci,r,TINTA,U)
	var d:=r.grow(-U)
	madeira(ci,d,base,tabua,semente)
	if tampas and r.size.x>U*20:
		var largura:=float(U*5)
		tampa(ci,Rect2(d.position.x,d.position.y,largura,d.size.y))
		tampa(ci,Rect2(d.end.x-largura,d.position.y,largura,d.size.y))
		ret(ci,d.position.x+largura,d.position.y,U,d.size.y,TINTA)
		ret(ci,d.end.x-largura-U,d.position.y,U,d.size.y,TINTA)

## Cortina de palco: trilho de madeira, pano em pregas com a barra em
## ondas e franja dourada. `caida` desce as pontas, como numa boca de cena.
static func cortina(ci:RID, r:Rect2, cor:Color=VINHO, caida:float=0.0) -> void:
	var trilho:=float(U*3)
	var tons:=[cor.darkened(.28),cor,cor.lightened(.14),cor,cor.darkened(.12),cor.darkened(.28)]
	var ondas:=[0,1,2,2,1,0]
	var coluna:=0
	var x:=r.position.x
	var altura:=r.size.y-trilho-U*4
	while x<r.end.x:
		var largura:=minf(U*3,r.end.x-x)
		var i:=coluna%6
		var desce:=float(ondas[i]*U)
		var borda:=minf(x-r.position.x,r.end.x-x-largura)
		var extra:=caida*clampf(1.0-borda/(U*18.0),0.0,1.0)
		extra=snappedf(extra,U)
		var h:=altura+desce+extra
		ret(ci,x,r.position.y+trilho,largura,h,tons[i])
		ret(ci,x,r.position.y+trilho+h,largura,U,Color("e8b56a"))
		ret(ci,x,r.position.y+trilho+h+U,largura,U,TINTA)
		x+=largura;coluna+=1
	ret(ci,r.position.x,r.position.y+trilho,r.size.x,U,cor.darkened(.45))
	bloco(ci,Rect2(r.position.x,r.position.y,r.size.x,trilho+U),TINTA,U)
	madeira(ci,Rect2(r.position.x+U,r.position.y+U,r.size.x-U*2,trilho-U),MADEIRA_ESCURA)

## Disco em degraus de pixel, para medalhões e contadores.
static func disco(ci:RID, c:Vector2, raio:float, cor:Color) -> void:
	var y:=-raio
	while y<raio:
		var meio:=y+U*.5
		var metade:=snappedf(sqrt(maxf(0.0,raio*raio-meio*meio)),U)
		ret(ci,c.x-metade,c.y+y,metade*2.0,U,cor)
		y+=U

## Medalhão: aro de madeira com miolo claro, onde entra um ícone.
static func medalhao(ci:RID, c:Vector2, raio:float, moldura:Color=MADEIRA, folha:Color=CREME) -> void:
	disco(ci,c,raio,TINTA)
	disco(ci,c,raio-U,moldura)
	disco(ci,Vector2(c.x,c.y-U),raio-U*2,moldura.lightened(.14))
	disco(ci,c,raio-U*2,moldura)
	disco(ci,c,raio-U*4,moldura.darkened(.5))
	disco(ci,c,raio-U*5,folha)

## Corrente curta que segura as placas penduradas.
static func corrente(ci:RID, x:float, y0:float, y1:float) -> void:
	var y:=y0
	var par:=true
	while y<y1:
		ret(ci,x-U,y,U*3,U*2,TINTA)
		ret(ci,x,y,U,U*2,Color("c9d6d4") if par else Color("8fa3a8"))
		y+=U*2;par=not par

const VOLUTA=[".####......","#....#.....","#.##..#....","#.#.#.#....","#..##.#####",".#....#....","..####....."]
## Voluta de canto, como nas carteirinhas. Espelha conforme o canto.
static func voluta(ci:RID, p:Vector2, cor:Color=NANQUIM, espelho_x:bool=false, espelho_y:bool=false) -> void:
	for j in VOLUTA.size():
		var linha:String=VOLUTA[VOLUTA.size()-1-j] if espelho_y else VOLUTA[j]
		for i in linha.length():
			var c:=linha[linha.length()-1-i] if espelho_x else linha[i]
			if c=="#":ret(ci,p.x+i*U,p.y+j*U,U,U,cor)

## Lâmpada de letreiro, 10 px. Acesa tem halo; apagada fica âmbar escuro.
static func lampada(ci:RID, c:Vector2, acesa:bool, cor:Color=Color("ffe9a8")) -> void:
	var x:=roundf(c.x*.5)*2.0-5.0;var y:=roundf(c.y*.5)*2.0-5.0
	if acesa:
		ret(ci,x-U*2,y-U,U*9,U*7,Color(cor.r,cor.g,cor.b,.16))
		ret(ci,x-U,y-U*2,U*7,U*9,Color(cor.r,cor.g,cor.b,.16))
	bloco(ci,Rect2(x,y,U*5,U*5),TINTA,U)
	bloco(ci,Rect2(x+U,y+U,U*3,U*3),cor if acesa else Color("7a5a34"),0)
	ret(ci,x+U,y+U,U,U,Color.WHITE if acesa else Color("a07a48"))
	if acesa:ret(ci,x+U*3,y+U*3,U,U,cor.darkened(.18))

## Estilo pronto para painéis e botões. Fica em cache por parâmetros.
static func estilo(tipo:String, margem:int=12, cor:Color=MADEIRA, opcoes:Dictionary={}) -> EstiloShowPlex:
	var chave:=str([tipo,margem,cor,opcoes])
	if estilos.has(chave):return estilos[chave]
	var e:=EstiloShowPlex.new()
	e.tipo=tipo;e.cor=cor
	e.tampas=bool(opcoes.get("tampas",false));e.tabua=int(opcoes.get("tabua",0))
	e.afundado=bool(opcoes.get("afundado",false));e.labio=int(opcoes.get("labio",0))
	e.folha=opcoes.get("folha",CREME);e.volutas=bool(opcoes.get("volutas",false))
	e.semente=int(opcoes.get("semente",0))
	for l in [SIDE_LEFT,SIDE_RIGHT]:e.set_content_margin(l,margem+(U*5 if e.tampas else 0))
	e.set_content_margin(SIDE_TOP,margem+(e.labio if e.afundado else 0))
	e.set_content_margin(SIDE_BOTTOM,margem+(0 if e.afundado else e.labio))
	estilos[chave]=e
	return e

## Botão de madeira com tampas de metal: sobe um tom no hover, afunda no
## clique e vira placa creme quando marcado.
static func botao_madeira(b:Button, cor:Color=MADEIRA, margem:int=8, tampas:bool=true) -> void:
	b.add_theme_stylebox_override("normal",estilo("painel",margem,cor,{"tampas":tampas,"labio":4}))
	b.add_theme_stylebox_override("hover",estilo("painel",margem,cor.lightened(.14),{"tampas":tampas,"labio":4}))
	b.add_theme_stylebox_override("disabled",estilo("painel",margem,cor.darkened(.3).lerp(Color("5a5048"),.5),{"tampas":tampas,"labio":4}))
	for nome in ["pressed","hover_pressed"]:b.add_theme_stylebox_override(nome,estilo("painel",margem,cor.darkened(.14),{"tampas":tampas,"labio":4,"afundado":true}))
	b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	for nome in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:b.add_theme_color_override(nome,CREME)
	b.add_theme_color_override("font_disabled_color",Color("b8a58c"))
	b.add_theme_color_override("font_outline_color",TINTA);b.add_theme_constant_override("outline_size",4)

## Marca um botão de madeira como escolhido: placa creme, afundada.
static func marcar(b:Button, ligado:bool, cor:Color=MADEIRA, margem:int=8, tampas:bool=true) -> void:
	botao_madeira(b,cor,margem,tampas)
	if not ligado:return
	var s:=estilo("placa",margem+2,cor,{"labio":4,"afundado":true})
	for nome in ["normal","hover","pressed","hover_pressed"]:b.add_theme_stylebox_override(nome,s)
	for nome in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:b.add_theme_color_override(nome,NANQUIM)
	b.add_theme_constant_override("outline_size",0)

## Pequeno salto para dar resposta a um clique ou troca.
static func pular(alvo:Control, altura:float=6.0) -> void:
	if not is_instance_valid(alvo) or not alvo.is_inside_tree():return
	if alvo.has_meta("pulo") and (alvo.get_meta("pulo") as Tween).is_valid():return
	var origem:=alvo.position.y
	var t:=alvo.create_tween()
	alvo.set_meta("pulo",t)
	t.tween_property(alvo,"position:y",origem-altura,.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(alvo,"position:y",origem,.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

## Entrada de janela: sobe alguns pixels enquanto aparece.
static func entrar(alvo:Control) -> void:
	if not is_instance_valid(alvo) or not alvo.is_inside_tree():return
	alvo.modulate.a=0.0
	var t:=alvo.create_tween().set_parallel(true)
	t.tween_property(alvo,"modulate:a",1.0,.12)
	t.tween_property(alvo,"position:y",alvo.position.y,.16).from(alvo.position.y+10.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
