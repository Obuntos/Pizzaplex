class_name FundoInicioPlex
extends Control
## Tela de abertura. A fachada do restaurante ocupa a tela inteira, em
## escala inteira e com um leve passeio de câmera; o título fica sobre o
## céu e o menu corre numa faixa escura embaixo, com as lâmpadas do
## letreiro acompanhando a opção escolhida.

signal acao_escolhida(acao: String)
const JANELA:=Vector2(290,104)
const OPCOES=[["novo","Novo jogo"],["carregar","Carregar"],["opcoes","Opções"],["creditos","Créditos"],["sair","Sair"]]
var palco:=Control.new()
var imagem:=TextureRect.new()
var atlas:=CatalogoPlex.atlas_vazio()
var botoes: Dictionary={}
var relogio:=0.0
var indice:=-1
var reduzido:=false
var nuvens: Array[Dictionary]=[]
var faixa:=Faixa.new()
var linha:=HBoxContainer.new()
var cursor:=LuzesShowPlex.new(true,18.0)
var titulo:=Titulo.new()
var dicas:=Label.new()
var fator:=3.0
var foco_atual:Button
var deslize:Tween
const NUVENS=[Vector4(185,48,5.5,0),Vector4(427,30,4.3,1),Vector4(594,71,6.2,2),Vector4(88,97,3.2,3),Vector4(344,105,2.4,4)]

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	add_child(palco);palco.size=Vector2(800,450);palco.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var ceu:=TextureRect.new();ceu.texture=load("res://assets/interface/inicio/revisao_2/ceu.png");ceu.size=Vector2(800,450);ceu.mouse_filter=Control.MOUSE_FILTER_IGNORE;palco.add_child(ceu)
	for dados in NUVENS:
		for copia in [-1,0,1]:
			var nuvem:=TextureRect.new();nuvem.texture=load("res://assets/interface/inicio/revisao_2/nuvem_"+str(int(dados.w))+".png");nuvem.size=Vector2(232,112);nuvem.mouse_filter=Control.MOUSE_FILTER_IGNORE;palco.add_child(nuvem)
			nuvens.append({"node":nuvem,"inicio":dados.x,"y":dados.y-20.0,"velocidade":dados.z,"copia":copia})
	atlas.atlas=load("res://assets/interface/inicio/revisao_2/cenario.png")
	atlas.region=Rect2(0,0,800,450)
	imagem.texture=atlas;imagem.size=Vector2(800,450);imagem.mouse_filter=Control.MOUSE_FILTER_IGNORE
	palco.add_child(imagem)
	add_child(titulo)
	add_child(faixa)
	add_child(linha);linha.add_theme_constant_override("separation",0)
	for i in OPCOES.size():
		var acao: String=OPCOES[i][0]
		var b:=Button.new();b.name=acao;b.text=str(OPCOES[i][1])
		b.add_theme_font_override("font",VintagePlex.fonte("titulo"));b.add_theme_font_size_override("font_size",28)
		b.add_theme_color_override("font_color",Color("f6e3b8"));b.add_theme_color_override("font_hover_color",Color("ffd75e"));b.add_theme_color_override("font_focus_color",Color("ffd75e"));b.add_theme_color_override("font_pressed_color",Color("ff9a6a"));b.add_theme_color_override("font_disabled_color",Color("7a6453"))
		b.add_theme_color_override("font_outline_color",Color("1d0e08"));b.add_theme_constant_override("outline_size",6)
		var vazio:=StyleBoxEmpty.new()
		for lado in [SIDE_LEFT,SIDE_RIGHT]:vazio.set_content_margin(lado,22)
		for lado in [SIDE_TOP,SIDE_BOTTOM]:vazio.set_content_margin(lado,10)
		for estado in ["normal","hover","pressed","focus","disabled","hover_pressed"]:b.add_theme_stylebox_override(estado,vazio)
		b.pressed.connect(func(): confirmar(b,acao))
		b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
		b.focus_entered.connect(func(): focar(b))
		linha.add_child(b);botoes[acao]=b
	add_child(cursor);cursor.ritmo=.16
	add_child(dicas)
	dicas.text="NAVEGAR: SETAS OU MOUSE   ·   CONFIRMAR: ENTER   ·   VOLTAR: ESC"
	dicas.add_theme_font_override("font",VintagePlex.fonte("forte"));dicas.add_theme_font_size_override("font_size",13)
	dicas.add_theme_color_override("font_color",Color("e88d9f"));dicas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(organizar);organizar();atualizar_nuvens()
	botoes.novo.grab_focus.call_deferred()

func organizar() -> void:
	# Escala inteira: a arte da fachada nunca fica com pixels desiguais.
	fator=maxf(2.0,ceilf(maxf(size.x/480.0,size.y/270.0)))
	palco.scale=Vector2.ONE*fator
	posicionar_palco()
	var base:=roundf(size.y*.66)
	faixa.position=Vector2(0,base);faixa.size=Vector2(size.x,roundf(size.y*.24))
	linha.reset_size()
	linha.position=Vector2(roundf(maxf(32.0,size.x*.05)),base+34.0)
	dicas.position=Vector2(linha.position.x+22.0,base+faixa.size.y-34.0)
	titulo.position=Vector2(roundf(maxf(32.0,size.x*.05)),roundf(size.y*.08))
	if is_instance_valid(foco_atual):focar.call_deferred(foco_atual,true)
	queue_redraw()

func posicionar_palco() -> void:
	var passeio:=0.0 if reduzido else sin(relogio*.18)*10.0
	var visivel:=size/fator
	var origem:=Vector2(JANELA.x+passeio+(455.0-visivel.x)*.5,JANELA.y+(256.0-visivel.y)*.6)
	origem.x=clampf(origem.x,286.0,800.0-visivel.x)
	origem.y=clampf(origem.y,0.0,450.0-visivel.y)
	palco.position=(-origem*fator).round()

## As lâmpadas deslizam até a opção em foco e a opção dá um pulinho.
func focar(b:Button, imediato:bool=false) -> void:
	foco_atual=b
	var destino:=Vector2(linha.position.x+b.position.x+18.0,linha.position.y+b.size.y+2.0)
	var largura:=Vector2(b.size.x-36.0,12.0)
	if deslize!=null and deslize.is_valid():deslize.kill()
	if imediato or reduzido or not cursor.visible or cursor.size.x<4.0:
		cursor.position=destino;cursor.size=largura;return
	deslize=create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	deslize.tween_property(cursor,"position",destino,.18)
	deslize.tween_property(cursor,"size",largura,.18)
	ShowPlex.pular(b,5.0)

func confirmar(b:Button, acao:String) -> void:
	if not reduzido and acao!="sair":ConfetePlex.sobre(b,24)
	acao_escolhida.emit(acao)

func _process(delta: float) -> void:
	if reduzido: return
	relogio+=delta
	atualizar_nuvens()
	posicionar_palco()
	var atual:=posmod(floori(relogio*4),32)
	if atual==indice: return
	indice=atual
	atlas.region=Rect2((indice%8)*800,floori(float(indice)/8)*450,800,450)

func atualizar_nuvens() -> void:
	for nuvem in nuvens:
		var x:=fposmod(float(nuvem.inicio)-relogio*float(nuvem.velocidade)+160.0,1040.0)-160.0
		nuvem.node.position=Vector2(roundf(x-28.0+float(nuvem.copia)*1040.0),float(nuvem.y))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("100a09"))

## Faixa do menu: tábua escura translúcida com barrado xadrez em cima.
class Faixa extends Control:
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		draw_rect(Rect2(0,0,size.x,size.y),Color(0.09,0.04,0.03,.84))
		draw_rect(Rect2(0,0,size.x,2),Color("1d0e08"))
		var x:=0.0
		var par:=true
		while x<size.x:
			draw_rect(Rect2(x,2,12,6),Color("8b2026") if par else Color("f6e3b8"))
			draw_rect(Rect2(x,8,12,6),Color("f6e3b8") if par else Color("8b2026"))
			x+=12.0;par=not par
		draw_rect(Rect2(0,14,size.x,2),Color("1d0e08"))
		draw_rect(Rect2(0,size.y-4,size.x,2),Color("e8b56a"))
		draw_rect(Rect2(0,size.y-2,size.x,2),Color("1d0e08"))

## Título em letras de letreiro, com sombra vinho e a etiqueta da versão.
class Titulo extends Control:
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size=Vector2(560,150)
	func _draw() -> void:
		var fonte:=VintagePlex.fonte("titulo")
		var nome:="PIZZAPLEX"
		draw_string(fonte,Vector2(6,92),nome,HORIZONTAL_ALIGNMENT_LEFT,-1,96,Color("1d0e08"))
		draw_string_outline(fonte,Vector2(0,86),nome,HORIZONTAL_ALIGNMENT_LEFT,-1,96,12,Color("1d0e08"))
		draw_string(fonte,Vector2(4,90),nome,HORIZONTAL_ALIGNMENT_LEFT,-1,96,Color("8b2026"))
		draw_string(fonte,Vector2(0,86),nome,HORIZONTAL_ALIGNMENT_LEFT,-1,96,Color("f6e3b8"))
		var versao:="[ "+str(ProjectSettings.get_setting("application/config/version","beta"))+" ]"
		var forte:=VintagePlex.fonte("titulo")
		draw_string_outline(forte,Vector2(6,128),versao,HORIZONTAL_ALIGNMENT_LEFT,-1,24,6,Color("1d0e08"))
		draw_string(forte,Vector2(6,128),versao,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("ffd75e"))
