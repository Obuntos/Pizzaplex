class_name BalaoMenuPlex
extends Control

var cor:=Color("30211d")
var foco:=false
var apertado:=false
var direcao:=Vector2.DOWN
var cauda:=true

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	show_behind_parent=true

func ligar(b:BaseButton) -> void:
	b.mouse_entered.connect(func():foco=true;queue_redraw())
	b.mouse_exited.connect(func():foco=false;apertado=false;queue_redraw())
	b.button_down.connect(func():apertado=true;queue_redraw())
	b.button_up.connect(func():apertado=false;queue_redraw())

func _draw() -> void:
	var w:=size.x;var h:=size.y
	var escuro:=Color("251914");var madeira:=Color("6b4e36");var luz:=Color("ceb685");var sombra:=Color("47372d")
	var fundo:=cor.lightened(.14) if foco else cor
	if apertado:fundo=cor.darkened(.18)
	var d:=Vector2(0,1) if apertado else Vector2.ZERO
	draw_rect(Rect2(Vector2(3,4),Vector2(w,h)),Color(0,0,0,.32))
	if cauda:desenhar_cauda(w,h,escuro,madeira,fundo)
	draw_rect(Rect2(d,Vector2(w,h)),escuro)
	draw_rect(Rect2(d+Vector2(2,2),Vector2(w-4,h-4)),madeira.lightened(.12) if foco else madeira)
	draw_rect(Rect2(d+Vector2(4,3),Vector2(w-8,1)),luz)
	draw_rect(Rect2(d+Vector2(4,h-4),Vector2(w-8,1)),sombra)
	draw_rect(Rect2(d+Vector2(5,5),Vector2(w-10,h-10)),escuro)
	draw_rect(Rect2(d+Vector2(6,6),Vector2(w-12,h-12)),fundo)
	draw_rect(Rect2(d+Vector2(7,7),Vector2(w-14,1)),fundo.lightened(.22))
	draw_rect(Rect2(d+Vector2(7,h-8),Vector2(w-14,1)),fundo.darkened(.3))
	for p in [Vector2(3,3),Vector2(w-5,3),Vector2(3,h-5),Vector2(w-5,h-5)]:
		draw_rect(Rect2(d+p,Vector2(2,2)),luz)
		draw_rect(Rect2(d+p+Vector2(1,1),Vector2(1,1)),sombra)
	if foco:
		draw_rect(Rect2(d+Vector2(6,6),Vector2(w-12,1)),Color("dfb16a"))
		draw_rect(Rect2(d+Vector2(6,h-7),Vector2(w-12,1)),Color("dfb16a"))

func desenhar_cauda(w:float,h:float,escuro:Color,madeira:Color,fundo:Color) -> void:
	var base:=Vector2(w*.5,h) if direcao.y>=0 else Vector2(w*.5,0)
	if absf(direcao.x)>absf(direcao.y)*1.6:base=Vector2(w if direcao.x>0 else 0.0,h*.5)
	var passo:=Vector2(signf(direcao.x) if absf(direcao.x)>absf(direcao.y)*1.6 else 0.0,0.0 if absf(direcao.x)>absf(direcao.y)*1.6 else signf(direcao.y) if direcao.y!=0 else 1.0)
	var lado:=Vector2(-passo.y,passo.x)
	for i in 6:
		var largura:=float(6-i)
		var centro:=base+passo*float(i)
		for k in range(-int(largura),int(largura)+1):
			var p:=(centro+lado*float(k)).floor()
			var borda:=absi(k)>=int(largura)-1 or i==5
			draw_rect(Rect2(p,Vector2.ONE),escuro if borda else (madeira if absi(k)>=int(largura)-2 else fundo))
