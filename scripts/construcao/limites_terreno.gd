class_name LimitesTerrenoPlex
extends Node2D

var editor: EditorPlex
var assinatura := -1

func atualizar() -> void:
	var ativa: bool = editor!=null and editor.construindo()
	visible = ativa
	if not ativa:
		assinatura = -1
		return
	var atual := hash([TerrenoPlex.area(editor.planta),GradePlex.visao])
	if assinatura==atual: return
	assinatura = atual
	queue_redraw()

func _draw() -> void:
	if editor==null or not editor.construindo(): return
	var limite := TerrenoPlex.area(editor.planta)
	for y in range(limite.position.y,limite.end.y):
		for x in range(limite.position.x,limite.end.x):
			var celula := Vector2i(x,y)
			if not TerrenoPlex.borda(editor.planta,celula): continue
			var inicio := Vector2(celula)-Vector2(.5,.5)
			var fim := Vector2(celula)+Vector2(.5,.5)
			if x==limite.position.x: fim.x+=.25
			if x==limite.end.x-1: inicio.x-=.25
			if y==limite.position.y: fim.y+=.25
			if y==limite.end.y-1: inicio.y-=.25
			var poligono: PackedVector2Array=[]
			for ponto in [inicio,Vector2(fim.x,inicio.y),fim,Vector2(inicio.x,fim.y)]: poligono.append(GradePlex.projetar(ponto))
			draw_colored_polygon(poligono,Color(.86,.17,.13,.5))
			draw_polyline(poligono+PackedVector2Array([poligono[0]]),Color(1,.36,.25,.85),1.0)

