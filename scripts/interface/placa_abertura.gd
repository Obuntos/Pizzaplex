class_name PlacaAberturaPlex
extends Control
## Placa de OPEN / CLOSED pendurada por correntes. Vira ao trocar de lado
## e solta confete quando o restaurante abre.

var aberto:=false
var trancado:=false
var iniciada:=false
var virando:Tween

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(136,56)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

## Troca o estado. Depois da primeira vez, a placa vira para mostrar o outro lado.
func definir(esta_aberto:bool, esta_trancado:bool) -> void:
	if iniciada and esta_aberto==aberto and esta_trancado==trancado:return
	var mudou_lado:=iniciada and esta_aberto!=aberto
	if not mudou_lado or not is_inside_tree():
		aberto=esta_aberto;trancado=esta_trancado;iniciada=true;queue_redraw();return
	pivot_offset=size*.5
	if virando!=null and virando.is_valid():virando.kill()
	virando=create_tween()
	virando.tween_property(self,"scale:x",0.0,.09)
	virando.tween_callback(func():
		aberto=esta_aberto;trancado=esta_trancado;queue_redraw())
	virando.tween_property(self,"scale:x",1.0,.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if esta_aberto:virando.tween_callback(func():ConfetePlex.sobre(self,30))

func _draw() -> void:
	var ci:=get_canvas_item()
	for x in [26.0,size.x-26.0]:ShowPlex.corrente(ci,x,-10,10)
	var cor:=Color("4f6a3f") if aberto else Color("8b2026")
	if trancado:cor=Color("5d5a52")
	var r:=Rect2(0,8,size.x,size.y-12)
	ShowPlex.ret(ci,4,r.end.y,size.x-8,4,Color(0.07,0.03,0.02,.4))
	ShowPlex.placa(ci,r,ShowPlex.MADEIRA,cor,3)
	var palavra:="OPEN" if aberto and not trancado else "CLOSED"
	var fonte:=VintagePlex.fonte("titulo")
	draw_string_outline(fonte,Vector2(0,r.position.y+29),palavra,HORIZONTAL_ALIGNMENT_CENTER,size.x,18,4,ShowPlex.TINTA)
	draw_string(fonte,Vector2(0,r.position.y+29),palavra,HORIZONTAL_ALIGNMENT_CENTER,size.x,18,ShowPlex.CREME)
	if trancado:
		var c:=size.x*.5
		ShowPlex.ret(ci,c-5,0,10,8,ShowPlex.TINTA);ShowPlex.ret(ci,c-3,2,6,4,Color("d9c591"))
