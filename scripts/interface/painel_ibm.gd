class_name PainelIBMPlex
extends PanelContainer

func _ready() -> void:resized.connect(queue_redraw)
func _draw() -> void:
	var c:=TemaIBMPlex.SUAVE
	for x in range(0,int(size.x),10):
		for y in [0,size.y-2]:draw_rect(Rect2(x,y,minf(6,size.x-x),2),c)
	for y in range(0,int(size.y),10):
		for x in [0,size.x-2]:draw_rect(Rect2(x,y,2,minf(6,size.y-y)),c)
