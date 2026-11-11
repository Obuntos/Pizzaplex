class_name PlacaAberturaPlex
extends Control
var aberto:=false
var trancado:=false
func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(132,52)
func _draw() -> void:
	var centro:=size.x*.5
	var madeira:=Color("6b4e36");var luz:=Color("ceb685");var sombra:=Color("342d27")
	for x in [centro-38,centro+38]:
		draw_rect(Rect2(x-1,-14,4,4),sombra);draw_rect(Rect2(x,-13,2,2),luz)
		draw_line(Vector2(x+1,-10),Vector2(x+1,12),sombra,3);draw_line(Vector2(x+1,-10),Vector2(x+1,12),luz,1)
	draw_rect(Rect2(3,12,size.x-6,36),sombra);draw_rect(Rect2(5,10,size.x-10,38),madeira)
	draw_rect(Rect2(7,11,size.x-14,2),luz);draw_rect(Rect2(7,46,size.x-14,2),Color("47372d"))
	var fundo:=Color("425d50") if aberto else Color("73493d")
	if trancado:fundo=Color("53524a")
	draw_rect(Rect2(9,16,size.x-18,27),fundo);draw_rect(Rect2(10,17,size.x-20,1),fundo.lightened(.2))
	for x in [7,size.x-9]:
		for y in [15,42]:draw_rect(Rect2(x,y,2,2),luz)
	var palavra:="OPEN" if aberto and not trancado else "CLOSED"
	var fonte:=VintagePlex.fonte("titulo");var largura:=fonte.get_string_size(palavra,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	draw_string(fonte,Vector2(roundf(centro-largura*.5),37),palavra,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f1dfb9"))
	if trancado:draw_rect(Rect2(centro-3,7,6,5),Color("d9c591"));draw_rect(Rect2(centro-1,9,2,2),sombra)
