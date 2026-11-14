class_name SaldoHudPlex
extends Control
## Placa do caixa: medalhão com a cédula preso a uma tábua com o visor de
## dígitos. O valor rola até o novo total, a placa dá um pulinho e, quando
## entra dinheiro, o ganho sobe flutuando e soltam-se moedinhas de confete.

const ALTURA:=56.0
var valor:=0.0
var mostrado:=0.0
var iniciado:=false
var numero:=NumeroPixelPlex.new("$ 0.00",3,Color("f3c46f"))
var icone:=TextureRect.new()
var rolagem:Tween
var tinta:=Color("f3c46f")

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text="Disponível no caixa"
	icone.texture=load("res://assets/interface/hud/dinheiro.png")
	icone.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	icone.mouse_filter=Control.MOUSE_FILTER_IGNORE
	icone.position=Vector2(12,12);icone.size=Vector2(32,32)
	add_child(icone)
	numero.apagado=Color("2c1d15")
	add_child(numero)
	medir()

func medir() -> void:
	# O visor reserva espaço para cinco dígitos e cresce com valores maiores.
	var largura:=maxf(numero.largura(),150.0)
	custom_minimum_size=Vector2(70.0+largura+30.0,ALTURA)
	size=custom_minimum_size
	numero.position=Vector2(70,18);numero.size=Vector2(largura,21)
	queue_redraw()

func escrever(v:float) -> void:
	mostrado=v
	numero.texto=NumeroPixelPlex.dinheiro(v)
	medir()

## Define o saldo. A primeira chamada entra direto; as seguintes rolam.
func definir(novo:float) -> void:
	if not iniciado or not is_inside_tree():
		iniciado=true;valor=novo;escrever(novo);return
	if is_equal_approx(novo,valor):return
	var caiu:=novo<valor
	valor=novo
	if rolagem!=null and rolagem.is_valid():rolagem.kill()
	rolagem=create_tween()
	rolagem.tween_method(escrever,mostrado,novo,.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	numero.cor=Color("ff9a86") if caiu else Color("d7f0a8")
	numero.queue_redraw()
	rolagem.tween_callback(func():numero.cor=tinta;numero.queue_redraw())
	ShowPlex.pular(self,4.0)

## Mostra o ganho subindo ao lado da placa.
func ganho(quantia:float) -> void:
	if not is_inside_tree() or quantia<=0.0:return
	var etiqueta:=NumeroPixelPlex.new("+"+NumeroPixelPlex.dinheiro(quantia).trim_prefix("$ "),2,Color("d7f0a8"))
	var fundo:=PanelContainer.new();fundo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fundo.add_theme_stylebox_override("panel",ShowPlex.estilo("fita",6,Color("2f4a2a")))
	fundo.add_child(etiqueta);add_child(fundo)
	fundo.position=Vector2(74,ALTURA+2)
	var t:=fundo.create_tween().set_parallel(true)
	t.tween_property(fundo,"position:y",ALTURA+22.0,1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(fundo,"modulate:a",0.0,.4).set_delay(1.0)
	t.chain().tween_callback(fundo.queue_free)
	ConfetePlex.estourar(self,get_global_transform_with_canvas()*Vector2(28,28),10,[Color("e8a237"),Color("f6cf6a"),Color("b5cf8a")],150.0)

func _draw() -> void:
	var ci:=get_canvas_item()
	var tabua:=Rect2(30,6,size.x-30,44)
	ShowPlex.ret(ci,tabua.position.x+2,tabua.end.y,tabua.size.x-4,4,Color(0.07,0.03,0.02,.4))
	ShowPlex.painel(ci,tabua,ShowPlex.MADEIRA,false,0,11)
	ShowPlex.tampa(ci,Rect2(tabua.end.x-12,tabua.position.y+2,10,tabua.size.y-4))
	ShowPlex.ret(ci,tabua.end.x-14,tabua.position.y+2,2,tabua.size.y-4,ShowPlex.TINTA)
	var visor:=Rect2(62,12,size.x-62-20,32)
	ShowPlex.bloco(ci,visor,ShowPlex.TINTA,ShowPlex.U)
	ShowPlex.ret(ci,visor.position.x+2,visor.position.y+2,visor.size.x-4,visor.size.y-4,Color("20150f"))
	ShowPlex.ret(ci,visor.position.x+2,visor.position.y+2,visor.size.x-4,2,Color("5f432f"))
	ShowPlex.medalhao(ci,Vector2(28,28),28)
