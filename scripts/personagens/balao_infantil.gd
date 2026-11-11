class_name BalaoInfantilPlex
extends Node2D
var cor:=Color("9b5b60")
func _ready() -> void:texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;use_parent_material=true;queue_redraw()
func _draw() -> void:
	draw_line(Vector2(-6,7),Vector2(0,-12),Color("9c9272"),1.0)
	for y in range(-23,-11):
		var largura:=5 if y in range(-21,-14) else 4 if y in [-22,-14] else 2
		draw_rect(Rect2(-largura,y,largura*2+1,1),cor.darkened(.25))
		draw_rect(Rect2(-largura+1,y,largura*2-1,1),cor)
	draw_rect(Rect2(-2,-21,2,3),cor.lightened(.22));draw_rect(Rect2(-1,-12,3,2),cor.darkened(.2))
