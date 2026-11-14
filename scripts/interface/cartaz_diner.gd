class_name CartazDinerPlex
extends CanvasLayer
## Cartazes animados no estilo de lanchonete, da mesma família da pausa.
## `abertura` anuncia o começo do expediente e some sozinho; `resumo` fecha
## o dia (ou a noite) numa nuvem com os números rolando até o total.

var jogo:Node
var raiz:=Control.new()
var faixa:=Faixa.new()
var cabeca:=DinerPlex.Silhueta.new()
var letreiro:DinerPlex.Letreiro
var palavra:DinerPlex.Quadradinhos
var nuvem:=Nuvem.new()
var legenda:=Label.new()
var continuar:BotaoBarra
var itens:Array[Item]=[]
var modal:=false
var fechando:=false

## Anúncio do começo do expediente. Não trava o jogo nem pega o mouse.
static func abertura(cena:Node) -> CartazDinerPlex:
	var c:=CartazDinerPlex.new()
	cena.add_child(c)
	c.montar(cena,"ABERTO","Bom dia!",false)
	c.tocar_abertura()
	return c

## Resumo em nuvem. `linhas` traz dicionários com nome, valor (número ou
## texto), formato ("dinheiro", "inteiro" ou "texto") e alerta.
static func resumo(cena:Node, tela:String, titulo:String, linhas:Array, festa:bool=false) -> CartazDinerPlex:
	var c:=CartazDinerPlex.new()
	cena.add_child(c)
	c.montar(cena,tela,titulo,true)
	c.tocar_resumo(linhas,festa)
	return c

func montar(cena:Node, tela:String, titulo:String, bloquear:bool) -> void:
	jogo=cena;modal=bloquear;layer=124;process_mode=Node.PROCESS_MODE_ALWAYS
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter=Control.MOUSE_FILTER_STOP if modal else Control.MOUSE_FILTER_IGNORE
	raiz.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(raiz)
	faixa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);faixa.escurecer=.55 if modal else .0;raiz.add_child(faixa)
	raiz.add_child(nuvem);nuvem.hide()
	raiz.add_child(cabeca)
	letreiro=DinerPlex.Letreiro.new(tela);raiz.add_child(letreiro)
	letreiro.definir_nome(str(jogo.operacao.nome))
	palavra=DinerPlex.Quadradinhos.new(titulo,44.0 if not modal else 32.0);raiz.add_child(palavra)
	raiz.add_child(legenda)
	legenda.add_theme_font_override("font",VintagePlex.fonte("titulo"));legenda.add_theme_font_size_override("font_size",20)
	legenda.add_theme_color_override("font_color",DinerPlex.CREME);legenda.add_theme_color_override("font_outline_color",DinerPlex.PRETO);legenda.add_theme_constant_override("outline_size",6)
	legenda.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var admin:PersonagemPlex=jogo.controle.administrador()
	var tela_h:=raiz.get_viewport_rect().size.y
	cabeca.mostrar(RetratoEquipePlex.criar(admin) if is_instance_valid(admin) else null,tela_h*(.5 if modal else .36))
	if modal:jogo.pausar("cartaz")

func tamanho() -> Vector2:
	return raiz.get_viewport_rect().size

func tocar_abertura() -> void:
	var t:=tamanho()
	var d:Dictionary=jogo.calendario.data()
	legenda.text="%s  %02d  ·  %s"%[tr(RelogioCalendarioPlex.SEMANA[int(d.semana)]).capitalize(),int(d.dia),tr(CalendarioPlex.MESES[int(d.mes)-1])]
	letreiro.position=Vector2(DinerPlex.par(t.x*.24),DinerPlex.par(t.y*.2))
	palavra.reset_size()
	palavra.position=Vector2(DinerPlex.par(t.x*.27),DinerPlex.par(t.y*.2+150.0))
	legenda.reset_size();legenda.position=Vector2(DinerPlex.par(t.x*.27+6.0),DinerPlex.par(palavra.position.y+70.0))
	cabeca.position=Vector2(DinerPlex.par(maxf(16.0,t.x*.12-cabeca.size.x*.5)),DinerPlex.par(t.y*.2+20.0))
	faixa.altura=Rect2(0,DinerPlex.par(t.y*.16),t.x,DinerPlex.par(t.y*.44))
	# entrada: a faixa varre a tela, a cabeça salta e as letras deslizam
	var a:=create_tween().set_parallel(true)
	a.tween_property(faixa,"entrada",1.0,.3).from(0.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	for peca in [letreiro,palavra,legenda]:
		var alvo:float=peca.position.x
		peca.modulate.a=0.0
		a.tween_property(peca,"position:x",alvo,.3).from(alvo+90.0).set_delay(.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		a.tween_property(peca,"modulate:a",1.0,.12).set_delay(.12)
	cabeca.scale=Vector2(.3,.3)
	a.tween_property(cabeca,"scale",Vector2.ONE,.3).set_delay(.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	a.tween_callback(func():ConfetePlex.estourar(self,Vector2(t.x*.5,t.y*.42),46)).set_delay(.4)
	# saída: tudo escorre para a direita
	var s:=create_tween()
	s.tween_interval(2.1)
	s.tween_property(faixa,"saida",1.0,.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	s.parallel().tween_property(raiz,"modulate:a",0.0,.2).set_delay(.14)
	s.tween_callback(queue_free)

func tocar_resumo(linhas:Array, festa:bool) -> void:
	var t:=tamanho()
	letreiro.position=Vector2(DinerPlex.par(t.x*.27),DinerPlex.par(t.y*.035))
	var altura_nuvem:=DinerPlex.par(maxf(250.0,130.0+linhas.size()*38.0))
	var r:=Rect2(DinerPlex.par(t.x*.36),DinerPlex.par(t.y*.24),DinerPlex.par(t.x*.56),altura_nuvem)
	nuvem.position=r.position;nuvem.size=r.size;nuvem.show()
	var miolo:=DinerPlex.miolo_nuvem(r)
	palavra.reset_size()
	palavra.position=Vector2(DinerPlex.par(miolo.end.x-palavra.custom_minimum_size.x-24.0),DinerPlex.par(r.position.y+22.0))
	cabeca.position=Vector2(DinerPlex.par(maxf(24.0,t.x*.165-cabeca.size.x*.5)),DinerPlex.par(t.y-cabeca.size.y-t.y*.07))
	faixa.altura=Rect2(0,0,t.x,t.y);faixa.inclinada=true
	legenda.hide()
	for i in linhas.size():
		var dados:Dictionary=linhas[i]
		var item:=Item.new(str(dados.nome),dados.get("valor",0),str(dados.get("formato","inteiro")),bool(dados.get("alerta",false)))
		item.position=Vector2(DinerPlex.par(miolo.position.x+40.0),DinerPlex.par(r.position.y+78.0+i*38.0))
		item.size=Vector2(DinerPlex.par(miolo.size.x-90.0),32)
		raiz.add_child(item);itens.append(item)
	continuar=BotaoBarra.new("Continuar")
	continuar.pressed.connect(fechar)
	raiz.add_child(continuar)
	continuar.size=Vector2(260,48)
	continuar.position=Vector2(DinerPlex.par(r.end.x-continuar.size.x-60.0),DinerPlex.par(r.end.y+26.0))
	continuar.grab_focus.call_deferred()
	var a:=create_tween().set_parallel(true)
	a.tween_property(faixa,"entrada",1.0,.3).from(0.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var alvo_cabeca:=cabeca.position.x
	a.tween_property(cabeca,"position:x",alvo_cabeca,.28).from(alvo_cabeca-120.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var alvo_letreiro:=letreiro.position.y
	a.tween_property(letreiro,"position:y",alvo_letreiro,.3).from(alvo_letreiro-90.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for peca in [nuvem,palavra,continuar]:
		peca.modulate.a=0.0
		a.tween_property(peca,"modulate:a",1.0,.14).set_delay(.12)
	var alvo_nuvem:=nuvem.position.x
	a.tween_property(nuvem,"position:x",alvo_nuvem,.3).from(alvo_nuvem+70.0).set_delay(.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in itens.size():itens[i].revelar(.3+i*.16)
	if festa:a.tween_callback(func():ConfetePlex.estourar(self,Vector2(r.position.x+r.size.x*.5,r.position.y+40.0),60)).set_delay(.45+itens.size()*.16)

func fechar() -> void:
	if fechando:return
	fechando=true
	var s:=create_tween()
	s.tween_property(raiz,"modulate:a",0.0,.16)
	s.tween_callback(queue_free)

func _unhandled_input(e:InputEvent) -> void:
	if not modal:return
	if e is InputEventKey and e.pressed and e.keycode in [KEY_ESCAPE,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
		get_viewport().set_input_as_handled();fechar()

func _exit_tree() -> void:
	if modal and is_instance_valid(jogo):jogo.retomar("cartaz")


## Faixa vermelha de fundo. `entrada` e `saida` vão de 0 a 1 e fazem a
## faixa varrer a tela em diagonal, em degraus.
class Faixa extends Control:
	var entrada:=0.0:
		set(v):
			entrada=v;queue_redraw()
	var saida:=0.0:
		set(v):
			saida=v;queue_redraw()
	var altura:=Rect2()
	var inclinada:=false
	var escurecer:=0.0
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		var ci:=get_canvas_item()
		var visivel:=entrada*(1.0-saida)
		if escurecer>0.0:ShowPlex.ret(ci,0,0,size.x,size.y,Color(.36,.05,.07,escurecer*visivel))
		if inclinada:
			# no resumo, a faixa fica à esquerda, atrás da cabeça, como na pausa
			var y:=0.0
			while y<size.y:
				ShowPlex.ret(ci,0,y,DinerPlex.par((size.x*.3-y*.12)*visivel),2,Color(.62,.1,.13,.86))
				y+=2.0
			return
		# na abertura, uma fita atravessa a tela de ponta a ponta
		var inclinacao:=altura.size.y*.5
		var total:=size.x+inclinacao
		var y2:=0.0
		while y2<altura.size.y:
			var recuo:=inclinacao*(y2/altura.size.y)
			var x0:=DinerPlex.par(maxf(0.0,total*saida-recuo))
			var x1:=DinerPlex.par(minf(size.x,total*entrada-recuo))
			if x1>x0:ShowPlex.ret(ci,x0,altura.position.y+y2,x1-x0,2,Color(.62,.1,.13,.9))
			y2+=2.0
		var largura:=DinerPlex.par(minf(size.x,total*entrada)-maxf(0.0,total*saida))
		if largura>44.0:
			var inicio:=DinerPlex.par(maxf(0.0,total*saida))
			DinerPlex.xadrez(ci,Rect2(inicio,altura.position.y-22.0,largura,22),22)
			DinerPlex.xadrez(ci,Rect2(inicio,altura.end.y,largura,22),22,DinerPlex.CREME,DinerPlex.VERMELHO)
			ShowPlex.ret(ci,inicio,altura.position.y-24.0,largura,2,DinerPlex.PRETO)
			ShowPlex.ret(ci,inicio,altura.end.y+22.0,largura,2,DinerPlex.PRETO)


class Nuvem extends Control:
	var miolo:=DinerPlex.CREME
	var com_xadrez:=true
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		var r:=Rect2(Vector2.ZERO,size)
		if com_xadrez:DinerPlex.xadrez(get_canvas_item(),Rect2(DinerPlex.par(size.x*.42),-66,DinerPlex.par(size.x*.5),132),22)
		DinerPlex.nuvem_cheia(get_canvas_item(),r,miolo,DinerPlex.VERMELHO,0)


## Linha do resumo: o nome e uma pílula com o valor, que rola até o total.
class Item extends Control:
	var nome:=""
	var formato:="inteiro"
	var alerta:=false
	var alvo:Variant=0
	var mostrado:=0.0:
		set(v):
			mostrado=v;queue_redraw()
	func _init(titulo:String, valor:Variant, tipo:String, vermelho:bool) -> void:
		nome=titulo;alvo=valor;formato=tipo;alerta=vermelho
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		modulate.a=0.0
	func revelar(atraso:float) -> void:
		var t:=create_tween().set_parallel(true)
		var destino:=position.x
		t.tween_property(self,"modulate:a",1.0,.12).set_delay(atraso)
		t.tween_property(self,"position:x",destino,.2).from(destino+40.0).set_delay(atraso).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if formato!="texto":t.tween_property(self,"mostrado",float(alvo),.5).from(0.0).set_delay(atraso+.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	func texto_valor() -> String:
		match formato:
			"dinheiro":return NumeroPixelPlex.dinheiro(mostrado).replace("'"," ")
			"texto":return tr(str(alvo))
		return str(roundi(mostrado))
	func _draw() -> void:
		var ci:=get_canvas_item()
		draw_string(VintagePlex.fonte("titulo"),Vector2(0,23),tr(nome),HORIZONTAL_ALIGNMENT_LEFT,size.x-250.0,20,DinerPlex.PRETO)
		var caixa:=Rect2(size.x-240.0,2,240,28)
		DinerPlex.pilula(ci,caixa,DinerPlex.PRETO)
		DinerPlex.pilula(ci,caixa.grow(-2),DinerPlex.VERMELHO if alerta else DinerPlex.CREME)
		draw_string(VintagePlex.fonte("forte"),Vector2(caixa.position.x,caixa.position.y+19),texto_valor(),HORIZONTAL_ALIGNMENT_CENTER,caixa.size.x,15,DinerPlex.CREME if alerta else DinerPlex.PRETO)


## Botão em barra preta inclinada, a ação principal dos cartazes.
class BotaoBarra extends Button:
	var rotulo:=""
	func _init(valor:String) -> void:
		rotulo=valor
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for estado in ["normal","hover","pressed","hover_pressed","disabled","focus"]:add_theme_stylebox_override(estado,StyleBoxEmpty.new())
		mouse_entered.connect(func():ShowPlex.pular(self,4.0))
	func _draw() -> void:
		var ci:=get_canvas_item()
		var afunda:=4.0 if get_draw_mode()==DRAW_PRESSED or get_draw_mode()==DRAW_HOVER_PRESSED else 0.0
		DinerPlex.barra(ci,Rect2(6,6,size.x,size.y-6),DinerPlex.SANGRIA)
		DinerPlex.barra(ci,Rect2(afunda,afunda,size.x,size.y-6),DinerPlex.PRETO)
		var tinta:=DinerPlex.AMARELO if is_hovered() or has_focus() else DinerPlex.CREME
		draw_string(VintagePlex.fonte("titulo"),Vector2(afunda,30+afunda),tr(rotulo).to_upper(),HORIZONTAL_ALIGNMENT_CENTER,size.x,22,tinta)
