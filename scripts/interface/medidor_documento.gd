class_name MedidorDocumentoPlex
extends Control
var cor:=Color("6f8a3a")
var valor:=0.0
var value:float:
	get:return valor
	set(v):valor=clampf(v,0,100);queue_redraw()
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var largura:=size.x*valor/100.0
	for x in range(0,ceili(largura),10):draw_rect(Rect2(x,0,minf(8,largura-x),size.y),cor)
