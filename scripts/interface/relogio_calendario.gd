class_name RelogioCalendarioPlex
extends Control
## Placa do tempo: uma tábua pendurada num trilho, com o calendário de
## folhas à esquerda, o visor da hora à direita e o medalhão do período do
## dia preso ao canto. Quando o dia vira, a folha velha se solta e cai.

const SEMANA=["DOMINGO","SEGUNDA","TERÇA","QUARTA","QUINTA","SEXTA","SÁBADO"]
const FOLHA:=Rect2(56,30,76,92)
var dia:=Label.new()
var mes:=Label.new()
var hora:=Label.new()
var ano:=Label.new()
var semana:=Label.new()
var periodo:=Label.new()
var medalhao:=Vector2(30,54)

func _init() -> void:
	custom_minimum_size=Vector2(272,140)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for l in [dia,mes,hora,ano,semana,periodo]:
		add_child(l)
		l.mouse_filter=Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	configurar(semana,Vector2(FOLHA.position.x,FOLHA.position.y+2),Vector2(FOLHA.size.x,16),9,ShowPlex.CREME,"forte")
	configurar(dia,Vector2(FOLHA.position.x,FOLHA.position.y+20),Vector2(FOLHA.size.x,48),38,ShowPlex.NANQUIM,"titulo")
	configurar(mes,Vector2(FOLHA.position.x,FOLHA.position.y+70),Vector2(FOLHA.size.x,16),10,ShowPlex.SEPIA,"forte")
	configurar(periodo,Vector2(144,30),Vector2(116,16),10,ShowPlex.AMBAR,"forte")
	configurar(ano,Vector2(144,100),Vector2(116,16),11,ShowPlex.CREME,"forte")
	hora.hide()

func configurar(l:Label, pos:Vector2, dimensao:Vector2, tamanho:int, cor:Color, fonte:String) -> void:
	l.position=pos
	l.size=dimensao
	l.add_theme_font_override("font",VintagePlex.fonte(fonte))
	l.add_theme_font_size_override("font_size",tamanho)
	l.add_theme_color_override("font_color",cor)

func atualizar(c:CalendarioPlex) -> void:
	var d:=c.data()
	var novo:="%02d"%d.dia
	if dia.text!=novo:
		if not dia.text.is_empty():soltar_folha(dia.text,semana.text,mes.text)
		dia.text=novo
	mes.text=IdiomaPlex.traduzir(CalendarioPlex.MESES[int(d.mes)-1]).to_upper()
	semana.text=IdiomaPlex.traduzir(SEMANA[int(d.semana)])
	ano.text=IdiomaPlex.traduzir("ANO ")+str(d.ano)
	periodo.text=IdiomaPlex.traduzir("MADRUGADA" if c.minutos<360 else "MANHÃ" if c.minutos<720 else "TARDE" if c.minutos<1080 else "NOITE")
	var nova:=c.hora()
	if hora.text!=nova:
		hora.text=nova
		queue_redraw()

## A folha do dia que passou se solta do bloco, gira um pouco e some.
func soltar_folha(numero:String, dia_semana:String, nome_mes:String) -> void:
	if not is_inside_tree():return
	var folha:=FolhaSolta.new()
	folha.numero=numero;folha.semana=dia_semana;folha.mes=nome_mes
	folha.position=FOLHA.position;folha.size=FOLHA.size;folha.pivot_offset=Vector2(FOLHA.size.x*.5,0)
	add_child(folha)
	var t:=folha.create_tween().set_parallel(true)
	t.tween_property(folha,"position",FOLHA.position+Vector2(-18,96),.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(folha,"rotation",-.5,.7)
	t.tween_property(folha,"modulate:a",0.0,.25).set_delay(.45)
	t.chain().tween_callback(folha.queue_free)
	ShowPlex.pular(dia,4.0)

static func pintar_folha(ci:RID, r:Rect2) -> void:
	ShowPlex.bloco(ci,r,ShowPlex.NANQUIM,ShowPlex.U)
	ShowPlex.ret(ci,r.position.x+2,r.position.y+2,r.size.x-4,r.size.y-4,ShowPlex.CREME)
	ShowPlex.ret(ci,r.position.x+2,r.position.y+2,r.size.x-4,18,ShowPlex.VINHO)
	ShowPlex.ret(ci,r.position.x+2,r.position.y+2,r.size.x-4,2,Color("b03a3a"))
	ShowPlex.ret(ci,r.position.x+2,r.position.y+20,r.size.x-4,2,Color("5c1419"))
	ShowPlex.ret(ci,r.position.x+8,r.end.y-24,r.size.x-16,2,Color("d9b97a"))

func _draw() -> void:
	var ci:=get_canvas_item()
	var u:=ShowPlex.U
	# trilho e correntes
	ShowPlex.bloco(ci,Rect2(48,0,220,10),ShowPlex.TINTA,u)
	ShowPlex.madeira(ci,Rect2(50,2,216,6),ShowPlex.MADEIRA_ESCURA)
	for x in [76.0,240.0]:ShowPlex.corrente(ci,x,10,20)
	# tábua
	var tabua:=Rect2(40,18,232,116)
	ShowPlex.ret(ci,tabua.position.x+2,tabua.end.y,tabua.size.x-4,4,Color(0.07,0.03,0.02,.4))
	ShowPlex.painel(ci,tabua,ShowPlex.MADEIRA,false,38,7)
	# bloco de folhas: duas de trás aparecendo, argolas em cima
	for i in [2,1]:
		var atras:=Rect2(FOLHA.position+Vector2(i*3,i*3),FOLHA.size)
		ShowPlex.bloco(ci,atras,ShowPlex.NANQUIM,u)
		ShowPlex.ret(ci,atras.position.x+2,atras.position.y+2,atras.size.x-4,atras.size.y-4,Color("e0c48e") if i==1 else Color("cdb07a"))
	pintar_folha(ci,FOLHA)
	for x in [FOLHA.position.x+16,FOLHA.end.x-22]:
		ShowPlex.ret(ci,x,FOLHA.position.y-8,6,14,ShowPlex.TINTA)
		ShowPlex.ret(ci,x+2,FOLHA.position.y-6,2,10,Color("c9d6d4"))
	# visor da hora
	var visor:=Rect2(144,50,116,44)
	ShowPlex.bloco(ci,visor,ShowPlex.TINTA,u)
	ShowPlex.ret(ci,visor.position.x+2,visor.position.y+2,visor.size.x-4,visor.size.y-4,Color("20150f"))
	ShowPlex.ret(ci,visor.position.x+2,visor.position.y+2,visor.size.x-4,2,Color("5f432f"))
	var largura:=0.0
	for simbolo in hora.text:largura+=(1.0 if simbolo==":" else 5.0)*3.0+3.0
	var x:=roundf(visor.position.x+(visor.size.x-largura+3.0)*.5)
	for simbolo in hora.text:
		var linhas:Array=NumeroPixelPlex.GLIFOS.get(simbolo,[])
		for y in linhas.size():
			for coluna in str(linhas[y]).length():
				if str(linhas[y])[coluna]=="1":draw_rect(Rect2(x+coluna*3,visor.position.y+12+y*3,3,3),Color("f3c46f"))
		x+=(1.0 if simbolo==":" else 5.0)*3.0+3.0
	# medalhão do período do dia
	ShowPlex.medalhao(ci,medalhao,28,ShowPlex.MADEIRA,Color("3b2a25"))

class FolhaSolta extends Control:
	var numero:=""
	var semana:=""
	var mes:=""
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		RelogioCalendarioPlex.pintar_folha(get_canvas_item(),Rect2(Vector2.ZERO,size))
		var titulo:=VintagePlex.fonte("titulo");var forte:=VintagePlex.fonte("forte")
		draw_string(forte,Vector2(0,15),semana,HORIZONTAL_ALIGNMENT_CENTER,size.x,9,ShowPlex.CREME)
		draw_string(titulo,Vector2(0,58),numero,HORIZONTAL_ALIGNMENT_CENTER,size.x,38,ShowPlex.NANQUIM)
		draw_string(forte,Vector2(0,82),mes,HORIZONTAL_ALIGNMENT_CENTER,size.x,10,ShowPlex.SEPIA)
