class_name ComandaDinerPlex
extends Control
## Comanda do botão direito: as opções de uma pessoa ou objeto num talão de
## lanchonete. Plaquinha vermelha com o nome (e a cabeça, se for alguém),
## barrado xadrez, uma linha por opção e a barra preta na que está sob o
## mouse. A base é picotada, como papel destacado.

const ALTURA_LINHA:=34.0
var largura:=248.0
var titulo:=""
var rosto:=DinerPlex.Silhueta.new()
var linhas:Array[Linha]=[]
var topo:=0.0

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

## Cria as linhas. `opcoes` traz texto, acao e cor; `executar` roda a ação.
func montar(opcoes:Array, executar:Callable, neutra:Color) -> void:
	var fonte:=VintagePlex.fonte("titulo")
	for o in opcoes:largura=maxf(largura,fonte.get_string_size(tr(str(o.texto)),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+76.0)
	largura=DinerPlex.par(minf(largura,400.0))
	for o in opcoes:
		var cor:Color=o.cor
		var l:=Linha.new(str(o.texto),DinerPlex.PRETO if cor.is_equal_approx(neutra) else cor.lightened(.25))
		l.pressed.connect(executar.bind(o.acao))
		add_child(l);linhas.append(l)
	add_child(rosto);rosto.hide()
	arrumar()

func definir_titulo(valor:String) -> void:
	if valor==titulo:return
	titulo=valor;arrumar()

func definir_rosto(textura:Texture2D) -> void:
	if rosto.figura.texture==textura:return
	rosto.mostrar(textura,64.0)
	arrumar()

func arrumar() -> void:
	var linhas_titulo:=0 if titulo.strip_edges().is_empty() else titulo.count("\n")+1
	topo=0.0 if linhas_titulo==0 else 22.0+linhas_titulo*18.0
	for i in linhas.size():
		linhas[i].position=Vector2(8,topo+16.0+i*ALTURA_LINHA)
		linhas[i].size=Vector2(largura-16.0,ALTURA_LINHA)
	size=Vector2(largura,topo+16.0+linhas.size()*ALTURA_LINHA+16.0)
	custom_minimum_size=size
	rosto.position=Vector2(-rosto.size.x*.55,-rosto.size.y*.45)
	queue_redraw()

## As linhas entram uma depois da outra, deslizando da esquerda.
func entrar() -> void:
	modulate.a=0.0
	var t:=create_tween().set_parallel(true)
	t.tween_property(self,"modulate:a",1.0,.08)
	for i in linhas.size():
		var destino:=linhas[i].position.x
		linhas[i].position.x=destino-18.0
		t.tween_property(linhas[i],"position:x",destino,.14).set_delay(i*.022).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if rosto.visible:
		rosto.scale=Vector2(.6,.6)
		t.tween_property(rosto,"scale",Vector2.ONE,.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var ci:=get_canvas_item()
	var corpo:=Rect2(0,0,largura,size.y-8.0)
	# sombra, contorno e papel
	ShowPlex.ret(ci,6,6,corpo.size.x,corpo.size.y,Color(0.07,0.03,0.02,.45))
	ShowPlex.bloco(ci,corpo.grow(4),DinerPlex.PRETO,4)
	ShowPlex.bloco(ci,corpo.grow(2),DinerPlex.VERMELHO,2)
	ShowPlex.ret(ci,corpo.position.x,corpo.position.y,corpo.size.x,corpo.size.y,DinerPlex.CREME)
	# base picotada
	var x:=0.0
	while x<largura:
		ShowPlex.ret(ci,x,corpo.end.y,8,4,DinerPlex.CREME)
		ShowPlex.ret(ci,x+2,corpo.end.y+4,4,4,DinerPlex.CREME)
		x+=16.0
	# plaquinha do nome
	if topo>0.0:
		ShowPlex.ret(ci,0,0,largura,topo,DinerPlex.VERMELHO)
		ShowPlex.ret(ci,4,4,largura-8,2,DinerPlex.AMARELO)
		ShowPlex.ret(ci,0,topo-2,largura,2,DinerPlex.PRETO)
		var fonte:=VintagePlex.fonte("titulo")
		var recuo:=rosto.size.x*.45+8.0 if rosto.visible else 0.0
		var partes:=titulo.split("\n")
		for i in partes.size():
			draw_string(fonte,Vector2(recuo+2,24.0+i*18.0+2.0),partes[i],HORIZONTAL_ALIGNMENT_CENTER,largura-recuo,15 if i==0 else 13,DinerPlex.SANGRIA)
			draw_string(fonte,Vector2(recuo,24.0+i*18.0),partes[i],HORIZONTAL_ALIGNMENT_CENTER,largura-recuo,15 if i==0 else 13,DinerPlex.CREME if i==0 else DinerPlex.AMARELO)
	# barrado xadrez
	DinerPlex.xadrez(ci,Rect2(0,topo,largura,8),8)
	ShowPlex.ret(ci,0,topo+8,largura,2,DinerPlex.PRETO)


## Linha da comanda: quadradinho da cor da ação e o texto. Sob o mouse,
## a barra preta inclinada toma a linha e o quadradinho acende.
class Linha extends Button:
	var rotulo:=""
	var marca:=DinerPlex.PRETO
	func _init(valor:String, cor:Color) -> void:
		rotulo=valor;marca=cor
		focus_mode=Control.FOCUS_NONE
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for estado in ["normal","hover","pressed","hover_pressed","disabled","focus"]:add_theme_stylebox_override(estado,StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
	func _draw() -> void:
		var ci:=get_canvas_item()
		var sobre:=is_hovered()
		var afunda:=2.0 if get_draw_mode()==DRAW_PRESSED or get_draw_mode()==DRAW_HOVER_PRESSED else 0.0
		if sobre:DinerPlex.barra(ci,Rect2(-4,3+afunda,size.x+8,size.y-6),DinerPlex.PRETO,10.0)
		var q:=Rect2(12,10+afunda,14,14)
		ShowPlex.ret(ci,q.position.x,q.position.y,q.size.x,q.size.y,DinerPlex.CREME if sobre else DinerPlex.PRETO)
		ShowPlex.ret(ci,q.position.x+2,q.position.y+2,q.size.x-4,q.size.y-4,DinerPlex.AMARELO if sobre else marca if marca!=DinerPlex.PRETO else DinerPlex.VERMELHO)
		draw_string(VintagePlex.fonte("titulo"),Vector2(36,23+afunda),tr(rotulo),HORIZONTAL_ALIGNMENT_LEFT,size.x-44.0,16,DinerPlex.CREME if sobre else DinerPlex.PRETO)
