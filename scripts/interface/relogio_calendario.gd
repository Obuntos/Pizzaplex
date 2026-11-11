class_name RelogioCalendarioPlex
extends Control

const T=preload("res://scripts/interface/tema_hud.gd")
const E=preload("res://scripts/gestao/tema.gd")
const SEMANA=["DOMINGO","SEGUNDA","TERÇA","QUARTA","QUINTA","SEXTA","SÁBADO"]
const DIGITOS={"0":["11111","10001","10011","10101","11001","10001","11111"],"1":["00100","01100","00100","00100","00100","00100","01110"],"2":["11110","00001","00001","11110","10000","10000","11111"],"3":["11110","00001","00001","01110","00001","00001","11110"],"4":["10010","10010","10010","11111","00010","00010","00010"],"5":["11111","10000","10000","11110","00001","00001","11110"],"6":["01111","10000","10000","11110","10001","10001","01110"],"7":["11111","00001","00010","00100","01000","01000","01000"],"8":["01110","10001","10001","01110","10001","10001","01110"],"9":["01110","10001","10001","01111","00001","00001","11110"],":":["0","1","1","0","1","1","0"]}
var dia:=Label.new()
var mes:=Label.new()
var hora:=Label.new()
var ano:=Label.new()
var semana:=Label.new()
var periodo:=Label.new()

func _init() -> void:
	custom_minimum_size=Vector2(232,124)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for l in [dia,mes,hora,ano,semana,periodo]:
		add_child(l)
		l.mouse_filter=Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	configurar(dia,Vector2(12,39),Vector2(78,43),33,E.TINTA)
	configurar(mes,Vector2(12,84),Vector2(78,17),10,E.SUAVE)
	configurar(semana,Vector2(12,21),Vector2(78,16),9,E.PAPEL)
	configurar(ano,Vector2(102,86),Vector2(118,17),11,T.SUAVE)
	configurar(periodo,Vector2(102,20),Vector2(118,16),10,T.SUAVE)
	hora.hide()

func configurar(l: Label, pos: Vector2, dimensao: Vector2, tamanho: int, cor: Color) -> void:
	l.position=pos
	l.size=dimensao
	l.add_theme_font_size_override("font_size",tamanho)
	l.add_theme_color_override("font_color",cor)

func atualizar(c: CalendarioPlex) -> void:
	var d:=c.data()
	dia.text="%02d"%d.dia
	mes.text=IdiomaPlex.traduzir(CalendarioPlex.MESES[int(d.mes)-1]).to_upper()
	semana.text=IdiomaPlex.traduzir(SEMANA[int(d.semana)])
	ano.text=IdiomaPlex.traduzir("ANO ")+str(d.ano)
	periodo.text=IdiomaPlex.traduzir("MADRUGADA" if c.minutos<360 else "MANHÃ" if c.minutos<720 else "TARDE" if c.minutos<1080 else "NOITE")
	var nova:=c.hora()
	if hora.text!=nova:
		hora.text=nova
		queue_redraw()

func _draw() -> void:
	draw_style_box(T.caixa(T.FUNDO,T.LINHA,8),Rect2(0,6,232,116))
	draw_style_box(E.caixa(E.PAPEL,E.LINHA,0,5),Rect2(8,16,86,92))
	draw_rect(Rect2(12,20,78,18),E.VINHO)
	draw_rect(Rect2(14,105,74,2),Color("bb9466"))
	for x in [24,71]:
		draw_rect(Rect2(x,2,8,20),Color("251914"))
		draw_rect(Rect2(x+2,3,3,15),Color("8c603d"))
		draw_rect(Rect2(x+2,16,3,4),Color("4f281a"))
	draw_rect(Rect2(103,41,115,36),Color("20150f"))
	draw_rect(Rect2(104,42,113,2),Color("5f432f"))
	draw_rect(Rect2(111,81,98,1),T.LINHA)
	var x:=111.0
	for simbolo in hora.text:
		var linhas:Array=DIGITOS.get(simbolo,[])
		for y in linhas.size():
			for coluna in str(linhas[y]).length():
				if str(linhas[y])[coluna]=="1": draw_rect(Rect2(x+coluna*3,48+y*3,3,3),T.AMBAR)
		x+=(3.0 if simbolo==":" else 7.0)*3.0
