class_name TransicaoNoitePlex
extends CanvasLayer
## Passagem da noite no estilo de lanchonete. Uma cortina vermelha varre a
## tela em diagonal; no meio, uma nuvem com a lua, o relógio rolando até as
## 06:00 e as letras "BOA NOITE", que viram "BOM DIA" quando o sol sobe.
## Depois a cortina escorre para o outro lado.

const DURACAO:=3.0
var jogo:Node
var raiz:=Control.new()
var cortina:=Cortina.new()
var miolo:=Control.new()
var nuvem:=CartazDinerPlex.Nuvem.new()
var palavra:=DinerPlex.Quadradinhos.new("Boa noite",40.0)
var relogio:=NumeroPixelPlex.new("00:00",6,DinerPlex.PRETO)
var lua:=IconeHudPlex.new("noite")
var sol:=IconeHudPlex.new("sol")
var tempo:=0.0
var realizado:=false
var acao:Callable
var minutos_inicio:=0.0
var minutos:=0.0:
	set(v):
		minutos=v
		relogio.texto="%02d:%02d"%[int(v/60.0)%24,int(v)%60]

func iniciar(cena:Node,aplicar:Callable) -> void:
	jogo=cena;acao=aplicar;layer=200;process_mode=Node.PROCESS_MODE_ALWAYS;jogo.pausar("noite")
	add_child(raiz);raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.mouse_filter=Control.MOUSE_FILTER_STOP
	raiz.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.add_child(cortina)
	raiz.add_child(miolo);miolo.mouse_filter=Control.MOUSE_FILTER_IGNORE;miolo.modulate.a=0.0
	var tela:=raiz.get_viewport_rect().size
	var r:=Rect2(DinerPlex.par(tela.x*.5-300.0),DinerPlex.par(tela.y*.5-110.0),600,240)
	nuvem.com_xadrez=false
	miolo.add_child(nuvem);nuvem.position=r.position;nuvem.size=r.size
	miolo.add_child(palavra)
	for icone in [lua,sol]:
		icone.escala_pixel=4.0;icone.custom_minimum_size=Vector2(96,96);icone.size=Vector2(96,96)
		icone.position=Vector2(r.position.x+86.0,r.position.y+72.0);miolo.add_child(icone)
	sol.modulate.a=0.0
	miolo.add_child(relogio);relogio.alinhamento=HORIZONTAL_ALIGNMENT_CENTER
	relogio.position=Vector2(r.position.x+230.0,r.position.y+92.0);relogio.size=Vector2(300,56)
	centralizar_palavra(r)
	minutos_inicio=float(jogo.calendario.minutos);minutos=minutos_inicio
	var t:=create_tween()
	t.tween_property(cortina,"entrada",1.0,.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(miolo,"modulate:a",1.0,.14)
	t.tween_property(self,"minutos",360.0,.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(amanhecer.bind(r))
	t.tween_interval(.85)
	t.tween_property(miolo,"modulate:a",0.0,.14)
	t.tween_property(cortina,"saida",1.0,.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	t.tween_callback(func():jogo.retomar("noite");queue_free())

func centralizar_palavra(r:Rect2) -> void:
	palavra.reset_size()
	palavra.position=Vector2(DinerPlex.par(r.position.x+(r.size.x-palavra.custom_minimum_size.x)*.5),DinerPlex.par(r.position.y-70.0))

## O dia vira: aplica o salto de horário, troca a lua pelo sol e festeja.
func amanhecer(r:Rect2) -> void:
	if not realizado:realizado=true;acao.call()
	minutos=360.0
	palavra.palavra="Bom dia"
	centralizar_palavra(r)
	ShowPlex.pular(palavra,8.0)
	var t:=create_tween().set_parallel(true)
	t.tween_property(lua,"position:y",lua.position.y+40.0,.25);t.tween_property(lua,"modulate:a",0.0,.2)
	t.tween_property(sol,"position:y",sol.position.y,.3).from(sol.position.y+40.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(sol,"modulate:a",1.0,.2)
	ConfetePlex.estourar(self,Vector2(r.position.x+r.size.x*.5,r.position.y),50)

func _input(_evento:InputEvent) -> void:get_viewport().set_input_as_handled()
func _exit_tree() -> void:
	if is_instance_valid(jogo):jogo.retomar("noite")

## Cortina vermelha que cobre a tela em diagonal, com barrados de xadrez.
class Cortina extends Control:
	var entrada:=0.0:
		set(v):
			entrada=v;queue_redraw()
	var saida:=0.0:
		set(v):
			saida=v;queue_redraw()
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		var ci:=get_canvas_item()
		var inclinacao:=size.y*.35
		var total:=size.x+inclinacao
		var y:=0.0
		while y<size.y:
			var recuo:=inclinacao*(1.0-y/size.y)
			var x0:=DinerPlex.par(maxf(0.0,total*saida-recuo))
			var x1:=DinerPlex.par(minf(size.x,total*entrada-recuo))
			if x1>x0:
				ShowPlex.ret(ci,x0,y,x1-x0,4,Color("8f1a22"))
				# faixas mais claras, como toalha listrada
				if int(y/44.0)%2==0:ShowPlex.ret(ci,x0,y,x1-x0,4,Color("a8232b"))
			y+=4.0
		var x_ini:=DinerPlex.par(maxf(0.0,total*saida))
		var x_fim:=DinerPlex.par(minf(size.x,total*entrada-inclinacao))
		if x_fim-x_ini>44.0:
			DinerPlex.xadrez(ci,Rect2(x_ini,0,x_fim-x_ini,44),22)
			DinerPlex.xadrez(ci,Rect2(x_ini,size.y-44,x_fim-x_ini,44),22,DinerPlex.CREME,DinerPlex.VERMELHO)
			ShowPlex.ret(ci,x_ini,44,x_fim-x_ini,4,DinerPlex.PRETO)
			ShowPlex.ret(ci,x_ini,size.y-48,x_fim-x_ini,4,DinerPlex.PRETO)
